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
end
