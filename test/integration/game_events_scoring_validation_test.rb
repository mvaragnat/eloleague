# frozen_string_literal: true

require 'test_helper'

class GameEventsScoringValidationTest < ActionDispatch::IntegrationTest
  test 'non-tournament game shows errors when scores violate constraints' do
    sign_in users(:player_one)
    chess = game_systems(:chess)
    scoring = game_scoring_systems(:chess_constrained)
    white = game_factions(:chess_white)

    post game_events_path, params: {
      game_event: {
        game_system_id: chess.id,
        scoring_system_id: scoring.id,
        non_competitive: '0',
        game_participations_attributes: [
          { user_id: users(:player_one).id, score: 28, faction_id: white.id },
          { user_id: users(:player_two).id, score: 6, faction_id: white.id }
        ]
      }
    }
    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t('games.errors.total_must_equal', total: 32)
  end
end
