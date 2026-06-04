# frozen_string_literal: true

require 'test_helper'

module Championship
  class ScoreCalculatorTest < ActiveSupport::TestCase
    setup do
      @system = game_systems(:chess)
      @scoring = game_scoring_systems(:chess_default)
      @player1 = users(:player_one)
      @player2 = users(:player_two)
      @faction = game_factions(:chess_white)

      Championship::Config.test_data = {
        'game_systems' => {
          'Chess' => {
            'levels' => [
              {
                'name' => 'Major',
                'placement_bonus' => { 1 => 10, 2 => 6 },
                'participation_points' => 1
              },
              {
                'name' => 'Local',
                'placement_bonus' => { 1 => 5, 2 => 3 },
                'participation_points' => 0
              }
            ]
          }
        }
      }
    end

    teardown do
      Championship::Config.reset_test_data!
    end

    test 'does not score open format tournaments' do
      tournament = create_tournament(format: :open, championship_level: 'Major')
      Championship::ScoreCalculator.new(tournament).call
      assert_equal 0, Championship::Score.count
    end

    test 'does not score tournaments without championship_level' do
      tournament = create_tournament(championship_level: nil)
      create_match_with_registrations(tournament: tournament, result: 'a_win')
      Championship::ScoreCalculator.new(tournament).call
      assert_equal 0, Championship::Score.count
    end

    test 'does not score non-completed tournaments' do
      tournament = create_tournament(state: 'running', championship_level: 'Major')
      Championship::ScoreCalculator.new(tournament).call
      assert_equal 0, Championship::Score.count
    end

    test 'awards points based on level placement_bonus for top ranks' do
      tournament = create_tournament(championship_level: 'Major')
      create_match_with_registrations(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call

      score_p1 = Championship::Score.find_by(user: @player1, tournament: tournament)
      score_p2 = Championship::Score.find_by(user: @player2, tournament: tournament)

      assert_equal 10, score_p1.total_points
      assert_equal 6, score_p2.total_points
    end

    test 'awards participation_points for unranked players' do
      player3 = User.create!(username: 'player_three', email: 'three@example.com',
                             password: 'password123',
                             password_confirmation: 'password123')

      tournament = create_tournament(championship_level: 'Major')
      tournament.registrations.create!(user: @player1, faction: @faction)
      tournament.registrations.create!(user: @player2, faction: @faction)
      tournament.registrations.create!(user: player3, faction: @faction)

      tournament.matches.create!(a_user: @player1, b_user: @player2, result: 'a_win')
      tournament.matches.create!(a_user: @player1, b_user: player3, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call

      score_p1 = Championship::Score.find_by(user: @player1, tournament: tournament)

      assert_equal 10, score_p1.total_points

      all_scores = Championship::Score.where(tournament: tournament).order(total_points: :desc)
      assert_equal 1, all_scores.last.total_points
    end

    test 'uses Local level with different points' do
      tournament = create_tournament(championship_level: 'Local')
      create_match_with_registrations(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call

      score_p1 = Championship::Score.find_by(user: @player1, tournament: tournament)
      score_p2 = Championship::Score.find_by(user: @player2, tournament: tournament)

      assert_equal 5, score_p1.total_points
      assert_equal 3, score_p2.total_points
    end

    test 'participation_points is 0 when configured as 0' do
      player3 = User.create!(username: 'player_four', email: 'four@example.com',
                             password: 'password123',
                             password_confirmation: 'password123')

      tournament = create_tournament(championship_level: 'Local')
      tournament.registrations.create!(user: @player1, faction: @faction)
      tournament.registrations.create!(user: @player2, faction: @faction)
      tournament.registrations.create!(user: player3, faction: @faction)

      tournament.matches.create!(a_user: @player1, b_user: @player2, result: 'a_win')
      tournament.matches.create!(a_user: @player1, b_user: player3, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call

      all_scores = Championship::Score.where(tournament: tournament).order(total_points: :desc)
      assert_equal 0, all_scores.last.total_points
    end

    test 'does not score when level name does not exist in config' do
      tournament = create_tournament(championship_level: 'Nonexistent')
      create_match_with_registrations(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call
      assert_equal 0, Championship::Score.count
    end

    test 'uses ends_at year for championship year' do
      tournament = create_tournament(championship_level: 'Major', ends_at: Time.zone.local(2025, 12, 31))
      create_match_with_registrations(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call
      assert_equal 2025, Championship::Score.first.year
    end

    test 'recalculates existing scores without duplicating' do
      tournament = create_tournament(championship_level: 'Major')
      create_match_with_registrations(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call
      initial_count = Championship::Score.count

      Championship::ScoreCalculator.new(tournament).call
      assert_equal initial_count, Championship::Score.count
    end

    test 'scores elimination tournament' do
      tournament = create_tournament(format: :elimination, championship_level: 'Major')
      create_match_with_registrations(tournament: tournament, result: 'b_win')

      Championship::ScoreCalculator.new(tournament).call

      score_p2 = Championship::Score.find_by(user: @player2, tournament: tournament)
      assert_equal 10, score_p2.total_points
    end

    private

    def create_tournament(format: :swiss, state: 'completed', ends_at: Time.zone.local(2026, 6, 15),
                          championship_level: nil)
      ::Tournament::Tournament.create!(
        name: "Championship Test #{SecureRandom.hex(4)}",
        game_system: @system,
        scoring_system: @scoring,
        format: format,
        state: state,
        creator: @player1,
        ends_at: ends_at,
        championship_level: championship_level
      )
    end

    def create_match_with_registrations(tournament:, result:)
      tournament.registrations.create!(user: @player1, faction: @faction)
      tournament.registrations.create!(user: @player2, faction: @faction)
      tournament.matches.create!(a_user: @player1, b_user: @player2, result: result)
    end
  end
end
