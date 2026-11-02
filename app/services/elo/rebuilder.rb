# frozen_string_literal: true

module Elo
  # Recomputes ratings chronologically from all events, optionally for one game system.
  # Used by `rails elo:rebuild` and when a reported game's competitiveness changes.
  class Rebuilder
    BATCH_SIZE = 1000

    def initialize(game_system_id: nil, updater: Updater.new)
      @game_system_id = game_system_id.presence&.to_i
      @updater = updater
    end

    # Returns the number of recomputed events.
    def call
      clear_ratings
      count = replay_events
      apply_pending_resets
      count
    end

    private

    def scoped?
      @game_system_id.present? && @game_system_id.positive?
    end

    def scope_relation(relation)
      scoped? ? relation.where(game_system_id: @game_system_id) : relation
    end

    def clear_ratings
      [EloRating, EloChange, FactionRating].each { |model| scope_relation(model).delete_all }
    end

    def replay_events
      # Only events with exactly two participations, in explicit order (no find_each, to respect it)
      scope = scope_relation(Game::Event.order(played_at: :asc, id: :asc))
              .joins(:game_participations)
              .group('game_events.id')
              .having('COUNT(game_participations.id) = 2')

      offset = 0
      count = 0
      loop do
        batch = scope.limit(BATCH_SIZE).offset(offset).to_a
        break if batch.empty?

        batch.each do |event|
          event.update!(elo_applied: false)
          @updater.update_for_event(event)
          count += 1
        end
        offset += BATCH_SIZE
      end
      count
    end

    # Balance patches recorded after a faction's last game still raise its deviation
    def apply_pending_resets
      now = Time.current
      scope_relation(FactionRating.all).find_each do |row|
        row.apply_pending_reset(now)
        row.save! if row.changed?
      end
    end
  end
end
