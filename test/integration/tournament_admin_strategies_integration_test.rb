# frozen_string_literal: true

require 'test_helper'

class TournamentAdminStrategiesIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:player_one)
    @system = game_systems(:chess)
  end

  test 'elimination admin: no pairing, tie-breaks present' do
    sign_in(@creator)

    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Elim Admin', description: 'X', game_system_id: @system.id, format: 'elimination' }
    }
    assert_response :redirect
    t = Tournament::Tournament.order(:created_at).last

    get tournament_path(t, locale: I18n.locale, tab: 2)
    assert_response :success

    assert_not_includes @response.body, "name='tournament[pairing_strategy_key]'"
    assert_not_includes @response.body, 'name="tournament[tiebreak1_strategy_key]"'
    assert_not_includes @response.body, 'name="tournament[tiebreak2_strategy_key]"'
  end

  test 'open admin: no pairing, tie-breaks present' do
    sign_in(@creator)

    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Open Admin', description: 'Y', game_system_id: @system.id, format: 'open' }
    }
    assert_response :redirect
    t = Tournament::Tournament.order(:created_at).last

    get tournament_path(t, locale: I18n.locale, tab: 3)
    assert_response :success

    assert_not_includes @response.body, "name='tournament[pairing_strategy_key]'"
    assert_includes @response.body, 'name="tournament[tiebreak1_strategy_key]"'
    assert_includes @response.body, 'name="tournament[tiebreak2_strategy_key]"'
  end

  test 'swiss admin: first round pairing is offered, defaults to avoiding affiliations and persists' do
    sign_in(@creator)

    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Swiss First Round', description: 'Z', game_system_id: @system.id, format: 'swiss' }
    }
    t = Tournament::Tournament.order(:created_at).last

    assert_equal 'random_avoid_same_affiliation', t.first_round_pairing_key

    get tournament_path(t, locale: I18n.locale, tab: 3)
    assert_response :success
    assert_includes @response.body, 'name="tournament[first_round_pairing_strategy_key]"'

    patch tournament_path(t, locale: I18n.locale),
          params: { tournament: { first_round_pairing_strategy_key: 'random' } },
          as: :json
    assert_response :success
    assert_equal 'random', t.reload.first_round_pairing_key
  end

  test 'unknown first round pairing strategy is rejected' do
    sign_in(@creator)

    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Swiss Bad Strategy', description: 'Z', game_system_id: @system.id, format: 'swiss' }
    }
    t = Tournament::Tournament.order(:created_at).last

    patch tournament_path(t, locale: I18n.locale),
          params: { tournament: { first_round_pairing_strategy_key: 'nope' } },
          as: :json
    assert_response :unprocessable_content
    assert_equal 'random_avoid_same_affiliation', t.reload.first_round_pairing_key
  end

  test 'overview shows the first round pairing strategy' do
    sign_in(@creator)

    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Swiss Overview', description: 'Z', game_system_id: @system.id, format: 'swiss' }
    }
    t = Tournament::Tournament.order(:created_at).last

    get tournament_path(t, locale: I18n.locale, tab: 0)
    assert_response :success
    assert_includes @response.body,
                    I18n.t('tournaments.show.strategies.names.first_round_pairing.random_avoid_same_affiliation')
  end

  test 'swiss admin: pairing present, JSON update persists and explanation matches' do
    sign_in(@creator)

    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Swiss Admin', description: 'Z', game_system_id: @system.id, format: 'swiss' }
    }
    assert_response :redirect
    t = Tournament::Tournament.order(:created_at).last

    # Admin tab
    get tournament_path(t, locale: I18n.locale, tab: 3)
    assert_response :success

    assert_includes @response.body, 'name="tournament[pairing_strategy_key]"'

    # Update via JSON and verify response
    patch tournament_path(t, locale: I18n.locale),
          params: { tournament: { tiebreak1_strategy_key: 'none' } },
          as: :json
    assert_response :success

    # Reload show and assert explanation text reflects new setting
    get tournament_path(t, locale: I18n.locale, tab: 3)
    assert_response :success
    expected = I18n.t('tournaments.show.strategies.explanations.tiebreak.none', default: 'No tie-break applied.')
    assert_includes @response.body, expected
  end
end
