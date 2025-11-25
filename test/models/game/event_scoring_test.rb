# frozen_string_literal: true

require 'test_helper'

class GameEventScoringTest < ActiveSupport::TestCase
  test 'scoring system must belong to same game system' do
    chess = game_systems(:chess)
    game_systems(:go)
    scoring = game_scoring_systems(:go_default) # wrong system
    event = Game::Event.new(game_system: chess, scoring_system: scoring, played_at: Time.current)
    u1 = users(:player_one)
    u2 = users(:player_two)
    f1 = game_factions(:chess_white)
    f2 = game_factions(:chess_white)
    event.game_participations.build(user: u1, score: 10, faction: f1)
    event.game_participations.build(user: u2, score: 5, faction: f2)
    assert_not event.valid?
    assert_includes event.errors.full_messages.join, I18n.t('games.errors.scoring_system_wrong_system')
  end

  test 'fixed total and max per player validations' do
    chess = game_systems(:chess)
    scoring = game_scoring_systems(:chess_constrained)
    event = Game::Event.new(game_system: chess, scoring_system: scoring, played_at: Time.current)
    u1 = users(:player_one)
    u2 = users(:player_two)
    f1 = game_factions(:chess_white)
    f2 = game_factions(:chess_white)

    # Exceeds max
    event.game_participations.build(user: u1, score: 101, faction: f1)
    event.game_participations.build(user: u2, score: 0, faction: f2)
    assert_not event.valid?
    assert_includes event.errors.full_messages.join, I18n.t('games.errors.score_exceeds_max', max: 100)

    # Reset with wrong total
    event.game_participations.clear
    event.game_participations.build(user: u1, score: 28, faction: f1)
    event.game_participations.build(user: u2, score: 6, faction: f2)
    assert_not event.valid?
    assert_includes event.errors.full_messages.join, I18n.t('games.errors.total_must_equal', total: 32)

    # Valid example
    event.game_participations.clear
    event.game_participations.build(user: u1, score: 28, faction: f1)
    event.game_participations.build(user: u2, score: 4, faction: f2)
    assert event.valid?
  end

  test 'min difference for win results in draw when below or equal threshold' do
    chess = game_systems(:chess)
    scoring = game_scoring_systems(:chess_constrained) # min_difference_for_win = 5
    event = Game::Event.new(game_system: chess, scoring_system: scoring, played_at: Time.current)
    u1 = users(:player_one)
    u2 = users(:player_two)
    f1 = game_factions(:chess_white)
    f2 = game_factions(:chess_white)
    event.game_participations.build(user: u1, score: 30, faction: f1)
    event.game_participations.build(user: u2, score: 25, faction: f2)
    # No validation error for min diff; it affects winner computation
    # Fix total must be satisfied for this scoring, so change to valid total
    event.game_participations.first.score = 18
    event.game_participations.second.score = 14 # total 32, diff 4 -> draw
    assert event.valid?
    assert_nil event.winner_user
  end
end
