# frozen_string_literal: true

require 'test_helper'

module Api
  class ChampionshipsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @system = game_systems(:chess)
      @scoring = game_scoring_systems(:chess_default)
      @player1 = users(:player_one)
      @player2 = users(:player_two)
      @faction = game_factions(:chess_white)
    end

    test 'rankings returns 400 when game_system is missing' do
      get api_championships_rankings_path(year: 2026)
      assert_response :bad_request
      json = response.parsed_body
      assert_equal 'game_system is required', json['error']
    end

    test 'rankings returns 404 when game_system is unknown' do
      get api_championships_rankings_path(game_system: 'Unknown', year: 2026)
      assert_response :not_found
      json = response.parsed_body
      assert_equal 'game_system not found', json['error']
    end

    test 'rankings returns 400 when year is missing' do
      get api_championships_rankings_path(game_system: @system.name)
      assert_response :bad_request
      json = response.parsed_body
      assert_equal 'year is required', json['error']
    end

    test 'rankings returns empty rankings when no data exists' do
      get api_championships_rankings_path(game_system: @system.name, year: 2026)
      assert_response :success
      json = response.parsed_body
      assert_equal @system.name, json['game_system']
      assert_equal 2026, json['year']
      assert_empty json['rankings']
    end

    test 'rankings returns ranked players' do
      create_scored_tournament

      get api_championships_rankings_path(game_system: @system.name, year: 2026)
      assert_response :success
      json = response.parsed_body

      assert_equal @system.name, json['game_system']
      assert_equal 2026, json['year']
      assert_equal 2, json['rankings'].size

      first = json['rankings'].first
      assert_equal 1, first['rank']
      assert first['username'].present?
      assert first.key?('total_points')
      assert first.key?('match_points')
      assert first.key?('placement_bonus')
      assert first.key?('tournaments_count')
    end

    test 'rankings assigns equal ranks to tied players' do
      create_two_tournaments_with_tie

      get api_championships_rankings_path(game_system: @system.name, year: 2026)
      assert_response :success
      json = response.parsed_body

      ranks = json['rankings'].pluck('rank')
      assert_equal ranks.first, ranks.second
    end

    private

    def create_scored_tournament
      tournament = ::Tournament::Tournament.create!(
        name: 'API Test Swiss 2026',
        game_system: @system,
        scoring_system: @scoring,
        format: :swiss,
        state: 'completed',
        creator: @player1,
        ends_at: Time.zone.local(2026, 6, 15)
      )
      tournament.registrations.create!(user: @player1, faction: @faction)
      tournament.registrations.create!(user: @player2, faction: @faction)
      tournament.matches.create!(a_user: @player1, b_user: @player2, result: 'a_win')

      Championship::ScoreCalculator.new(tournament).call
      tournament
    end

    def create_two_tournaments_with_tie
      [1, 2].each do |i|
        tournament = ::Tournament::Tournament.create!(
          name: "Tie Tournament #{i}",
          game_system: @system,
          scoring_system: @scoring,
          format: :swiss,
          state: 'completed',
          creator: @player1,
          ends_at: Time.zone.local(2026, 6, 15)
        )
        tournament.registrations.create!(user: @player1, faction: @faction)
        tournament.registrations.create!(user: @player2, faction: @faction)
        result = i == 1 ? 'a_win' : 'b_win'
        tournament.matches.create!(a_user: @player1, b_user: @player2, result: result)

        Championship::ScoreCalculator.new(tournament).call
      end
    end
  end
end
