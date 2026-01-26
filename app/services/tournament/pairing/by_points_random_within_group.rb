# frozen_string_literal: true

module Tournament
  module Pairing
    class ByPointsRandomWithinGroup
      Result = Struct.new(:pairs, :bye_user) # pairs: array of [user_a, user_b]
      MAX_SWAP_ITERATIONS = 50

      def initialize(tournament)
        @tournament = tournament
      end

      def call
        users = eligible_users
        return Result.new([], nil) if users.size < 2

        rng = Random.new(seed_for_round)

        # Points including previous byes
        points_map = current_points

        # Optionally pick a bye up-front from the lowest-points group to avoid
        # breaking already-formed pairs later. Avoid assigning a bye to the same
        # player twice in the same tournament when possible.
        bye_user = nil
        if users.size.odd?
          bye_user = select_bye_user(users, points_map, rng)
          users -= [bye_user]
        end

        grouped, scores_desc = group_users_by_points(users, points_map)
        pairs = build_pairs_across_groups(grouped, scores_desc, rng)

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

      def current_points
        points = Hash.new(0.0)
        tournament.matches.includes(:a_user, :b_user).find_each do |m|
          # Count wins including byes (one-sided matches)
          case m.result
          when 'a_win'
            points[m.a_user_id] += 1.0 if m.a_user_id
          when 'b_win'
            points[m.b_user_id] += 1.0 if m.b_user_id
          when 'draw'
            # Only count draw if both players present
            if m.a_user_id && m.b_user_id
              points[m.a_user_id] += 0.5
              points[m.b_user_id] += 0.5
            end
          end
        end
        points
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

      def select_bye_user(all_users, points_map, rng)
        bye_already = users_with_bye_ids

        # Build groups ascending by points (lowest rank first)
        grouped = all_users.group_by { |u| points_map[u.id] || 0.0 }
        scores_asc = grouped.keys.sort

        candidate = nil
        scores_asc.each do |score|
          group = grouped[score]
          # Prefer those without a previous bye
          eligible = group.reject { |u| bye_already.include?(u.id) }
          pool = eligible.any? ? eligible : group
          next if pool.empty?

          candidate = pool.sample(random: rng)
          break
        end

        candidate
      end

      def seed_for_round
        # Basic deterministic seed: round count + tournament id
        (tournament.rounds.maximum(:number) || 0) + tournament.id
      end

      def group_users_by_points(users, points_map)
        grouped = users.group_by { |u| points_map[u.id] || 0.0 }
        scores_desc = grouped.keys.sort.reverse
        [grouped, scores_desc]
      end

      def build_pairs_across_groups(grouped, scores_desc, rng)
        pairs = []
        scores_desc.each_with_index do |score, idx|
          group = (grouped[score] || []).shuffle(random: rng)

          if group.size.odd? && idx < (scores_desc.size - 1)
            grp_pairs, grp_leftover = pair_group(group, rng)
            pairs.concat(grp_pairs)

            floater = grp_leftover.first
            partner, partner_group_score = find_partner_for_floater(floater, grouped, scores_desc, idx)

            if partner
              grouped[partner_group_score].delete(partner)
              pairs << [floater, partner]
            else
              # Should not happen given even total after bye removal, but keep safe
              grouped[score] = []
            end
          else
            grp_pairs, = pair_group(group, rng)
            pairs.concat(grp_pairs)
          end
        end

        # After initial pairing, resolve any remaining duplicates via swapping
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
        return false if already_played?(new_a1, new_a2)
        return false if already_played?(new_b1, new_b2)

        true
      end

      def find_partner_for_floater(floater, grouped, scores_desc, current_idx)
        ((current_idx + 1)...scores_desc.size).each do |j|
          lower_score = scores_desc[j]
          lower_group = grouped[lower_score] || []
          next if lower_group.empty?

          candidate = lower_group.find { |u| !already_played?(floater, u) }
          candidate ||= lower_group.first

          return [candidate, lower_score] if candidate
        end
        [nil, nil]
      end

      def pair_group(group_users, _rng)
        pairs = []
        leftover = group_users.dup

        # Greedy: try pairing avoiding repeats
        while leftover.size >= 2
          a = leftover.shift
          partner_idx = leftover.find_index { |b| !already_played?(a, b) }
          partner_idx ||= 0 # fallback to first (repeat allowed only if needed)
          b = leftover.delete_at(partner_idx)
          pairs << [a, b]
        end

        [pairs, leftover]
      end

      def already_played?(a_user, b_user)
        tournament.matches.where(a_user: a_user, b_user: b_user).or(
          tournament.matches.where(a_user: b_user, b_user: a_user)
        ).exists?
      end
    end
  end
end
