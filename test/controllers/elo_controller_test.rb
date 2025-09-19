# frozen_string_literal: true

require 'test_helper'

class EloControllerTest < ActionDispatch::IntegrationTest
  setup do
    @system = game_systems(:chess)
  end

  def create_user_with_elo!(username:, rating:)
    user = User.create!(username: username, email: "#{username}@example.com", password: 'password')
    EloRating.create!(user: user, game_system: @system, rating: rating, games_played: 1)
    user
  end

  test 'guest sees top 15 players (top 10 + next 5), no separators' do
    (1..25).each { |i| create_user_with_elo!(username: "guest_user_#{i}", rating: 4001 - i) }

    get elo_path, params: { game_system_id: @system.id }
    assert_response :success

    # Top 15 present
    assert_match(/guest_user_1\b/, @response.body)
    assert_match(/guest_user_15\b/, @response.body)
    # 16th not present
    assert_no_match(/guest_user_16\b/, @response.body)
    # No separators for guests
    assert_no_match(/\*\*\*/, @response.body)
  end

  test 'logged-in user in top 15 sees top 15 and bolded name without separators' do
    users = (1..25).map { |i| create_user_with_elo!(username: "user_#{i}", rating: 3001 - i) }
    target = users[11] # rank 12

    sign_in target

    get elo_path, params: { game_system_id: @system.id }
    assert_response :success

    # Bold current user
    assert_select 'tbody tr td strong', text: target.username
    # Shows up to 15
    assert_match(/user_15\b/, @response.body)
    assert_no_match(/user_16\b/, @response.body)
    # No separators
    assert_no_match(/\*\*\*/, @response.body)
  end

  test 'logged-in user below top 15 sees neighbors with separators' do
    users = (1..30).map { |i| create_user_with_elo!(username: "user_#{i}", rating: 3001 - i) }
    target = users[22] # rank 23 (zero-based index)

    sign_in target

    get elo_path, params: { game_system_id: @system.id }
    assert_response :success

    # Top still shows
    assert_match(/user_1\b/, @response.body)

    # Two separators present
    assert_equal 2, @response.body.scan('***').size

    # Neighbors around current user
    assert_match(/user_22\b/, @response.body)
    assert_select 'tbody tr td strong', text: target.username
    assert_match(/user_24\b/, @response.body)

    # Should not show the next-5 block (no user_15)
    assert_no_match(/user_15\b/, @response.body)
  end
end
