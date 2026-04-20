# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  test 'should get home when not logged in' do
    get root_path
    assert_response :success
    assert_select 'h1', 'Welcome to Eloleague'
    assert_select 'p.hero-subtitle', 'Tournaments and statistics for any game system'
    assert_select 'a', text: 'Browse tournaments'
  end

  test 'should redirect to dashboard when logged in' do
    user = users(:player_one)
    sign_in user

    get root_path
    assert_redirected_to dashboard_path(locale: I18n.locale)
  end

  test 'should get home in French' do
    get root_path(locale: :fr)
    assert_response :success
    assert_select 'h1', 'Bienvenue sur Eloleague'
    assert_select 'p.hero-subtitle', 'Tournois et statistiques pour tous les systèmes de jeu'
    assert_select 'a', text: 'Parcourir les tournois'
  end
end
