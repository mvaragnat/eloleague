# frozen_string_literal: true

module Elo
  # Glicko-style rating of a (player + faction) pair.
  #
  # Each side's effective strength combines the player and faction ratings with
  # coefficients (cp, cf): cp·R_player + cf·R_faction, uncertainties combining as
  # cp²·RD_player² + cf²·RD_faction². With a player influence a (PLAYER_INFLUENCE)
  # the coefficients are (a, 1 - a), a weighted mean that caps the faction's
  # influence; without it they are (1, 1), the plain additive model.
  # A game yields one Glicko update for the combined pair, which is then split
  # between player and faction in proportion to cp·RD_player² and cf·RD_faction²:
  # the most uncertain component absorbs most of the signal. Deviations shrink at
  # the natural (additive, Kalman) pace whatever the coefficients:
  # RD'² = RD² − RD⁴ / (RD_player² + RD_faction² + v). The influence only governs how
  # much the ratings move, never how fast uncertainty decreases (spec section 7.3).
  #
  # When a faction is mostly played by a few players, its games say more about
  # them than about the faction. A diversity factor d (effective / actual number
  # of contributors, Herfindahl index) then shrinks the faction's share of the
  # change (the rest goes to the player) and inflates the observation variance
  # used for the faction deviation (v / d), so it shrinks more slowly.
  #
  # All maths run in floats; results are rounded to integers for storage.
  class Calculator
    Q = Math.log(10) / 400.0

    # Tunable parameters, see config/initializers/rating.rb
    SETTINGS = Rails.application.config.x.rating
    START_RATING = SETTINGS.player_start_rating
    START_DEVIATION = SETTINGS.player_start_deviation
    RD_MIN = SETTINGS.min_deviation
    RD_MAX = START_DEVIATION
    # A faction's deviation never exceeds its start deviation.
    FACTION_START_RATING = SETTINGS.faction_start_rating
    FACTION_START_DEVIATION = SETTINGS.faction_start_deviation
    FACTION_RD_MAX = FACTION_START_DEVIATION
    # Player influence a (factions weigh 1 - a); nil for the additive model.
    PLAYER_INFLUENCE = SETTINGS.player_influence
    # Above this deviation a rating is shown as provisional.
    PROVISIONAL_RD = SETTINGS.provisional_deviation
    # Seeding rating: R - CONSERVATIVE_FACTOR * RD.
    CONSERVATIVE_FACTOR = SETTINGS.conservative_factor
    DIVERSITY_WINDOW_MONTHS = SETTINGS.diversity_window_months
    # Above this concentration (Herfindahl index) a faction rating is flagged.
    HIGH_CONCENTRATION = SETTINGS.high_concentration

    Side = Struct.new(:player_rating, :player_rd, :faction_rating, :faction_rd, :faction_diversity,
                      keyword_init: true) do
      def diversity
        faction_diversity || 1.0
      end
    end
    Diversity = Struct.new(:effective_players, :players, :factor, keyword_init: true)
    Result = Struct.new(:expected, :player_rating, :player_rd, :faction_rating, :faction_rd, keyword_init: true)

    class << self
      def high_concentration?(concentration)
        concentration.present? && concentration > HIGH_CONCENTRATION
      end

      def provisional?(deviation)
        deviation.to_i > PROVISIONAL_RD
      end

      # Cautious lower bound R - k·RD, used for elimination seeding.
      def conservative(rating, deviation)
        (rating - (CONSERVATIVE_FACTOR * deviation)).round
      end

      # Concentration of a faction's games among its players.
      # `games_by_player` holds the number of games each player played with the faction.
      # N_eff = 1 / sum(share²); d = N_eff / N (1.0 when there is no data).
      def diversity(games_by_player)
        counts = games_by_player.select(&:positive?)
        total = counts.sum.to_f
        return Diversity.new(effective_players: 0.0, players: 0, factor: 1.0) if total.zero?

        effective = 1.0 / counts.sum { |n| (n / total)**2 }
        Diversity.new(effective_players: effective, players: counts.size, factor: effective / counts.size)
      end
    end

    # Rates one game. `score_a` is 1.0 (A wins), 0.5 (draw) or 0.0 (B wins).
    # In a mirror match the faction cancels out and teaches nothing: it is left
    # out of the uncertainty and only the players are updated.
    # Returns [Result for A, Result for B].
    def initialize(player_influence: PLAYER_INFLUENCE)
      @player_coef, @faction_coef = player_influence ? [player_influence, 1.0 - player_influence] : [1.0, 1.0]
    end

    def rate(side_a, side_b, score_a, mirror: false)
      [
        rate_side(side_a, side_b, score_a, mirror),
        rate_side(side_b, side_a, 1.0 - score_a, mirror)
      ]
    end

    private

    def rate_side(side, opp, score, mirror)
      player_var, faction_var = variances(side, mirror)
      combined_var = combined_variance(player_var, faction_var)

      g = attenuation(Math.sqrt(combined_variance(*variances(opp, mirror))))
      expected = expected_score(combined_rating(side) - combined_rating(opp), g)
      observation_var = observation_variance(expected, g)
      delta = combined_change(combined_var, observation_var, g, score - expected)

      # The faction takes its weighted variance share scaled by diversity; the player takes the rest.
      faction_weight = faction_share(player_var, faction_var) * side.diversity
      # Uncertainty decreases independently of the influence coefficients
      raw_var = player_var + faction_var
      player = split(side.player_rating, player_var, (1.0 - faction_weight) * delta,
                     raw_var + observation_var, RD_MAX)
      faction = if mirror
                  [side.faction_rating, side.faction_rd]
                else
                  split(side.faction_rating, faction_var, faction_weight * delta,
                        raw_var + (observation_var / side.diversity), FACTION_RD_MAX)
                end

      Result.new(expected: expected, player_rating: player[0], player_rd: player[1],
                 faction_rating: faction[0], faction_rd: faction[1])
    end

    # Glicko update of the combined (player + faction) rating.
    def combined_change(combined_var, observation_var, attenuation, surprise)
      new_combined_var = 1.0 / ((1.0 / combined_var) + (1.0 / observation_var))
      Q * new_combined_var * attenuation * surprise
    end

    def expected_score(rating_gap, attenuation)
      1.0 / (1.0 + (10.0**(-attenuation * rating_gap / 400.0)))
    end

    # Faction share of the combined change: cf·RD_f² / (cp·RD_i² + cf·RD_f²).
    def faction_share(player_var, faction_var)
      weighted_faction = @faction_coef * faction_var
      weighted_faction / ((@player_coef * player_var) + weighted_faction)
    end

    # Applies one component's share of the combined change and its posterior deviation
    # RD'² = RD² − RD⁴ / innovation_var, where `innovation_var` is RD_player² + RD_faction²
    # plus the observation variance.
    def split(rating, var, change, innovation_var, rd_max)
      new_rating = rating + change
      new_var = var * (1.0 - (var / innovation_var))
      [new_rating.round, Math.sqrt(new_var).clamp(RD_MIN, rd_max).round]
    end

    def combined_rating(side)
      (@player_coef * side.player_rating) + (@faction_coef * side.faction_rating)
    end

    # cp²·RD_i² + cf²·RD_f²
    def combined_variance(player_var, faction_var)
      ((@player_coef**2) * player_var) + ((@faction_coef**2) * faction_var)
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
