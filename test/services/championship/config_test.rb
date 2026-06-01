# frozen_string_literal: true

require 'test_helper'

module Championship
  class ConfigTest < ActiveSupport::TestCase
    setup do
      Championship::Config.test_data = {
        'game_systems' => {
          'TestSystem' => {
            'levels' => [
              {
                'name' => 'Major',
                'placement_bonus' => { 1 => 20, 2 => 15, 3 => 10 },
                'participation_points' => 2
              },
              {
                'name' => 'Local',
                'placement_bonus' => { 1 => 8 },
                'participation_points' => 0
              }
            ]
          }
        }
      }
    end

    teardown do
      Championship::Config.reset_test_data!
    end

    test 'levels_for returns levels for a known system' do
      levels = Championship::Config.levels_for('TestSystem')
      assert_equal 2, levels.size
      assert_equal 'Major', levels.first.name
      assert_equal 'Local', levels.last.name
    end

    test 'levels_for returns empty array for unknown system' do
      assert_equal [], Championship::Config.levels_for('Unknown')
    end

    test 'level_names_for returns level names' do
      names = Championship::Config.level_names_for('TestSystem')
      assert_equal %w[Major Local], names
    end

    test 'level_for returns specific level' do
      level = Championship::Config.level_for('TestSystem', 'Major')
      assert_not_nil level
      assert_equal 'Major', level.name
      assert_equal 20, level.placement_bonus[1]
      assert_equal 2, level.participation_points
    end

    test 'level_for returns nil for unknown level' do
      assert_nil Championship::Config.level_for('TestSystem', 'Nonexistent')
    end

    test 'Level#points_for_rank returns placement_bonus for ranked positions' do
      level = Championship::Config.level_for('TestSystem', 'Major')
      assert_equal 20, level.points_for_rank(1)
      assert_equal 15, level.points_for_rank(2)
      assert_equal 10, level.points_for_rank(3)
    end

    test 'Level#points_for_rank returns participation_points for unranked positions' do
      level = Championship::Config.level_for('TestSystem', 'Major')
      assert_equal 2, level.points_for_rank(4)
      assert_equal 2, level.points_for_rank(99)
    end

    test 'Level#points_for_rank returns 0 when participation_points is 0' do
      level = Championship::Config.level_for('TestSystem', 'Local')
      assert_equal 0, level.points_for_rank(2)
    end

    test 'game_system_names_with_levels lists configured systems' do
      names = Championship::Config.game_system_names_with_levels
      assert_includes names, 'TestSystem'
    end
  end
end
