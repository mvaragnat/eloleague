# frozen_string_literal: true

module Game
  class System < ApplicationRecord
    has_many :events, class_name: 'Game::Event', foreign_key: 'game_system_id',
                      inverse_of: :game_system, dependent: :destroy
    has_many :participations, through: :events
    has_many :players, through: :participations, source: :user
    has_many :factions, class_name: 'Game::Faction', foreign_key: 'game_system_id',
                        inverse_of: :game_system, dependent: :destroy

    validates :name, presence: true, uniqueness: true
    validates :description, presence: true
  end
end
