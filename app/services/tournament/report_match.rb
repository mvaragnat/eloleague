# frozen_string_literal: true

module Tournament
  # Encapsulates reporting or editing a match result.
  # Handles validations, building/updating the underlying Game::Event and participants,
  # and sets the Match result accordingly. Returns a Result object.
  class ReportMatch
    Result = Struct.new(:ok, :event, :error)

    def initialize(tournament:, match:, scores: {})
      @tournament = tournament
      @match = match
      @a_score = scores[:a_score]
      @b_score = scores[:b_score]
      @a_secondary = scores[:a_secondary_score]
      @b_secondary = scores[:b_secondary_score]
    end

    def call
      return Result.new(false, nil, :scores_missing) unless scores_present?
      return Result.new(false, nil, :draw_not_allowed) if elimination_draw?

      success, event = if @match.game_event.present?
                         update_existing_event(@match.game_event)
                       else
                         build_new_event
                       end

      return Result.new(false, event, :event_invalid) unless success

      finalize_match_update(event)
      Result.new(true, event, nil)
    end

    private

    def scores_present?
      @a_score.present? && @b_score.present?
    end

    def elimination_draw?
      @tournament.elimination? && @a_score.to_i == @b_score.to_i
    end

    def update_existing_event(event)
      a_part = event.game_participations.find_by(user: @match.a_user)
      b_part = event.game_participations.find_by(user: @match.b_user)

      if a_part && b_part
        a_part.assign_attributes(score: @a_score, secondary_score: @a_secondary)
        b_part.assign_attributes(score: @b_score, secondary_score: @b_secondary)
      else
        rebuild_participations(event)
        a_part = event.game_participations.find { |p| p.user_id == @match.a_user_id }
        b_part = event.game_participations.find { |p| p.user_id == @match.b_user_id }
      end

      success = persist_event_and_parts?(event, a_part, b_part)
      [success, event]
    end

    def build_new_event
      event = Game::Event.new(
        game_system: @tournament.game_system,
        played_at: Time.current,
        tournament: @tournament,
        non_competitive: @tournament.non_competitive
      )
      add_participations(event)
      [event.save, event]
    end

    def rebuild_participations(event)
      event.game_participations.destroy_all
      add_participations(event)
    end

    def add_participations(event)
      a_reg = @tournament.registrations.find_by(user: @match.a_user)
      b_reg = @tournament.registrations.find_by(user: @match.b_user)
      event.game_participations.build(user: @match.a_user, score: @a_score, secondary_score: @a_secondary,
                                      faction: a_reg&.faction)
      event.game_participations.build(user: @match.b_user, score: @b_score, secondary_score: @b_secondary,
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

    def finalize_match_update(event)
      @match.game_event ||= event
      @match.non_competitive = @tournament.non_competitive
      @match.result = ::Tournament::Match.deduce_result(@a_score.to_i, @b_score.to_i)
      @match.save!
      @match.propagate_winner_to_parent!
      ::UserNotifications::Notifier.match_result_recorded(@match, event)
    end
  end
end
