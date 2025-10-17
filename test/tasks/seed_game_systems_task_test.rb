# frozen_string_literal: true

require 'test_helper'
require 'rake'

class SeedGameSystemsTaskTest < ActiveSupport::TestCase
  def setup
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    # Clean DB to avoid uniqueness conflicts between tests (bypass callbacks to avoid dependent restrictions)
    Game::Participation.delete_all
    Game::Event.delete_all
    Game::Faction.delete_all
    Game::System.delete_all
  end

  test 'seeds game systems and factions from YAML config' do
    config = YAML.load_file(Rails.root.join('config/game_systems.yml'))
    systems_data = config['game_systems']
    total_systems = systems_data.size
    total_factions = systems_data.sum { |s| (s['factions'] || []).size }

    assert_difference 'Game::System.count', total_systems do
      assert_difference 'Game::Faction.count', total_factions do
        Rake::Task['seed:game_systems'].execute
      end
    end

    # Verify game systems were created
    epic = Game::System.find_by(name: 'Epic Armageddon - FERC')
    assert_not_nil epic
    assert_equal '6mm strategy – French community-maintained lists', epic.description

    # Verify factions were created for FERC (count from YAML)
    ferc_config = systems_data.find do |s|
      name = s['name']
      names = name.is_a?(Hash) ? name : { 'en' => name, 'fr' => name }
      names.value?('Epic Armageddon - FERC')
    end
    assert_equal (ferc_config['factions'] || []).size, epic.factions.count
    assert epic.factions.pluck(:name).include?('Steel Legion')

    # Verify Epic UK was created
    epic_uk = Game::System.find_by(name: 'Epic UK')
    assert_not_nil epic_uk

    epic_uk_config = systems_data.find do |s|
      name = s['name']
      names = name.is_a?(Hash) ? name : { 'en' => name, 'fr' => name }
      names.value?('Epic UK')
    end
    assert_equal (epic_uk_config['factions'] || []).size, epic_uk.factions.count

    # Verify OPR Grimdark Future was created
    opr = Game::System.find_by(name: 'OPR Grimdark Future')
    assert_not_nil opr
    assert opr.factions.exists?(name: 'Battle Brothers')
  end

  test 'does not duplicate existing game systems and factions' do
    # Create existing system and faction
    existing_system = Game::System.create!(name: 'Epic Armageddon - FERC', description: 'Old description')
    Game::Faction.create!(name: 'Steel Legion', game_system: existing_system)

    config = YAML.load_file(Rails.root.join('config/game_systems.yml'))
    systems_data = config['game_systems']

    # One system already exists (FERC), so expect all others to be created
    expected_new_systems = systems_data.size - 1
    # Total factions minus the pre-existing 'Steel Legion'
    expected_new_factions = systems_data.sum { |s| (s['factions'] || []).size } - 1

    assert_difference 'Game::System.count', expected_new_systems do # New systems should be created
      assert_difference 'Game::Faction.count', expected_new_factions do # All factions except existing Steel Legion
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
