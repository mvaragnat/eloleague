# frozen_string_literal: true

module Tournament
  module Pairing
    # First round pairing: random, but two players sharing the same affiliation
    # are not paired together unless there is no other option.
    class RandomAvoidingSameAffiliation < RandomFirstRound
      MAX_SWAP_ITERATIONS = 50

      private

      def build_pairs(users, affiliations)
        pairs = greedy_pairs(users, affiliations)
        resolve_same_affiliation_pairs(pairs, affiliations)
        pairs
      end

      # Walks the shuffled list and pairs each player with the first following
      # player from another affiliation (falling back to the next one).
      def greedy_pairs(users, affiliations)
        remaining = users.dup
        pairs = []

        while remaining.size >= 2
          player = remaining.shift
          partner_idx = remaining.find_index { |other| !same_affiliation?(player, other, affiliations) } || 0
          pairs << [player, remaining.delete_at(partner_idx)]
        end

        pairs
      end

      # The greedy pass can leave conflicts at the tail of the list; try to
      # resolve them by swapping players with other pairs.
      def resolve_same_affiliation_pairs(pairs, affiliations)
        iterations = 0

        while iterations < MAX_SWAP_ITERATIONS
          conflict_idx = find_conflict_index(pairs, affiliations)
          break unless conflict_idx

          # No valid swap: the conflict has to be accepted
          break unless swap_performed?(pairs, conflict_idx, affiliations)

          iterations += 1
        end
      end

      def find_conflict_index(pairs, affiliations)
        pairs.index { |pair| pair.size == 2 && same_affiliation?(pair[0], pair[1], affiliations) }
      end

      def swap_performed?(pairs, conflict_idx, affiliations)
        player_a, player_b = pairs[conflict_idx]

        swap_distances(pairs.size, conflict_idx).each do |target_idx|
          target_pair = pairs[target_idx]
          next unless target_pair.size == 2

          target_x, target_y = target_pair
          candidates = [
            [[player_a, target_x], [player_b, target_y]],
            [[player_a, target_y], [target_x, player_b]],
            [[target_x, player_b], [player_a, target_y]],
            [[target_y, player_b], [target_x, player_a]]
          ]

          swap = candidates.find { |first, second| valid_swap?(first, second, affiliations) }
          next unless swap

          pairs[conflict_idx] = swap.first
          pairs[target_idx] = swap.last
          return true
        end

        false
      end

      # Returns indices to try swapping with, ordered by proximity (nearest first)
      def swap_distances(total_pairs, conflict_idx)
        (0...total_pairs).reject { |i| i == conflict_idx }.sort_by { |i| (i - conflict_idx).abs }
      end

      def valid_swap?(first_pair, second_pair, affiliations)
        [first_pair, second_pair].none? { |a, b| same_affiliation?(a, b, affiliations) }
      end

      def same_affiliation?(player, other, affiliations)
        affiliation_id = affiliations[player.id]
        affiliation_id.present? && affiliation_id == affiliations[other.id]
      end
    end
  end
end
