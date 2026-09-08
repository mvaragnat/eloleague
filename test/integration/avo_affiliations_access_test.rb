# frozen_string_literal: true

require 'test_helper'

class AvoAffiliationsAccessTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: 'affiliation_admin@example.com', password: 'password123',
                           password_confirmation: 'password123')
    sign_in @admin, scope: :admin
  end

  test 'admin can access affiliations index' do
    Affiliation.find_or_create_by_name('Club des tests')

    get '/avo/resources/affiliations'
    assert_response :success
    assert_includes @response.body, 'Club des tests'
  end

  # Avo redirects /avo to the first resource in alphabetical order, which is
  # the affiliations one. That landing page must not 404.
  test 'avo root redirects to a reachable page' do
    get '/avo'
    assert_response :redirect

    follow_redirect!
    assert_response :success
  end
end
