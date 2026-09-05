# frozen_string_literal: true

require 'test_helper'

class TournamentAffiliationsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:player_one)
    @player = users(:player_two)
    @system = game_systems(:chess)

    sign_in @creator
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Affiliation Tournament', description: 'T', game_system_id: @system.id, format: 'swiss' }
    }
    @tournament = Tournament::Tournament.order(:created_at).last
    @tournament.update!(state: 'registration')

    sign_out @creator
    sign_in @player
    post register_tournament_path(@tournament, locale: I18n.locale)
    @registration = @tournament.registrations.find_by(user: @player)
  end

  test 'search returns affiliations matching the typed text' do
    Affiliation.create!(name: 'Club des Six')
    Affiliation.create!(name: 'Club Alpha')
    Affiliation.create!(name: 'Guilde du Nord')

    get affiliations_search_path(locale: I18n.locale, q: 'clu')
    assert_response :success

    names = response.parsed_body.pluck('name')
    assert_equal ['Club Alpha', 'Club des Six'], names
  end

  test 'search returns nothing for a blank term' do
    Affiliation.create!(name: 'Club des Six')

    get affiliations_search_path(locale: I18n.locale, q: '  ')
    assert_response :success
    assert_empty response.parsed_body
  end

  test 'participants tab offers the affiliation input while registrations are open' do
    get tournament_path(@tournament, locale: I18n.locale, tab: 2)
    assert_response :success

    assert_includes @response.body, I18n.t('tournaments.show.participant_columns.affiliation')
    assert_includes @response.body, 'name="tournament_registration[affiliation_name]"'
  end

  test 'participants tab shows the affiliation as plain text once the tournament is running' do
    @registration.update!(affiliation: Affiliation.create!(name: 'Club des Six'))
    @tournament.update!(state: 'running')

    get tournament_path(@tournament, locale: I18n.locale, tab: 2)
    assert_response :success

    assert_not_includes @response.body, 'name="tournament_registration[affiliation_name]"'
    assert_includes @response.body, 'Club des Six'
  end
end
