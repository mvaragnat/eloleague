# frozen_string_literal: true

require 'test_helper'
require 'rake'

class BackfillScoringDefaultsTaskTest < ActiveSupport::TestCase
  def setup
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  test 'fills tournament scoring_system_id from default' do
    sys = game_systems(:chess)
    default_scoring = game_scoring_systems(:chess_default)
    t = Tournament::Tournament.create!(
      name: 'Legacy T',
      creator: users(:player_one),
      game_system: sys,
      format: :open,
      score_for_bye: 0,
      scoring_system: default_scoring
    )
    # Simulate legacy row with NULL column
    t.update_column(:scoring_system_id, nil) # rubocop:disable Rails/SkipsModelValidations
    assert_nil t.reload.scoring_system_id

    Rake::Task['scoring:backfill_defaults'].execute
    assert_equal default_scoring.id, t.reload.scoring_system_id
  end

  test 'fills non-tournament event scoring_system_id from default' do
    e = game_events(:chess_game)
    # Simulate legacy row with NULL column
    e.update_column(:scoring_system_id, nil) # rubocop:disable Rails/SkipsModelValidations
    assert_nil e.reload.scoring_system_id

    default_scoring = game_scoring_systems(:chess_default)
    Rake::Task['scoring:backfill_defaults'].execute
    assert_equal default_scoring.id, e.reload.scoring_system_id
  end

  test 'recomputes match results based on scoring rules' do
    sys = game_systems(:chess)
    scoring = game_scoring_systems(:chess_constrained) # min_difference_for_win = 5
    t = Tournament::Tournament.create!(
      name: 'Legacy T2',
      creator: users(:player_one),
      game_system: sys,
      format: :open,
      score_for_bye: 0,
      scoring_system: scoring
    )
    m = Tournament::Match.create!(tournament: t, result: 'a_win')

    # Event with a 4-point difference (should be draw with min_diff=5)
    e = Game::Event.new(game_system: sys, tournament: t, scoring_system: scoring, played_at: Time.current)
    e.game_participations.build(user: users(:player_one), score: 18, faction: game_factions(:chess_white))
    e.game_participations.build(user: users(:player_two), score: 14, faction: game_factions(:chess_white))
    e.save!
    m.update!(game_event: e, a_user: users(:player_one), b_user: users(:player_two))

    # Sanity: currently marked as a_win (legacy wrong result)
    assert_equal 'a_win', m.reload.result

    # Run backfill: should convert to draw
    Rake::Task['scoring:backfill_defaults'].execute
    assert_equal 'draw', m.reload.result
  end
end
