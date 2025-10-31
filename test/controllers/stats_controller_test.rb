# frozen_string_literal: true

require 'test_helper'

class StatsControllerTest < ActionDispatch::IntegrationTest
  test 'redirects guests to user login' do
    get stats_path
    assert_response :redirect
    assert_includes @response.redirect_url, '/users/sign_in'
  end

  test 'user can see index' do
    user = User.create!(username: 'jane', email: 'jane@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user
    get stats_path
    assert_response :success
    assert_select 'h1', /Stats|Statistiques/
  end

  test 'factions json requires authentication' do
    system = Game::System.first || Game::System.create!(name: 'TestSys', description: 'desc')
    get stats_factions_path, params: { game_system_id: system.id }
    assert_response :redirect
    assert_includes @response.redirect_url, '/users/sign_in'
  end

  test 'factions json returns data for authenticated user' do
    user = User.create!(username: 'john', email: 'john@example.com', password: 'password123',
                        password_confirmation: 'password123')
    sign_in user
    system = Game::System.first || Game::System.create!(name: 'TestSys2', description: 'desc')
    get stats_factions_path, params: { game_system_id: system.id }, as: :json
    assert_response :success
    json = JSON.parse(@response.body)
    assert json['ok']
    assert json['rows'].is_a?(Array)
  end
end
