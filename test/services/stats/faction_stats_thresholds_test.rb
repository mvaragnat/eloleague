# frozen_string_literal: true

require 'test_helper'

module Stats
  class FactionStatsThresholdsTest < ActiveSupport::TestCase
    def setup
      @system = Game::System.create!(name: 'Sys', description: 'desc')
      @f1 = Game::Faction.create!(game_system: @system, name: 'F1')
      @f2 = Game::Faction.create!(game_system: @system, name: 'F2')
      @users = 1.upto(6).map do |i|
        User.create!(username: "u#{i}", email: "u#{i}@e.com", password: 'password', password_confirmation: 'password')
      end
      @orig_players = Rails.application.config.x.stats.min_players
      @orig_games = Rails.application.config.x.stats.min_games
      Rails.application.config.x.stats.min_players = 4
      Rails.application.config.x.stats.min_games = 10
    end

    def teardown
      Rails.application.config.x.stats.min_players = @orig_players
      Rails.application.config.x.stats.min_games = @orig_games
    end

    test 'global winrates excludes rows below thresholds and non-competitive games' do
      create_competitive_series(11)
      create_non_competitive_series(5)

      rows = Stats::FactionWinRates.new(game_system: @system).call
      assert rows.any? { |r| r[:faction_id] == @f1.id }, 'F1 row should be present'
      assert(rows.all? { |r| r[:total_games] >= Rails.application.config.x.stats.min_games })
      assert(rows.all? { |r| r[:unique_players] >= Rails.application.config.x.stats.min_players })
    end

    test 'versus table filters rows per opponent below thresholds' do
      create_competitive_series(11)

      rows = Stats::FactionVersus.new(faction: @f1).call
      f2_row = rows.find { |r| r[:opponent_faction_id] == @f2.id }
      assert f2_row, 'F2 row should be present'
      assert f2_row[:games] >= Rails.application.config.x.stats.min_games
      assert f2_row[:unique_players] >= Rails.application.config.x.stats.min_players
    end

    test 'global winrates are sorted by win_percent desc by default' do
      create_competitive_series(11)
      rows = Stats::FactionWinRates.new(game_system: @system).call
      assert rows.size >= 2, 'Expected at least two factions in results'
      # F1 wins all games in setup, should be first
      assert_equal @f1.id, rows.first[:faction_id]
      assert rows.first[:win_percent] >= rows.second[:win_percent]
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
  end
end
