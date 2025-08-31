# frozen_string_literal: true

module Tournament
  class MatchesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_tournament
    before_action :set_match, only: %i[show update]
    before_action :authorize_update!, only: %i[update]

    def index
      @matches = @tournament.matches.order(created_at: :desc)
    end

    def show; end

    def new
      unless can_add_match?
        return redirect_back(fallback_location: tournament_path(@tournament),
                             alert: t('tournaments.unauthorized', default: 'Not authorized'))
      end

      @game = Game::Event.new
      # Prebuild current user participation for convenience
      @game.game_participations.build(user: Current.user)
    end

    def create
      unless can_add_match?
        return redirect_back(fallback_location: tournament_path(@tournament),
                             alert: t('tournaments.unauthorized', default: 'Not authorized'))
      end

      game = Game::Event.new(game_params.merge(played_at: Time.current, game_system: @tournament.game_system))
      if game.save
        match = @tournament.matches.create!(
          a_user_id: game.game_participations.first.user_id,
          b_user_id: game.game_participations.second.user_id,
          game_event: game,
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
      a_score = params.dig(:tournament_match, :a_score)
      b_score = params.dig(:tournament_match, :b_score)
      a_secondary = params.dig(:tournament_match, :a_secondary_score)
      b_secondary = params.dig(:tournament_match, :b_secondary_score)

      unless a_score.present? && b_score.present?
        flash.now[:alert] = t('tournaments.score_required', default: 'Both scores are required')
        return render :show, status: :unprocessable_content
      end

      if @tournament.elimination? && a_score.to_i == b_score.to_i
        flash.now[:alert] = t('tournaments.draw_not_allowed', default: 'Draw is not allowed in elimination')
        return render :show, status: :unprocessable_content
      end

      event = Game::Event.new(
        game_system: @tournament.game_system,
        played_at: Time.current
      )
      a_reg = @tournament.registrations.find_by(user: @match.a_user)
      b_reg = @tournament.registrations.find_by(user: @match.b_user)
      event.game_participations.build(user: @match.a_user, score: a_score, secondary_score: a_secondary,
                                      faction: a_reg&.faction)
      event.game_participations.build(user: @match.b_user, score: b_score, secondary_score: b_secondary,
                                      faction: b_reg&.faction)

      if event.save
        @match.game_event = event
        @match.result = deduce_result(a_score.to_i, b_score.to_i)
        @match.save!

        propagate_winner_to_parent!(@match)

        # After reporting, redirect to Rounds/Matches tab (index 1 due to Overview at 0)
        redirect_to tournament_path(@tournament, tab: 1),
                    notice: t('tournaments.match_updated', default: 'Match updated')
      else
        flash.now[:alert] = event.errors.full_messages.to_sentence
        render :show, status: :unprocessable_content
      end
    end

    private

    # Devise provides authentication; Current.user is set at ApplicationController

    def set_tournament
      @tournament = ::Tournament::Tournament.find(params[:tournament_id])
    end

    def set_match
      @match = @tournament.matches.find(params[:id])
    end

    def deduce_result(a_score, b_score)
      return 'draw' if a_score == b_score

      a_score > b_score ? 'a_win' : 'b_win'
    end

    def propagate_winner_to_parent!(match)
      parent = match.parent_match
      return unless parent

      winner_user = match.result == 'a_win' ? match.a_user : match.b_user
      return unless winner_user

      if match.child_slot == 'a'
        parent.update!(a_user_id: winner_user.id)
      elsif match.child_slot == 'b'
        parent.update!(b_user_id: winner_user.id)
      end
    end

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
      view_context.content_tag(:li, style: 'margin:0 0 0.5rem 0; display:flex; justify-content:center;') do
        view_context.content_tag(:svg, width: 240, height: 68) do
          view_context.small_match_box(@tournament, match, 0, 0, width: 240, show_seeds: false)
        end
      end
    end

    # rubocop:disable Rails/StrongParametersExpect
    def game_params
      key = params.key?(:event) ? :event : :game_event
      params.require(key).permit(
        game_participations_attributes: %i[user_id score secondary_score faction_id]
      )
    end
    # rubocop:enable Rails/StrongParametersExpect
  end
end
