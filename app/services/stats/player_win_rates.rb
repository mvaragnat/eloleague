# frozen_string_literal: true

module Stats
  # Computes per-faction win/loss/draw and win% for a specific player, grouped by game system.
  # Returns data in a format similar to FactionWinRates but for a single user.
  class PlayerWinRates
    ResultRow = Struct.new(:faction_id, :faction_name, :total_games,
                           :wins, :losses, :draws, :win_percent, :loss_percent, :draw_percent, keyword_init: true)

    SystemStats = Struct.new(:system_id, :system_name, :total_games,
                             :wins, :losses, :draws, :win_percent, :loss_percent, :draw_percent,
                             :faction_rows, keyword_init: true)

    def initialize(user:)
      @user = user
    end

    def call
      participations = preload_participations
      parts_by_event = build_parts_by_event(participations)

      # Group user's participations by game system
      by_system = participations.group_by { |p| p.game_event.game_system_id }

      by_system.map do |system_id, system_parts|
        build_system_stats(system_id, system_parts, parts_by_event)
      end
    end

    private

    def preload_participations
      # Get all participations for this user in competitive games
      Game::Participation.joins(:game_event)
                         .where(user: @user)
                         .where(game_events: { non_competitive: false })
                         .includes(:faction, game_event: %i[game_system scoring_system game_participations])
    end

    def build_parts_by_event(participations)
      # Build index of all participations per event (including opponents)
      event_ids = participations.map(&:game_event_id).uniq
      Game::Participation.where(game_event_id: event_ids)
                         .includes(:user, :faction)
                         .group_by(&:game_event_id)
    end

    def build_system_stats(system_id, system_parts, parts_by_event)
      system = system_parts.first.game_event.game_system

      # Overall totals for this system
      system_totals = totals_for(system_parts, parts_by_event)

      # Group by faction within this system
      faction_rows = build_faction_rows(system_parts, parts_by_event)

      SystemStats.new(
        system_id: system_id,
        system_name: system.localized_name,
        total_games: system_parts.size,
        wins: system_totals[:wins],
        losses: system_totals[:losses],
        draws: system_totals[:draws],
        win_percent: system_totals[:win_percent],
        loss_percent: system_totals[:loss_percent],
        draw_percent: system_totals[:draw_percent],
        faction_rows: faction_rows
      ).to_h
    end

    def build_faction_rows(system_parts, parts_by_event)
      by_faction = system_parts.group_by(&:faction_id)

      rows = by_faction.map do |faction_id, faction_parts|
        faction = faction_parts.first.faction
        totals = totals_for(faction_parts, parts_by_event)

        ResultRow.new(
          faction_id: faction_id,
          faction_name: faction&.localized_name || 'Unknown',
          total_games: faction_parts.size,
          wins: totals[:wins],
          losses: totals[:losses],
          draws: totals[:draws],
          win_percent: totals[:win_percent],
          loss_percent: totals[:loss_percent],
          draw_percent: totals[:draw_percent]
        ).to_h
      end
      rows.sort_by { |r| -r[:total_games] }
    end

    def totals_for(parts, parts_by_event)
      wins = 0
      losses = 0
      draws = 0

      parts.each do |p|
        opponent = opponent_participation(p, parts_by_event)
        next unless opponent

        wld = compare_scores(p, opponent)
        wins += 1 if wld == :win
        losses += 1 if wld == :loss
        draws += 1 if wld == :draw
      end

      denom = wins + losses + draws
      {
        wins: wins,
        losses: losses,
        draws: draws,
        win_percent: (denom.zero? ? 0.0 : (wins.to_f * 100.0 / denom).round(2)),
        loss_percent: (denom.zero? ? 0.0 : (losses.to_f * 100.0 / denom).round(2)),
        draw_percent: (denom.zero? ? 0.0 : (draws.to_f * 100.0 / denom).round(2))
      }
    end

    def opponent_participation(part, parts_by_event)
      (parts_by_event[part.game_event_id] || []).find { |op| op.user_id != part.user_id }
    end

    def compare_scores(part_a, part_b)
      return :none unless part_a.score && part_b.score

      event = part_a.game_event
      if event&.scoring_system
        res = event.scoring_system.result_for(part_a.score, part_b.score)
        return :win if res == 'a_win'
        return :loss if res == 'b_win'
        return :draw if res == 'draw'
      end
      return :win if part_a.score > part_b.score
      return :loss if part_a.score < part_b.score

      :draw
    end
  end
end
