# frozen_string_literal: true

# Centralized configuration for Stats thresholds
Rails.application.config.x.stats = ActiveSupport::OrderedOptions.new unless Rails.application.config.x.respond_to?(:stats)
Rails.application.config.x.stats.min_players = ENV.fetch('STATS_MIN_PLAYERS', '4').to_i
Rails.application.config.x.stats.min_games = ENV.fetch('STATS_MIN_GAMES', '10').to_i
Rails.application.config.x.stats.min_matchup_players = [Rails.application.config.x.stats.min_players - ENV.fetch('STATS_MATCHUP_DISCOUNT', '4').to_i, 2].max
Rails.application.config.x.stats.min_matchup_games = [Rails.application.config.x.stats.min_games - ENV.fetch('STATS_MATCHUP_DISCOUNT', '4').to_i, 2].max


