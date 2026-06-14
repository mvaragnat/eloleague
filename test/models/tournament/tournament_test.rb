# frozen_string_literal: true

require 'test_helper'

module Tournament
  class TournamentTest < ActiveSupport::TestCase
    setup do
      @creator = users(:player_one)
      @system = game_systems(:chess)
    end

    test 'valid tournament with minimal attributes' do
      t = ::Tournament::Tournament.new(
        name: 'Spring Open',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert t.valid?
    end

    test 'invalid without name' do
      t = ::Tournament::Tournament.new(
        name: nil,
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert_not t.valid?
      assert t.errors[:name].present?
    end

    test 'invalid with unknown format' do
      assert_raises ArgumentError do
        ::Tournament::Tournament.new(
          name: 'X',
          creator: @creator,
          game_system: @system,
          format: 'league'
        )
      end
    end

    test 'rounds_count must be positive when provided' do
      t = ::Tournament::Tournament.new(
        name: 'Swiss Cup',
        creator: @creator,
        game_system: @system,
        format: 'swiss',
        rounds_count: 0
      )
      assert_not t.valid?
      assert t.errors[:rounds_count].present?

      t.rounds_count = -1
      assert_not t.valid?
      assert t.errors[:rounds_count].present?

      t.rounds_count = nil
      assert t.valid?
    end

    test 'generates slug from name on creation' do
      t = ::Tournament::Tournament.create!(
        name: 'Spring Open Tournament',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert_equal 'spring_open_tournament', t.slug
    end

    test 'slug removes special characters and accents and normalizes hyphens to underscores' do
      t = ::Tournament::Tournament.create!(
        name: 'Tournoi d\'Été 2025 - Spécial!',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert_equal 'tournoi_dete_2025_special', t.slug
    end

    test 'slug replaces spaces with underscores' do
      t = ::Tournament::Tournament.create!(
        name: 'My   Multiple   Spaces',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert_equal 'my_multiple_spaces', t.slug
    end

    test 'slug must be unique' do
      ::Tournament::Tournament.create!(
        name: 'Spring Open',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )

      duplicate = ::Tournament::Tournament.new(
        name: 'Something else',
        slug: 'spring_open',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert_not duplicate.valid?
      assert duplicate.errors[:slug].present?
    end

    test 'slug does not change when name is updated' do
      t = ::Tournament::Tournament.create!(
        name: 'Original Name',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      original_slug = t.slug

      t.update!(name: 'Updated Name')
      assert_equal original_slug, t.slug
    end

    test 'to_param returns slug' do
      t = ::Tournament::Tournament.create!(
        name: 'Spring Open',
        creator: @creator,
        game_system: @system,
        format: 'open'
      )
      assert_equal t.slug, t.to_param
    end

    test 'changing non_competitive propagates to existing matches and game events' do
      t = ::Tournament::Tournament.create!(
        name: 'Friendly Cup',
        creator: @creator,
        game_system: @system,
        format: 'open',
        non_competitive: true
      )
      player_a = users(:player_one)
      player_b = users(:player_two)

      match = ::Tournament::Match.create!(tournament: t, a_user: player_a, b_user: player_b, result: :pending)
      event = Game::Event.create!(
        game_system: @system,
        tournament: t,
        played_at: Time.current,
        game_participations_attributes: [
          { user: player_a, score: 5, faction: game_factions(:chess_white) },
          { user: player_b, score: 3, faction: game_factions(:chess_white) }
        ]
      )

      assert match.reload.non_competitive
      assert event.reload.non_competitive

      t.update!(non_competitive: false)

      assert_not match.reload.non_competitive
      assert_not event.reload.non_competitive
    end

    test 'changing non_competitive from false to true propagates to children' do
      t = ::Tournament::Tournament.create!(
        name: 'Serious Cup',
        creator: @creator,
        game_system: @system,
        format: 'open',
        non_competitive: false
      )
      player_a = users(:player_one)
      player_b = users(:player_two)

      match = ::Tournament::Match.create!(tournament: t, a_user: player_a, b_user: player_b, result: :pending)
      event = Game::Event.create!(
        game_system: @system,
        tournament: t,
        played_at: Time.current,
        game_participations_attributes: [
          { user: player_a, score: 5, faction: game_factions(:chess_white) },
          { user: player_b, score: 3, faction: game_factions(:chess_white) }
        ]
      )

      assert_not match.reload.non_competitive
      assert_not event.reload.non_competitive

      t.update!(non_competitive: true)

      assert match.reload.non_competitive
      assert event.reload.non_competitive
    end

    test 'updating other attributes does not trigger non_competitive propagation' do
      t = ::Tournament::Tournament.create!(
        name: 'Stable Cup',
        creator: @creator,
        game_system: @system,
        format: 'open',
        non_competitive: true
      )
      match = ::Tournament::Match.create!(tournament: t, a_user: users(:player_one),
                                          b_user: users(:player_two), result: :pending)

      assert match.reload.non_competitive

      t.update!(name: 'Renamed Cup')

      assert match.reload.non_competitive
    end
  end
end
