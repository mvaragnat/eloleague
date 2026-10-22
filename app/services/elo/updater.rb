# frozen_string_literal: true

module Elo
  # Applies a game's result to both players' and both factions' ratings.
  class Updater
    Context = Struct.new(:event, :system)
    # Sliding window over which a faction's player concentration is measured.
    DIVERSITY_WINDOW = Calculator::DIVERSITY_WINDOW_MONTHS.months

    def initialize(calculator: Calculator.new)
      @calculator = calculator
    end

    def update_for_event(event)
      return if event.elo_applied

      # Skip Elo updates for non-competitive events, but mark as applied to avoid reprocessing
      if event.respond_to?(:non_competitive) && event.non_competitive
        event.update!(elo_applied: true)
        return
      end

      ActiveRecord::Base.transaction { process_event(event) }
    end

    private

    def process_event(event)
      p1, p2 = ensure_two_participations!(event)
      ctx = Context.new(event, event.game_system)
      mirror = p1.faction_id == p2.faction_id

      players, factions, faction_rows = load_and_lock_ratings(p1, p2, ctx)
      diversities = factions.to_h { |row| [row.faction_id, faction_diversity(row.faction_id, event.played_at)] }
      sides = players.zip(faction_rows).map do |player, faction|
        side_for(player, faction, diversities[faction.faction_id])
      end

      score = score_from_event(p1, p2)
      results = @calculator.rate(sides[0], sides[1], score, mirror: mirror)

      [p1, p2].zip([score, 1.0 - score]).each_with_index do |(participation, actual), i|
        persist_change(ctx, participation, sides[i], results[i], actual)
        persist_player(players[i], results[i], event.played_at)
      end
      persist_factions(factions, faction_rows, results, mirror, diversities)

      event.update!(elo_applied: true)
    end

    # Returns [player rows, distinct faction rows, faction row of each side].
    # Pending balance-patch resets are applied before the game is rated.
    def load_and_lock_ratings(participation1, participation2, ctx)
      sides = [participation1, participation2]
      players = sides.map { |p| find_or_create_rating(p.user, ctx.system) }
      factions = sides.map(&:faction).uniq.map { |f| find_or_create_faction_rating(f, ctx.system) }
      lock_in_order(players + factions)

      factions.each { |row| row.apply_pending_reset(ctx.event.played_at) }
      faction_rows = sides.map { |p| factions.find { |row| row.faction_id == p.faction_id } }
      [players, factions, faction_rows]
    end

    def ensure_two_participations!(event)
      participations = event.game_participations.to_a
      raise ArgumentError, 'Exactly two participations required' unless participations.size == 2

      participations
    end

    def find_or_create_rating(user, system)
      EloRating.find_or_create_by!(user: user, game_system: system)
    end

    def find_or_create_faction_rating(faction, system)
      FactionRating.find_or_create_by!(faction: faction) { |row| row.game_system = system }
    end

    def lock_in_order(rows)
      rows.sort_by { |row| [row.class.name, row.id] }.each(&:lock!)
    end

    def side_for(player, faction, diversity)
      Calculator::Side.new(
        player_rating: player.rating,
        player_rd: player.rating_deviation,
        faction_rating: faction.rating,
        faction_rd: faction.rating_deviation,
        faction_diversity: diversity.factor
      )
    end

    # Games per player with the faction over the window ending with this game (included).
    # Based on played_at only, so a rebuild sees the same window as the live update.
    def faction_diversity(faction_id, played_at)
      counts = Game::Participation.joins(:game_event)
                                  .where(faction_id: faction_id)
                                  .where(game_events: { non_competitive: false,
                                                        played_at: (played_at - DIVERSITY_WINDOW)..played_at })
                                  .group(:user_id)
                                  .count
      Calculator.diversity(counts.values)
    end

    def score_from_event(participation1, participation2)
      ev = participation1.game_event
      scoring = ev.scoring_system
      result =
        if scoring
          scoring.result_for(participation1.score, participation2.score)
        elsif participation1.score.to_i == participation2.score.to_i
          'draw'
        else
          (participation1.score.to_i > participation2.score.to_i ? 'a_win' : 'b_win')
        end
      case result
      when 'a_win' then 1.0
      when 'b_win' then 0.0
      else 0.5
      end
    end

    def persist_player(row, result, played_at)
      last = [row.last_played_at, played_at].compact.max
      row.update!(
        rating: result.player_rating,
        rating_deviation: result.player_rd,
        games_played: row.games_played + 1,
        last_played_at: last
      )
    end

    # A mirror updates nothing on the faction; otherwise each faction takes its side's result.
    def persist_factions(factions, faction_rows, results, mirror, diversities)
      factions.each { |row| row.assign_attributes(diversity_attributes(diversities[row.faction_id])) }
      if mirror
        factions.each(&:save!) # persists a pending reset and the diversity
        return
      end

      faction_rows.zip(results).each do |row, result|
        row.update!(rating: result.faction_rating, rating_deviation: result.faction_rd,
                    games_played: row.games_played + 1)
      end
    end

    def diversity_attributes(diversity)
      { effective_players: diversity.effective_players.round(2), distinct_players: diversity.players,
        diversity: diversity.factor.round(3) }
    end

    def persist_change(ctx, participation, side, result, actual)
      EloChange.create!(
        game_event: ctx.event,
        user: participation.user,
        game_system: ctx.system,
        faction: participation.faction,
        rating_before: side.player_rating,
        rating_after: result.player_rating,
        rd_before: side.player_rd,
        rd_after: result.player_rd,
        faction_rating_before: side.faction_rating,
        faction_rating_after: result.faction_rating,
        faction_rd_before: side.faction_rd,
        faction_rd_after: result.faction_rd,
        faction_diversity: side.diversity.round(3),
        expected_score: result.expected.round(3),
        actual_score: actual
      )
    end
  end
end
