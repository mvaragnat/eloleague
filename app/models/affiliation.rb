# frozen_string_literal: true

# An affiliation (club, team, store, ...) a player can declare when registering
# to a tournament. Affiliations are shared across tournaments and are created
# on the fly by players during the registration phase.
class Affiliation < ApplicationRecord
  has_many :registrations, class_name: 'Tournament::Registration', dependent: :nullify
  has_many :users, through: :registrations

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  normalizes :name, with: ->(name) { name.to_s.squish }

  scope :matching, lambda { |term|
    where('name ILIKE ?', "%#{sanitize_sql_like(term.to_s.strip)}%")
  }

  # Finds an existing affiliation with the same (case-insensitive) name or
  # creates it. Returns nil for a blank name.
  def self.find_or_create_by_name(name)
    normalized = name.to_s.squish
    return nil if normalized.blank?

    where('LOWER(name) = ?', normalized.downcase).first || create!(name: normalized)
  end
end
