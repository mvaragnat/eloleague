# frozen_string_literal: true

require 'test_helper'

class StatsControllerTest < ActionDispatch::IntegrationTest
  test 'redirects guests to user login' do
    get stats_path
    assert_response :redirect
    assert_includes @response.redirect_url, '/users/sign_in'
  end

  test 'user can see index' do
    user = User.create!(username: 'jane', email: 'jane@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user
    get stats_path
    assert_response :success
    assert_select 'h1', /Stats|Statistiques/
  end

  test 'factions json requires authentication' do
    system = Game::System.first || Game::System.create!(name: 'TestSys', description: 'desc')
    get stats_factions_path, params: { game_system_id: system.id }
    assert_response :redirect
    assert_includes @response.redirect_url, '/users/sign_in'
  end

  test 'factions json returns data for authenticated user' do
    user = User.create!(username: 'john', email: 'john@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user
    system = Game::System.first || Game::System.create!(name: 'TestSys2', description: 'desc')
    get stats_factions_path, params: { game_system_id: system.id }, as: :json
    assert_response :success
    json = JSON.parse(@response.body)
    assert json['ok']
    assert json['rows'].is_a?(Array)
  end

  test 'factions json supports tournament_only filter' do
    user = User.create!(username: 'jules', email: 'jules@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user

    system = Game::System.create!(name: 'FilteredSys', description: 'desc')
    scoring = Game::ScoringSystem.create!(game_system: system, name: 'Default', is_default: true)
    f1 = Game::Faction.create!(game_system: system, name: 'F1')
    f2 = Game::Faction.create!(game_system: system, name: 'F2')
    opponent = User.create!(username: 'oppo', email: 'oppo@example.com', password: 'password123',
                            password_confirmation: 'password123')

    tournament = Tournament::Tournament.create!(
      name: 'Cup',
      creator: user,
      game_system: system,
      scoring_system: scoring,
      format: :open,
      state: :registration
    )

    Game::Event.create!(
      game_system: system,
      tournament: tournament,
      played_at: Time.current,
      game_participations_attributes: [
        { user_id: user.id, faction_id: f1.id, score: 10 },
        { user_id: opponent.id, faction_id: f2.id, score: 0 }
      ]
    )
    Game::Event.create!(
      game_system: system,
      played_at: 1.minute.from_now,
      game_participations_attributes: [
        { user_id: user.id, faction_id: f1.id, score: 10 },
        { user_id: opponent.id, faction_id: f2.id, score: 0 }
      ]
    )

    get stats_factions_path, params: { game_system_id: system.id }, as: :json
    all_rows = JSON.parse(@response.body)['rows']
    all_f1 = all_rows.find { |row| row['faction_id'] == f1.id }
    assert_equal 2, all_f1['total_games']

    get stats_factions_path, params: { game_system_id: system.id, tournament_only: true }, as: :json
    tournament_rows = JSON.parse(@response.body)['rows']
    tournament_f1 = tournament_rows.find { |row| row['faction_id'] == f1.id }
    assert_equal 1, tournament_f1['total_games']
  end
end
