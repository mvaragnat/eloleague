# frozen_string_literal: true

require 'test_helper'

class EloIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:player_one)
    @player2 = users(:player_two)
    @system = game_systems(:chess)
  end

  test 'tournament registration, lock, pairing and result reporting' do
    # Creator signs in and creates a swiss tournament
    sign_in @creator
    # sign_in does not issue a request; no response to assert here

    post tournaments_path(locale: I18n.locale), params: {
      tournament: {
        name: 'Swiss Challenge',
        description: 'Test swiss',
        game_system_id: @system.id,
        format: 'swiss',
        rounds_count: 3
      }
    }
    assert_response :redirect
    t = ::Tournament::Tournament.order(:created_at).last

    # Creator registers and checks in
    post register_tournament_path(t, locale: I18n.locale)
    assert_response :redirect
    f = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
    t.registrations.find_by(user: @creator).update!(faction: f)
    post check_in_tournament_path(t, locale: I18n.locale)
    assert_response :redirect

    # Another player registers and checks in
    sign_out @creator
    sign_in @player2
    assert_response :redirect
    post register_tournament_path(t, locale: I18n.locale)
    assert_response :redirect
    f2 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Black')
    t.registrations.find_by(user: @player2).update!(faction: f2)
    post check_in_tournament_path(t, locale: I18n.locale)
    assert_response :redirect

    # Creator locks registration and starts round (pairings)
    sign_out @player2
    sign_in @creator
    post lock_registration_tournament_path(t, locale: I18n.locale)
    assert_response :redirect
    post next_round_tournament_path(t, locale: I18n.locale)
    assert_response :redirect

    match = t.matches.order(:created_at).last
    assert_not_nil match

    # Non-participant cannot report
    stranger = User.create!(username: 'stranger', email: 'stranger@example.com', password: 'password')
    sign_out @creator
    sign_in stranger
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 1, b_score: 0 } }
    assert_redirected_to tournament_tournament_match_path(t, match, locale: I18n.locale)

    # Participant can report
    sign_out stranger
    sign_in @player2
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 1, b_score: 0 } }
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 1, round_tab: 0)

    match.reload
    assert_equal 'a_win', match.result
    event_id = match.game_event_id
    assert_not_nil event_id

    # After reported, only organizer can modify
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 0, b_score: 1 } }
    assert_redirected_to tournament_tournament_match_path(t, match, locale: I18n.locale)
    match.reload
    assert_equal 'a_win', match.result

    sign_out @player2
    sign_in @creator
    patch tournament_tournament_match_path(t, match, locale: I18n.locale),
          params: { tournament_match: { a_score: 0, b_score: 1 } }
    assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 1, round_tab: 0)
    match.reload
    assert_equal 'b_win', match.result
  end
end
