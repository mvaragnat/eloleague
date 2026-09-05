# frozen_string_literal: true

require 'test_helper'

class AffiliationTest < ActiveSupport::TestCase
  test 'requires a name' do
    assert_not Affiliation.new(name: '').valid?
  end

  test 'name is unique regardless of case' do
    Affiliation.create!(name: 'Les Dés Pipés')
    duplicate = Affiliation.new(name: 'les dés pipés')

    assert_not duplicate.valid?
  end

  test 'find_or_create_by_name reuses an existing affiliation whatever the case and spacing' do
    existing = Affiliation.create!(name: 'Club des Six')

    assert_equal existing, Affiliation.find_or_create_by_name('  club   des six ')
  end

  test 'find_or_create_by_name creates a new affiliation for an unknown name' do
    assert_difference -> { Affiliation.count }, 1 do
      affiliation = Affiliation.find_or_create_by_name(' Nouveau Club ')
      assert_equal 'Nouveau Club', affiliation.name
    end
  end

  test 'find_or_create_by_name returns nil for a blank name' do
    assert_nil Affiliation.find_or_create_by_name('   ')
  end

  test 'has many registrations and users through them' do
    affiliation = Affiliation.create!(name: 'Team Alpha')
    tournament = ::Tournament::Tournament.create!(
      name: 'Affiliation Assoc',
      creator: users(:player_one),
      game_system: game_systems(:chess),
      format: 'swiss'
    )
    tournament.registrations.create!(user: users(:player_two), affiliation: affiliation)

    assert_equal [users(:player_two)], affiliation.reload.users.to_a
  end

  test 'destroying an affiliation keeps registrations without affiliation' do
    affiliation = Affiliation.create!(name: 'Team Beta')
    tournament = ::Tournament::Tournament.create!(
      name: 'Affiliation Nullify',
      creator: users(:player_one),
      game_system: game_systems(:chess),
      format: 'swiss'
    )
    registration = tournament.registrations.create!(user: users(:player_two), affiliation: affiliation)

    affiliation.destroy

    assert_nil registration.reload.affiliation_id
  end
end
