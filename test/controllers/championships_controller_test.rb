# frozen_string_literal: true

require 'test_helper'

class ChampionshipsControllerTest < ActionDispatch::IntegrationTest
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
            }
          ]
        }
      }
    }
  end

  teardown do
    Championship::Config.reset_test_data!
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

  test 'index shows level rules for selected system' do
    get championships_path(game_system_id: @system.id)
    assert_response :success
    assert_select 'strong', text: 'Major'
  end

  test 'best_of limits counted results in standings' do
    Championship::Config.test_data = {
      'game_systems' => {
        'Chess' => {
          'best_of' => 2,
          'levels' => [
            { 'name' => 'Major', 'placement_bonus' => { 1 => 10, 2 => 6 }, 'participation_points' => 1 }
          ]
        }
      }
    }

    t1 = create_scored_tournament(name: 'T1')
    t2 = create_scored_tournament(name: 'T2')
    t3 = create_scored_tournament(name: 'T3')

    get championships_path(game_system_id: @system.id, year: 2026)
    assert_response :success

    p1_scores = [t1, t2, t3].map do |t|
      Championship::Score.find_by(user: @player1, tournament: t).total_points
    end
    best2 = p1_scores.sort.reverse.first(2).sum

    assert_select 'td', text: best2.to_s
  end

  test 'best_of shows rule in info box' do
    Championship::Config.test_data = {
      'game_systems' => {
        'Chess' => {
          'best_of' => 3,
          'levels' => [
            { 'name' => 'Major', 'placement_bonus' => { 1 => 10 }, 'participation_points' => 1 }
          ]
        }
      }
    }

    get championships_path(game_system_id: @system.id)
    assert_response :success
    assert_select 'p strong', /3/
  end

  private

  def create_scored_tournament(name: "Championship Swiss #{SecureRandom.hex(4)}")
    tournament = ::Tournament::Tournament.create!(
      name: name,
      game_system: @system,
      scoring_system: @scoring,
      format: :swiss,
      state: 'completed',
      creator: @player1,
      ends_at: Time.zone.local(2026, 6, 15),
      championship_level: 'Major'
    )
    tournament.registrations.create!(user: @player1, faction: @faction)
    tournament.registrations.create!(user: @player2, faction: @faction)
    tournament.matches.create!(a_user: @player1, b_user: @player2, result: 'a_win')

    Championship::ScoreCalculator.new(tournament).call
    tournament
  end
end
