# frozen_string_literal: true

module Championship
  # Annual championship standings of a game system: points per player (best-of applied), ranked with ties.
  class Standings
    attr_reader :entries, :excluded_scores

    def self.latest_year(game_system)
      Score.for_game_system(game_system).maximum(:year)
    end

    def initialize(scores, best_of: nil)
      @best_of = best_of
      @excluded_scores = Set.new
      @entries = build(scores)
    end

    private

    def build(scores)
      entries = scores.group_by(&:user).map do |user, user_scores|
        counted = apply_best_of(user_scores)
        { user: user, total_points: counted.sum(&:total_points), tournaments_count: user_scores.size }
      end
      entries.sort_by! { |e| [-e[:total_points], e[:user].username] }
      assign_ranks(entries)
    end

    # Equal totals share the same rank.
    def assign_ranks(entries)
      previous = nil
      entries.each_with_index do |entry, index|
        entry[:rank] = previous && entry[:total_points] == previous[:total_points] ? previous[:rank] : index + 1
        previous = entry
      end
    end

    def apply_best_of(user_scores)
      return user_scores unless @best_of

      sorted = user_scores.sort_by { |s| -s.total_points }
      (sorted[@best_of..] || []).each { |s| @excluded_scores.add([s.user_id, s.tournament_id]) }
      sorted.first(@best_of)
    end
  end
end
