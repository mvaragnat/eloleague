# frozen_string_literal: true

class FactionRating < ApplicationRecord
  START_RATING = Elo::Calculator::START_RATING
  START_DEVIATION = Elo::Calculator::START_DEVIATION

  belongs_to :faction, class_name: 'Game::Faction'
  belongs_to :game_system, class_name: 'Game::System'

  validates :rating, :rating_deviation, :games_played, presence: true
  validates :faction_id, uniqueness: true

  def provisional?
    Elo::Calculator.provisional?(rating_deviation)
  end

  # Applies the latest balance-patch reset recorded for this faction up to `time`
  # that has not been applied yet. Resets only ever raise the deviation.
  def apply_pending_reset(time)
    scope = FactionRatingReset.where(faction_id: faction_id).where(reset_at: ..time)
    scope = scope.where('reset_at > ?', last_reset_at) if last_reset_at
    reset = scope.order(:reset_at).last
    return unless reset

    self.rating_deviation = [rating_deviation, reset.rating_deviation].max
    self.last_reset_at = reset.reset_at
  end
end
