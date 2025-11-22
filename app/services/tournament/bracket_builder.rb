# frozen_string_literal: true

module Tournament
  class BracketBuilder
    # Builds an elimination bracket tree for a tournament.
    # - Seeds players by Elo descending (fallback to START_RATING)
    # - Places seeds into standard single-elimination positions
    # - Pads to next power of two with byes (higher seeds receive byes)
    # - Creates leaf matches, then parents recursively to the root
    # - Propagates byes upward one step (to the immediate parent) so that the
    #   next round has a waiting opponent, but does not auto-advance beyond
    #   that point
    def initialize(tournament)
      @tournament = tournament
      @system = tournament.game_system
    end

    def call
      players = checked_in_players.presence || all_registered_players
      return [] if players.empty?

      seeds = elo_seeded(players)
      size_pow2 = next_power_of_two(seeds.size)
      positions = bracket_positions(size_pow2)
      leaf_slots = positions.map { |seed_num| seeds[seed_num - 1] }

      ActiveRecord::Base.transaction do
        leaf_matches = create_leaf_matches(leaf_slots)
        levels = build_internal_levels(leaf_matches)
        propagate_byes_single_step(levels)
        levels
      end
    end

    private

    attr_reader :tournament, :system

    def checked_in_players
      tournament.registrations.where(status: 'checked_in').includes(:user).map(&:user)
    end

    def all_registered_players
      tournament.registrations.includes(:user).map(&:user)
    end

    def elo_seeded(players)
      seeded = players.map do |u|
        rating = EloRating.find_by(user: u, game_system: system)&.rating || EloRating::START_RATING
        [u, rating]
      end
      seeded.sort_by { |(_u, r)| -r }.map(&:first)
    end

    def next_power_of_two(num)
      size = 1
      size <<= 1 while size < num
      size
    end

    # Standard bracket positions for 1..size seeds.
    # Recursively builds the seeding order: positions for a power-of-two bracket.
    def bracket_positions(size)
      return [1] if size == 1

      prev = bracket_positions(size / 2)
      mirrored = prev.map { |p| (size + 1) - p }
      prev.zip(mirrored).flatten
    end

    def create_leaf_matches(leaf_slots)
      matches = []
      (0...(leaf_slots.size / 2)).each do |i|
        a = leaf_slots[i * 2]
        b = leaf_slots[(i * 2) + 1]
        matches << tournament.matches.create!(
          a_user: a,
          b_user: b,
          non_competitive: tournament.non_competitive,
          table_number: i + 1
        )
      end
      matches
    end

    def build_internal_levels(leaf_matches)
      prev_level = leaf_matches
      levels = [leaf_matches]
      while prev_level.size > 1
        next_level = []
        prev_level.each_slice(2) do |left, right|
          parent = tournament.matches.create!(non_competitive: tournament.non_competitive)
          left&.update!(parent_match: parent, child_slot: 'a')
          right&.update!(parent_match: parent, child_slot: 'b')
          next_level << parent
        end
        levels << next_level
        prev_level = next_level
      end
      levels
    end

    # Only propagate byes from leaves to their immediate parent
    def propagate_byes_single_step(levels)
      leaves = levels.first || []
      leaves.each do |m|
        next unless m.parent_match

        if m.child_slot == 'a' && m.a_user_id.present? && m.b_user_id.nil?
          m.parent_match.update!(a_user_id: m.a_user_id) if m.parent_match.a_user_id.nil?
        elsif m.child_slot == 'b' && m.a_user_id.present? && m.b_user_id.nil?
          m.parent_match.update!(b_user_id: m.a_user_id) if m.parent_match.b_user_id.nil?
        end
      end
    end
  end
end
