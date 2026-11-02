# frozen_string_literal: true

require 'test_helper'

# Organizer-only "not played" flag: the match counts for the tournament but not for Elo and statistics
class TournamentMatchNotPlayedTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
    @opponent = users(:player_two)
    @system = game_systems(:chess)
    sign_in @user
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Open M', description: 'S', game_system_id: @system.id, format: 'open' }
    }
    @tournament = Tournament::Tournament.order(:created_at).last
    @tournament.update!(state: 'registration')
    post register_tournament_path(@tournament, locale: I18n.locale)
    f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
    @tournament.registrations.find_by(user: @user).update!(faction: f1)

    sign_out @user
    sign_in @opponent
    post register_tournament_path(@tournament, locale: I18n.locale)
    f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')
    @tournament.registrations.find_by(user: @opponent).update!(faction: f2)

    sign_out @opponent
    sign_in @tournament.creator
    post lock_registration_tournament_path(@tournament, locale: I18n.locale)
  end

  test 'organizer can record a match as not played: counts for the tournament, not for Elo' do
    r = @tournament.rounds.create!(number: 1, state: 'pending')
    m = @tournament.matches.create!(round: r, a_user: @user, b_user: @opponent)

    get tournament_tournament_match_path(@tournament, m, locale: I18n.locale)
    assert_select 'input[type=checkbox][name=?]', 'tournament_match[not_played]'

    perform_enqueued_jobs do
      patch tournament_tournament_match_path(@tournament, m, locale: I18n.locale),
            params: { tournament_match: { a_score: 2, b_score: 1, not_played: '1' } }
    end
    m.reload
    assert m.not_played
    assert m.non_competitive
    assert_equal 'a_win', m.result
    assert m.game_event.non_competitive
    assert_equal 0, EloChange.where(game_event_id: m.game_event_id).count
  end

  test 'participants cannot record a match as not played' do
    r = @tournament.rounds.create!(number: 1, state: 'pending')
    m = @tournament.matches.create!(round: r, a_user: @user, b_user: @opponent)

    # @user created the tournament: report as the other participant
    sign_out @tournament.creator
    sign_in @opponent
    get tournament_tournament_match_path(@tournament, m, locale: I18n.locale)
    assert_select 'input[name=?]', 'tournament_match[not_played]', count: 0

    patch tournament_tournament_match_path(@tournament, m, locale: I18n.locale),
          params: { tournament_match: { a_score: 2, b_score: 1, not_played: '1' } }
    m.reload
    assert_not m.not_played
    assert_not m.game_event.non_competitive
  end

  test 'marking a reported match as not played rebuilds Elo without it' do
    r = @tournament.rounds.create!(number: 1, state: 'pending')
    m = @tournament.matches.create!(round: r, a_user: @user, b_user: @opponent)
    perform_enqueued_jobs do
      patch tournament_tournament_match_path(@tournament, m, locale: I18n.locale),
            params: { tournament_match: { a_score: 2, b_score: 1 } }
    end
    m.reload
    assert_equal 2, EloChange.where(game_event_id: m.game_event_id).count

    assert_enqueued_with(job: EloRebuildJob, args: [@system.id]) do
      patch tournament_tournament_match_path(@tournament, m, locale: I18n.locale),
            params: { tournament_match: { a_score: 2, b_score: 1, not_played: '1' } }
    end
    perform_enqueued_jobs
    assert m.reload.not_played
    assert_equal 0, EloChange.where(game_event_id: m.game_event_id).count

    # Editing scores without changing the flag does not rebuild
    assert_no_enqueued_jobs only: EloRebuildJob do
      patch tournament_tournament_match_path(@tournament, m, locale: I18n.locale),
            params: { tournament_match: { a_score: 1, b_score: 2, not_played: '1' } }
    end
  end

  test 'not played matches stay non-competitive when the tournament flag changes' do
    r = @tournament.rounds.create!(number: 1, state: 'pending')
    m = @tournament.matches.create!(round: r, a_user: @user, b_user: @opponent)
    patch tournament_tournament_match_path(@tournament, m, locale: I18n.locale),
          params: { tournament_match: { a_score: 2, b_score: 1, not_played: '1' } }

    @tournament.reload.update!(non_competitive: true)
    @tournament.update!(non_competitive: false)
    assert m.reload.non_competitive
    assert m.game_event.non_competitive
  end

  test 'organizer can add an open match recorded as not played' do
    @tournament.update!(state: 'running')
    f1 = @tournament.registrations.find_by(user: @user).faction
    f2 = @tournament.registrations.find_by(user: @opponent).faction
    post tournament_tournament_matches_path(@tournament, locale: I18n.locale), params: {
      game_event: {
        not_played: '1',
        game_participations_attributes: [
          { user_id: @user.id, score: 2, faction_id: f1.id },
          { user_id: @opponent.id, score: 1, faction_id: f2.id }
        ]
      }
    }
    m = @tournament.matches.order(:created_at).last
    assert m.not_played
    assert m.non_competitive
    assert m.game_event.non_competitive
  end
end
