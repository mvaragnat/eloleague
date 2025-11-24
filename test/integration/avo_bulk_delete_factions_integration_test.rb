# frozen_string_literal: true

require 'test_helper'

class AvoBulkDeleteFactionsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: 'admin2@example.com', password: 'password123', password_confirmation: 'password123')
    sign_in @admin, scope: :admin
  end

  test 'bulk delete button label is English and action fails safely when referenced' do
    # Create a system and a faction referenced by a tournament registration
    system = Game::System.create!(name: 'Test System', description: 'D')
    faction = Game::Faction.create!(name: 'Ref Faction', game_system: system)

    user = User.create!(email: 'user@example.com', password: 'password123', username: 'u')
    # Ensure a default scoring system exists for the system
    Game::ScoringSystem.create!(game_system: system, name: 'Default', is_default: true)
    tournament = Tournament::Tournament.create!(name: 'T1', description: 'D', game_system: system, format: 'open',
                                                creator: user)
    Tournament::Registration.create!(tournament:, user:, faction: faction, status: 'pending')

    # Visit Avo factions index
    get '/avo/resources/game_factions'
    assert_response :success

    # Ensure the action is listed with static English name
    assert_includes @response.body, 'Delete selected factions'
    assert_not_includes @response.body, 'No faction deleted. Some selected factions are referenced.'

    # Execute the action logic directly to verify safe cancellation behavior
    action = Avo::Actions::BulkDestroyFactions.new
    action.handle(query: [faction])
    assert Game::Faction.exists?(faction.id), 'Faction should not be deleted when referenced'
  end
end
