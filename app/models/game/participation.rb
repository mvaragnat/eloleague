# frozen_string_literal: true

module Game
  class Participation < ApplicationRecord
    belongs_to :game_event, class_name: 'Game::Event'
    belongs_to :user
    belongs_to :faction, class_name: 'Game::Faction', counter_cache: :game_participations_count

    validates :score, presence: true
    validates :secondary_score, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :user_id, uniqueness: { scope: :game_event_id }
  end
end
