# frozen_string_literal: true

module Tournament
  class Standings
    ResultRow = Struct.new(:user, :points, :score_sum, :secondary_score_sum, :sos, :primary, :tiebreak1, :tiebreak2)

    def self.top3_usernames(tournament)
      rows = new(tournament).rows
      rows.first(3).map { |r| r.user.username }
    end

    def initialize(tournament)
      @tournament = tournament
    end

    def rows
      users = registered_users
      return [] if users.empty?

      points, score_sum, secondary_score_sum, opponents = initialize_aggregates(users)
      aggregate(points, score_sum, secondary_score_sum, opponents)

      sort_rows(users, points, score_sum, secondary_score_sum, opponents)
    end

    private

    def aggregate(points, score_sum, secondary_score_sum, opponents)
      @tournament.matches.includes(:a_user, :b_user, :game_event).find_each do |match|
        aggregate_for_match(points, score_sum, secondary_score_sum, opponents, match)
      end
    end

    def aggregate_for_match(points, score_sum, secondary_score_sum, opponents, match)
      if bye_win_for_single_participant?(match)
        apply_bye(points, score_sum, match)
        return
      end

      return unless match.a_user && match.b_user

      track_opponents(opponents, match)
      update_points_for_match(points, match)
      update_scores_for_match(score_sum, secondary_score_sum, match)
    end

    def track_opponents(opponents, match)
      opponents[match.a_user.id] << match.b_user.id
      opponents[match.b_user.id] << match.a_user.id
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

    def apply_bye(points, score_sum, match)
      if match.result == 'a_win' && match.a_user && match.b_user.nil?
        points[match.a_user.id] += 1.0
        score_sum[match.a_user.id] += @tournament.score_for_bye.to_f
      elsif match.result == 'b_win' && match.b_user && match.a_user.nil?
        points[match.b_user.id] += 1.0
        score_sum[match.b_user.id] += @tournament.score_for_bye.to_f
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
      @tournament.registrations.includes(:user).map(&:user)
    end

    def initialize_aggregates(users)
      points = Hash.new(0.0)
      score_sum = Hash.new(0.0)
      secondary_score_sum = Hash.new(0.0)
      opponents = Hash.new { |h, k| h[k] = [] }

      users.each do |user|
        points[user.id] ||= 0.0
        score_sum[user.id] ||= 0.0
        secondary_score_sum[user.id] ||= 0.0
        opponents[user.id] ||= []
      end

      [points, score_sum, secondary_score_sum, opponents]
    end

    def sort_rows(users, points, score_sum, secondary_score_sum, opponents)
      context = build_context(
        points: points,
        score_sum: score_sum,
        secondary_score_sum: secondary_score_sum,
        opponents: opponents
      )

      rows = users.map do |user|
        build_row(user, context[:agg], context)
      end
      rows.sort_by { |r| [-r.primary, -r.tiebreak1, -r.tiebreak2, r.user.username] }
    end

    def build_context(points:, score_sum:, secondary_score_sum:, opponents:)
      tiebreaks = ::Tournament::StrategyRegistry.tiebreak_strategies
      primaries = ::Tournament::StrategyRegistry.primary_strategies
      tie1 = tiebreaks[@tournament.tiebreak1_key] || tiebreaks[::Tournament::StrategyRegistry.default_tiebreak1_key]
      tie2 = tiebreaks[@tournament.tiebreak2_key] || tiebreaks[::Tournament::StrategyRegistry.default_tiebreak2_key]
      primary = primaries[@tournament.primary_key] || primaries[::Tournament::StrategyRegistry.default_primary_key]

      agg = build_agg(points, score_sum, secondary_score_sum, opponents)

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

    def build_agg(points, score_sum, secondary_score_sum, opponents)
      {
        score_sum_by_user_id: score_sum,
        secondary_score_sum_by_user_id: secondary_score_sum,
        points_by_user_id: points,
        opponents_by_user_id: opponents
      }
    end

    def build_row(user, agg, ctx)
      ResultRow.new(
        user,
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
