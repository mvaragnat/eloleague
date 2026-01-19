# frozen_string_literal: true

module Tournament
  class Standings
    ResultRow = Struct.new(:user, :registration, :points, :score_sum, :secondary_score_sum, :sos, :primary, :tiebreak1,
                           :tiebreak2)

    # Internal struct to bundle all aggregate data together
    Aggregates = Struct.new(:points, :score_sum, :secondary_score_sum, :opponents, :games_played, keyword_init: true)

    def self.top3_usernames(tournament)
      rows = new(tournament).rows
      rows.first(3).map { |r| r.user.username }
    end

    def initialize(tournament)
      @tournament = tournament
    end

    def rows
      regs = registrations
      users = regs.map(&:user)
      return [] if users.empty?

      aggregates = initialize_aggregates(users)
      aggregate_all_matches(aggregates)
      sort_rows(regs: regs, aggregates: aggregates)
    end

    private

    def registrations
      @tournament.registrations.includes(:user, :faction)
    end

    def aggregate_all_matches(aggregates)
      @tournament.matches.includes(:a_user, :b_user, :game_event).find_each do |match|
        aggregate_for_match(aggregates: aggregates, match: match)
      end
    end

    def aggregate_for_match(aggregates:, match:)
      if bye_win_for_single_participant?(match)
        apply_bye(aggregates: aggregates, match: match)
        return
      end

      return unless match.a_user && match.b_user

      # Only track opponents and update points for finalized matches
      if finalized_match?(match)
        track_opponents(aggregates.opponents, match)
        update_points_for_match(aggregates.points, match)
        update_games_played(aggregates.games_played, match)
      end
      update_scores_for_match(aggregates: aggregates, match: match)
    end

    def finalized_match?(match)
      match.result != 'pending'
    end

    def track_opponents(opponents, match)
      opponents[match.a_user.id] << match.b_user.id
      opponents[match.b_user.id] << match.a_user.id
    end

    def update_games_played(games_played, match)
      games_played[match.a_user.id] += 1
      games_played[match.b_user.id] += 1
    end

    def update_points_for_match(points, match)
      case match.result
      when 'a_win'
        points[match.a_user.id] += 1.0
      when 'b_win'
        points[match.b_user.id] += 1.0
      when 'draw'
        points[match.a_user.id] += 0.5
        points[match.b_user.id] += 0.5
      end
    end

    def update_scores_for_match(aggregates:, match:)
      a_score, b_score, a_secondary, b_secondary = extract_scores(match)
      return unless a_score && b_score

      aggregates.score_sum[match.a_user.id] += a_score
      aggregates.score_sum[match.b_user.id] += b_score
      aggregates.secondary_score_sum[match.a_user.id] += a_secondary || 0.0
      aggregates.secondary_score_sum[match.b_user.id] += b_secondary || 0.0
    end

    def bye_win_for_single_participant?(match)
      (match.result == 'a_win' && match.a_user && match.b_user.nil?) ||
        (match.result == 'b_win' && match.b_user && match.a_user.nil?)
    end

    def apply_bye(aggregates:, match:)
      if match.result == 'a_win' && match.a_user && match.b_user.nil?
        aggregates.points[match.a_user.id] += 1.0
        aggregates.score_sum[match.a_user.id] += @tournament.score_for_bye.to_f
        aggregates.games_played[match.a_user.id] += 1
      elsif match.result == 'b_win' && match.b_user && match.a_user.nil?
        aggregates.points[match.b_user.id] += 1.0
        aggregates.score_sum[match.b_user.id] += @tournament.score_for_bye.to_f
        aggregates.games_played[match.b_user.id] += 1
      end
    end

    def extract_scores(match)
      event = match.game_event
      return [nil, nil, nil, nil] unless event

      a_part = event.game_participations.find { |p| p.user_id == match.a_user_id }
      b_part = event.game_participations.find { |p| p.user_id == match.b_user_id }
      return [nil, nil, nil, nil] unless a_part && b_part

      [a_part.score&.to_f, b_part.score&.to_f, a_part.secondary_score&.to_f, b_part.secondary_score&.to_f]
    end

    def initialize_aggregates(users)
      aggregates = Aggregates.new(
        points: Hash.new(0.0),
        score_sum: Hash.new(0.0),
        secondary_score_sum: Hash.new(0.0),
        opponents: Hash.new { |h, k| h[k] = [] },
        games_played: Hash.new(0)
      )

      users.each do |user|
        aggregates.points[user.id] ||= 0.0
        aggregates.score_sum[user.id] ||= 0.0
        aggregates.secondary_score_sum[user.id] ||= 0.0
        aggregates.opponents[user.id] ||= []
        aggregates.games_played[user.id] ||= 0
      end

      aggregates
    end

    def sort_rows(regs:, aggregates:)
      context = build_context(aggregates: aggregates)

      rows = regs.map do |reg|
        build_row(reg: reg, aggregates: aggregates, context: context)
      end
      rows.sort_by { |r| [-r.primary, -r.tiebreak1, -r.tiebreak2, r.user.username] }
    end

    def build_context(aggregates:)
      tiebreaks = ::Tournament::StrategyRegistry.tiebreak_strategies
      primaries = ::Tournament::StrategyRegistry.primary_strategies
      tie1 = tiebreaks[@tournament.tiebreak1_key] || tiebreaks[::Tournament::StrategyRegistry.default_tiebreak1_key]
      tie2 = tiebreaks[@tournament.tiebreak2_key] || tiebreaks[::Tournament::StrategyRegistry.default_tiebreak2_key]
      primary = primaries[@tournament.primary_key] || primaries[::Tournament::StrategyRegistry.default_primary_key]

      agg_hash = build_agg_hash(aggregates: aggregates)

      {
        points: aggregates.points,
        score_sum: aggregates.score_sum,
        secondary_score_sum: aggregates.secondary_score_sum,
        tiebreaks: tiebreaks,
        primary: primary,
        tie1: tie1,
        tie2: tie2,
        agg: agg_hash
      }
    end

    def build_agg_hash(aggregates:)
      {
        score_sum_by_user_id: aggregates.score_sum,
        secondary_score_sum_by_user_id: aggregates.secondary_score_sum,
        points_by_user_id: aggregates.points,
        opponents_by_user_id: aggregates.opponents,
        games_played_by_user_id: aggregates.games_played
      }
    end

    def build_row(reg:, aggregates:, context:)
      user = reg.user
      ResultRow.new(
        user,
        reg,
        aggregates.points[user.id],
        aggregates.score_sum[user.id],
        aggregates.secondary_score_sum[user.id],
        context[:tiebreaks]['sos'].last.call(user.id, context[:agg]),
        context[:primary].last.call(user.id, context[:agg]),
        context[:tie1].last.call(user.id, context[:agg]),
        context[:tie2].last.call(user.id, context[:agg])
      )
    end
  end
end
