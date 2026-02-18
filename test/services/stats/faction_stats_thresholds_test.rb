# frozen_string_literal: true

require 'test_helper'

module Stats
  class FactionStatsThresholdsTest < ActiveSupport::TestCase
    def setup
      @system = Game::System.create!(name: 'Sys', description: 'desc')
      Game::ScoringSystem.create!(game_system: @system, name: 'Default', is_default: true)
      @f1 = Game::Faction.create!(game_system: @system, name: 'F1')
      @f2 = Game::Faction.create!(game_system: @system, name: 'F2')
      @users = 1.upto(6).map do |i|
        User.create!(username: "u#{i}", email: "u#{i}@e.com", password: 'password', password_confirmation: 'password')
      end
      @orig_players = Rails.application.config.x.stats.min_players
      @orig_games = Rails.application.config.x.stats.min_games
      @orig_matchup_players = Rails.application.config.x.stats.min_matchup_players
      @orig_matchup_games = Rails.application.config.x.stats.min_matchup_games
      @orig_max_share = Rails.application.config.x.stats.max_player_match_share_percent
      Rails.application.config.x.stats.min_players = 4
      Rails.application.config.x.stats.min_games = 10
      Rails.application.config.x.stats.min_matchup_players = 4
      Rails.application.config.x.stats.min_matchup_games = 10
      Rails.application.config.x.stats.max_player_match_share_percent = 60
    end

    def teardown
      Rails.application.config.x.stats.min_players = @orig_players
      Rails.application.config.x.stats.min_games = @orig_games
      Rails.application.config.x.stats.min_matchup_players = @orig_matchup_players
      Rails.application.config.x.stats.min_matchup_games = @orig_matchup_games
      Rails.application.config.x.stats.max_player_match_share_percent = @orig_max_share
    end

    test 'global winrates keeps all rows and excludes non-competitive games' do
      create_competitive_series(11)
      create_non_competitive_series(5)

      rows = Stats::FactionWinRates.new(game_system: @system).call
      f1_row = rows.find { |r| r[:faction_id] == @f1.id }
      assert f1_row, 'F1 row should be present'
      assert_equal 11, f1_row[:total_games]
    end

    test 'global winrates marks low-reliability rows with warnings instead of filtering' do
      create_competitive_series(6)
      Rails.application.config.x.stats.min_players = 10
      Rails.application.config.x.stats.min_games = 10

      rows = Stats::FactionWinRates.new(game_system: @system).call
      f1_row = rows.find { |r| r[:faction_id] == @f1.id }
      assert f1_row, 'F1 row should be present'
      assert_includes f1_row[:warnings], I18n.t('stats.warnings.insufficient_players')
      assert_includes f1_row[:warnings], I18n.t('stats.warnings.insufficient_games')
    end

    test 'versus table keeps rows below thresholds and exposes warnings' do
      create_competitive_series(6)
      Rails.application.config.x.stats.min_matchup_players = 10
      Rails.application.config.x.stats.min_matchup_games = 10

      rows = Stats::FactionVersus.new(faction: @f1).call
      f2_row = rows.find { |r| r[:opponent_faction_id] == @f2.id }
      assert f2_row, 'F2 row should be present'
      assert_equal 6, f2_row[:games]
      assert_includes f2_row[:warnings], I18n.t('stats.warnings.insufficient_players')
      assert_includes f2_row[:warnings], I18n.t('stats.warnings.insufficient_games')
    end

    test 'global winrates are sorted by win_percent desc by default' do
      create_competitive_series(11)
      rows = Stats::FactionWinRates.new(game_system: @system).call
      assert rows.size >= 2, 'Expected at least two factions in results'
      # F1 wins all games in setup, should be first
      assert_equal @f1.id, rows.first[:faction_id]
      assert rows.first[:win_percent] >= rows.second[:win_percent]
    end

    test 'global winrates warns when one player over-represents games' do
      create_dominated_series(10)
      Rails.application.config.x.stats.max_player_match_share_percent = 50

      rows = Stats::FactionWinRates.new(game_system: @system).call
      f1_row = rows.find { |r| r[:faction_id] == @f1.id }

      assert f1_row, 'F1 row should be present'
      assert_includes f1_row[:warnings],
                      I18n.t('stats.warnings.player_match_share',
                             percent: Rails.application.config.x.stats.max_player_match_share_percent)
    end

    private

    def create_competitive_series(num)
      num.times do |i|
        a_user = @users[i % @users.size]
        b_user = @users[(i + 1) % @users.size]
        Game::Event.create!(
          game_system: @system,
          played_at: Time.current + i.minutes,
          non_competitive: false,
          game_participations_attributes: [
            { user_id: a_user.id, faction_id: @f1.id, score: 10 },
            { user_id: b_user.id, faction_id: @f2.id, score: 0 }
          ]
        )
      end
    end

    def create_non_competitive_series(num)
      num.times do |i|
        Game::Event.create!(
          game_system: @system,
          played_at: 1.hour.from_now + i.minutes,
          non_competitive: true,
          game_participations_attributes: [
            { user_id: @users.first.id, faction_id: @f1.id, score: 1 },
            { user_id: @users.last.id, faction_id: @f2.id, score: 0 }
          ]
        )
      end
    end

    def create_dominated_series(num)
      num.times do |i|
        b_user = @users[(i + 1) % @users.size]
        Game::Event.create!(
          game_system: @system,
          played_at: 2.hours.from_now + i.minutes,
          non_competitive: false,
          game_participations_attributes: [
            { user_id: @users.first.id, faction_id: @f1.id, score: 10 },
            { user_id: b_user.id, faction_id: @f2.id, score: 0 }
          ]
        )
      end
    end
  end
end
