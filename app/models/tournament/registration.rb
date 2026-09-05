# frozen_string_literal: true

module Tournament
  class Registration < ApplicationRecord
    self.table_name = 'tournament_registrations'

    belongs_to :tournament, class_name: 'Tournament::Tournament', counter_cache: :tournament_registrations_count
    belongs_to :user
    belongs_to :faction, class_name: 'Game::Faction', optional: true
    belongs_to :affiliation, optional: true

    STATUSES = { pending: 'Pending', checked_in: 'Checked in', cancelled: 'Cancelled' }.freeze

    scope :active, -> { where.not(status: 'cancelled') }
    scope :cancelled, -> { where(status: 'cancelled') }

    validates :user_id, uniqueness: { scope: :tournament_id }
    validates :status, inclusion: { in: STATUSES.keys.map(&:to_s) }

    # Assigns the affiliation from a free-text name, creating it when needed.
    # A blank name clears the affiliation.
    def affiliation_name=(value)
      self.affiliation = ::Affiliation.find_or_create_by_name(value)
    end

    def affiliation_name
      affiliation&.name
    end

    def registration_label
      user_name = user&.username || '?'
      tournament_name = tournament&.name || 'Tournament'
      "#{tournament_name} – #{user_name}"
    end
  end
end
