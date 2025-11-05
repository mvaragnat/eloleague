# frozen_string_literal: true

module Tournament
  module Pairing
    # Pairs players by current standings order (primary and tie-breakers),
    # attempting to avoid repeats by shifting neighbors when possible.
    # Example: pair (1,2), (3,4), ... unless (1,2) already played; then try (1,3) and (2,4).
    class ByStandingsNeighbors
      Result = Struct.new(:pairs, :bye_user)

      def initialize(tournament)
        @tournament = tournament
      end

      def call
        users = eligible_users
        return Result.new([], nil) if users.size < 2

        # Order by the same criteria as ranking (primary and tie-breakers)
        ordered = ordered_users_by_standings(users)

        bye_user = nil
        if ordered.size.odd?
          bye_user = select_bye_user_from_standings_tail(ordered)
          ordered -= [bye_user] if bye_user
        end

        pairs = build_neighbor_pairs_with_shift(ordered)
        Result.new(pairs, bye_user)
      end

      private

      attr_reader :tournament

      # Users who are checked in if any, else all registered
      def eligible_users
        regs = tournament.registrations.includes(:user)
        checked = regs.select { |r| r.status == 'checked_in' }.map(&:user)
        return checked if checked.any?

        regs.map(&:user)
      end

      def ordered_users_by_standings(scope_users)
        scope_ids = scope_users.to_set(&:id)
        rows = ::Tournament::Standings.new(tournament).rows
        rows
          .map(&:user)
          .select { |u| scope_ids.include?(u.id) }
      end

      def users_with_bye_ids
        ids = []
        tournament.matches.find_each do |m|
          next unless %w[a_win b_win].include?(m.result)

          ids << m.a_user_id if m.a_user_id && m.b_user_id.nil? && m.result == 'a_win'
          ids << m.b_user_id if m.b_user_id && m.a_user_id.nil? && m.result == 'b_win'
        end
        ids.compact.uniq
      end

      # Prefer assigning a bye to the lowest-ranked player who hasn't had a bye yet.
      def select_bye_user_from_standings_tail(ordered)
        bye_already = users_with_bye_ids
        candidate = ordered.reverse.find { |u| bye_already.exclude?(u.id) }
        candidate || ordered.last
      end

      def already_played?(a_user, b_user)
        tournament.matches.where(a_user: a_user, b_user: b_user).or(
          tournament.matches.where(a_user: b_user, b_user: a_user)
        ).exists?
      end

      # Pairs neighbors (0-1, 2-3, ...) but if a neighbor pair already played,
      # tries a single-position shift within the local block of four:
      # (0,2) and (1,3) when available and beneficial.
      def build_neighbor_pairs_with_shift(users)
        pairs = []
        i = 0
        while i < users.length
          # Safety: even count expected here
          break if i >= users.length - 1

          a = users[i]
          b = users[i + 1]

          unless already_played?(a, b)
            pairs << [a, b]
            i += 2
            next
          end

          # Try shift-by-one if we have a block of four
          if i + 3 < users.length
            c = users[i + 2]
            d = users[i + 3]

            # Prefer avoiding repeats for both pairs after shift
            if !already_played?(a, c) && !already_played?(b, d)
              pairs << [a, c]
              pairs << [b, d]
              i += 4
              next
            end
          end

          # Fallback: keep neighbors even if repeat
          pairs << [a, b]
          i += 2
        end

        pairs
      end
    end
  end
end
