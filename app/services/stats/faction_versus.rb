# frozen_string_literal: true

module Stats
  # Versus table for a given faction against all other factions in same system.
  # Mirror row contains only mirror_count; other metrics remain nil as requested.
  class FactionVersus
    Row = Struct.new(:opponent_faction_id, :opponent_faction_name, :games, :unique_players,
                     :wins, :losses, :draws, :win_percent, :loss_percent, :draw_percent, :mirror_count,
                     :warnings,
                     keyword_init: true)

    def initialize(faction:, tournament_only: false)
      @faction = faction
      @system = faction.game_system
      @tournament_only = tournament_only
    end

    def call
      parts, parts_by_event = preload_parts
      rows, rows_by_id = build_rows_index
      my_parts = parts.select { |p| p.faction_id == @faction.id }

      accumulate_results(my_parts, parts_by_event, rows_by_id)
      finalize_rows(rows, my_parts, parts_by_event)
    end

    private

    def preload_parts
      events = Game::Event.where(game_system: @system).competitive
      events = events.where.not(tournament_id: nil) if @tournament_only
      event_ids = events.pluck(:id)
      parts = Game::Participation.where(game_event_id: event_ids).includes(:faction, :user, game_event: :scoring_system)
      [parts, parts.group_by(&:game_event_id)]
    end

    def build_rows_index
      rows = @system.factions.map do |opp|
        Row.new(opponent_faction_id: opp.id, opponent_faction_name: opp.localized_name,
                games: 0, unique_players: 0, wins: 0, losses: 0, draws: 0, win_percent: nil, loss_percent: nil,
                draw_percent: nil, mirror_count: 0, warnings: [])
      end
      [rows, rows.index_by(&:opponent_faction_id)]
    end

    def accumulate_results(my_parts, parts_by_event, rows_by_id)
      my_parts.each do |p|
        opponent = find_opponent(p, parts_by_event)
        next unless opponent

        row = rows_by_id[opponent.faction_id]
        next unless row

        if opponent.faction_id == p.faction_id
          row.mirror_count += 1
          next
        end

        row.games += 1
        wld = compare_scores(p, opponent)
        row.wins += 1 if wld == :win
        row.losses += 1 if wld == :loss
        row.draws += 1 if wld == :draw
      end
    end

    def finalize_rows(rows, my_parts, parts_by_event)
      rows.each do |row|
        populate_unique_players!(row, my_parts, parts_by_event)
        compute_row_win_and_draw_percent!(row)
        row.warnings = warnings_for(row, my_parts, parts_by_event)
      end

      rows.reject { |r| r.opponent_faction_id == @faction.id }.map do |r|
        build_row_hash(r)
      end
    end

    def populate_unique_players!(row, my_parts, parts_by_event)
      return if row.opponent_faction_id == @faction.id

      user_ids = my_parts.select do |p|
        opp = find_opponent(p, parts_by_event)
        opp && opp.faction_id == row.opponent_faction_id && opp.faction_id != p.faction_id
      end.map(&:user_id)
      row.unique_players = user_ids.uniq.size
    end

    def compute_row_win_and_draw_percent!(row)
      denom = row.wins + row.losses + row.draws
      row.win_percent = denom.zero? ? 0.0 : (row.wins.to_f * 100.0 / denom).round(2)
      row.loss_percent = denom.zero? ? 0.0 : (row.losses.to_f * 100.0 / denom).round(2)
      row.draw_percent = denom.zero? ? 0.0 : (row.draws.to_f * 100.0 / denom).round(2)
    end

    def warnings_for(row, my_parts, parts_by_event)
      warnings = []
      min_matchup_players = Rails.application.config.x.stats.min_matchup_players
      min_matchup_games = Rails.application.config.x.stats.min_matchup_games
      max_share_percent = Rails.application.config.x.stats.max_player_match_share_percent

      if row.unique_players < min_matchup_players
        warnings << I18n.t('stats.warnings.insufficient_players',
                           default: 'Number of players is insufficient')
      end
      if row.games < min_matchup_games
        warnings << I18n.t('stats.warnings.insufficient_games',
                           default: 'Number of games is insufficient')
      end

      max_share = matchup_max_player_match_share(row, my_parts, parts_by_event)
      return warnings unless max_share > max_share_percent

      warnings << I18n.t('stats.warnings.player_match_share',
                         default: 'One player represents more than %{percent}% of games',
                         percent: max_share_percent)
      warnings
    end

    def matchup_max_player_match_share(row, my_parts, parts_by_event)
      return 0.0 if row.games.zero?

      user_counts = Hash.new(0)
      my_parts.each do |p|
        opp = find_opponent(p, parts_by_event)
        next unless opp
        next if opp.faction_id != row.opponent_faction_id
        next if opp.faction_id == p.faction_id

        user_counts[p.user_id] += 1
      end

      max_games_by_player = user_counts.values.max.to_i
      (max_games_by_player.to_f * 100.0 / row.games).round(2)
    end

    def build_row_hash(row)
      {
        opponent_faction_id: row.opponent_faction_id,
        opponent_faction_name: row.opponent_faction_name,
        games: row.games,
        unique_players: row.unique_players,
        wins: row.wins,
        losses: row.losses,
        draws: row.draws,
        win_percent: row.win_percent,
        loss_percent: row.loss_percent,
        draw_percent: row.draw_percent,
        mirror_count: row.mirror_count,
        warnings: row.warnings
      }
    end

    def find_opponent(part, parts_by_event)
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
