# frozen_string_literal: true

module Elo
  # Glicko-style rating of a (player + faction) pair.
  #
  # Each side's effective strength is the sum of the player and faction ratings,
  # with independent uncertainties (RD). A game yields one Glicko update for the
  # combined pair, which is then split between player and faction in proportion
  # to their variances (Kalman filter): the most uncertain component absorbs most
  # of the signal, and its deviation shrinks the most.
  #
  # All maths run in floats; results are rounded to integers for storage.
  class Calculator
    Q = Math.log(10) / 400.0
    START_RATING = 1500
    START_DEVIATION = 350
    RD_MIN = 30
    RD_MAX = 350
    # Deviation regained per month of player inactivity.
    INACTIVITY_C = 34.6
    SECONDS_PER_MONTH = 30.4375 * 24 * 3600
    # Above this deviation a rating is shown as provisional.
    PROVISIONAL_RD = 100
    # Seeding uses R - CONSERVATIVE_FACTOR * RD.
    CONSERVATIVE_FACTOR = 2

    Side = Struct.new(:player_rating, :player_rd, :faction_rating, :faction_rd, keyword_init: true)
    Result = Struct.new(:expected, :player_rating, :player_rd, :faction_rating, :faction_rd, keyword_init: true)

    class << self
      def provisional?(deviation)
        deviation.to_i > PROVISIONAL_RD
      end

      def conservative(rating, deviation)
        rating - (CONSERVATIVE_FACTOR * deviation)
      end

      # Raises a player's deviation after `months` without playing.
      def inflate_deviation(deviation, months)
        return deviation unless months.to_f.positive?

        [Math.sqrt((deviation**2) + ((INACTIVITY_C**2) * months)), RD_MAX].min.round
      end

      def months_between(from, to)
        return 0.0 unless from && to

        [(to - from) / SECONDS_PER_MONTH, 0.0].max
      end
    end

    # Rates one game. `score_a` is 1.0 (A wins), 0.5 (draw) or 0.0 (B wins).
    # In a mirror match the faction cancels out and teaches nothing: it is left
    # out of the uncertainty and only the players are updated.
    # Returns [Result for A, Result for B].
    def rate(side_a, side_b, score_a, mirror: false)
      [
        rate_side(side_a, side_b, score_a, mirror),
        rate_side(side_b, side_a, 1.0 - score_a, mirror)
      ]
    end

    private

    def rate_side(side, opp, score, mirror)
      player_var, faction_var = variances(side, mirror)
      combined_var = player_var + faction_var

      g = attenuation(Math.sqrt(variances(opp, mirror).sum))
      expected = expected_score(combined_rating(side) - combined_rating(opp), g)
      observation_var = observation_variance(expected, g)
      new_combined_var = 1.0 / ((1.0 / combined_var) + (1.0 / observation_var))
      delta = Q * new_combined_var * g * (score - expected)

      player = split(side.player_rating, player_var, combined_var, observation_var, delta)
      faction = if mirror
                  [side.faction_rating, side.faction_rd]
                else
                  split(side.faction_rating, faction_var, combined_var, observation_var, delta)
                end

      Result.new(expected: expected, player_rating: player[0], player_rd: player[1],
                 faction_rating: faction[0], faction_rd: faction[1])
    end

    def expected_score(rating_gap, attenuation)
      1.0 / (1.0 + (10.0**(-attenuation * rating_gap / 400.0)))
    end

    # Share of the combined update and posterior deviation for one component.
    def split(rating, var, combined_var, observation_var, delta)
      new_rating = rating + ((var / combined_var) * delta)
      new_var = var * (1.0 - (var / (combined_var + observation_var)))
      [new_rating.round, Math.sqrt(new_var).clamp(RD_MIN, RD_MAX).round]
    end

    def combined_rating(side)
      side.player_rating + side.faction_rating
    end

    # [player variance, faction variance]; the faction is left out of a mirror match.
    def variances(side, mirror)
      [side.player_rd.to_f**2, mirror ? 0.0 : side.faction_rd.to_f**2]
    end

    # How noisy a single game is as a measure of the combined strength.
    def observation_variance(expected, attenuation)
      1.0 / ((Q**2) * (attenuation**2) * expected * (1.0 - expected))
    end

    def attenuation(deviation)
      1.0 / Math.sqrt(1.0 + (3.0 * (Q**2) * (deviation**2) / (Math::PI**2)))
    end
  end
end
