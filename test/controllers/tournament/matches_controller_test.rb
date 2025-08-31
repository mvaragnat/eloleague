# frozen_string_literal: true

require 'test_helper'

class TournamentMatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
    @opponent = users(:player_two)
    @system = game_systems(:chess)
    sign_in @user
    post tournaments_path(locale: I18n.locale), params: {
      tournament: { name: 'Open M', description: 'S', game_system_id: @system.id, format: 'open' }
    }
    @tournament = Tournament::Tournament.order(:created_at).last
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

  test 'update accepts secondary scores' do
    # Create a swiss-like pairing by creating a round and a match with the two players
    r = @tournament.rounds.create!(number: 1, state: 'pending')
    m = @tournament.matches.create!(round: r, a_user: @user, b_user: @opponent)

    sign_out @tournament.creator
    sign_in @user
    patch tournament_tournament_match_path(@tournament, m, locale: I18n.locale),
          params: { tournament_match: { a_score: 1, b_score: 1, a_secondary_score: 10, b_secondary_score: 5 } }

    assert_redirected_to tournament_path(@tournament, locale: I18n.locale, tab: 1)
    m.reload
    assert_equal 'draw', m.result
    assert_not_nil m.game_event
    a = m.game_event.game_participations.find_by(user: @user)
    b = m.game_event.game_participations.find_by(user: @opponent)
    assert_equal 10, a.secondary_score
    assert_equal 5, b.secondary_score
  end
end

# frozen_string_literal: true

module Tournament
  class MatchesControllerTest < ActionDispatch::IntegrationTest
    def setup
      @system = game_systems(:chess)
      @creator = users(:player_one)
      @p2 = users(:player_two)
      @p3 = User.create!(username: 'third', email: 'third@example.com', password: 'password')

      EloRating.find_or_create_by!(user: @creator, game_system: @system) do |r|
        r.rating = 1600
        r.games_played = 0
      end
      EloRating.find_or_create_by!(user: @p2, game_system: @system) do |r|
        r.rating = 1500
        r.games_played = 0
      end
      EloRating.find_or_create_by!(user: @p3, game_system: @system) do |r|
        r.rating = 1400
        r.games_played = 0
      end
    end

    test 'winner is propagated to parent after reporting' do
      # Creator signs in and creates elimination tournament
      sign_in @creator
      post tournaments_path(locale: I18n.locale), params: {
        tournament: { name: 'KO', description: 'Tree', game_system_id: @system.id, format: 'elimination' }
      }
      t = ::Tournament::Tournament.order(:created_at).last

      # Register and check in all three players
      post register_tournament_path(t, locale: I18n.locale)
      f1 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'White')
      t.registrations.find_by(user: @creator).update!(faction: f1)
      post check_in_tournament_path(t, locale: I18n.locale)

      sign_out @creator
      sign_in @p2
      post register_tournament_path(t, locale: I18n.locale)
      f2 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Black')
      t.registrations.find_by(user: @p2).update!(faction: f2)
      post check_in_tournament_path(t, locale: I18n.locale)

      sign_out @p2
      sign_in @p3
      post register_tournament_path(t, locale: I18n.locale)
      f3 = Game::Faction.find_or_create_by!(game_system: t.game_system, name: 'Third')
      t.registrations.find_by(user: @p3).update!(faction: f3)
      post check_in_tournament_path(t, locale: I18n.locale)

      # Lock (build bracket with a bye for the top seed)
      sign_out @p3
      sign_in @creator
      post lock_registration_tournament_path(t, locale: I18n.locale)

      # Find a leaf with two players (not a bye)
      match = t.matches.select { |m| m.child_matches.empty? && m.a_user_id.present? && m.b_user_id.present? }.first
      assert_not_nil match

      # Report result as one of the participants
      sign_out @creator
      sign_in [match.a_user, match.b_user].first
      patch tournament_tournament_match_path(t, match, locale: I18n.locale),
            params: { tournament_match: { a_score: 5, b_score: 3 } }
      assert_redirected_to tournament_path(t, locale: I18n.locale, tab: 1)

      match.reload
      parent = match.parent_match
      assert_not_nil parent, 'parent should exist'

      winner = match.a_user # since 5 > 3
      side = match.child_slot
      propagated = parent.send("#{side}_user_id")
      assert_equal winner.id, propagated, 'winner should be placed on parent on the same side'

      other_side = side == 'a' ? 'b' : 'a'
      assert parent.send("#{other_side}_user_id").present?, 'other side should be the bye-propagated top seed'
    end
  end
end
