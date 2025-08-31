# frozen_string_literal: true

require 'application_system_test_case'

class GamesTest < ApplicationSystemTestCase
  setup do
    @user = users(:player_one)
    @other_user = users(:player_two)
    @system = game_systems(:chess)

    login_as(@user)
  end

  test 'creating a new game' do
    visit dashboard_path

    click_on I18n.t('games.add')
    assert_selector 'h2', text: I18n.t('games.new.title')

    select @system.name, from: 'game_event[game_system_id]'
    fill_in 'game_event[game_participations_attributes][0][score]', with: '21'

    fill_in I18n.t('games.new.search_placeholder'), with: @other_user.username
    find("[data-player-search-username='#{@other_user.username}']").click

    fill_in 'game_event[game_participations_attributes][1][score]', with: '18'

    # Fill optional army list
    fill_in 'game_event[game_participations_attributes][0][army_list]', with: 'My list'
    click_on I18n.t('games.new.submit')

    assert_current_path dashboard_path
    assert_text I18n.t('games.create.success')
  end

  test 'new game modal is shown when clicking add a game' do
    visit dashboard_path
    click_on I18n.t('games.add')
    assert_selector 'turbo-frame#modal' # modal frame exists
    assert_selector 'h2', text: I18n.t('games.new.title')
  end

  test 'cannot submit without selecting exactly one opponent' do
    visit dashboard_path

    click_on I18n.t('games.add')
    assert_selector 'h2', text: I18n.t('games.new.title')

    select @system.name, from: 'game_event[game_system_id]'
    fill_in 'game_event[game_participations_attributes][0][score]', with: '21'

    click_on I18n.t('games.new.submit')

    assert_text I18n.t('games.errors.exactly_two_players')
  end

  test 'cannot submit without both scores' do
    visit dashboard_path

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
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'
    click_on I18n.t('auth.login')
  end
end
