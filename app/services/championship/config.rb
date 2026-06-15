# frozen_string_literal: true

module Championship
  class Config
    CONFIG_PATH = Rails.root.join('config/championship.yml')

    class << self
      def levels_for(game_system_name)
        system_config = data.dig('game_systems', game_system_name)
        return [] unless system_config

        (system_config['levels'] || []).map { |l| Level.new(l) }
      end

      def level_names_for(game_system_name)
        levels_for(game_system_name).map(&:name)
      end

      def level_for(game_system_name, level_name)
        levels_for(game_system_name).find { |l| l.name == level_name }
      end

      def best_of_for(game_system_name)
        data.dig('game_systems', game_system_name, 'best_of')
      end

      def game_system_names_with_levels
        (data['game_systems'] || {}).keys
      end

      def all_level_names
        (data['game_systems'] || {}).values.flat_map { |s| (s['levels'] || []).pluck('name') }.uniq
      end

      attr_writer :test_data

      def reset_test_data!
        @test_data = nil
      end

      private

      def data
        return @test_data if @test_data

        @data = nil if Rails.env.local?
        @data ||= YAML.load_file(CONFIG_PATH)
      end
    end

    class Level
      attr_reader :name, :placement_bonus, :participation_points

      def initialize(hash)
        @name = hash['name']
        @placement_bonus = (hash['placement_bonus'] || {}).transform_keys(&:to_i)
        @participation_points = hash['participation_points'] || 0
      end

      def points_for_rank(rank)
        placement_bonus.fetch(rank, participation_points)
      end

      # Groups consecutive ranks with identical points into [start_rank, end_rank, points] tuples.
      def condensed_placement
        sorted = placement_bonus.sort_by(&:first)
        return [] if sorted.empty?

        groups = []
        start_rank, current_pts = sorted.first
        end_rank = start_rank

        sorted.drop(1).each do |rank, pts|
          if pts == current_pts && rank == end_rank + 1
            end_rank = rank
          else
            groups << [start_rank, end_rank, current_pts]
            start_rank = rank
            end_rank = rank
            current_pts = pts
          end
        end
        groups << [start_rank, end_rank, current_pts]
        groups
      end
    end
  end
end
