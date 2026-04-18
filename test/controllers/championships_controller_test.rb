# frozen_string_literal: true

require 'test_helper'

class ChampionshipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @system = game_systems(:chess)
    @scoring = game_scoring_systems(:chess_default)
    @player1 = users(:player_one)
    @player2 = users(:player_two)
    @faction = game_factions(:chess_white)
  end

  test 'index is accessible without login' do
    get championships_path
    assert_response :success
  end

  test 'index shows game system selector' do
    get championships_path
    assert_response :success
    assert_select 'select[name="game_system_id"]'
  end

  test 'index with game system shows year selector when data exists' do
    create_scored_tournament

    get championships_path(game_system_id: @system.id)
    assert_response :success
    assert_select 'select[name="year"]'
  end

  test 'index shows standings table' do
    create_scored_tournament

    get championships_path(game_system_id: @system.id, year: 2026)
    assert_response :success
    assert_select 'table.table'
    assert_select 'td', text: @player1.username
  end

  test 'index shows no data message when no championships exist' do
    get championships_path(game_system_id: @system.id)
    assert_response :success
  end

  test 'index shows tournament breakdown table' do
    tournament = create_scored_tournament

    get championships_path(game_system_id: @system.id, year: 2026)
    assert_response :success
    assert_select 'a', text: tournament.name
  end

  private

  def create_scored_tournament
    tournament = ::Tournament::Tournament.create!(
      name: 'Championship Swiss 2026',
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
end
