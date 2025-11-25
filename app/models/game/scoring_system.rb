# frozen_string_literal: true

module Game
  class ScoringSystem < ApplicationRecord
    self.table_name = 'game_scoring_systems'

    belongs_to :game_system, class_name: 'Game::System'

    validates :name, presence: true
    validates :max_score_per_player, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :fix_total_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :min_difference_for_win, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                                       allow_nil: true
    validates :is_default, inclusion: { in: [true, false] }

    # Ensure only one default per game system
    validate :single_default_per_system

    scope :defaults, -> { where(is_default: true) }

    def self.default_for(system)
      where(game_system_id: system.id, is_default: true).first || where(game_system_id: system.id).first
    end

    # Returns one of: 'a_win', 'b_win', 'draw'
    def result_for(a_score, b_score)
      a = a_score.to_i
      b = b_score.to_i
      return 'draw' if a == b

      if min_difference_for_win.present?
        diff = (a - b).abs
        return 'draw' if diff <= min_difference_for_win
      end

      a > b ? 'a_win' : 'b_win'
    end

    # Returns a short localized summary string of active options
    def summary(locale = I18n.locale)
      parts = []
      if max_score_per_player.present?
        parts << I18n.t('scoring_system.summary.max_per_player', value: max_score_per_player, locale: locale)
      end
      if fix_total_score.present?
        parts << I18n.t('scoring_system.summary.fixed_total', value: fix_total_score, locale: locale)
      end
      if min_difference_for_win.present?
        parts << I18n.t('scoring_system.summary.min_diff', value: min_difference_for_win, locale: locale)
      end
      parts.join(' · ')
    end

    private

    def single_default_per_system
      return unless is_default

      existing = self.class.where(game_system_id: game_system_id, is_default: true)
      existing = existing.where.not(id: id) if persisted?
      return if existing.none?

      errors.add(:is_default,
                 I18n.t('scoring_system.errors.only_one_default',
                        default: 'Only one default scoring system per game system'))
    end
  end
end
