# frozen_string_literal: true

require 'test_helper'

class AvoUserSearchTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: 'admin_user_search@example.com', password: 'password123',
                           password_confirmation: 'password123')
    sign_in @admin, scope: :admin
    @user1 = users(:player_one)
    @user2 = users(:player_two)
  end

  test 'admin can search users by username on Avo' do
    # Query a partial of player_one
    get '/avo/resources/users', params: { q: 'player_' }
    assert_response :success
    assert_includes @response.body, @user1.username
    assert_includes @response.body, @user2.username

    # Query a more specific substring only matching player_two
    get '/avo/resources/users', params: { q: 'two' }
    assert_response :success
    assert_includes @response.body, @user2.username
    assert_not_includes @response.body, @user1.username
  end
end
