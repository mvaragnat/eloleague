# frozen_string_literal: true

require 'test_helper'

class AvoTournamentRegistrationCreationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: 'admin@test.com', password: 'password123', password_confirmation: 'password123')
    sign_in @admin, scope: :admin
    @tournament = Tournament::Tournament.create!(
      name: 'Berry Champs Epic 2025',
      format: :swiss,
      creator: users(:player_one),
      game_system: game_systems(:chess),
      state: :registration
    )
    @user = users(:player_one)
  end

  test 'Avo new registration page works when passing tournament slug as via_record_id' do
    get '/avo/resources/tournament_registrations/new',
        params: {
          via_record_id: @tournament.slug,
          via_relation: 'tournament',
          via_relation_class: 'Tournament::Tournament',
          via_resource_class: 'Avo::Resources::Tournament'
        }

    assert_response :success
    assert_select 'form'
  end

  test 'Avo new registration page works when passing tournament ID as via_record_id' do
    get '/avo/resources/tournament_registrations/new',
        params: {
          via_record_id: @tournament.id,
          via_relation: 'tournament',
          via_relation_class: 'Tournament::Tournament',
          via_resource_class: 'Avo::Resources::Tournament'
        }

    assert_response :success
    assert_select 'form'
  end
end
