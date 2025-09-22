# frozen_string_literal: true

require 'test_helper'

module Tournament
  class MatchTest < ActiveSupport::TestCase
    setup do
      @t = ::Tournament::Tournament.create!(
        name: 'Elimination Cup',
        creator: users(:player_one),
        game_system: game_systems(:chess),
        format: 'elimination'
      )
      @a = users(:player_one)
      @b = users(:player_two)
    end

    test 'valid with required fields' do
      m = ::Tournament::Match.new(tournament: @t, a_user: @a, b_user: @b)
      assert m.valid?
      assert_equal 'pending', m.result
      assert_match(/#{@a.username} .* #{@b.username}/, m.match_label)
    end

    test 'invalid result value' do
      m = ::Tournament::Match.new(tournament: @t, a_user: @a, b_user: @b, result: 'foo')
      assert_not m.valid?
      assert m.errors[:result].present?
    end
  end
end
