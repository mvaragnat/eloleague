# frozen_string_literal: true

require 'test_helper'

module Tournament
  class RegistrationTest < ActiveSupport::TestCase
    setup do
      @t = ::Tournament::Tournament.create!(
        name: 'Autumn Open',
        creator: users(:player_one),
        game_system: game_systems(:chess),
        format: 'open'
      )
      @user = users(:player_two)
    end

    test 'valid registration' do
      reg = ::Tournament::Registration.new(tournament: @t, user: @user)
      assert reg.valid?
    end

    test 'uniqueness per tournament and user' do
      ::Tournament::Registration.create!(tournament: @t, user: @user)
      dup = ::Tournament::Registration.new(tournament: @t, user: @user)
      assert_not dup.valid?
      assert dup.errors[:user_id].present?
    end

    test 'affiliation_name assigns an existing affiliation without creating a new one' do
      affiliation = ::Affiliation.create!(name: 'Club Alpha')
      reg = ::Tournament::Registration.new(tournament: @t, user: @user)

      assert_no_difference -> { ::Affiliation.count } do
        reg.affiliation_name = 'club alpha'
      end
      assert_equal affiliation, reg.affiliation
      assert_equal 'Club Alpha', reg.affiliation_name
    end

    test 'affiliation_name creates the affiliation when it does not exist' do
      reg = ::Tournament::Registration.new(tournament: @t, user: @user)

      assert_difference -> { ::Affiliation.count }, 1 do
        reg.affiliation_name = 'Club Beta'
      end
      assert_equal 'Club Beta', reg.affiliation_name
    end

    test 'blank affiliation_name clears the affiliation' do
      reg = ::Tournament::Registration.new(tournament: @t, user: @user,
                                           affiliation: ::Affiliation.create!(name: 'Club Gamma'))

      reg.affiliation_name = ''

      assert_nil reg.affiliation
      assert_nil reg.affiliation_name
    end

    test 'valid status values' do
      reg = ::Tournament::Registration.new(tournament: @t, user: @user)

      reg.status = 'pending'
      assert reg.valid?

      reg.status = 'checked_in'
      assert reg.valid?

      reg.status = 'cancelled'
      assert reg.valid?
    end

    test 'invalid status values' do
      reg = ::Tournament::Registration.new(tournament: @t, user: @user)

      reg.status = 'approved'
      assert_not reg.valid?
      assert reg.errors[:status].present?
      assert_includes reg.errors[:status].first, 'is not included in the list'

      reg.status = 'invalid_status'
      assert_not reg.valid?
      assert reg.errors[:status].present?
      assert_includes reg.errors[:status].first, 'is not included in the list'
    end

    test 'active scope excludes cancelled registrations' do
      reg_active = ::Tournament::Registration.create!(tournament: @t, user: @user, status: 'checked_in')
      u3 = User.create!(username: 'scope_user', email: 'scope@example.com', password: 'password')
      reg_cancelled = ::Tournament::Registration.create!(tournament: @t, user: u3, status: 'cancelled')

      active_regs = @t.registrations.active
      assert_includes active_regs, reg_active
      assert_not_includes active_regs, reg_cancelled
    end

    test 'cancelled scope returns only cancelled registrations' do
      ::Tournament::Registration.create!(tournament: @t, user: @user, status: 'checked_in')
      u3 = User.create!(username: 'cancelled_user', email: 'cancelled@example.com', password: 'password')
      reg_cancelled = ::Tournament::Registration.create!(tournament: @t, user: u3, status: 'cancelled')

      assert_equal [reg_cancelled], @t.registrations.cancelled.to_a
    end
  end
end
