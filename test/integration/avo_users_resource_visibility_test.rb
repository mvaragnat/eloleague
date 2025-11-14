# frozen_string_literal: true

require 'test_helper'

class AvoUsersResourceVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: 'admin+users@example.com', password: 'password123',
                           password_confirmation: 'password123')
    sign_in @admin, scope: :admin
  end

  test 'new user page shows password fields' do
    get '/avo/resources/users/new'
    assert_response :success
    assert_select 'input[type=password]', minimum: 1
  end

  test 'edit user page hides password fields' do
    user = users(:player_one)
    get "/avo/resources/users/#{user.id}/edit"
    assert_response :success
    assert_select 'input[type=password]', false
  end
end
