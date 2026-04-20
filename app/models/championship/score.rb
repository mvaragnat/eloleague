# frozen_string_literal: true

module Championship
  class Score < ApplicationRecord
    self.table_name = 'championship_scores'

    belongs_to :user
    belongs_to :tournament, class_name: 'Tournament::Tournament'
    belongs_to :game_system, class_name: 'Game::System'

    validates :year, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :user_id, uniqueness: { scope: :tournament_id }

    scope :for_year, ->(year) { where(year: year) }
    scope :for_game_system, ->(game_system) { where(game_system: game_system) }

    scope :ranked, lambda {
      select('championship_scores.*, SUM(total_points) OVER (PARTITION BY user_id) AS cumulative_points')
        .order(total_points: :desc)
    }
  end
end
