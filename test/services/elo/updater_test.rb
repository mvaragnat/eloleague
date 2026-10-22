# frozen_string_literal: true

require 'test_helper'

module Elo
  class UpdaterTest < ActiveSupport::TestCase
    def setup
      @system = game_systems(:chess)
      @user1 = users(:player_one)
      @user2 = users(:player_two)
      @updater = Elo::Updater.new
      @f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
      @f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')
    end

    def create_event(score1:, score2:, faction1: @f1, faction2: @f2, played_at: Time.current)
      event = Game::Event.new(game_system: @system, played_at: played_at)
      event.game_participations.build(user: @user1, score: score1, faction: faction1)
      event.game_participations.build(user: @user2, score: score2, faction: faction2)
      event.save!
      event
    end

    PLAYER_START = Elo::Calculator::START_RATING
    PLAYER_RD = Elo::Calculator::START_DEVIATION
    FACTION_START = Elo::Calculator::FACTION_START_RATING
    FACTION_RD = Elo::Calculator::FACTION_START_DEVIATION

    def rating(user)
      EloRating.find_by!(user: user, game_system: @system)
    end

    test 'win updates player and faction ratings and shrinks deviations' do
      event = create_event(score1: 21, score2: 18)
      @updater.update_for_event(event)

      r1 = rating(@user1)
      r2 = rating(@user2)
      assert_operator r1.rating, :>, PLAYER_START
      assert_operator r2.rating, :<, PLAYER_START
      assert_operator r1.rating_deviation, :<, PLAYER_RD
      assert_equal 1, r1.games_played
      assert_equal event.played_at.to_i, r1.last_played_at.to_i

      f1 = @f1.reload.faction_rating
      f2 = @f2.reload.faction_rating
      assert_operator f1.rating, :>, FACTION_START
      assert_operator f2.rating, :<, FACTION_START
      assert_operator f1.rating_deviation, :<, FACTION_RD
      assert_equal 1, f1.games_played
    end

    test 'a new player absorbs most of the change, a new faction a smaller share' do
      @updater.update_for_event(create_event(score1: 21, score2: 18))

      player_gain = rating(@user1).rating - PLAYER_START
      faction_gain = @f1.reload.faction_rating.rating - FACTION_START
      assert_operator faction_gain, :positive?
      assert_operator player_gain, :>, faction_gain
    end

    test 'records the change for each participant' do
      event = create_event(score1: 21, score2: 18)
      @updater.update_for_event(event)

      change = EloChange.find_by!(game_event: event, user: @user1)
      assert_equal [PLAYER_START, PLAYER_RD], [change.rating_before, change.rd_before]
      assert_equal rating(@user1).rating, change.rating_after
      assert_equal @f1.id, change.faction_id
      assert_equal [FACTION_START, FACTION_RD], [change.faction_rating_before, change.faction_rd_before]
      assert_equal @f1.reload.faction_rating.rating, change.faction_rating_after
      assert_in_delta 0.5, change.expected_score.to_f, 0.001
      assert_in_delta 1.0, change.actual_score.to_f, 0.001
    end

    test 'draw between new entities keeps ratings at the start' do
      @updater.update_for_event(create_event(score1: 10, score2: 10))

      assert_equal 1500, rating(@user1).rating
      assert_equal 1500, rating(@user2).rating
    end

    test 'mirror match leaves the faction untouched' do
      event = create_event(score1: 21, score2: 18, faction2: @f1)
      @updater.update_for_event(event)

      assert_operator rating(@user1).rating, :>, PLAYER_START
      f1 = @f1.reload.faction_rating
      assert_equal [FACTION_START, FACTION_RD, 0], [f1.rating, f1.rating_deviation, f1.games_played]
    end

    test 'a break between games does not change the player deviation' do
      @updater.update_for_event(create_event(score1: 21, score2: 18, played_at: 1.year.ago))
      rd_after_first = rating(@user1).rating_deviation

      event = create_event(score1: 21, score2: 18, played_at: Time.current)
      @updater.update_for_event(event)

      assert_equal rd_after_first, EloChange.find_by!(game_event: event, user: @user1).rd_before
    end

    test 'a balance-patch reset raises the faction deviation for later games only' do
      3.times { |i| @updater.update_for_event(create_event(score1: 21, score2: 18, played_at: (10 - i).days.ago)) }
      calibrated = @f1.reload.faction_rating.rating_deviation
      assert_operator calibrated, :<, FACTION_RD

      @f1.reset_rating_deviation!(Elo::Calculator::FACTION_RD_MAX, at: 5.days.ago)
      assert_equal Elo::Calculator::FACTION_RD_MAX, @f1.faction_rating.reload.rating_deviation

      event = create_event(score1: 21, score2: 18, played_at: 1.day.ago)
      @updater.update_for_event(event)
      assert_equal Elo::Calculator::FACTION_RD_MAX,
                   EloChange.find_by!(game_event: event, user: @user1).faction_rd_before
    end

    test 'a reset never lowers the deviation' do
      @updater.update_for_event(create_event(score1: 21, score2: 18))
      before = @f1.reload.faction_rating.rating_deviation

      @f1.reset_rating_deviation!(Elo::Calculator::RD_MIN)
      assert_equal before, @f1.faction_rating.reload.rating_deviation
    end

    test 'idempotency: applying twice does not double count' do
      event = create_event(score1: 30, score2: 0)
      @updater.update_for_event(event)
      first = [rating(@user1).rating, rating(@user2).rating, @f1.reload.faction_rating.rating]

      @updater.update_for_event(event)
      assert_equal first, [rating(@user1).rating, rating(@user2).rating, @f1.reload.faction_rating.rating]
    end

    test 'non-competitive tournament event does not update ratings and is marked applied' do
      t = ::Tournament::Tournament.create!(
        name: 'NC', description: 'no elo', creator: @user1, game_system: @system,
        format: 'open', non_competitive: true
      )

      event = Game::Event.new(game_system: @system, played_at: Time.current, tournament: t)
      event.game_participations.build(user: @user1, score: 10, faction: @f1)
      event.game_participations.build(user: @user2, score: 5, faction: @f2)
      event.save!

      @updater.update_for_event(event)

      assert_nil EloRating.find_by(user: @user1, game_system: @system)
      assert_nil @f1.reload.faction_rating
      assert_equal 0, EloChange.where(game_event: event).count
      assert event.reload.elo_applied
    end

    test 'faction diversity is measured over the configured window, current game included' do
      Game::Event.destroy_all # fixture games use the same faction
      user3 = User.create!(username: 'third', email: 'third@example.com', password: 'password')
      # user1 plays White 3 times; user3 once; an old game falls outside the window
      old = (Elo::Calculator::DIVERSITY_WINDOW_MONTHS + 2).months.ago
      [old, 3.days.ago, 2.days.ago].each do |at|
        @updater.update_for_event(create_event(score1: 21, score2: 18, played_at: at))
      end
      other = Game::Event.new(game_system: @system, played_at: 1.day.ago)
      other.game_participations.build(user: user3, score: 21, faction: @f1)
      other.game_participations.build(user: @user2, score: 18, faction: @f2)
      other.save!
      event = create_event(score1: 21, score2: 18, played_at: Time.current)
      @updater.update_for_event(event)

      # Window: user1 x3 (incl. current game), user3 x1 -> H = 0.625, N_eff = 1.6, d = 0.8
      f1 = @f1.reload.faction_rating
      assert_in_delta 1.6, f1.effective_players, 0.01
      assert_equal 2, f1.distinct_players
      assert_in_delta 0.8, f1.diversity, 0.001
      assert_in_delta 0.8, EloChange.find_by!(game_event: event, user: @user1).faction_diversity, 0.001
    end
  end
end
