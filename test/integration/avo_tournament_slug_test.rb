# frozen_string_literal: true

require 'test_helper'

class AvoTournamentSlugTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: 'admin@example.com', password: 'password123', password_confirmation: 'password123')
    sign_in @admin, scope: :admin
    @user = users(:player_one)
    @tournament = Tournament::Tournament.create!(
      name: 'Exemple Tournoi',
      creator: @user,
      game_system: game_systems(:chess),
      format: 'open'
    )
  end

  test 'admin can access tournament edit page using slug in URL' do
    # The to_param method returns slug, so Avo generates URLs with slugs
    get "/avo/resources/tournaments/#{@tournament.to_param}/edit"
    assert_response :success
    assert_includes @response.body, 'Exemple Tournoi'
  end

  test 'admin can access tournament show page using slug in URL' do
    get "/avo/resources/tournaments/#{@tournament.to_param}"
    assert_response :success
    assert_includes @response.body, 'Exemple Tournoi'
  end

  test 'admin can access tournament using numeric ID for backward compatibility' do
    # Ensure we can still access tournaments by numeric ID
    get "/avo/resources/tournaments/#{@tournament.id}"
    assert_response :success
    assert_includes @response.body, 'Exemple Tournoi'
  end

  test 'admin can access tournament associations (rounds) via slug URL' do
    # Create a round for the tournament
    Tournament::Round.create!(tournament: @tournament, number: 1, state: 'pending')

    # Access the rounds association via slug
    get "/avo/resources/tournaments/#{@tournament.to_param}/rounds"
    assert_response :success
    # Should not raise RecordNotFound error
  end
end
