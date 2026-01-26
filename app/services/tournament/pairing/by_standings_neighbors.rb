# frozen_string_literal: true

module Tournament
  module Pairing
    # Pairs players by current standings order (primary and tie-breakers),
    # attempting to avoid repeats by shifting neighbors when possible.
    # Example: pair (1,2), (3,4), ... unless (1,2) already played; then try (1,3) and (2,4).
    class ByStandingsNeighbors
      Result = Struct.new(:pairs, :bye_user)
      MAX_SWAP_ITERATIONS = 50

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

      # Pairs neighbors (0-1, 2-3, ...) while avoiding repeats through swapping.
      # Algorithm:
      # 1. Generate initial neighbor pairs
      # 2. Detect duplicate matches
      # 3. For each duplicate, attempt swaps with progressively further pairs
      # 4. Use a max iteration limit to avoid infinite loops
      def build_neighbor_pairs_with_shift(users)
        # Step 1: Generate initial neighbor pairs (0-1, 2-3, ...)
        pairs = users.each_slice(2).to_a

        # Step 2: Iteratively resolve duplicates by swapping
        resolve_duplicate_pairings(pairs)

        pairs
      end

      def resolve_duplicate_pairings(pairs)
        iterations = 0

        loop do
          break if iterations >= MAX_SWAP_ITERATIONS

          duplicate_idx = find_duplicate_pair_index(pairs)
          break unless duplicate_idx

          resolved = swap_performed?(pairs, duplicate_idx)

          # If no swap resolved the issue, we must accept the duplicate (no valid alternative)
          break unless resolved

          iterations += 1
        end
      end

      def find_duplicate_pair_index(pairs)
        pairs.each_with_index do |pair, idx|
          next unless pair.size == 2

          return idx if already_played?(pair[0], pair[1])
        end
        nil
      end

      def swap_performed?(pairs, dup_idx)
        dup_pair = pairs[dup_idx]
        player_a, player_b = dup_pair

        # Try swapping with other pairs, starting from the nearest
        swap_distances(pairs.size, dup_idx).each do |target_idx|
          target_pair = pairs[target_idx]
          next unless target_pair.size == 2

          target_x, target_y = target_pair

          # Try swapping player_b with target_x: new pairs would be [a, x] and [b, y]
          if valid_swap?(player_a, target_x, player_b, target_y)
            pairs[dup_idx] = [player_a, target_x]
            pairs[target_idx] = [player_b, target_y]
            return true
          end

          # Try swapping player_b with target_y: new pairs would be [a, y] and [x, b]
          if valid_swap?(player_a, target_y, target_x, player_b)
            pairs[dup_idx] = [player_a, target_y]
            pairs[target_idx] = [target_x, player_b]
            return true
          end

          # Try swapping player_a with target_x: new pairs would be [x, b] and [a, y]
          if valid_swap?(target_x, player_b, player_a, target_y)
            pairs[dup_idx] = [target_x, player_b]
            pairs[target_idx] = [player_a, target_y]
            return true
          end

          # Try swapping player_a with target_y: new pairs would be [y, b] and [x, a]
          next unless valid_swap?(target_y, player_b, target_x, player_a)

          pairs[dup_idx] = [target_y, player_b]
          pairs[target_idx] = [target_x, player_a]
          return true
        end

        false
      end

      # Returns indices to try swapping with, ordered by proximity (nearest first)
      def swap_distances(total_pairs, dup_idx)
        (0...total_pairs).reject { |i| i == dup_idx }.sort_by { |i| (i - dup_idx).abs }
      end

      # Check if the swap creates two valid (non-duplicate) pairs
      def valid_swap?(new_a1, new_a2, new_b1, new_b2)
        !already_played?(new_a1, new_a2) && !already_played?(new_b1, new_b2)
      end
    end
  end
end
