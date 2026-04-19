# frozen_string_literal: true

require 'test_helper'

module Api
  class TournamentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @system = game_systems(:chess)
      @scoring = game_scoring_systems(:chess_default)
      @player1 = users(:player_one)
    end

    test 'finished returns 404 when game_system_id is unknown' do
      get api_tournaments_finished_path(game_system_id: 999_999)
      assert_response :not_found
    end

    test 'finished returns completed tournaments' do
      completed = create_tournament(state: 'completed', name: 'Finished Cup')
      create_tournament(state: 'registration', name: 'Open Cup')

      get api_tournaments_finished_path(game_system_id: @system.id)
      assert_response :success
      json = response.parsed_body
      assert_equal 1, json.size
      assert_equal 'Finished Cup', json.first['name']
      assert_equal 'completed', json.first['state']
      assert json.first['url'].include?(completed.slug)
    end

    test 'finished excludes cancelled tournaments' do
      create_tournament(state: 'completed', name: 'Done')
      create_tournament(state: 'cancelled', name: 'Cancelled')

      get api_tournaments_finished_path(game_system_id: @system.id)
      json = response.parsed_body
      assert_equal 1, json.size
    end

    test 'open returns 404 when game_system_id is unknown' do
      get api_tournaments_open_path(game_system_id: 999_999)
      assert_response :not_found
    end

    test 'open returns registration and running tournaments' do
      create_tournament(state: 'registration', name: 'Signup Open')
      create_tournament(state: 'running', name: 'In Progress')
      create_tournament(state: 'completed', name: 'Done')

      get api_tournaments_open_path(game_system_id: @system.id)
      assert_response :success
      json = response.parsed_body
      assert_equal 2, json.size
      names = json.pluck('name')
      assert_includes names, 'Signup Open'
      assert_includes names, 'In Progress'
    end

    test 'open excludes cancelled tournaments' do
      create_tournament(state: 'registration', name: 'Signup')
      create_tournament(state: 'cancelled', name: 'Cancelled')

      get api_tournaments_open_path(game_system_id: @system.id)
      json = response.parsed_body
      assert_equal 1, json.size
    end

    test 'response includes expected fields' do
      t = create_tournament(state: 'completed', name: 'Full Fields')

      get api_tournaments_finished_path(game_system_id: @system.id)
      json = response.parsed_body
      entry = json.first

      assert_equal t.name, entry['name']
      assert_equal t.slug, entry['slug']
      assert_equal t.state, entry['state']
      assert_equal t.format, entry['format']
      assert entry.key?('url')
      assert entry.key?('starts_at')
      assert entry.key?('ends_at')
    end

    private

    def create_tournament(state:, name:)
      ::Tournament::Tournament.create!(
        name: name,
        game_system: @system,
        scoring_system: @scoring,
        format: :swiss,
        state: state,
        creator: @player1,
        starts_at: Time.zone.local(2026, 6, 1),
        ends_at: Time.zone.local(2026, 6, 2)
      )
    end
  end
end
