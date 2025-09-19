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

  test 'paginates standings and defaults to page containing current user, highlights name' do
    # Create 30 users ranked from 3000 down to 2971 (unique ratings)
    users = (1..30).map do |i|
      create_user_with_elo!(username: "user_#{i}", rating: 3001 - i)
    end

    # Target user is rank 23 (page 3 when per=10)
    target = users[22] # zero-based index => 23rd user

    sign_in target

    get elo_path, params: { game_system_id: @system.id, per: 10 }
    assert_response :success

    # Page indicator should read 3 of 3
    assert_select 'span.card-date', text: I18n.t('elo.page_of', page: 3, total: 3)

    # Current user is bolded in standings
    assert_select 'tbody tr td strong', text: target.username

    # A top-ranked user from page 1 should not be on page 3
    assert_no_match(/user_1\b/, @response.body)
  end

  test 'without login defaults to first page' do
    (1..25).each { |i| create_user_with_elo!(username: "guest_user_#{i}", rating: 4001 - i) }

    get elo_path, params: { game_system_id: @system.id, per: 10 }
    assert_response :success

    # First page should contain top user and not contain an item from page 3
    assert_match(/guest_user_1\b/, @response.body)
    assert_no_match(/guest_user_21\b/, @response.body)
  end
end
