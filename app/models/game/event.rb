# frozen_string_literal: true

module Game
  class Event < ApplicationRecord
    belongs_to :game_system, class_name: 'Game::System'
    belongs_to :scoring_system, class_name: 'Game::ScoringSystem', optional: true
    belongs_to :tournament, class_name: 'Tournament::Tournament', optional: true
    has_one :match, class_name: 'Tournament::Match', foreign_key: 'game_event_id', inverse_of: :game_event,
                    dependent: :destroy

    has_many :game_participations,
             class_name: 'Game::Participation',
             foreign_key: 'game_event_id',
             inverse_of: :game_event,
             dependent: :destroy
    accepts_nested_attributes_for :game_participations
    has_many :players, through: :game_participations, source: :user
    has_many :elo_changes,
             foreign_key: 'game_event_id',
             inverse_of: :game_event,
             dependent: :destroy

    validates :played_at, presence: true
    validates :scoring_system, presence: true
    validate :must_have_exactly_two_players
    validate :players_must_be_distinct
    validate :both_scores_present
    validate :both_factions_present
    validate :scoring_system_matches_game_system
    validate :scores_respect_scoring_rules

    before_validation :assign_scoring_system_default, on: :create
    before_validation :apply_tournament_competitiveness, on: :create
    after_commit :enqueue_elo_update, on: :create
    after_commit :notify_created, on: :create

    scope :competitive, -> { where(non_competitive: false) }
    scope :non_competitive, -> { where(non_competitive: true) }

    def participants_summary
      game_participations.includes(:user).map do |p|
        username = p.user&.username || '?'
        secondary = if p.secondary_score.present?
                      " (#{I18n.t('games.secondary_score_short')}: #{p.secondary_score})"
                    else
                      ''
                    end
        "#{username}: #{p.score}#{secondary}"
      end.join(' | ')
    end

    def winner_user
      participations = game_participations.to_a
      return nil unless participations.size == 2

      a, b = participations
      return nil unless scoring_system

      result = scoring_system.result_for(a.score.to_i, b.score.to_i)
      return nil if result == 'draw'

      result == 'a_win' ? a.user : b.user
    end

    private

    def apply_tournament_competitiveness
      # Respect manual flag for non-tournament games; mirror tournament for tournament games
      return self.non_competitive = tournament.non_competitive if tournament.present?

      # For non-tournament events, keep any explicit value, defaulting to false
      self.non_competitive = !!non_competitive
    end

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

    def scoring_system_matches_game_system
      return unless scoring_system
      return if scoring_system.game_system_id == game_system_id

      errors.add(:scoring_system, I18n.t('games.errors.scoring_system_wrong_system',
                                         default: 'Selected scoring system belongs to a different game system'))
    end

    def scores_respect_scoring_rules
      return unless scoring_system

      parts = game_participations.reject(&:marked_for_destruction?)
      return unless parts.size == 2 && parts.all? { |p| p.score.present? }

      a = parts[0].score.to_i
      b = parts[1].score.to_i

      if scoring_system.max_score_per_player.present?
        max = scoring_system.max_score_per_player
        if a.negative? || b.negative? || a > max || b > max
          errors.add(:base, I18n.t('games.errors.score_exceeds_max',
                                   max: max,
                                   default: "Each score must be between 0 and #{max}"))
        end
      end

      return if scoring_system.fix_total_score.blank?

      total = scoring_system.fix_total_score
      return unless (a + b) != total

      errors.add(:base, I18n.t('games.errors.total_must_equal',
                               total: total,
                               default: "Total of both scores must equal #{total} (id #{id})"))
    end

    def assign_scoring_system_default
      return if scoring_system_id.present?
      return if game_system_id.blank?

      self.scoring_system = if tournament&.scoring_system
                              tournament.scoring_system
                            else
                              Game::ScoringSystem.default_for(game_system)
                            end
    end

    def enqueue_elo_update
      EloUpdateJob.perform_later(id)
    end

    def notify_created
      ::UserNotifications::Notifier.game_event_created(self)
    end
  end
end
