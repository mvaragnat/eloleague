# frozen_string_literal: true

require 'test_helper'

class ByStandingsNeighborsPairingTest < ActiveSupport::TestCase
  def setup
    @creator = users(:player_one)
    @system = game_systems(:chess)
  end

  test 'pairs neighbors by current standings order' do
    t = ::Tournament::Tournament.create!(
      name: 'Standings Pairing',
      description: 'Test',
      game_system: @system,
      format: 'open',
      creator: @creator
    )

    u2 = users(:player_two)
    u3 = User.create!(username: 'a_third', email: 'u3@example.com', password: 'password')
    u4 = User.create!(username: 'b_fourth', email: 'u4@example.com', password: 'password')

    [@creator, u2, u3, u4].each { |u| t.registrations.create!(user: u) }

    # Give @creator and u2 more points so they are the top two
    t.matches.create!(a_user: @creator, b_user: u3, result: 'a_win')
    t.matches.create!(a_user: u2, b_user: u4, result: 'a_win')

    result = ::Tournament::Pairing::ByStandingsNeighbors.new(t).call
    assert_equal 2, result.pairs.size

    # Top pair should be the two leading players
    assert(result.pairs.any? { |a, b| (a == @creator && b == u2) || (a == u2 && b == @creator) })
  end

  test 'avoids repeats by shifting neighbors when possible' do
    t = ::Tournament::Tournament.create!(
      name: 'Standings Pairing Shift',
      description: 'Test',
      game_system: @system,
      format: 'open',
      creator: @creator
    )

    u2 = users(:player_two)
    u3 = User.create!(username: 'third_user', email: 'third@example.com', password: 'password')
    u4 = User.create!(username: 'fourth_user', email: 'fourth@example.com', password: 'password')

    [@creator, u2, u3, u4].each { |u| t.registrations.create!(user: u) }

    # Award points without creating conflicting previous pairings for the shift
    t.matches.create!(a_user: @creator, b_user: nil, result: 'a_win') # bye for creator
    t.matches.create!(a_user: u2, b_user: nil, result: 'a_win')       # bye for u2

    # Ensure top neighbor pair (@creator, u2) has already played
    t.matches.create!(a_user: @creator, b_user: u2, result: 'a_win')

    result = ::Tournament::Pairing::ByStandingsNeighbors.new(t).call
    assert_equal 2, result.pairs.size

    # Expect shift: the two top-ranked neighbors should not be paired together
    assert_not result.pairs.any? { |a, b| (a == @creator && b == u2) || (a == u2 && b == @creator) },
               'Expected top neighbors not to be paired together after shift'

    # Each top neighbor should be paired with one of the remaining two
    bottom = [u3, u4]
    creator_partner = result.pairs.find { |a, b| a == @creator || b == @creator }&.then { |a, b| a == @creator ? b : a }
    u2_partner = result.pairs.find { |a, b| a == u2 || b == u2 }&.then { |a, b| a == u2 ? b : a }

    assert_includes bottom, creator_partner
    assert_includes bottom, u2_partner
  end

  test 'avoids repeats at bottom of standings by swapping with non-adjacent pairs' do
    t = ::Tournament::Tournament.create!(
      name: 'Swiss Avoid Bottom Repeat',
      description: 'Test',
      game_system: @system,
      format: 'swiss',
      rounds_count: 3,
      creator: @creator
    )

    u2 = users(:player_two)
    u3 = User.create!(username: 'user_three', email: 'three@example.com', password: 'password')
    u4 = User.create!(username: 'user_four', email: 'four@example.com', password: 'password')
    u5 = User.create!(username: 'user_five', email: 'five@example.com', password: 'password')
    u6 = User.create!(username: 'user_six', email: 'six@example.com', password: 'password')

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
    result = ::Tournament::Pairing::ByStandingsNeighbors.new(t).call

    u5_u6_paired = result.pairs.any? do |a, b|
      (a == u5 && b == u6) || (a == u6 && b == u5)
    end

    assert_not u5_u6_paired, 'u5 and u6 should not be paired again as they already played'
  end

  test 'accepts duplicate when no valid swap exists (all combinations exhausted)' do
    t = ::Tournament::Tournament.create!(
      name: 'Swiss Forced Repeat',
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

    result = ::Tournament::Pairing::ByStandingsNeighbors.new(t).call

    # Should still generate a pair (forced repeat)
    assert_equal 1, result.pairs.size
    assert(result.pairs.any? { |a, b| (a == @creator && b == u2) || (a == u2 && b == @creator) })
  end

  test 'extended swap resolves multiple duplicates across several pairs' do
    t = ::Tournament::Tournament.create!(
      name: 'Swiss Multi Duplicate',
      description: 'Test',
      game_system: @system,
      format: 'swiss',
      rounds_count: 4,
      creator: @creator
    )

    u2 = users(:player_two)
    u3 = User.create!(username: 'ext_three', email: 'ext3@example.com', password: 'password')
    u4 = User.create!(username: 'ext_four', email: 'ext4@example.com', password: 'password')

    all_users = [@creator, u2, u3, u4]
    all_users.each { |u| t.registrations.create!(user: u, status: 'checked_in') }

    # All direct neighbor pairs have already played:
    # @creator-u2, u3-u4 already played
    t.matches.create!(a_user: @creator, b_user: u2, result: 'a_win')
    t.matches.create!(a_user: u3, b_user: u4, result: 'a_win')

    result = ::Tournament::Pairing::ByStandingsNeighbors.new(t).call

    # With extended swapping, it should find cross pairs: @creator-u3 or @creator-u4, and u2-u4 or u2-u3
    assert_equal 2, result.pairs.size

    # Neither original neighbor pair should appear
    neighbor1_present = result.pairs.any? { |a, b| (a == @creator && b == u2) || (a == u2 && b == @creator) }
    neighbor2_present = result.pairs.any? { |a, b| (a == u3 && b == u4) || (a == u4 && b == u3) }

    assert_not neighbor1_present, '@creator and u2 should not be paired again'
    assert_not neighbor2_present, 'u3 and u4 should not be paired again'
  end
end
