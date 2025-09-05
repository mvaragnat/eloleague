# frozen_string_literal: true

require 'test_helper'

class AvoAuthIntegrationTest < ActionDispatch::IntegrationTest
  test 'avo is protected for guests' do
    get '/avo'
    assert_response :redirect
    assert_includes @response.redirect_url, '/admins/sign_in'
  end

  test 'admin can access avo after login' do
    admin = Admin.create!(email: 'admin@example.com', password: 'password123', password_confirmation: 'password123')
    sign_in admin
    get '/avo'
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end
end
