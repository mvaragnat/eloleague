# frozen_string_literal: true

class EloRating < ApplicationRecord
  START_RATING = Elo::Calculator::START_RATING
  START_DEVIATION = Elo::Calculator::START_DEVIATION

  belongs_to :user
  belongs_to :game_system, class_name: 'Game::System'

  attribute :rating, :integer, default: -> { START_RATING }
  attribute :rating_deviation, :integer, default: -> { START_DEVIATION }

  validates :rating, presence: true
  validates :rating_deviation, presence: true
  validates :games_played, presence: true

  def provisional?
    Elo::Calculator.provisional?(rating_deviation)
  end

  def conservative_rating
    Elo::Calculator.conservative(rating, rating_deviation)
  end

  # Seeding value for a user: R - 2·RD (lower bound), defaulting to a brand new player.
  def self.conservative_for(user, system)
    row = find_by(user: user, game_system: system)
    row ? row.conservative_rating : Elo::Calculator.conservative(START_RATING, START_DEVIATION)
  end
end
