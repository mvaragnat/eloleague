# frozen_string_literal: true

require 'test_helper'

module Game
  class EventsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:player_one)
      @system = game_systems(:chess)
      @opponent = users(:player_two)
      sign_in @user

      # Ensure factions exist for system
      @f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
      @f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')
    end

    test 'should get new game form' do
      get new_game_event_path
      assert_response :success
      assert_select 'h2', text: I18n.t('games.new.title')
    end

    test 'should create game with scores for both players' do
      assert_difference 'Game::Event.count' do
        post game_events_path, params: {
          event: {
            game_system_id: @system.id,
            game_participations_attributes: [
              { user_id: @user.id, score: 21, faction_id: @f1.id, army_list: 'A list' },
              { user_id: @opponent.id, score: 18, faction_id: @f2.id, army_list: 'B list' }
            ]
          }
        }
      end

      assert_redirected_to dashboard_path(locale: I18n.locale)
    end

    test 'should not create game with invalid params' do
      post game_events_path, params: {
        event: {
          game_system_id: nil,
          game_participations_attributes: []
        }
      }

      assert_response :unprocessable_content
    end

    test 'should not create game if a score is missing' do
      post game_events_path, params: {
        event: {
          game_system_id: @system.id,
          game_participations_attributes: [
            { user_id: @user.id, score: 21, faction_id: @f1.id },
            { user_id: @opponent.id, faction_id: @f2.id }
          ]
        }
      }

      assert_response :unprocessable_content
    end

    test 'should not create game if a faction is missing' do
      post game_events_path, params: {
        event: {
          game_system_id: @system.id,
          game_participations_attributes: [
            { user_id: @user.id, score: 21, faction_id: @f1.id },
            { user_id: @opponent.id, score: 18 }
          ]
        }
      }

      assert_response :unprocessable_content
    end

    test 'should not create game without players' do
      post game_events_path, params: {
        event: {
          game_system_id: @system.id,
          game_participations_attributes: []
        }
      }

      assert_response :unprocessable_content
    end
  end
end
