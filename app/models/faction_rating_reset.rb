# frozen_string_literal: true

# A balance patch: from `reset_at` on, the faction's rating deviation is raised
# back to `rating_deviation`. Kept as history so `elo:rebuild` replays it.
class FactionRatingReset < ApplicationRecord
  DEFAULT_DEVIATION = Elo::Calculator::FACTION_START_DEVIATION

  belongs_to :faction, class_name: 'Game::Faction'

  validates :reset_at, presence: true
  validates :rating_deviation, presence: true,
                               numericality: { only_integer: true,
                                               greater_than_or_equal_to: Elo::Calculator::RD_MIN,
                                               less_than_or_equal_to: Elo::Calculator::FACTION_RD_MAX }
end
