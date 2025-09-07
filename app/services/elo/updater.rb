# frozen_string_literal: true

module Elo
  class Updater
    Context = Struct.new(:event, :system)

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

      r1, r2 = load_and_lock_ratings(p1.user, p2.user, ctx.system)
      expected = expected_pair(r1.rating, r2.rating)
      scores = scores_from_event(p1, p2)

      apply_bundle(ctx, users: [p1.user, p2.user], ratings: [r1, r2], expecteds: expected, scores: scores)
      event.update!(elo_applied: true)
    end

    def ensure_two_participations!(event)
      participations = event.game_participations.to_a
      raise ArgumentError, 'Exactly two participations required' unless participations.size == 2

      participations
    end

    def load_and_lock_ratings(user1, user2, system)
      r1 = find_or_create_rating(user1, system)
      r2 = find_or_create_rating(user2, system)
      lock_in_order(r1, r2)
      [r1, r2]
    end

    def expected_pair(r1_value, r2_value)
      [
        @calculator.expected_score(r1_value, r2_value),
        @calculator.expected_score(r2_value, r1_value)
      ]
    end

    def find_or_create_rating(user, system)
      EloRating.find_or_create_by!(user: user, game_system: system) do |row|
        row.rating = Calculator::START_RATING
        row.games_played = 0
      end
    end

    def lock_in_order(rating_a, rating_b)
      a, b = [rating_a, rating_b].sort_by(&:id)
      a.with_lock { b.with_lock { true } }
    end

    def scores_from_event(participation1, participation2)
      return [1.0, 0.0] if participation1.score > participation2.score
      return [0.0, 1.0] if participation2.score > participation1.score

      [0.5, 0.5]
    end

    def apply_bundle(ctx, users:, ratings:, expecteds:, scores:)
      users.zip(ratings, expecteds, scores).each do |user, rating_row, expected, score|
        apply_change(ctx, user: user, rating_row: rating_row, expected: expected, score: score)
      end
    end

    def apply_change(ctx, user:, rating_row:, expected:, score:)
      before = rating_row.rating
      after = before + @calculator.delta(score: score, expected: expected)

      persist_rating_change(rating_row, after)
      persist_elo_change(ctx, attrs: { user: user, before: before, after: after, expected: expected, score: score })
    end

    def persist_rating_change(rating_row, new_value)
      rating_row.update!(
        rating: new_value,
        games_played: rating_row.games_played + 1,
        last_updated_at: Time.current
      )
    end

    def persist_elo_change(ctx, attrs:)
      EloChange.create!(
        game_event: ctx.event,
        user: attrs[:user],
        game_system: ctx.system,
        rating_before: attrs[:before],
        rating_after: attrs[:after],
        expected_score: attrs[:expected].round(3),
        actual_score: attrs[:score],
        k_factor: Calculator::K_FACTOR
      )
    end
  end
end
