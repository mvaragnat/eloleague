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
    end

    test 'does not score open format tournaments' do
      tournament = create_tournament(format: :open)
      Championship::ScoreCalculator.new(tournament).call
      assert_equal 0, Championship::Score.count
    end

    test 'does not score non-completed tournaments' do
      tournament = create_tournament(state: 'running')
      Championship::ScoreCalculator.new(tournament).call
      assert_equal 0, Championship::Score.count
    end

    test 'calculates match points correctly for swiss tournament' do
      tournament = create_tournament(format: :swiss)
      create_match(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call

      score_p1 = Championship::Score.find_by(user: @player1, tournament: tournament)
      score_p2 = Championship::Score.find_by(user: @player2, tournament: tournament)

      assert_equal 3, score_p1.match_points
      assert_equal 1, score_p2.match_points
    end

    test 'calculates draw match points correctly' do
      tournament = create_tournament(format: :swiss)
      create_match(tournament: tournament, result: 'draw')

      Championship::ScoreCalculator.new(tournament).call

      score_p1 = Championship::Score.find_by(user: @player1, tournament: tournament)
      score_p2 = Championship::Score.find_by(user: @player2, tournament: tournament)

      assert_equal 2, score_p1.match_points
      assert_equal 2, score_p2.match_points
    end

    test 'calculates placement bonus for top 3' do
      tournament = create_tournament(format: :swiss)
      tournament.registrations.create!(user: @player1, faction: @faction)
      tournament.registrations.create!(user: @player2, faction: @faction)

      create_match(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call

      score_p1 = Championship::Score.find_by(user: @player1, tournament: tournament)
      score_p2 = Championship::Score.find_by(user: @player2, tournament: tournament)

      assert_equal 3, score_p1.placement_bonus
      assert_equal 2, score_p2.placement_bonus
    end

    test 'total_points is sum of match_points and placement_bonus' do
      tournament = create_tournament(format: :swiss)
      tournament.registrations.create!(user: @player1, faction: @faction)
      tournament.registrations.create!(user: @player2, faction: @faction)

      create_match(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call

      score_p1 = Championship::Score.find_by(user: @player1, tournament: tournament)

      assert_equal score_p1.match_points + score_p1.placement_bonus, score_p1.total_points
    end

    test 'uses ends_at year for championship year' do
      tournament = create_tournament(format: :swiss, ends_at: Time.zone.local(2025, 12, 31))
      create_match(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call

      assert_equal 2025, Championship::Score.first.year
    end

    test 'recalculates existing scores without duplicating' do
      tournament = create_tournament(format: :swiss)
      create_match(tournament: tournament, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call
      initial_count = Championship::Score.count

      Championship::ScoreCalculator.new(tournament).call
      assert_equal initial_count, Championship::Score.count
    end

    test 'scores elimination tournament' do
      tournament = create_tournament(format: :elimination)
      create_match(tournament: tournament, result: 'b_win')

      Championship::ScoreCalculator.new(tournament).call

      score_p1 = Championship::Score.find_by(user: @player1, tournament: tournament)
      score_p2 = Championship::Score.find_by(user: @player2, tournament: tournament)

      assert_equal 1, score_p1.match_points
      assert_equal 3, score_p2.match_points
    end

    private

    def create_tournament(format: :swiss, state: 'completed', ends_at: Time.zone.local(2026, 6, 15))
      ::Tournament::Tournament.create!(
        name: "Championship Test #{SecureRandom.hex(4)}",
        game_system: @system,
        scoring_system: @scoring,
        format: format,
        state: state,
        creator: @player1,
        ends_at: ends_at
      )
    end

    def create_match(tournament:, result:)
      tournament.matches.create!(
        a_user: @player1,
        b_user: @player2,
        result: result
      )
    end
  end
end
