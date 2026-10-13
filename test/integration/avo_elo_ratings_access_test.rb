# frozen_string_literal: true

require 'test_helper'

class AvoEloRatingsAccessTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: 'elo_admin@example.com', password: 'password123',
                           password_confirmation: 'password123')
    sign_in @admin, scope: :admin
  end

  test 'admin can access elo ratings index' do
    get '/avo/resources/elo_ratings'
    assert_response :success
    assert_includes @response.body, 'Elo ratings'
  end

  test 'admin can access faction ratings index' do
    get '/avo/resources/faction_ratings'
    assert_response :success
  end

  test 'admin can access faction rating resets index' do
    get '/avo/resources/faction_rating_resets'
    assert_response :success
  end

  test 'game factions offer the balance-patch reset action' do
    get '/avo/resources/game_factions'
    assert_response :success
    assert_includes @response.body, 'Reset rating deviation (balance patch)'
  end

  test 'reset action raises the deviation and records the reset' do
    faction = Game::Faction.create!(game_system: game_systems(:chess), name: 'Patched')
    rating = FactionRating.create!(faction: faction, game_system: faction.game_system, rating_deviation: 60)
    Avo::Actions::ResetFactionRatingDeviation.new.handle(query: [faction], fields: { rating_deviation: '150' })

    assert_equal 150, rating.reload.rating_deviation
    assert_equal 1, faction.faction_rating_resets.count
  end
end
