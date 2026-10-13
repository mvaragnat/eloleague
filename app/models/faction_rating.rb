# frozen_string_literal: true

class FactionRating < ApplicationRecord
  START_RATING = Elo::Calculator::FACTION_START_RATING
  START_DEVIATION = Elo::Calculator::FACTION_START_DEVIATION

  belongs_to :faction, class_name: 'Game::Faction'
  belongs_to :game_system, class_name: 'Game::System'

  attribute :rating, :integer, default: -> { START_RATING }
  attribute :rating_deviation, :integer, default: -> { START_DEVIATION }

  validates :rating, :rating_deviation, :games_played, presence: true
  validates :faction_id, uniqueness: true

  def conservative_rating
    Elo::Calculator.conservative(rating, rating_deviation)
  end

  # Herfindahl index of the faction's recent games among players: 1 / N_eff, from
  # 1/N (evenly shared) to 1 (a single player). Nil before the first rated game.
  def concentration
    return nil unless effective_players.to_f.positive?

    1.0 / effective_players
  end

  def high_concentration?
    Elo::Calculator.high_concentration?(concentration)
  end

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

    self.rating_deviation = reset.rating_deviation.clamp(rating_deviation, Elo::Calculator::FACTION_RD_MAX)
    self.last_reset_at = reset.reset_at
  end
end
