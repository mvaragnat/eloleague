# frozen_string_literal: true

require 'test_helper'

class StatsFactionRatingsTest < ActionDispatch::IntegrationTest
  test 'faction_rating_series returns rating history with deviation and resets' do
    user = User.create!(username: 'rita', email: 'rita@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user

    system = Game::System.create!(name: 'RatedSys', description: 'desc')
    Game::ScoringSystem.create!(game_system: system, name: 'Default', is_default: true)
    f1 = Game::Faction.create!(game_system: system, name: 'F1')
    f2 = Game::Faction.create!(game_system: system, name: 'F2')
    opponent = User.create!(username: 'ricky', email: 'ricky@example.com', password: 'password123',
                            password_confirmation: 'password123')

    [3.days.ago, 1.day.ago].each do |played_at|
      event = Game::Event.create!(
        game_system: system, played_at: played_at,
        game_participations_attributes: [
          { user_id: user.id, faction_id: f1.id, score: 10 },
          { user_id: opponent.id, faction_id: f2.id, score: 0 }
        ]
      )
      Elo::Updater.new.update_for_event(event)
    end
    f1.reset_rating_deviation!(Elo::Calculator::FACTION_RD_MAX, at: 2.days.ago)

    get stats_faction_rating_series_path, params: { faction_id: f1.id }, as: :json
    assert_response :success
    series = response.parsed_body['series'].first
    points = series['points']

    # start point, first game, reset, second game
    assert_equal 4, points.size
    assert_equal [Elo::Calculator::FACTION_START_RATING, Elo::Calculator::FACTION_START_DEVIATION],
                 points.first.values_at('r', 'rd')
    assert_equal Elo::Calculator::FACTION_RD_MAX, points[2]['rd']
    assert_equal points[1]['r'], points[2]['r']
    assert_equal 1, series['resets'].size
    assert_equal f1.reload.faction_rating.rating, points.last['r']

    get stats_factions_path, params: { game_system_id: system.id }, as: :json
    row = response.parsed_body['rows'].find { |r| r['faction_id'] == f1.id }
    assert_equal f1.faction_rating.rating, row['rating']
    assert_equal f1.faction_rating.rating_deviation, row['rating_deviation']
    assert row['provisional']
    # Two rated wins: actual 2.0 against the expected scores stored in the rating history
    expected = EloChange.where(faction: f1).sum(:expected_score).to_f
    assert_equal 2, row['rated_games']
    assert_in_delta 2.0, row['actual_score'], 0.001
    assert_in_delta (2.0 - expected).round(1), row['score_vs_expected'], 0.001
    # A single player behind the faction: 100% concentration
    assert_in_delta 1.0, row['concentration'], 0.001
    assert row['high_concentration']
  end

  test 'players ranking page is sorted by R and requires authentication' do
    system = game_systems(:chess)
    get stats_players_ranking_path, params: { game_system_id: system.id }
    assert_response :redirect

    user = User.create!(username: 'ranker', email: 'ranker@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user
    newcomer = User.create!(username: 'lucky', email: 'lucky@example.com', password: 'password123')
    EloRating.create!(user: newcomer, game_system: system, rating: 1900, rating_deviation: 250)
    EloRating.create!(user: user, game_system: system, rating: 1700, rating_deviation: 60)

    # High uncertainty players are hidden by default
    get stats_players_ranking_path, params: { game_system_id: system.id }
    assert_response :success
    assert_select 'input[type=checkbox][name=hide_high_uncertainty][checked]'
    assert_select 'tbody tr', 1
    assert_select 'tbody td', text: 'lucky', count: 0

    get stats_players_ranking_path, params: { game_system_id: system.id, hide_high_uncertainty: '0' }
    assert_response :success
    assert_select 'h1', I18n.t('stats.players_ranking.title')
    assert_select 'tbody tr:first-child td:nth-child(2)', 'lucky'
    assert_select 'td', '1900'
    assert_select 'td', /250/
    assert_includes response.body, 'status-badge--provisional'
  end

  test 'stats page no longer shows the players ranking' do
    sign_in users(:player_one), scope: :user
    get stats_path
    assert_response :success
    assert_not_includes response.body, I18n.t('stats.players_ranking.title')
  end
end
