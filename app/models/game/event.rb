# frozen_string_literal: true

module Game
  class Event < ApplicationRecord
    belongs_to :game_system, class_name: 'Game::System'
    has_many :game_participations,
             class_name: 'Game::Participation',
             foreign_key: 'game_event_id',
             inverse_of: :game_event,
             dependent: :destroy
    accepts_nested_attributes_for :game_participations
    has_many :players, through: :game_participations, source: :user

    validates :played_at, presence: true
    validate :must_have_exactly_two_players
    validate :players_must_be_distinct
    validate :both_scores_present
    validate :both_factions_present

    after_commit :enqueue_elo_update, on: :create

    def winner_user
      participations = game_participations.to_a
      return nil unless participations.size == 2

      a, b = participations
      return nil if a.score == b.score

      a.score > b.score ? a.user : b.user
    end

    private

    def must_have_exactly_two_players
      return if game_participations.reject(&:marked_for_destruction?).size == 2

      errors.add(:players, I18n.t('games.errors.exactly_two_players'))
    end

    def players_must_be_distinct
      participations = game_participations.reject(&:marked_for_destruction?)
      return unless participations.size == 2

      user_ids = participations.map(&:user_id)
      return unless user_ids.all?(&:present?)

      errors.add(:players, I18n.t('games.errors.exactly_two_players')) if user_ids.uniq.size != 2
    end

    def both_scores_present
      participations = game_participations.reject(&:marked_for_destruction?)
      return unless participations.size == 2

      return unless participations.any? { |p| p.score.blank? }

      errors.add(:players, I18n.t('games.errors.both_scores_required'))
    end

    def both_factions_present
      participations = game_participations.reject(&:marked_for_destruction?)
      return unless participations.size == 2

      return unless participations.any? { |p| p.faction_id.blank? }

      errors.add(:players, I18n.t('games.errors.both_factions_required', default: 'Both players must select a faction'))
    end

    def enqueue_elo_update
      EloUpdateJob.perform_later(id)
    end
  end
end
