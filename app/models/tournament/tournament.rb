# frozen_string_literal: true

module Tournament
  class Tournament < ApplicationRecord
    self.table_name = 'tournaments'

    enum :format, { open: 0, swiss: 1, elimination: 2 }
    enum :state,
         { draft: 'draft', registration: 'registration', running: 'running', completed: 'completed',
           cancelled: 'cancelled' }

    belongs_to :creator, class_name: 'User'
    belongs_to :game_system, class_name: 'Game::System'
    belongs_to :scoring_system, class_name: 'Game::ScoringSystem', optional: true

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
    validates :score_for_bye, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: false
    validates :slug, presence: true, uniqueness: true
    validates :scoring_system, presence: true
    validate :scoring_system_matches_game_system

    validate :strategy_keys_are_known

    before_validation :generate_slug, on: :create
    before_validation :assign_default_scoring_system, on: :create

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

    def primary_key
      primary_strategy_key.presence || ::Tournament::StrategyRegistry.default_primary_key
    end

    def to_param
      slug
    end

    private

    def generate_slug
      return if slug.present?

      base_slug = name.to_s
                      .unicode_normalize(:nfd)
                      .gsub(/[\u0300-\u036f]/, '') # Remove accents
                      .downcase
                      .gsub(/[^a-z0-9\s-]/, '') # Remove special characters (keep spaces & hyphens as separators)
                      .gsub(/[-\s]+/, '_') # Replace spaces and hyphens with underscores
                      .gsub(/_+/, '_') # Remove multiple underscores
                      .gsub(/^_|_$/, '') # Remove leading/trailing underscores

      self.slug = base_slug.presence || SecureRandom.hex(8)
    end

    def assign_default_scoring_system
      return if scoring_system_id.present?
      return unless game_system

      self.scoring_system = Game::ScoringSystem.default_for(game_system)
    end

    def scoring_system_matches_game_system
      return unless scoring_system
      return if scoring_system.game_system_id == game_system_id

      errors.add(:scoring_system, I18n.t('tournaments.errors.scoring_system_wrong_system',
                                         default: 'Selected scoring system belongs to a different game system'))
    end

    def strategy_keys_are_known
      pairings = ::Tournament::StrategyRegistry.pairing_strategies
      tbs = ::Tournament::StrategyRegistry.tiebreak_strategies
      primaries = ::Tournament::StrategyRegistry.primary_strategies

      errors.add(:pairing_strategy_key, 'is not a recognized pairing strategy') unless pairing_key.in?(pairings.keys)
      errors.add(:primary_strategy_key, 'is not a recognized primary strategy') unless primary_key.in?(primaries.keys)
      errors.add(:tiebreak1_strategy_key, 'is not a recognized tie-break strategy') unless tiebreak1_key.in?(tbs.keys)
      return if tiebreak2_key.in?(tbs.keys)

      errors.add(:tiebreak2_strategy_key, 'is not a recognized tie-break strategy')
    end
  end
end
