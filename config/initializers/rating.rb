# frozen_string_literal: true

# Rating parameters (player + faction Glicko-style ratings, see Elo::Calculator).
# Each value can be overridden with the environment variable named next to it.
# After changing any of them, restart the app and run `rails elo:rebuild`:
# existing ratings are not migrated.
Rails.application.config.x.rating = ActiveSupport::OrderedOptions.new
Rails.application.config.x.rating.tap do |rating|
  # Initial rating R and deviation RD of a new player
  rating.player_start_rating = ENV.fetch('RATING_PLAYER_START', '1500').to_i
  rating.player_start_deviation = ENV.fetch('RATING_PLAYER_START_RD', '250').to_i
  # Initial rating R and deviation RD of a new faction (the deviation is also its maximum).
  rating.faction_start_rating = ENV.fetch('RATING_FACTION_START', '1500').to_i
  rating.faction_start_deviation = ENV.fetch('RATING_FACTION_START_RD', '250').to_i
  # Player influence a (0 < a <= 1) on a game: each side's strength is
  # R_player + ((1 - a) / a)·R_faction, so the faction weighs (1 - a) against a for the player
  # while player ratings keep the Elo scale. A game's change is split between player and
  # faction in proportion to a·RD_player² and (1 - a)·RD_faction². 0.7 = factions weigh 30%.
  # 0.5 (or an empty value) is the plain additive model R_player + R_faction.
  rating.player_influence = ENV.fetch('RATING_PLAYER_INFLUENCE', '0.7').presence&.to_f
  # Lowest deviation anyone can reach; a player's maximum is its start deviation
  # si cette valeur est trop basse (exemple : 5) un joueur tres actif ne verrait presque plus son score bouger. garder min 30 environ
  rating.min_deviation = ENV.fetch('RATING_MIN_RD', '30').to_i
  # Ratings are flagged "provisional" above this deviation
  rating.provisional_deviation = ENV.fetch('RATING_PROVISIONAL_RD', '100').to_i
  # A faction's concentration (Herfindahl index of its games among players, 0..1) is
  # flagged as too high above this value. 0.5 = fewer than 2 "effective" players.
  rating.high_concentration = ENV.fetch('RATING_HIGH_CONCENTRATION', '0.3').to_f
  # Balance target: between two players of the same level, a faction gap may shift the win
  # probability by at most this much (0.05 = 55/45). The Stats faction table draws the
  # matching band around the faction start rating (about ±41 with a = 0.7).
  rating.balance_max_shift = ENV.fetch('RATING_BALANCE_MAX_SHIFT', '0.05').to_f
  # Elimination seeding uses the cautious lower bound R - conservative_factor * RD
  rating.conservative_factor = ENV.fetch('RATING_CONSERVATIVE_FACTOR', '2').to_f
  # Window over which a faction's player concentration is measured
  rating.diversity_window_months = ENV.fetch('RATING_DIVERSITY_WINDOW_MONTHS', '12').to_i
end
