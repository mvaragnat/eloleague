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
  # Initial rating R and deviation RD of a new faction. The faction deviation is also
  # its maximum: a game's change is split between player and faction in proportion to
  # RD², so two newcomers split it 350² : 150² (about 84 / 16).
  rating.faction_start_rating = ENV.fetch('RATING_FACTION_START', '1300').to_i
  rating.faction_start_deviation = ENV.fetch('RATING_FACTION_START_RD', '150').to_i
  # Lowest deviation anyone can reach; a player's maximum is its start deviation
  # si cette valeur est trop basse (exemple : 5) un joueur tres actif ne verrait presque plus son score bouger. garder min 30 environ
  rating.min_deviation = ENV.fetch('RATING_MIN_RD', '30').to_i
  # Ratings are flagged "provisional" above this deviation
  rating.provisional_deviation = ENV.fetch('RATING_PROVISIONAL_RD', '100').to_i
  # A faction's concentration (Herfindahl index of its games among players, 0..1) is
  # flagged as too high above this value. 0.5 = fewer than 2 "effective" players.
  rating.high_concentration = ENV.fetch('RATING_HIGH_CONCENTRATION', '0.5').to_f
  # Displayed and seeding rating: R - conservative_factor * RD
  rating.conservative_factor = ENV.fetch('RATING_CONSERVATIVE_FACTOR', '2').to_f
  # Window over which a faction's player concentration is measured
  rating.diversity_window_months = ENV.fetch('RATING_DIVERSITY_WINDOW_MONTHS', '12').to_i
end
