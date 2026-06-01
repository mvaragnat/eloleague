# frozen_string_literal: true

require 'test_helper'

module Championship
  class ScoreTest < ActiveSupport::TestCase
    setup do
      @system = game_systems(:chess)
      @scoring = game_scoring_systems(:chess_default)
      @user = users(:player_one)
      @tournament = ::Tournament::Tournament.create!(
        name: 'Test Championship Tournament',
        game_system: @system,
        scoring_system: @scoring,
        format: :swiss,
        state: 'completed',
        creator: @user,
        ends_at: Time.zone.local(2026, 6, 15)
      )
    end

    test 'valid championship score' do
      score = Championship::Score.new(
        user: @user,
        tournament: @tournament,
        game_system: @system,
        year: 2026,
        match_points: 9,
        placement_bonus: 3,
        total_points: 12
      )
      assert score.valid?
    end

    test 'requires year' do
      score = Championship::Score.new(
        user: @user,
        tournament: @tournament,
        game_system: @system,
        match_points: 9,
        placement_bonus: 3,
        total_points: 12
      )
      assert_not score.valid?
      assert_includes score.errors[:year], "can't be blank"
    end

    test 'user-tournament uniqueness' do
      Championship::Score.create!(
        user: @user,
        tournament: @tournament,
        game_system: @system,
        year: 2026,
        match_points: 9,
        placement_bonus: 3,
        total_points: 12
      )

      duplicate = Championship::Score.new(
        user: @user,
        tournament: @tournament,
        game_system: @system,
        year: 2026,
        match_points: 5,
        placement_bonus: 0,
        total_points: 5
      )
      assert_not duplicate.valid?
    end

    test 'scopes for_year and for_game_system' do
      Championship::Score.create!(
        user: @user,
        tournament: @tournament,
        game_system: @system,
        year: 2026,
        match_points: 9,
        placement_bonus: 3,
        total_points: 12
      )

      assert_equal 1, Championship::Score.for_year(2026).for_game_system(@system).count
      assert_equal 0, Championship::Score.for_year(2025).count
    end
  end
end
