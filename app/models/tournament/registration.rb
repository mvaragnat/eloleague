# frozen_string_literal: true

module Tournament
  class Registration < ApplicationRecord
    self.table_name = 'tournament_registrations'

    belongs_to :tournament, class_name: 'Tournament::Tournament'
    belongs_to :user
    belongs_to :faction, class_name: 'Game::Faction', optional: true

    validates :user_id, uniqueness: { scope: :tournament_id }
    validates :status, inclusion: { in: %w[pending checked_in] }

    def registration_label
      user_name = user&.username || '?'
      tournament_name = tournament&.name || 'Tournament'
      "#{tournament_name} – #{user_name}"
    end
  end
end
