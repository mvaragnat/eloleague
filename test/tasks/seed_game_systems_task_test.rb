# frozen_string_literal: true

require 'test_helper'
require 'rake'

class SeedGameSystemsTaskTest < ActiveSupport::TestCase
  def setup
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    # Clean DB to avoid uniqueness conflicts between tests
    Game::Participation.destroy_all
    Game::Event.destroy_all
    Game::Faction.destroy_all
    Game::System.destroy_all
  end

  test 'seeds game systems and factions from YAML config' do
    assert_difference 'Game::System.count', 2 do
      assert_difference 'Game::Faction.count', 65 do
        Rake::Task['seed:game_systems'].execute
      end
    end

    # Verify game systems were created
    epic = Game::System.find_by(name: 'Epic Armageddon - FERC')
    assert_not_nil epic
    assert_equal '6mm strategy – French community-maintained lists', epic.description

    # Verify factions were created
    assert_equal 37, epic.factions.count
    assert epic.factions.pluck(:name).include?('Steel Legion')
  end

  test 'does not duplicate existing game systems and factions' do
    # Create existing system and faction
    existing_system = Game::System.create!(name: 'Epic Armageddon - FERC', description: 'Old description')
    Game::Faction.create!(name: 'Steel Legion', game_system: existing_system)

    assert_difference 'Game::System.count', 1 do # Only Go should be created
      assert_difference 'Game::Faction.count', 64 do # Black for Chess, and both for Go
        Rake::Task['seed:game_systems'].execute
      end
    end

    # Verify existing system was updated
    existing_system.reload
    assert_equal '6mm strategy – French community-maintained lists', existing_system.description

    # Verify existing faction was not duplicated
    assert_equal 1, existing_system.factions.where(name: 'Steel Legion').count
  end
end
