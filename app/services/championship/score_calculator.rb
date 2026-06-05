# frozen_string_literal: true

module Championship
  class ScoreCalculator
    ELIGIBLE_FORMATS = %w[swiss elimination].freeze

    def initialize(tournament)
      @tournament = tournament
    end

    def call
      return unless eligible?

      level = Championship::Config.level_for(@tournament.game_system.name, @tournament.championship_level)
      return unless level

      year = championship_year
      standings = ::Tournament::Standings.new(@tournament).rows

      standings.each_with_index do |row, index|
        rank = index + 1
        points = level.points_for_rank(rank)

        Championship::Score.find_or_initialize_by(
          user_id: row.user.id,
          tournament_id: @tournament.id
        ).update!(
          game_system_id: @tournament.game_system_id,
          year: year,
          total_points: points
        )
      end
    end

    private

    def eligible?
      @tournament.completed? &&
        ELIGIBLE_FORMATS.include?(@tournament.format) &&
        @tournament.championship_level.present?
    end

    def championship_year
      (@tournament.ends_at || @tournament.updated_at).year
    end
  end
end
