# frozen_string_literal: true

require 'test_helper'
require 'rake'

class EloRebuildTaskTest < ActiveSupport::TestCase
  def setup
    @system = game_systems(:chess)
    @user1 = users(:player_one)
    @user2 = users(:player_two)
    @f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
    @f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')

    # Only the games played below should be rebuilt
    Game::Event.destroy_all

    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['elo:rebuild'].reenable
  end

  def play(played_at, score1, score2)
    event = Game::Event.new(game_system: @system, played_at: played_at)
    event.game_participations.build(user: @user1, score: score1, faction: @f1)
    event.game_participations.build(user: @user2, score: score2, faction: @f2)
    event.save!
    Elo::Updater.new.update_for_event(event)
  end

  def snapshot
    [@user1, @user2].map { |u| EloRating.find_by!(user: u, game_system: @system).slice(:rating, :rating_deviation) } +
      [@f1, @f2].map { |f| FactionRating.find_by!(faction: f).slice(:rating, :rating_deviation, :last_reset_at) }
  end

  test 'elo:rebuild reproduces online results, including balance-patch resets' do
    play(3.months.ago, 20, 15)
    play(2.months.ago, 21, 15)
    @f1.reset_rating_deviation!(150, at: 6.weeks.ago)
    play(1.month.ago, 10, 15)
    @f2.reset_rating_deviation!(150, at: 1.week.ago) # after the last game

    online = snapshot
    assert_equal 150, FactionRating.find_by!(faction: @f2).rating_deviation

    Rake::Task['elo:rebuild'].invoke

    assert_equal online, snapshot
  end
end
