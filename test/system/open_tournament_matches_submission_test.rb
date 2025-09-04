# frozen_string_literal: true

require 'application_system_test_case'

class OpenTournamentMatchesSubmissionTest < ApplicationSystemTestCase
  setup do
    @organizer = users(:player_one)
    @participant = users(:player_two)
    @player_a = @participant
    @player_b = User.create!(username: 'player_three', email: 'three@example.com', password: 'password')
    @system = game_systems(:chess)
  end

  def login_as(user)
    visit new_user_session_path
    within('form') do
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password'
      click_button I18n.t('auth.login')
    end
  end

  def create_open_running_tournament!(creator: @organizer, system: @system)
    Tournament::Tournament.create!(
      name: 'Open Tourney',
      description: 'D',
      creator: creator,
      game_system: system,
      format: 'open',
      state: 'running'
    )
  end

  def register!(tournament, user)
    Tournament::Registration.create!(tournament: tournament, user: user)
  end

  def select_in_first_block(username)
    within first('.participation-block') do
      within('[data-player-search-target="container"]') do
        fill_in I18n.t('games.new.search_placeholder'), with: username
      end
    end
    find("[data-player-search-username='#{username}']").click
  end

  def select_in_second_block(username)
    within all('.participation-block')[1] do
      within('[data-player-search-target="container"]') do
        fill_in I18n.t('games.new.search_placeholder'), with: username
      end
    end
    find("[data-player-search-username='#{username}']").click
  end

  def choose_factions_for_both_players(label: 'White')
    # Wait for factions to load
    assert_selector "select[name='game_event[game_participations_attributes][0][faction_id]']"
    assert_selector "select[name='game_event[game_participations_attributes][1][faction_id]']"

    select label, from: 'game_event[game_participations_attributes][0][faction_id]'
    select label, from: 'game_event[game_participations_attributes][1][faction_id]'
  end

  test 'participant can submit an Open tournament match from the tournament page' do
    tournament = create_open_running_tournament!
    register!(tournament, @participant)
    register!(tournament, @organizer) # Opponent also registered

    login_as(@participant)
    visit tournament_path(tournament, locale: I18n.locale)
    click_on I18n.t('tournaments.show.tabs.matches', default: 'Matches')

    click_on I18n.t('games.add')
    assert_selector 'h2', text: I18n.t('tournaments.show.matches', default: 'Matches')

    # Intended behavior: current user is preselected as Player A and cannot be removed (for participants)
    within first('.participation-block') do
      # Preselection UI exists
      assert_selector '.selected-player', count: 1
      # Remove button should not be present for preselected current user (intended)
      assert_no_selector '.selected-player button'
    end

    # Select players in both blocks
    # First block should already be current user; selecting again is not needed
    select_in_second_block(@organizer.username)

    # Fill scores
    fill_in 'game_event[game_participations_attributes][0][score]', with: '10'
    fill_in 'game_event[game_participations_attributes][1][score]', with: '8'

    # Select factions
    choose_factions_for_both_players

    assert_difference -> { Game::Event.count }, 1 do
      assert_difference -> { Tournament::Match.count }, 1 do
        click_on I18n.t('games.new.submit')
        # Modal should close via turbo stream
        assert_no_selector 'turbo-frame#modal', wait: 5
      end
    end
  end

  test 'organizer who is also a player can submit an Open tournament match' do
    tournament = create_open_running_tournament!(creator: @organizer)
    register!(tournament, @organizer)
    register!(tournament, @participant)

    login_as(@organizer)
    visit tournament_path(tournament, locale: I18n.locale)
    click_on I18n.t('tournaments.show.tabs.matches', default: 'Matches')
    click_on I18n.t('games.add')
    assert_selector 'h2', text: I18n.t('tournaments.show.matches', default: 'Matches')

    # Organizer is preselected and can remove themselves
    within first('.participation-block') do
      assert_selector '.selected-player button'
    end
    select_in_second_block(@participant.username)

    fill_in 'game_event[game_participations_attributes][0][score]', with: '12'
    fill_in 'game_event[game_participations_attributes][1][score]', with: '9'
    choose_factions_for_both_players

    assert_difference -> { Game::Event.count }, 1 do
      assert_difference -> { Tournament::Match.count }, 1 do
        click_on I18n.t('games.new.submit')
        assert_no_selector 'turbo-frame#modal', wait: 5
      end
    end
  end

  test 'organizer-player can unselect self and submit a match between A and B' do
    tournament = create_open_running_tournament!(creator: @organizer)
    register!(tournament, @organizer)
    register!(tournament, @player_a)
    register!(tournament, @player_b)

    login_as(@organizer)
    visit tournament_path(tournament, locale: I18n.locale)
    click_on I18n.t('tournaments.show.tabs.matches', default: 'Matches')
    click_on I18n.t('games.add')

    # Remove preselected (if any) and select two other players
    within first('.participation-block') do
      find('.selected-player button').click if has_selector?('.selected-player button', wait: 1)
    end
    select_in_first_block(@player_a.username)
    select_in_second_block(@player_b.username)

    fill_in 'game_event[game_participations_attributes][0][score]', with: '7'
    fill_in 'game_event[game_participations_attributes][1][score]', with: '3'
    choose_factions_for_both_players

    assert_difference -> { Game::Event.count }, 1 do
      assert_difference -> { Tournament::Match.count }, 1 do
        click_on I18n.t('games.new.submit')
        assert_no_selector 'turbo-frame#modal', wait: 5
      end
    end
  end

  test 'organizer not a player can submit a match between A and B' do
    tournament = create_open_running_tournament!(creator: @organizer)
    # Organizer NOT registered
    register!(tournament, @player_a)
    register!(tournament, @player_b)

    login_as(@organizer)
    visit tournament_path(tournament, locale: I18n.locale)
    click_on I18n.t('tournaments.show.tabs.matches', default: 'Matches')
    click_on I18n.t('games.add')

    select_in_first_block(@player_a.username)
    select_in_second_block(@player_b.username)

    fill_in 'game_event[game_participations_attributes][0][score]', with: '15'
    fill_in 'game_event[game_participations_attributes][1][score]', with: '14'
    choose_factions_for_both_players

    assert_difference -> { Game::Event.count }, 1 do
      assert_difference -> { Tournament::Match.count }, 1 do
        click_on I18n.t('games.new.submit')
        assert_no_selector 'turbo-frame#modal', wait: 5
      end
    end
  end

  test 'participant cannot submit a match between two other players (should be restricted)' do
    tournament = create_open_running_tournament!(creator: @organizer)
    # Current user is a participant but not the organizer
    register!(tournament, @participant)
    other1 = User.create!(username: 'player_four', email: 'four@example.com', password: 'password')
    other2 = User.create!(username: 'player_five', email: 'five@example.com', password: 'password')
    register!(tournament, other1)
    register!(tournament, other2)

    login_as(@participant)
    visit tournament_path(tournament)
    click_on I18n.t('tournaments.show.tabs.matches', default: 'Matches')
    click_on I18n.t('games.add')

    # Attempt to report a match between two different players (not including current user)
    select_in_first_block(other1.username)
    select_in_second_block(other2.username)

    fill_in 'game_event[game_participations_attributes][0][score]', with: '11'
    fill_in 'game_event[game_participations_attributes][1][score]', with: '9'
    choose_factions_for_both_players

    assert_no_difference -> { Game::Event.count } do
      assert_no_difference -> { Tournament::Match.count } do
        click_on I18n.t('games.new.submit')
        # Ideally, UI or server should block this action for non-organizers
      end
    end
  end
end
