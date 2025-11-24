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
  end
end
