# frozen_string_literal: true

module Tournament
  class Tournament < ApplicationRecord
    self.table_name = 'tournaments'

    enum :format, { open: 0, swiss: 1, elimination: 2 }
    enum :state, { draft: 'draft', registration: 'registration', running: 'running', completed: 'completed' }

    belongs_to :creator, class_name: 'User'
    belongs_to :game_system, class_name: 'Game::System'

    has_many :registrations,
             class_name: 'Tournament::Registration',
             inverse_of: :tournament,
             dependent: :destroy
    has_many :participants, through: :registrations, source: :user

    has_many :rounds,
             class_name: 'Tournament::Round',
             inverse_of: :tournament,
             dependent: :destroy

    has_many :matches,
             class_name: 'Tournament::Match',
             inverse_of: :tournament,
             dependent: :destroy

    validates :name, presence: true
    validates :format, presence: true
    validates :rounds_count, numericality: { greater_than: 0 }, allow_nil: true
    validates :max_players, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

    validate :strategy_keys_are_known

    scope :competitive, -> { where(non_competitive: false) }
    scope :non_competitive, -> { where(non_competitive: true) }

    def registrations_open?
      state.in?(%w[draft registration])
    end

    def registration_full?
      return false if max_players.blank?

      registrations.count >= max_players
    end

    def state_label
      I18n.t("tournaments.state.#{state}", default: state.to_s.humanize)
    end

    def pairing_key
      pairing_strategy_key.presence || ::Tournament::StrategyRegistry.default_pairing_key
    end

    def tiebreak1_key
      tiebreak1_strategy_key.presence || ::Tournament::StrategyRegistry.default_tiebreak1_key
    end

    def tiebreak2_key
      tiebreak2_strategy_key.presence || ::Tournament::StrategyRegistry.default_tiebreak2_key
    end

    private

    def strategy_keys_are_known
      pairings = ::Tournament::StrategyRegistry.pairing_strategies
      tbs = ::Tournament::StrategyRegistry.tiebreak_strategies

      errors.add(:pairing_strategy_key, 'is not a recognized pairing strategy') unless pairing_key.in?(pairings.keys)
      errors.add(:tiebreak1_strategy_key, 'is not a recognized tie-break strategy') unless tiebreak1_key.in?(tbs.keys)
      return if tiebreak2_key.in?(tbs.keys)

      errors.add(:tiebreak2_strategy_key, 'is not a recognized tie-break strategy')
    end
  end
end
