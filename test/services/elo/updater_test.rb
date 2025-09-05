# frozen_string_literal: true

require 'test_helper'

module Elo
  class UpdaterTest < ActiveSupport::TestCase
    def setup
      @system = game_systems(:chess)
      @user1 = users(:player_one)
      @user2 = users(:player_two)
      @calc = Elo::Calculator.new
      @updater = Elo::Updater.new(calculator: @calc)
      @f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
      @f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')
    end

    def create_event(score1:, score2:)
      event = Game::Event.new(game_system: @system, played_at: Time.current)
      event.game_participations.build(user: @user1, score: score1, faction: @f1)
      event.game_participations.build(user: @user2, score: score2, faction: @f2)
      event.save!
      event
    end

    test 'win updates ratings correctly' do
      event = create_event(score1: 21, score2: 18)
      @updater.update_for_event(event)

      r1 = EloRating.find_by!(user: @user1, game_system: @system)
      r2 = EloRating.find_by!(user: @user2, game_system: @system)
      assert_operator r1.rating, :>, 1200
      assert_operator r2.rating, :<, 1200
    end

    test 'draw updates ratings modestly' do
      event = create_event(score1: 10, score2: 10)
      @updater.update_for_event(event)

      r1 = EloRating.find_by!(user: @user1, game_system: @system)
      r2 = EloRating.find_by!(user: @user2, game_system: @system)
      # From equal start, draw should keep them near 1200 (rounding may keep exact)
      assert_in_delta 1200, r1.rating, 5
      assert_in_delta 1200, r2.rating, 5
    end

    test 'idempotency: applying twice does not double count' do
      event = create_event(score1: 30, score2: 0)
      @updater.update_for_event(event)
      r1_after_first = EloRating.find_by!(user: @user1, game_system: @system).rating
      r2_after_first = EloRating.find_by!(user: @user2, game_system: @system).rating

      # second call should no-op
      @updater.update_for_event(event)
      r1_after_second = EloRating.find_by!(user: @user1, game_system: @system).rating
      r2_after_second = EloRating.find_by!(user: @user2, game_system: @system).rating

      assert_equal r1_after_first, r1_after_second
      assert_equal r2_after_first, r2_after_second
    end

    test 'non-competitive tournament event does not update ratings and is marked applied' do
      # Create a non-competitive tournament and an event attached to it
      t = ::Tournament::Tournament.create!(
        name: 'NC', description: 'no elo', creator: @user1, game_system: @system,
        format: 'open', non_competitive: true
      )

      # Ensure factions exist for validations
      event = Game::Event.new(game_system: @system, played_at: Time.current, tournament: t)
      event.game_participations.build(user: @user1, score: 10, faction: @f1)
      event.game_participations.build(user: @user2, score: 5, faction: @f2)
      event.save!

      # Seed ratings so we can assert no change
      r1 = EloRating.find_or_create_by!(user: @user1, game_system: @system) do |r|
        r.rating = 1200
        r.games_played = 0
      end
      r2 = EloRating.find_or_create_by!(user: @user2, game_system: @system) do |r|
        r.rating = 1200
        r.games_played = 0
      end

      @updater.update_for_event(event)

      r1.reload
      r2.reload
      assert_equal 1200, r1.rating
      assert_equal 1200, r2.rating
      assert_equal 0, EloChange.where(game_event: event).count
      assert event.reload.elo_applied
    end
  end
end
