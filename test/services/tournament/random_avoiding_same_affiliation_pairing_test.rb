# frozen_string_literal: true

require 'test_helper'

class RandomAvoidingSameAffiliationPairingTest < ActiveSupport::TestCase
  def setup
    @creator = users(:player_one)
    @system = game_systems(:chess)
  end

  test 'never pairs two players sharing an affiliation when another pairing exists' do
    tournament = build_tournament('First Round Affiliations')
    club_a = Affiliation.create!(name: 'Club A')
    club_b = Affiliation.create!(name: 'Club B')

    register(tournament, 'aff_a1', club_a)
    register(tournament, 'aff_a2', club_a)
    register(tournament, 'aff_b1', club_b)
    register(tournament, 'aff_b2', club_b)

    result = ::Tournament::Pairing::RandomAvoidingSameAffiliation.new(tournament).call

    assert_equal 2, result.pairs.size
    assert_nil result.bye_user
    assert_empty same_affiliation_pairs(tournament, result.pairs)
  end

  test 'players without affiliation can be paired together' do
    tournament = build_tournament('First Round No Affiliation')
    4.times { |i| register(tournament, "aff_none#{i}", nil) }

    result = ::Tournament::Pairing::RandomAvoidingSameAffiliation.new(tournament).call

    assert_equal 2, result.pairs.size
    assert_empty same_affiliation_pairs(tournament, result.pairs)
  end

  test 'falls back to a same-affiliation pairing when no other option exists' do
    tournament = build_tournament('First Round Single Affiliation')
    club = Affiliation.create!(name: 'Only Club')
    4.times { |i| register(tournament, "aff_only#{i}", club) }

    result = ::Tournament::Pairing::RandomAvoidingSameAffiliation.new(tournament).call

    assert_equal 2, result.pairs.size
    assert_equal 2, same_affiliation_pairs(tournament, result.pairs).size
  end

  test 'assigns a bye when the number of players is odd' do
    tournament = build_tournament('First Round Odd')
    club = Affiliation.create!(name: 'Club Odd')
    register(tournament, 'aff_odd1', club)
    register(tournament, 'aff_odd2', nil)
    register(tournament, 'aff_odd3', nil)

    result = ::Tournament::Pairing::RandomAvoidingSameAffiliation.new(tournament).call

    assert_equal 1, result.pairs.size
    assert_not_nil result.bye_user
  end

  test 'random strategy pairs everyone without looking at affiliations' do
    tournament = build_tournament('First Round Random')
    club = Affiliation.create!(name: 'Club Random')
    4.times { |i| register(tournament, "aff_random#{i}", club) }

    result = ::Tournament::Pairing::RandomFirstRound.new(tournament).call

    assert_equal 2, result.pairs.size
    assert_equal 4, result.pairs.flatten.uniq.size
  end

  private

  def build_tournament(name)
    ::Tournament::Tournament.create!(
      name: name,
      description: 'Test',
      game_system: @system,
      format: 'swiss',
      rounds_count: 3,
      creator: @creator
    )
  end

  def register(tournament, username, affiliation)
    user = User.create!(username: username, email: "#{username}@example.com", password: 'password')
    tournament.registrations.create!(user: user, status: 'checked_in', affiliation: affiliation)
    user
  end

  def same_affiliation_pairs(tournament, pairs)
    affiliations = tournament.registrations.to_h { |r| [r.user_id, r.affiliation_id] }
    pairs.select do |a, b|
      affiliations[a.id].present? && affiliations[a.id] == affiliations[b.id]
    end
  end
end
