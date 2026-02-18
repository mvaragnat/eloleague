# frozen_string_literal: true

module Stats
  # Computes per-faction win/loss/draw and win% within a game system.
  # Mirrors: include in total games count but exclude from W/L/D and Win%.
  class FactionWinRates
    ResultRow = Struct.new(:faction_id, :faction_name, :total_games, :unique_players,
                           :wins, :losses, :draws, :win_percent, :loss_percent, :draw_percent, :warnings,
                           keyword_init: true)

    def initialize(game_system:, tournament_only: false)
      @system = game_system
      @tournament_only = tournament_only
    end

    def call
      parts, parts_by_event = preload_parts
      rows = @system.factions.map do |f|
        build_row_for_faction(f, parts, parts_by_event)
      end
      # Default sort: highest win% first
      rows.sort_by { |r| -r[:win_percent].to_f }
    end

    private

    def preload_parts
      events = Game::Event.where(game_system: @system).competitive
      events = events.where.not(tournament_id: nil) if @tournament_only
      event_ids = events.pluck(:id)
      parts = Game::Participation.where(game_event_id: event_ids).includes(:faction, :user, game_event: :scoring_system)
      [parts, parts.group_by(&:game_event_id)]
    end

    def build_row_for_faction(faction, parts, parts_by_event)
      faction_parts = parts.select { |p| p.faction_id == faction.id }
      totals = totals_for(faction_parts, parts_by_event)
      warnings = warnings_for(faction_parts)

      ResultRow.new(
        faction_id: faction.id,
        faction_name: faction.localized_name,
        total_games: faction_parts.size,
        unique_players: faction_parts.map(&:user_id).uniq.size,
        wins: totals[:wins],
        losses: totals[:losses],
        draws: totals[:draws],
        win_percent: totals[:win_percent],
        loss_percent: totals[:loss_percent],
        draw_percent: totals[:draw_percent],
        warnings: warnings
      ).to_h
    end

    def thresholds
      Rails.application.config.x.stats
    end

    def warnings_for(faction_parts)
      total_games = faction_parts.size
      unique_players = faction_parts.map(&:user_id).uniq.size
      warnings = []

      if unique_players < thresholds.min_players
        warnings << I18n.t('stats.warnings.insufficient_players',
                           default: 'Number of players is insufficient')
      end
      if total_games < thresholds.min_games
        warnings << I18n.t('stats.warnings.insufficient_games',
                           default: 'Number of games is insufficient')
      end

      max_share = max_player_match_share(faction_parts, total_games)
      return warnings unless max_share > thresholds.max_player_match_share_percent

      warnings << I18n.t('stats.warnings.player_match_share',
                         default: 'One player represents more than %{percent}% of games',
                         percent: thresholds.max_player_match_share_percent)
      warnings
    end

    def max_player_match_share(faction_parts, total_games)
      return 0.0 if total_games.zero?

      max_games_by_player = faction_parts.group_by(&:user_id).values.map(&:size).max.to_i
      (max_games_by_player.to_f * 100.0 / total_games).round(2)
    end

    def totals_for(faction_parts, parts_by_event)
      wins = 0
      losses = 0
      draws = 0

      faction_parts.each do |p|
        opponent = opponent_participation(p, parts_by_event)
        next unless opponent
        next if mirror_match?(p, opponent)

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

    def mirror_match?(part_a, part_b)
      part_a.faction_id == part_b.faction_id
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
