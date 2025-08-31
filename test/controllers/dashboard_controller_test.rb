# frozen_string_literal: true

require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
    sign_in @user
  end

  test 'should redirect to login when not authenticated' do
    sign_out @user
    get dashboard_path(locale: I18n.locale)
    assert_redirected_to new_user_session_path(locale: I18n.locale)
  end

  test 'should show dashboard when authenticated' do
    get dashboard_path(locale: :en)
    assert_response :success
    assert_select 'h1', "Hello #{@user.username}"
  end

  test 'should show game history' do
    # Use English locale to match the expected header text in assertions
    get dashboard_path(locale: :en)
    assert_response :success
    assert_select '#games-list'
    assert_select 'h3', /Game of\s*#{Regexp.escape(game_events(:chess_game).game_system.localized_name)}/
  end

  test 'should show dashboard in French when authenticated' do
    get dashboard_path(locale: :fr)
    assert_response :success
    assert_select 'h1', "Bonjour #{@user.username}"
  end
end
