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
    f1.reset_rating_deviation!(150, at: 2.days.ago)

    get stats_faction_rating_series_path, params: { faction_id: f1.id }, as: :json
    assert_response :success
    series = response.parsed_body['series'].first
    points = series['points']

    # start point, first game, reset, second game
    assert_equal 4, points.size
    assert_equal [1500, 150], points.first.values_at('r', 'rd')
    assert_equal 150, points[2]['rd']
    assert_equal points[1]['r'], points[2]['r']
    assert_equal 1, series['resets'].size
    assert_equal f1.reload.faction_rating.rating, points.last['r']

    get stats_factions_path, params: { game_system_id: system.id }, as: :json
    row = response.parsed_body['rows'].find { |r| r['faction_id'] == f1.id }
    assert_equal f1.faction_rating.rating, row['rating']
    assert_equal f1.faction_rating.rating_deviation, row['rating_deviation']
    assert row['provisional']
    assert_in_delta 1.0, row['effective_players'], 0.001
    assert_equal 1, row['distinct_players']
  end

  test 'players ranking is sorted by R - 2 RD and requires authentication' do
    system = game_systems(:chess)
    get stats_players_path, params: { game_system_id: system.id }
    assert_response :redirect

    user = User.create!(username: 'ranker', email: 'ranker@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user, scope: :user
    newcomer = User.create!(username: 'lucky', email: 'lucky@example.com', password: 'password123')
    EloRating.create!(user: newcomer, game_system: system, rating: 1900, rating_deviation: 250) # 1400
    EloRating.create!(user: user, game_system: system, rating: 1700, rating_deviation: 60)      # 1580

    get stats_players_path, params: { game_system_id: system.id }
    assert_response :success
    assert_operator response.body.index('ranker'), :<, response.body.index('lucky')
    assert_includes response.body, '1580'
    assert_includes response.body, 'status-badge--provisional'
  end
end
