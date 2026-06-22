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

  test 'faction_games requires authentication' do
    faction = Game::Faction.first || Game::Faction.create!(
      game_system: Game::System.first || Game::System.create!(name: 'Sys', description: 'desc'),
      name: 'TestFaction'
    )
    get stats_faction_games_path, params: { faction_id: faction.id }
    assert_response :redirect
    assert_includes @response.redirect_url, '/users/sign_in'
  end

  test 'faction_games returns games for a faction' do
    user = User.create!(username: 'fguser', email: 'fguser@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user

    system = Game::System.create!(name: 'FGSys', description: 'desc')
    Game::ScoringSystem.create!(game_system: system, name: 'Default', is_default: true)
    faction_a = Game::Faction.create!(game_system: system, name: 'FGA')
    faction_b = Game::Faction.create!(game_system: system, name: 'FGB')
    opponent = User.create!(username: 'fgopp', email: 'fgopp@example.com', password: 'password123',
                            password_confirmation: 'password123')

    Game::Event.create!(
      game_system: system,
      played_at: Time.current,
      game_participations_attributes: [
        { user_id: user.id, faction_id: faction_a.id, score: 10 },
        { user_id: opponent.id, faction_id: faction_b.id, score: 5 }
      ]
    )

    get stats_faction_games_path, params: { faction_id: faction_a.id }
    assert_response :success
    assert_select 'turbo-frame#faction-games-frame'
  end

  test 'faction_games paginates results' do
    user = User.create!(username: 'pguser', email: 'pguser@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user

    system = Game::System.create!(name: 'PGSys', description: 'desc')
    Game::ScoringSystem.create!(game_system: system, name: 'Default', is_default: true)
    faction_a = Game::Faction.create!(game_system: system, name: 'PGA')
    faction_b = Game::Faction.create!(game_system: system, name: 'PGB')
    opponent = User.create!(username: 'pgopp', email: 'pgopp@example.com', password: 'password123',
                            password_confirmation: 'password123')

    12.times do |i|
      Game::Event.create!(
        game_system: system,
        played_at: i.days.ago,
        game_participations_attributes: [
          { user_id: user.id, faction_id: faction_a.id, score: 10 },
          { user_id: opponent.id, faction_id: faction_b.id, score: 5 }
        ]
      )
    end

    get stats_faction_games_path, params: { faction_id: faction_a.id, page: 1 }
    assert_response :success
    assert_select '.card--win, .card--loss, .card--draw', count: 10

    get stats_faction_games_path, params: { faction_id: faction_a.id, page: 2 }
    assert_response :success
    assert_select '.card--win, .card--loss, .card--draw', count: 2
  end

  test 'faction_top_players requires authentication' do
    faction = Game::Faction.first || Game::Faction.create!(
      game_system: Game::System.first || Game::System.create!(name: 'Sys', description: 'desc'),
      name: 'TestFaction'
    )
    get stats_faction_top_players_path, params: { faction_id: faction.id }
    assert_response :redirect
  end

  test 'faction_top_players returns top 5 players by games count' do
    user = User.create!(username: 'tpuser', email: 'tpuser@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user

    system = Game::System.create!(name: 'TPSys', description: 'desc')
    Game::ScoringSystem.create!(game_system: system, name: 'Default', is_default: true)
    faction_a = Game::Faction.create!(game_system: system, name: 'TPA')
    faction_b = Game::Faction.create!(game_system: system, name: 'TPB')
    opponent = User.create!(username: 'tpopp', email: 'tpopp@example.com', password: 'password123',
                            password_confirmation: 'password123')

    3.times do |i|
      Game::Event.create!(
        game_system: system,
        played_at: i.days.ago,
        game_participations_attributes: [
          { user_id: user.id, faction_id: faction_a.id, score: 10 },
          { user_id: opponent.id, faction_id: faction_b.id, score: 5 }
        ]
      )
    end

    get stats_faction_top_players_path, params: { faction_id: faction_a.id }, as: :json
    assert_response :success
    json = JSON.parse(@response.body)
    assert json['ok']
    players = json['players']
    assert_equal 1, players.size
    assert_equal user.username, players.first['username']
    assert_equal 3, players.first['games_count']
    assert_equal 100, players.first['win_percent']
    assert_equal 0, players.first['loss_percent']
    assert_equal 0, players.first['draw_percent']
    assert_not_nil players.first['profile_url']
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
