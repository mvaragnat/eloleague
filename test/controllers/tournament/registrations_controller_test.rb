# frozen_string_literal: true

require 'test_helper'

module Tournament
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @creator = users(:player_one)
      @p2 = users(:player_two)
      @system = game_systems(:chess)

      sign_in @creator
      post tournaments_path(locale: I18n.locale), params: {
        tournament: { name: 'ArmyView', description: 'T', game_system_id: @system.id, format: 'open' }
      }
      @t = ::Tournament::Tournament.order(:created_at).last

      # Register creator and p2
      post register_tournament_path(@t, locale: I18n.locale)
      f1 = Game::Faction.find_or_create_by!(game_system: @system, name: 'White')
      @t.registrations.find_by(user: @creator).update!(faction: f1, army_list: 'LIST A')

      sign_out @creator
      sign_in @p2
      post register_tournament_path(@t, locale: I18n.locale)
      f2 = Game::Faction.find_or_create_by!(game_system: @system, name: 'Black')
      @t.registrations.find_by(user: @p2).update!(faction: f2, army_list: 'LIST B')

      @reg_creator = @t.registrations.find_by(user: @creator)
      @reg_p2 = @t.registrations.find_by(user: @p2)
    end

    test 'organizer can toggle participant status regardless of requirements and preserves tab' do
      # Organizer signs in and toggles p2 to checked_in
      sign_out @p2
      sign_in @creator
      reg = @t.registrations.find_by(user: @p2)
      patch tournament_tournament_registration_path(@t, reg, locale: I18n.locale), params: {
        tournament_registration: { status: 'checked_in' }, tab: 2
      }
      assert_redirected_to tournament_path(@t, locale: I18n.locale, tab: 2)
      assert_equal 'checked_in', reg.reload.status

      # Toggle back to pending
      patch tournament_tournament_registration_path(@t, reg, locale: I18n.locale), params: {
        tournament_registration: { status: 'pending' }, tab: 2
      }
      assert_redirected_to tournament_path(@t, locale: I18n.locale, tab: 2)
      assert_equal 'pending', reg.reload.status
    end

    test 'before running: participant cannot view other participant army list' do
      # p2 tries to view creator list
      get tournament_tournament_registration_path(@t, @reg_creator, locale: I18n.locale)
      assert_redirected_to tournament_path(@t, locale: I18n.locale)
    end

    test 'before running: owner and organizer can view' do
      # Owner (p2 views own)
      get tournament_tournament_registration_path(@t, @reg_p2, locale: I18n.locale)
      assert_response :success

      # Organizer views creator reg (self) and participant reg
      sign_out @p2
      sign_in @creator
      get tournament_tournament_registration_path(@t, @reg_creator, locale: I18n.locale)
      assert_response :success
      get tournament_tournament_registration_path(@t, @reg_p2, locale: I18n.locale)
      assert_response :success
    end

    test 'before running: guest cannot view' do
      sign_out @p2
      get tournament_tournament_registration_path(@t, @reg_creator, locale: I18n.locale)
      assert_redirected_to tournament_path(@t, locale: I18n.locale)
    end

    test 'after running: guest can view any list' do
      # Move to running
      sign_in @creator
      post lock_registration_tournament_path(@t, locale: I18n.locale)

      sign_out @creator
      get tournament_tournament_registration_path(@t, @reg_creator, locale: I18n.locale)
      assert_response :success
      get tournament_tournament_registration_path(@t, @reg_p2, locale: I18n.locale)
      assert_response :success
    end

    test 'after completed: guest can view any list' do
      # Move to running then finalize
      sign_in @creator
      post lock_registration_tournament_path(@t, locale: I18n.locale)
      post finalize_tournament_path(@t, locale: I18n.locale)

      # As guest
      sign_out @creator
      get tournament_tournament_registration_path(@t, @reg_creator, locale: I18n.locale)
      assert_response :success
      get tournament_tournament_registration_path(@t, @reg_p2, locale: I18n.locale)
      assert_response :success
    end
  end
end
