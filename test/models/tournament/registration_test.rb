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
