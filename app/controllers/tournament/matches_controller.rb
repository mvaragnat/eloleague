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
      # Prebuild two participations with role-specific defaults
      set_preselection_flags
      @game.game_participations.build(user: @preselected_user) if @preselected_user.present?
      # Ensure exactly two participation slots are present
      @game.game_participations.build while @game.game_participations.size < 2
    end

    def create
      unless can_add_match?
        return redirect_back(fallback_location: tournament_path(@tournament),
                             alert: t('tournaments.unauthorized', default: 'Not authorized'))
      end

      # For non-organizers, ensure they are one of the two selected players
      unless @tournament.creator_id == Current.user.id
        selected_user_ids = extract_participation_user_ids_from(game_params)
        unless selected_user_ids.include?(Current.user.id)
          flash.now[:alert] = t('tournaments.unauthorized', default: 'Not authorized')
          # Re-render the form with the same defaults as #new
          @game = Game::Event.new
          set_preselection_flags
          @game.game_participations.build while @game.game_participations.size < 2
          return render :new, status: :unprocessable_content
        end
      end

      game = Game::Event.new(
        game_params.merge(
          played_at: Time.current,
          game_system: @tournament.game_system,
          tournament: @tournament,
          non_competitive: @tournament.non_competitive,
          scoring_system: @tournament.scoring_system
        )
      )
      if game.save
        match = @tournament.matches.create!(
          a_user_id: game.game_participations.first.user_id,
          b_user_id: game.game_participations.second.user_id,
          game_event: game,
          non_competitive: @tournament.non_competitive,
          result: ::Tournament::Match.deduce_result(
            game.game_participations.first.score.to_i,
            game.game_participations.second.score.to_i,
            scoring_system: @tournament.scoring_system
          )
        )

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove('no-matches-message'),
              turbo_stream.prepend('matches-list', view_context.svg_match_list_item(@tournament, match)),
              turbo_stream.replace('modal', '')
            ]
          end
          format.html do
            # After creating match, redirect to Matches tab (index 1 due to Overview at 0)
            round_index = @tournament.rounds.order(:number).pluck(:id).index(match.tournament_round_id) || 0
            redirect_to tournament_path(@tournament, tab: 1, round_tab: round_index),
                        notice: t('tournaments.match_updated', default: 'Match updated')
          end
        end
      else
        @game = game
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

      result = ::Tournament::ReportMatch
               .new(
                 tournament: @tournament,
                 match: @match,
                 scores: {
                   a_score: a_score,
                   b_score: b_score,
                   a_secondary_score: a_secondary,
                   b_secondary_score: b_secondary
                 }
               ).call

      unless result.ok
        message = case result.error
                  when :scores_missing
                    t('tournaments.score_required', default: 'Both scores are required')
                  when :draw_not_allowed
                    t('tournaments.draw_not_allowed', default: 'Draw is not allowed in elimination')
                  else
                    # Keep this short to avoid long safe navigation chains
                    errs = result.event&.errors
                    errs&.full_messages&.to_sentence
                  end
        flash.now[:alert] = message
        return render :show, status: :unprocessable_content
      end

      round_index = @tournament.rounds.order(:number).pluck(:id).index(@match.tournament_round_id) || 0
      redirect_to tournament_path(@tournament, tab: 1, round_tab: round_index),
                  notice: t('tournaments.match_updated', default: 'Match updated')
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

    def set_preselection_flags
      registered_current_user =
        Current.user &&
        @tournament.registrations.exists?(user_id: Current.user.id)

      is_organizer = Current.user && (@tournament.creator_id == Current.user.id)

      if registered_current_user
        @preselected_user = Current.user
        # Participants cannot remove themselves; organizers can
        @preselected_removable = is_organizer
      else
        @preselected_user = nil
        @preselected_removable = true
      end
    end

    def extract_participation_user_ids_from(g_params)
      attrs = g_params[:game_participations_attributes]
      return [] if attrs.blank?

      # attrs can be an Array of hashes or a Hash with numeric keys
      participations =
        if attrs.is_a?(Array)
          attrs
        else
          attrs.values
        end

      participations
        .map { |h| h[:user_id].presence || h['user_id'] }
        .compact
        .map(&:to_i)
    end

    # Devise provides authentication; Current.user is set at ApplicationController

    def set_tournament
      @tournament = ::Tournament::Tournament.find_by(slug: params[:tournament_id]) ||
                    ::Tournament::Tournament.find(params[:tournament_id])
    end

    def set_match
      @match = @tournament.matches.find(params[:id])
    end

    def authorize_admin!
      return if Current.user && @tournament.creator_id == Current.user.id

      redirect_to tournament_tournament_match_path(@tournament, @match),
                  alert: t('tournaments.unauthorized', default: 'Not authorized')
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

    # View helper moved to ApplicationHelper#svg_match_list_item

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
