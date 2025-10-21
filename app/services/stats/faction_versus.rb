# frozen_string_literal: true

module Stats
  # Versus table for a given faction against all other factions in same system.
  # Mirror row contains only mirror_count; other metrics remain nil as requested.
  class FactionVersus
    Row = Struct.new(:opponent_faction_id, :opponent_faction_name, :games, :unique_players,
                     :wins, :losses, :draws, :win_percent, :mirror_count, keyword_init: true)

    def initialize(faction:)
      @faction = faction
      @system = faction.game_system
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
      event_ids = Game::Event.where(game_system: @system).competitive.pluck(:id)
      parts = Game::Participation.where(game_event_id: event_ids).includes(:faction, :user)
      [parts, parts.group_by(&:game_event_id)]
    end

    def build_rows_index
      rows = @system.factions.map do |opp|
        Row.new(opponent_faction_id: opp.id, opponent_faction_name: opp.localized_name,
                games: 0, unique_players: 0, wins: 0, losses: 0, draws: 0, win_percent: nil,
                mirror_count: 0)
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
        compute_row_win_percent!(row)
      end

      filter_rows_by_thresholds(rows).map do |r|
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

    def compute_row_win_percent!(row)
      denom = row.wins + row.losses + row.draws
      row.win_percent = denom.zero? ? 0.0 : (row.wins.to_f * 100.0 / denom).round(2)
    end

    def filter_rows_by_thresholds(rows)
      min_players = Rails.application.config.x.stats.min_players
      min_games = Rails.application.config.x.stats.min_games
      rows.select do |r|
        r.opponent_faction_id != @faction.id && r.unique_players >= min_players && r.games >= min_games
      end
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
        mirror_count: row.mirror_count
      }
    end

    def find_opponent(part, parts_by_event)
      (parts_by_event[part.game_event_id] || []).find { |op| op.user_id != part.user_id }
    end

    def compare_scores(part_a, part_b)
      return :none unless part_a.score && part_b.score

      return :win if part_a.score > part_b.score
      return :loss if part_a.score < part_b.score

      :draw
    end
  end
end
