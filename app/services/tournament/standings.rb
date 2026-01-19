# frozen_string_literal: true

module Tournament
  class Standings
    ResultRow = Struct.new(:user, :registration, :points, :score_sum, :secondary_score_sum, :sos, :primary, :tiebreak1,
                           :tiebreak2)

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

      points, score_sum, secondary_score_sum, opponents, games_played = initialize_aggregates(users)
      aggregate(points, score_sum, secondary_score_sum, opponents, games_played)

      sort_rows(regs, points, score_sum, secondary_score_sum, opponents, games_played)
    end

    private

    def registrations
      @tournament.registrations.includes(:user, :faction)
    end

    def aggregate(points, score_sum, secondary_score_sum, opponents, games_played)
      @tournament.matches.includes(:a_user, :b_user, :game_event).find_each do |match|
        aggregate_for_match(points, score_sum, secondary_score_sum, opponents, games_played, match)
      end
    end

    def aggregate_for_match(points, score_sum, secondary_score_sum, opponents, games_played, match)
      if bye_win_for_single_participant?(match)
        apply_bye(points, score_sum, games_played, match)
        return
      end

      return unless match.a_user && match.b_user

      # Only track opponents and update points for finalized matches
      if finalized_match?(match)
        track_opponents(opponents, match)
        update_points_for_match(points, match)
        update_games_played(games_played, match)
      end
      update_scores_for_match(score_sum, secondary_score_sum, match)
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

    def update_scores_for_match(score_sum, secondary_score_sum, match)
      a_score, b_score, a_secondary, b_secondary = extract_scores(match)
      return unless a_score && b_score

      score_sum[match.a_user.id] += a_score
      score_sum[match.b_user.id] += b_score
      secondary_score_sum[match.a_user.id] += a_secondary || 0.0
      secondary_score_sum[match.b_user.id] += b_secondary || 0.0
    end

    def bye_win_for_single_participant?(match)
      (match.result == 'a_win' && match.a_user && match.b_user.nil?) ||
        (match.result == 'b_win' && match.b_user && match.a_user.nil?)
    end

    def apply_bye(points, score_sum, games_played, match)
      if match.result == 'a_win' && match.a_user && match.b_user.nil?
        points[match.a_user.id] += 1.0
        score_sum[match.a_user.id] += @tournament.score_for_bye.to_f
        games_played[match.a_user.id] += 1
      elsif match.result == 'b_win' && match.b_user && match.a_user.nil?
        points[match.b_user.id] += 1.0
        score_sum[match.b_user.id] += @tournament.score_for_bye.to_f
        games_played[match.b_user.id] += 1
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

    def registered_users
      registrations.map(&:user)
    end

    def initialize_aggregates(users)
      points = Hash.new(0.0)
      score_sum = Hash.new(0.0)
      secondary_score_sum = Hash.new(0.0)
      opponents = Hash.new { |h, k| h[k] = [] }
      games_played = Hash.new(0)

      users.each do |user|
        points[user.id] ||= 0.0
        score_sum[user.id] ||= 0.0
        secondary_score_sum[user.id] ||= 0.0
        opponents[user.id] ||= []
        games_played[user.id] ||= 0
      end

      [points, score_sum, secondary_score_sum, opponents, games_played]
    end

    def sort_rows(regs, points, score_sum, secondary_score_sum, opponents, games_played)
      context = build_context(
        points: points,
        score_sum: score_sum,
        secondary_score_sum: secondary_score_sum,
        opponents: opponents,
        games_played: games_played
      )

      rows = regs.map do |reg|
        build_row(reg, context[:agg], context)
      end
      rows.sort_by { |r| [-r.primary, -r.tiebreak1, -r.tiebreak2, r.user.username] }
    end

    def build_context(points:, score_sum:, secondary_score_sum:, opponents:, games_played:)
      tiebreaks = ::Tournament::StrategyRegistry.tiebreak_strategies
      primaries = ::Tournament::StrategyRegistry.primary_strategies
      tie1 = tiebreaks[@tournament.tiebreak1_key] || tiebreaks[::Tournament::StrategyRegistry.default_tiebreak1_key]
      tie2 = tiebreaks[@tournament.tiebreak2_key] || tiebreaks[::Tournament::StrategyRegistry.default_tiebreak2_key]
      primary = primaries[@tournament.primary_key] || primaries[::Tournament::StrategyRegistry.default_primary_key]

      agg = build_agg(points, score_sum, secondary_score_sum, opponents, games_played)

      {
        points: points,
        score_sum: score_sum,
        secondary_score_sum: secondary_score_sum,
        tiebreaks: tiebreaks,
        primary: primary,
        tie1: tie1,
        tie2: tie2,
        agg: agg
      }
    end

    def build_agg(points, score_sum, secondary_score_sum, opponents, games_played)
      {
        score_sum_by_user_id: score_sum,
        secondary_score_sum_by_user_id: secondary_score_sum,
        points_by_user_id: points,
        opponents_by_user_id: opponents,
        games_played_by_user_id: games_played
      }
    end

    def build_row(reg, agg, ctx)
      user = reg.user
      ResultRow.new(
        user,
        reg,
        ctx[:points][user.id],
        ctx[:score_sum][user.id],
        ctx[:secondary_score_sum][user.id],
        ctx[:tiebreaks]['sos'].last.call(user.id, agg),
        ctx[:primary].last.call(user.id, agg),
        ctx[:tie1].last.call(user.id, agg),
        ctx[:tie2].last.call(user.id, agg)
      )
    end
  end
end
