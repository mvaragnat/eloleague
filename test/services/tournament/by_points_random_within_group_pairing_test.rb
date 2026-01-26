# frozen_string_literal: true

require 'test_helper'

class ByPointsRandomWithinGroupPairingTest < ActiveSupport::TestCase
  def setup
    @creator = users(:player_one)
    @system = game_systems(:chess)
  end

  test 'avoids repeats at bottom of standings by swapping with non-adjacent pairs' do
    t = ::Tournament::Tournament.create!(
      name: 'Swiss Avoid Bottom Repeat Points',
      description: 'Test',
      game_system: @system,
      format: 'swiss',
      rounds_count: 3,
      creator: @creator
    )

    u2 = users(:player_two)
    u3 = User.create!(username: 'pts_user_three', email: 'pts_three@example.com', password: 'password')
    u4 = User.create!(username: 'pts_user_four', email: 'pts_four@example.com', password: 'password')
    u5 = User.create!(username: 'pts_user_five', email: 'pts_five@example.com', password: 'password')
    u6 = User.create!(username: 'pts_user_six', email: 'pts_six@example.com', password: 'password')

    all_users = [@creator, u2, u3, u4, u5, u6]
    all_users.each { |u| t.registrations.create!(user: u, status: 'checked_in') }

    # Simulate standings where bottom pair (u5, u6) already played each other
    # Round 1: top players win
    t.matches.create!(a_user: @creator, b_user: u4, result: 'a_win')
    t.matches.create!(a_user: u2, b_user: u5, result: 'a_win')
    t.matches.create!(a_user: u3, b_user: u6, result: 'a_win')

    # Round 2: ensure u5 and u6 are paired and play
    t.matches.create!(a_user: u5, b_user: u6, result: 'draw')
    t.matches.create!(a_user: @creator, b_user: u2, result: 'a_win')
    t.matches.create!(a_user: u3, b_user: u4, result: 'a_win')

    # Now u5 and u6 should NOT be paired again
    result = ::Tournament::Pairing::ByPointsRandomWithinGroup.new(t).call

    u5_u6_paired = result.pairs.any? do |a, b|
      (a == u5 && b == u6) || (a == u6 && b == u5)
    end

    assert_not u5_u6_paired, 'u5 and u6 should not be paired again as they already played'
  end

  test 'accepts duplicate when no valid swap exists (all combinations exhausted)' do
    t = ::Tournament::Tournament.create!(
      name: 'Swiss Forced Repeat Points',
      description: 'Test',
      game_system: @system,
      format: 'swiss',
      rounds_count: 3,
      creator: @creator
    )

    u2 = users(:player_two)

    # Only 2 players - if they already played, there's no alternative
    [@creator, u2].each { |u| t.registrations.create!(user: u, status: 'checked_in') }
    t.matches.create!(a_user: @creator, b_user: u2, result: 'a_win')

    result = ::Tournament::Pairing::ByPointsRandomWithinGroup.new(t).call

    # Should still generate a pair (forced repeat)
    assert_equal 1, result.pairs.size
    assert(result.pairs.any? { |a, b| (a == @creator && b == u2) || (a == u2 && b == @creator) })
  end

  test 'extended swap resolves multiple duplicates across several pairs' do
    t = ::Tournament::Tournament.create!(
      name: 'Swiss Multi Duplicate Points',
      description: 'Test',
      game_system: @system,
      format: 'swiss',
      rounds_count: 4,
      creator: @creator
    )

    u2 = users(:player_two)
    u3 = User.create!(username: 'pts_ext_three', email: 'pts_ext3@example.com', password: 'password')
    u4 = User.create!(username: 'pts_ext_four', email: 'pts_ext4@example.com', password: 'password')

    all_users = [@creator, u2, u3, u4]
    all_users.each { |u| t.registrations.create!(user: u, status: 'checked_in') }

    # All have same points (0), so they're in the same group
    # Create previous matches so that @creator-u2 and u3-u4 already played
    t.matches.create!(a_user: @creator, b_user: u2, result: 'draw')
    t.matches.create!(a_user: u3, b_user: u4, result: 'draw')

    result = ::Tournament::Pairing::ByPointsRandomWithinGroup.new(t).call

    # With extended swapping, it should find cross pairs
    assert_equal 2, result.pairs.size

    # Neither original neighbor pair should appear
    pair1_present = result.pairs.any? { |a, b| (a == @creator && b == u2) || (a == u2 && b == @creator) }
    pair2_present = result.pairs.any? { |a, b| (a == u3 && b == u4) || (a == u4 && b == u3) }

    assert_not pair1_present, '@creator and u2 should not be paired again'
    assert_not pair2_present, 'u3 and u4 should not be paired again'
  end
end
