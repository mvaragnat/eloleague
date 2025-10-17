# frozen_string_literal: true

require 'test_helper'

class StatsControllerTest < ActionDispatch::IntegrationTest
  test 'redirects guests to admin login' do
    get stats_path
    assert_response :redirect
    assert_includes @response.redirect_url, '/admins/sign_in'
  end

  test 'admin can see index' do
    admin = Admin.create!(email: 'admin@example.com', password: 'password123', password_confirmation: 'password123')
    sign_in admin, scope: :admin
    get stats_path
    assert_response :success
    assert_select 'h1', /Stats|Statistiques/
  end

  test 'factions json requires admin' do
    system = Game::System.first || Game::System.create!(name: 'TestSys', description: 'desc')
    get stats_factions_path, params: { game_system_id: system.id }
    assert_response :redirect
  end

  test 'factions json returns data for admin' do
    admin = Admin.create!(email: 'admin2@example.com', password: 'password123', password_confirmation: 'password123')
    sign_in admin, scope: :admin
    system = Game::System.first || Game::System.create!(name: 'TestSys2', description: 'desc')
    get stats_factions_path, params: { game_system_id: system.id }, as: :json
    assert_response :success
    json = JSON.parse(@response.body)
    assert json['ok']
    assert json['rows'].is_a?(Array)
  end
end
