# frozen_string_literal: true

module Tournament
  class Match < ApplicationRecord
    self.table_name = 'tournament_matches'

    RESULTS = %w[pending a_win b_win draw].freeze

    belongs_to :tournament, class_name: 'Tournament::Tournament', inverse_of: :matches
    belongs_to :round, class_name: 'Tournament::Round', optional: true, foreign_key: 'tournament_round_id',
                       inverse_of: :matches
    belongs_to :a_user, class_name: 'User', optional: true
    belongs_to :b_user, class_name: 'User', optional: true
    belongs_to :game_event, class_name: 'Game::Event', optional: true, dependent: :destroy

    belongs_to :parent_match, class_name: 'Tournament::Match', optional: true, inverse_of: :child_matches
    has_many :child_matches, class_name: 'Tournament::Match', foreign_key: 'parent_match_id', dependent: :nullify,
                             inverse_of: :parent_match

    validates :result, inclusion: { in: RESULTS }
    validates :child_slot, inclusion: { in: %w[a b], allow_nil: true }

    scope :competitive, -> { where(non_competitive: false) }
    scope :non_competitive, -> { where(non_competitive: true) }

    before_validation :copy_non_competitive_from_tournament, on: :create
    after_commit :notify_on_create, on: :create

    def self.deduce_result(a_score, b_score, scoring_system: nil)
      return scoring_system.result_for(a_score, b_score) if scoring_system
      return 'draw' if a_score == b_score

      a_score.to_i > b_score.to_i ? 'a_win' : 'b_win'
    end

    def match_label
      a_name = a_user&.username || '?'
      b_name = b_user&.username || '?'
      "#{a_name} #{I18n.t('vs')} #{b_name}"
    end

    private

    def copy_non_competitive_from_tournament
      self.non_competitive = tournament&.non_competitive || false
    end

    public

    # Update the parent match's participant based on this match's result.
    # No-op if the parent already has a played/recorded result.
    def propagate_winner_to_parent!
      parent = parent_match
      return unless parent

      # Do not change bracket if the next match has already been played
      return if parent.game_event.present? || parent.result != 'pending'

      winner_user = case result
                    when 'a_win' then a_user
                    when 'b_win' then b_user
                    end
      return unless winner_user

      if child_slot == 'a'
        parent.update!(a_user_id: winner_user.id)
      elsif child_slot == 'b'
        parent.update!(b_user_id: winner_user.id)
      end
    end

    private

    def notify_on_create
      ::UserNotifications::Notifier.match_created(self)
    end
  end
end
