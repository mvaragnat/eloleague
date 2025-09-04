# frozen_string_literal: true

require 'application_system_test_case'

class GamesTest < ApplicationSystemTestCase
  setup do
    @user = users(:player_one)
    @other_user = users(:player_two)
    @system = game_systems(:chess)
    @faction = game_factions(:chess_white)

    login_as(@user)
  end

  test 'creating a new game with two players from dashboard' do
    visit dashboard_path(locale: I18n.locale)

    click_on I18n.t('games.add')
    assert_selector 'h2', text: I18n.t('games.new.title')

    # Assert two independent participation blocks exist
    assert_selector '.participation-block', count: 2

    select @system.name, from: 'game_event[game_system_id]'
    fill_in 'game_event[game_participations_attributes][0][score]', with: '21'

    fill_in I18n.t('games.new.search_placeholder'), with: @other_user.username
    find("[data-player-search-username='#{@other_user.username}']").click

    fill_in 'game_event[game_participations_attributes][1][score]', with: '18'

    # Select factions for both players
    select @faction.name, from: 'game_event[game_participations_attributes][0][faction_id]'
    select @faction.name, from: 'game_event[game_participations_attributes][1][faction_id]'

    # Hidden user_id fields should exist for both participations
    assert_selector "input[name='game_event[game_participations_attributes][0][user_id]']", count: 1
    assert_selector "input[name='game_event[game_participations_attributes][1][user_id]']", count: 1

    # Fill optional army list
    fill_in 'game_event[game_participations_attributes][0][army_list]', with: 'My list'
    click_on I18n.t('games.new.submit')

    assert_current_path dashboard_path
    assert_text I18n.t('games.create.success')
  end

  test 'cannot submit with only one selected player' do
    visit dashboard_path(locale: I18n.locale)

    click_on I18n.t('games.add')
    assert_selector 'h2', text: I18n.t('games.new.title')

    select @system.name, from: 'game_event[game_system_id]'
    fill_in 'game_event[game_participations_attributes][0][score]', with: '10'

    fill_in I18n.t('games.new.search_placeholder'), with: @other_user.username
    find("[data-player-search-username='#{@other_user.username}']").click

    # Do not fill opponent score or factions to trigger the client-side validation first
    click_on I18n.t('games.new.submit')

    assert_text I18n.t('games.errors.exactly_two_players')
  end

  test 'new game modal is shown when clicking add a game' do
    visit dashboard_path(locale: I18n.locale)
    click_on I18n.t('games.add')
    assert_selector 'turbo-frame#modal' # modal frame exists
    assert_selector 'h2', text: I18n.t('games.new.title')
  end

  test 'cannot submit without selecting exactly one opponent' do
    visit dashboard_path(locale: I18n.locale)

    click_on I18n.t('games.add')
    assert_selector 'h2', text: I18n.t('games.new.title')

    select @system.name, from: 'game_event[game_system_id]'
    fill_in 'game_event[game_participations_attributes][0][score]', with: '21'

    click_on I18n.t('games.new.submit')

    assert_text I18n.t('games.errors.exactly_two_players')
  end

  test 'cannot submit without both scores' do
    visit dashboard_path(locale: I18n.locale)

    click_on I18n.t('games.add')
    select @system.name, from: 'game_event[game_system_id]'
    fill_in 'game_event[game_participations_attributes][0][score]', with: '21'

    fill_in I18n.t('games.new.search_placeholder'), with: @other_user.username
    find("[data-player-search-username='#{@other_user.username}']").click

    # Omit opponent score
    click_on I18n.t('games.new.submit')

    assert_text I18n.t('games.errors.both_scores_required')
  end

  private

  def login_as(user)
    visit new_user_session_path
    within('form') do
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password'
      click_button I18n.t('auth.login')
    end
  end
end
