# frozen_string_literal: true

require 'test_helper'

class TournamentScoringTest < ActiveSupport::TestCase
  test 'tournament scoring system must belong to same game system' do
    chess = game_systems(:chess)
    game_systems(:go)
    wrong_scoring = game_scoring_systems(:go_default)
    t = Tournament::Tournament.new(
      name: 'Test',
      creator: users(:player_one),
      game_system: chess,
      format: :open,
      score_for_bye: 0,
      scoring_system: wrong_scoring
    )
    assert_not t.valid?
    assert_includes t.errors.full_messages.join, I18n.t('tournaments.errors.scoring_system_wrong_system')
  end
end
