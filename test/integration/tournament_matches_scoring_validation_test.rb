# frozen_string_literal: true

require 'test_helper'

class TournamentMatchesScoringValidationTest < ActionDispatch::IntegrationTest
  test 'tournament match form shows errors when scores violate constraints' do
    sign_in users(:player_one)
    chess = game_systems(:chess)
    scoring = game_scoring_systems(:chess_constrained)

    t = Tournament::Tournament.create!(
      name: 'Test T',
      creator: users(:player_one),
      game_system: chess,
      format: :open,
      state: 'running',
      score_for_bye: 0,
      scoring_system: scoring
    )

    white = game_factions(:chess_white)

    post tournament_tournament_matches_path(locale: 'en', tournament_id: t.to_param), params: {
      game_event: {
        game_participations_attributes: [
          { user_id: users(:player_one).id, score: 20, faction_id: white.id },
          { user_id: users(:player_two).id, score: 20, faction_id: white.id }
        ]
      }
    }
    # This is valid by fixed total only if 20+20=40, invalid for fixed total 32
    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t('games.errors.total_must_equal', total: 32)
    assert_includes @response.body, 'form-error-summary'
    assert_includes @response.body, 'input-error'
    assert_includes @response.body, 'data-controller="game-form form-errors"'
  end

  test 'tournament match report keeps score form visible with highlighted fields on invalid scoring' do
    sign_in users(:player_one)
    chess = game_systems(:chess)
    scoring = game_scoring_systems(:chess_constrained)
    white = game_factions(:chess_white)
    black = game_factions(:chess_black)

    tournament = Tournament::Tournament.create!(
      name: 'Swiss T',
      creator: users(:player_one),
      game_system: chess,
      format: :swiss,
      rounds_count: 1,
      state: 'running',
      score_for_bye: 0,
      scoring_system: scoring
    )
    Tournament::Registration.create!(tournament: tournament, user: users(:player_one), status: :checked_in, faction: white)
    Tournament::Registration.create!(tournament: tournament, user: users(:player_two), status: :checked_in, faction: black)
    round = Tournament::Round.create!(tournament: tournament, number: 1, state: :pending)
    match = Tournament::Match.create!(tournament: tournament, tournament_round: round, a_user: users(:player_one),
                                      b_user: users(:player_two), result: :pending)

    patch tournament_tournament_match_path(locale: 'en', tournament_id: tournament.to_param, id: match.id), params: {
      tournament_match: { a_score: 20, b_score: 20 }
    }

    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t('games.errors.total_must_equal', total: 32)
    assert_includes @response.body, 'data-controller="form-errors"'
    assert_includes @response.body, 'form-error-summary'
    assert_includes @response.body, 'input-error'
  end
end
