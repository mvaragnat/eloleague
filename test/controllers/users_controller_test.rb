# frozen_string_literal: true

require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
    sign_in @user
  end

  test 'should search users' do
    get users_search_path, params: { q: 'play' }
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json.size
    assert_equal users(:player_two).username, json.first['username']
  end

  test 'player profile shows ratings and games' do
    # Ensure there is at least one rating and one change/event
    system = game_systems(:chess)
    EloRating.create!(user: @user, game_system: system, rating: 1300, games_played: 2)
    event = game_events(:chess_game)
    EloChange.create!(user: @user, game_system: system, game_event: event,
                      rating_before: 1200, rating_after: 1210, expected_score: 0.5,
                      actual_score: 1.0, k_factor: 20)

    get user_path(@user, locale: I18n.locale)
    assert_response :success
    assert_match(/#{@user.username}/, @response.body)
    assert_match(/#{system.name}/, @response.body)
  end

  test 'should not include current user in search results' do
    get users_search_path, params: { q: @user.username }
    assert_response :success

    json = response.parsed_body
    assert_empty json
  end
end
