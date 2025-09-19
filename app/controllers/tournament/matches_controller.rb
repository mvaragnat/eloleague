# frozen_string_literal: true

module Tournament
  class MatchesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_tournament
    before_action :set_match, only: %i[show update reassign]
    before_action :authorize_update!, only: %i[update]
    before_action :authorize_admin!, only: %i[reassign]

    def index
      @matches = @tournament.matches.order(created_at: :desc)
    end

    def show
      @eligible_users = ::Tournament::SwapPairing.eligible_users_for(@tournament, @match)
    end

    def new
      unless can_add_match?
        return redirect_back(fallback_location: tournament_path(@tournament),
                             alert: t('tournaments.unauthorized', default: 'Not authorized'))
      end

      @game = Game::Event.new
      # Prebuild two participations. If current user is registered, default them as player A
      if Current.user && @tournament.registrations.exists?(user_id: Current.user.id)
        @game.game_participations.build(user: Current.user)
        @preselected_user = Current.user
        # Organizer can unselect themselves; regular participant cannot
        @preselected_removable = (@tournament.creator_id == Current.user.id)
      else
        @game.game_participations.build
        @preselected_user = nil
        @preselected_removable = true
      end
      # Always build the second slot
      @game.game_participations.build
    end

    def create
      unless can_add_match?
        return redirect_back(fallback_location: tournament_path(@tournament),
                             alert: t('tournaments.unauthorized', default: 'Not authorized'))
      end

      game = Game::Event.new(
        game_params.merge(
          played_at: Time.current,
          game_system: @tournament.game_system,
          tournament: @tournament,
          non_competitive: @tournament.non_competitive
        )
      )
      if game.save
        match = @tournament.matches.create!(
          a_user_id: game.game_participations.first.user_id,
          b_user_id: game.game_participations.second.user_id,
          game_event: game,
          non_competitive: @tournament.non_competitive,
          result: deduce_result(game.game_participations.first.score.to_i, game.game_participations.second.score.to_i)
        )

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove('no-matches-message'),
              turbo_stream.prepend('matches-list', svg_match_list_item(match)),
              turbo_stream.replace('modal', '')
            ]
          end
          format.html do
            # After creating match, redirect to Matches tab (index 1 due to Overview at 0)
            redirect_to tournament_path(@tournament, tab: 1),
                        notice: t('tournaments.match_updated', default: 'Match updated')
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { render :new, status: :unprocessable_content }
          format.html { render :new, status: :unprocessable_content }
        end
      end
    end

    def update
      a_score, b_score, a_secondary, b_secondary = fetch_scores

      unless scores_present?(a_score, b_score)
        flash.now[:alert] = t('tournaments.score_required', default: 'Both scores are required')
        return render :show, status: :unprocessable_content
      end

      if elimination_draw?(a_score, b_score)
        flash.now[:alert] = t('tournaments.draw_not_allowed', default: 'Draw is not allowed in elimination')
        return render :show, status: :unprocessable_content
      end

      success, event = if @match.game_event.present?
                         update_existing_event(@match.game_event, a_score, b_score, a_secondary, b_secondary)
                       else
                         build_new_event(a_score, b_score, a_secondary, b_secondary)
                       end

      return handle_event_failure(event) unless success

      finalize_match_update(a_score, b_score, event)
    end

    def reassign
      result = ::Tournament::SwapPairing.new(@tournament, @match, params[:slot], params[:user_id]).call
      unless result.ok
        return redirect_back(
          fallback_location: tournament_tournament_match_path(@tournament, @match),
          alert: t('tournaments.invalid_swap_target', default: 'Cannot swap with selected player')
        )
      end

      redirect_to tournament_tournament_match_path(@tournament, @match),
                  notice: t('tournaments.pairing_reassigned', default: 'Pairing updated')
    end

    private

    # Devise provides authentication; Current.user is set at ApplicationController

    def set_tournament
      @tournament = ::Tournament::Tournament.find(params[:tournament_id])
    end

    def set_match
      @match = @tournament.matches.find(params[:id])
    end

    def authorize_admin!
      return if Current.user && @tournament.creator_id == Current.user.id

      redirect_to tournament_tournament_match_path(@tournament, @match),
                  alert: t('tournaments.unauthorized', default: 'Not authorized')
    end

    def deduce_result(a_score, b_score)
      return 'draw' if a_score == b_score

      a_score > b_score ? 'a_win' : 'b_win'
    end

    def fetch_scores
      a_score = params.dig(:tournament_match, :a_score)
      b_score = params.dig(:tournament_match, :b_score)
      a_secondary = params.dig(:tournament_match, :a_secondary_score)
      b_secondary = params.dig(:tournament_match, :b_secondary_score)
      [a_score, b_score, a_secondary, b_secondary]
    end

    def scores_present?(a_score, b_score)
      a_score.present? && b_score.present?
    end

    def elimination_draw?(a_score, b_score)
      @tournament.elimination? && a_score.to_i == b_score.to_i
    end

    def update_existing_event(event, a_score, b_score, a_secondary, b_secondary)
      a_part = event.game_participations.find_by(user: @match.a_user)
      b_part = event.game_participations.find_by(user: @match.b_user)

      if a_part && b_part
        a_part.assign_attributes(score: a_score, secondary_score: a_secondary)
        b_part.assign_attributes(score: b_score, secondary_score: b_secondary)
      else
        rebuild_participations(event, a_score, b_score, a_secondary, b_secondary)
        # Re-lookup parts in case they are needed below (kept symmetrical with the logic above)
        a_part = event.game_participations.find { |p| p.user_id == @match.a_user_id }
        b_part = event.game_participations.find { |p| p.user_id == @match.b_user_id }
      end

      success = persist_event_and_parts?(event, a_part, b_part)
      [success, event]
    end

    def build_new_event(a_score, b_score, a_secondary, b_secondary)
      event = Game::Event.new(
        game_system: @tournament.game_system,
        played_at: Time.current,
        tournament: @tournament,
        non_competitive: @tournament.non_competitive
      )

      add_participations(event, a_score, b_score, a_secondary, b_secondary)
      [event.save, event]
    end

    def rebuild_participations(event, a_score, b_score, a_secondary, b_secondary)
      event.game_participations.destroy_all
      add_participations(event, a_score, b_score, a_secondary, b_secondary)
    end

    def add_participations(event, a_score, b_score, a_secondary, b_secondary)
      a_reg = @tournament.registrations.find_by(user: @match.a_user)
      b_reg = @tournament.registrations.find_by(user: @match.b_user)
      event.game_participations.build(user: @match.a_user, score: a_score, secondary_score: a_secondary,
                                      faction: a_reg&.faction)
      event.game_participations.build(user: @match.b_user, score: b_score, secondary_score: b_secondary,
                                      faction: b_reg&.faction)
    end

    def persist_event_and_parts?(event, a_part, b_part)
      ActiveRecord::Base.transaction do
        a_part&.save!
        b_part&.save!
        event.save!
        true
      end
    rescue ActiveRecord::ActiveRecordError
      false
    end

    def handle_event_failure(event)
      flash.now[:alert] = event.errors.full_messages.to_sentence
      render :show, status: :unprocessable_content
    end

    def finalize_match_update(a_score, b_score, event)
      @match.game_event ||= event
      @match.non_competitive = @tournament.non_competitive
      @match.result = deduce_result(a_score.to_i, b_score.to_i)
      @match.save!
      @match.propagate_winner_to_parent!
      redirect_to tournament_path(@tournament, tab: 1),
                  notice: t('tournaments.match_updated', default: 'Match updated')
    end

    # Parent propagation moved to Tournament::Match

    def authorize_update!
      # If already reported, only organizer/admin may change
      if @match.game_event.present? && @tournament.creator != Current.user
        redirect_to tournament_tournament_match_path(@tournament, @match),
                    alert: t('tournaments.unauthorized', default: 'Not authorized') and return
      end

      # For first report, only participants or organizer
      return if [@match.a_user_id, @match.b_user_id].include?(Current.user.id)
      return if @tournament.creator == Current.user

      redirect_to tournament_tournament_match_path(@tournament, @match),
                  alert: t('tournaments.unauthorized', default: 'Not authorized')
    end

    def can_add_match?
      return false unless @tournament.open?
      return false unless @tournament.running?
      return false unless Current.user

      # Only participants (registered) or organizer can add
      participant_ids = @tournament.registrations.pluck(:user_id)
      (@tournament.creator_id == Current.user.id) || participant_ids.include?(Current.user.id)
    end

    def svg_match_list_item(match)
      view_context.content_tag(:li, style: 'margin:0; display:flex; justify-content:center;') do
        view_context.content_tag(:svg, width: 240, height: 88) do
          view_context.small_match_box(@tournament, match, 0, 0, width: 240, show_seeds: false)
        end
      end
    end

    # rubocop:disable Rails/StrongParametersExpect
    def game_params
      key = params.key?(:event) ? :event : :game_event
      params.require(key).permit(
        game_participations_attributes: %i[user_id score secondary_score faction_id army_list]
      )
    end
    # rubocop:enable Rails/StrongParametersExpect
  end
end
