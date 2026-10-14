# frozen_string_literal: true

class EloChange < ApplicationRecord
  belongs_to :game_event, class_name: 'Game::Event'
  belongs_to :user
  belongs_to :game_system, class_name: 'Game::System'
  belongs_to :faction, class_name: 'Game::Faction', optional: true

  # Displayed values: lower bound R - 2·RD, as everywhere in the UI
  def conservative_before
    Elo::Calculator.conservative(rating_before, rd_before)
  end

  def conservative_after
    Elo::Calculator.conservative(rating_after, rd_after)
  end

  def faction_changed?
    faction_rating_after.present? &&
      [faction_rating_before, faction_rd_before] != [faction_rating_after, faction_rd_after]
  end

  def faction_conservative_before
    Elo::Calculator.conservative(faction_rating_before, faction_rd_before)
  end

  def faction_conservative_after
    Elo::Calculator.conservative(faction_rating_after, faction_rd_after)
  end

  validates :rating_before, :rating_after, :rd_before, :rd_after, :expected_score, :actual_score, presence: true
end
