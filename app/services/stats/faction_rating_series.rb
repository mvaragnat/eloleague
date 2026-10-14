# frozen_string_literal: true

module Stats
  # Rating history of a faction for the chart: one point per rated game
  # ({ t: ms, r: rating, rd: deviation }) plus balance-patch resets, which both
  # add a point (the deviation jumps back up) and are listed for the chart to mark.
  # `band_factor` sets the shaded band (R ± factor·RD): its lower edge is the displayed rating.
  class FactionRatingSeries
    def initialize(faction:)
      @faction = faction
    end

    def call
      changes = rating_changes
      resets = @faction.faction_rating_resets.order(:reset_at).to_a

      [{
        id: @faction.id,
        name: @faction.localized_name,
        band_factor: Elo::Calculator::CONSERVATIVE_FACTOR,
        points: build_points(changes, resets),
        resets: resets.map { |reset| { t: ms(reset.reset_at) } }
      }]
    end

    private

    # One row per game (both rows of a mirror carry the same faction values).
    def rating_changes
      EloChange.joins(:game_event)
               .where(faction_id: @faction.id)
               .where.not(faction_rating_after: nil)
               .select('elo_changes.*, game_events.played_at AS played_at')
               .order('game_events.played_at ASC, game_events.id ASC')
               .to_a
               .uniq(&:game_event_id)
    end

    def build_points(changes, resets)
      return [] if changes.empty?

      first = changes.first
      points = [point(first.played_at, first.faction_rating_before, first.faction_rd_before)]
      pending = resets.reject { |reset| reset.reset_at <= first.played_at }

      changes.each do |change|
        pending = add_resets_before(points, pending, change.played_at)
        points << point(change.played_at, change.faction_rating_after, change.faction_rd_after)
      end
      add_resets_before(points, pending, nil)
      points
    end

    # Resets only ever raise the deviation, mirroring FactionRating#apply_pending_reset.
    def add_resets_before(points, resets, time)
      due, later = resets.partition { |reset| time.nil? || reset.reset_at < time }
      due.each do |reset|
        last = points.last
        points << { t: ms(reset.reset_at), r: last[:r], rd: [last[:rd], reset.rating_deviation].max }
      end
      later
    end

    def point(time, rating, deviation)
      { t: ms(time), r: rating, rd: deviation }
    end

    def ms(time)
      time.to_i * 1000
    end
  end
end
