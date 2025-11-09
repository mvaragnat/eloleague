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
end
