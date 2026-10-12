# frozen_string_literal: true

class EloChange < ApplicationRecord
  belongs_to :game_event, class_name: 'Game::Event'
  belongs_to :user
  belongs_to :game_system, class_name: 'Game::System'
  belongs_to :faction, class_name: 'Game::Faction', optional: true

  validates :rating_before, :rating_after, :rd_before, :rd_after, :expected_score, :actual_score, presence: true
end
