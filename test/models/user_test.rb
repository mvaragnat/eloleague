# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'should not save user without username' do
    user = User.new(email: 'test@example.com', password: 'xxx')
    assert_not user.save, 'Saved the user without a username'
  end

  test 'should not save user without email' do
    user = User.new(username: 'testuser')
    assert_not user.save, 'Saved the user without an email'
  end

  test 'should not save user with invalid email' do
    user = User.new(username: 'testuser', email: 'invalid-email', password: 'xxx')
    assert_not user.save, 'Saved the user with an invalid email'
  end

  test 'should not save user with duplicate username' do
    users(:player_one)
    user = User.new(username: 'player_one', email: 'test2@example.com', password: 'xxx')
    assert_not user.save, 'Saved the user with a duplicate username'
  end

  test 'should not save user with duplicate email' do
    users(:player_one)
    user = User.new(username: 'testuser2', email: 'one@example.com', password: 'xxx')
    assert_not user.save, 'Saved the user with a duplicate email'
  end

  test 'can update username and email without changing password' do
    user = users(:player_one)
    original_encrypted_password = user.encrypted_password
    assert user.update(username: 'player_one_updated', email: 'player_one_updated@example.com')
    assert_equal original_encrypted_password, user.reload.encrypted_password
  end
end
