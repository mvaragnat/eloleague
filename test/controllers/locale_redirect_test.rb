# frozen_string_literal: true

require 'test_helper'

class LocaleRedirectTest < ActionDispatch::IntegrationTest
  test 'preserves query string when redirecting to cookie locale' do
    cookies[:locale] = 'fr'
    token = 'test-reset-token'

    get '/users/password/edit', params: { reset_password_token: token }

    assert_response :redirect
    location = response.redirect_url
    assert_includes location, '/fr/users/password/edit'
    assert_includes location, "reset_password_token=#{token}"
  end
end
