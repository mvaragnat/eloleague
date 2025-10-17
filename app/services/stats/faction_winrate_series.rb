# frozen_string_literal: true

module Stats
  # Builds a simple time series of winrate over time for a faction.
  # Uses cumulative win/loss/draw excluding mirrors; x = played_at in ms.
  class FactionWinrateSeries
    def initialize(faction:)
      @faction = faction
      @system = faction.game_system
    end

    def call
      wins = 0
      losses = 0
      draws = 0
      points = []

      ordered_events.find_each do |ev|
        mine, other = two_participants_for(ev)
        next unless mine && other

        if other.faction_id == mine.faction_id
          points << point(ev.played_at, wins, losses, draws)
          next
        end

        case compare_scores(mine, other)
        when :win then wins += 1
        when :loss then losses += 1
        when :draw then draws += 1
        end

        points << point(ev.played_at, wins, losses, draws)
      end

      [{ id: @faction.id, name: @faction.localized_name, points: points }]
    end

    private

    def ordered_events
      Game::Event.where(game_system: @system).includes(:game_participations).order(:played_at)
    end

    def two_participants_for(event)
      parts = event.game_participations.to_a
      return [nil, nil] unless parts.size == 2

      a, b = parts
      mine = [a, b].find { |p| p.faction_id == @faction.id }
      return [nil, nil] unless mine

      other = (mine == a ? b : a)
      [mine, other]
    end

    def compare_scores(part_a, part_b)
      return :none unless part_a.score && part_b.score
      return :win if part_a.score > part_b.score
      return :loss if part_a.score < part_b.score

      :draw
    end

    def point(time, wins, losses, draws)
      total = wins + losses + draws
      wr = total.zero? ? 0.0 : (wins.to_f * 100.0 / total)
      { t: time.to_i * 1000, r: wr.round(2) }
    end
  end
end
