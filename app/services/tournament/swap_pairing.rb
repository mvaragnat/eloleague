# frozen_string_literal: true

module Tournament
  class SwapPairing
    Result = Struct.new(:ok, :error)

    def self.eligible_users_for(tournament, match)
      return [] if match.game_event_id.present?

      matches = group_matches_for(tournament, match)
      pending_others = matches.select { |m| m.id != match.id && m.game_event_id.nil? }
      pending_others.flat_map { |m| [m.a_user, m.b_user] }.compact.uniq
    end

    def self.group_matches_for(tournament, match)
      if match.tournament_round_id.present?
        tournament.matches.includes(:a_user, :b_user).where(tournament_round_id: match.tournament_round_id)
      else
        # Elimination: group by depth from root (same level == same round)
        target_depth = depth_for(match)
        all = tournament.matches.includes(:a_user, :b_user, :parent_match)
        all.select { |m| depth_for(m) == target_depth }
      end
    end

    def self.depth_for(match)
      d = 0
      cur = match
      while cur.parent_match
        d += 1
        cur = cur.parent_match
      end
      d
    end

    def initialize(tournament, match, slot, target_user_id)
      @tournament = tournament
      @match = match
      @slot = slot.to_s
      @target_user_id = target_user_id.to_i
    end

    def call
      return Result.new(false, :invalid_state) unless allowed_state?
      return Result.new(false, :invalid_match) if @match.game_event_id.present?
      return Result.new(false, :invalid_slot) unless valid_slot?

      target_user = find_target_user
      return Result.new(false, :invalid_target) unless target_user

      other_match = find_other_match_for(target_user)
      return Result.new(false, :invalid_target) unless other_match

      return Result.new(true, nil) if same_player_selected?(target_user)

      perform_swap!(other_match, target_user)
      Result.new(true, nil)
    end

    private

    def allowed_state?
      @tournament.running? && (@tournament.swiss? || @tournament.elimination?)
    end

    def valid_slot?
      %w[a b].include?(@slot)
    end

    def find_target_user
      User.find_by(id: @target_user_id)
    end

    def same_player_selected?(target_user)
      (@slot == 'a' ? @match.a_user_id : @match.b_user_id) == target_user.id
    end

    def find_other_match_for(target_user)
      group = self.class.group_matches_for(@tournament, @match)
      group.find do |m|
        m.id != @match.id && m.game_event_id.nil? && [m.a_user_id, m.b_user_id].include?(target_user.id)
      end
    end

    def perform_swap!(other_match, target_user)
      current_user_id = @slot == 'a' ? @match.a_user_id : @match.b_user_id
      other_slot = other_match.a_user_id == target_user.id ? 'a' : 'b'

      ApplicationRecord.transaction do
        @match.update!((@slot == 'a' ? :a_user_id : :b_user_id) => target_user.id)
        other_match.update!((other_slot == 'a' ? :a_user_id : :b_user_id) => current_user_id)
      end
    end
  end
end
