# frozen_string_literal: true

module Tournament
  module Pairing
    # First round pairing: fully random.
    # Players are shuffled and paired in the resulting order; when the number of
    # players is odd, the last one of the shuffle receives the bye.
    class RandomFirstRound
      Result = Struct.new(:pairs, :bye_user) # pairs: array of [user_a, user_b]

      def initialize(tournament)
        @tournament = tournament
      end

      def call
        registrations = eligible_registrations
        users = registrations.map(&:user)
        return Result.new([], nil) if users.size < 2

        shuffled = users.shuffle(random: Random.new(seed_for_round))
        bye_user = shuffled.size.odd? ? shuffled.pop : nil

        Result.new(build_pairs(shuffled, affiliation_by_user_id(registrations)), bye_user)
      end

      private

      attr_reader :tournament

      # Overridden by strategies adding constraints on top of the shuffle.
      def build_pairs(users, _affiliations)
        users.each_slice(2).to_a
      end

      def eligible_registrations
        regs = tournament.registrations.active.includes(:user).to_a
        checked = regs.select { |r| r.status == 'checked_in' }
        checked.any? ? checked : regs
      end

      def affiliation_by_user_id(registrations)
        registrations.each_with_object({}) { |r, acc| acc[r.user_id] = r.affiliation_id }
      end

      def seed_for_round
        # Basic deterministic seed, consistent with the other pairing strategies
        (tournament.rounds.maximum(:number) || 0) + tournament.id
      end
    end
  end
end
