# frozen_string_literal: true

require 'test_helper'

class EloCalculatorTest < ActiveSupport::TestCase
  Side = Elo::Calculator::Side

  def setup
    @calc = Elo::Calculator.new
    # Example 1/2 of the spec: veteran on a rare faction vs newcomer on a well-known faction
    @veteran = Side.new(player_rating: 1800, player_rd: 50, faction_rating: 1500, faction_rd: 300)
    @newcomer = Side.new(player_rating: 1500, player_rd: 300, faction_rating: 1600, faction_rd: 80)
  end

  test 'expected scores of both sides sum to 1 between equal uncertainties' do
    a = Side.new(player_rating: 1500, player_rd: 100, faction_rating: 1500, faction_rd: 100)
    b = Side.new(player_rating: 1700, player_rd: 100, faction_rating: 1500, faction_rd: 100)
    ra, rb = @calc.rate(a, b, 1.0)
    assert_in_delta 1.0, ra.expected + rb.expected, 1e-9
  end

  test 'expected win: the uncertain faction absorbs almost all the signal' do
    a, = @calc.rate(@veteran, @newcomer, 1.0)

    assert_in_delta 0.694, a.expected, 0.001
    assert_equal 1802, a.player_rating # +2.4
    assert_equal 1585, a.faction_rating # +84.8
  end

  test 'upset: the uncertain newcomer gains a lot, its known faction little' do
    _, b = @calc.rate(@veteran, @newcomer, 0.0)

    assert_equal 1692, b.player_rating # +192
    assert_equal 1614, b.faction_rating # +13.7
  end

  test 'deviations shrink after a game, the most uncertain component the most (Kalman)' do
    a, = @calc.rate(@veteran, @newcomer, 1.0)

    assert_equal 50, a.player_rd # 49.8, rounded
    assert_equal 261, a.faction_rd
  end

  test 'calibrated pairs move little and share the change' do
    c = Side.new(player_rating: 1700, player_rd: 40, faction_rating: 1550, faction_rd: 50)
    d = Side.new(player_rating: 1650, player_rd: 45, faction_rating: 1500, faction_rd: 60)
    rc, = @calc.rate(c, d, 0.0)

    assert_in_delta 0.636, rc.expected, 0.001
    assert_equal 1694, rc.player_rating
    assert_equal 1541, rc.faction_rating
  end

  test 'mirror match only updates players' do
    a = Side.new(player_rating: 1500, player_rd: 200, faction_rating: 1550, faction_rd: 300)
    b = Side.new(player_rating: 1500, player_rd: 200, faction_rating: 1550, faction_rd: 300)
    ra, rb = @calc.rate(a, b, 1.0, mirror: true)

    assert_in_delta 0.5, ra.expected, 1e-9
    assert_equal [1550, 300], [ra.faction_rating, ra.faction_rd]
    assert_equal [1550, 300], [rb.faction_rating, rb.faction_rd]
    assert_operator ra.player_rating, :>, 1500
    assert_operator rb.player_rating, :<, 1500
    assert_operator ra.player_rd, :<, 200
  end

  test 'draw between equal sides changes no rating' do
    a = Side.new(player_rating: 1500, player_rd: 350, faction_rating: 1500, faction_rd: 350)
    ra, rb = @calc.rate(a, a.dup, 0.5)

    assert_equal 1500, ra.player_rating
    assert_equal 1500, rb.faction_rating
    assert_operator ra.player_rd, :<, 350
  end

  test 'deviation never goes below the minimum' do
    a = Side.new(player_rating: 1500, player_rd: 30, faction_rating: 1500, faction_rd: 30)
    ra, = @calc.rate(a, a.dup, 1.0)

    assert_equal Elo::Calculator::RD_MIN, ra.player_rd
    assert_equal Elo::Calculator::RD_MIN, ra.faction_rd
  end

  test 'inactivity raises the deviation, capped at the maximum' do
    assert_equal 98, Elo::Calculator.inflate_deviation(50, 6)
    assert_equal 50, Elo::Calculator.inflate_deviation(50, 0)
    assert_equal Elo::Calculator::RD_MAX, Elo::Calculator.inflate_deviation(300, 120)
  end

  test 'provisional above 100 RD and conservative rating is R - 2 RD' do
    assert Elo::Calculator.provisional?(101)
    assert_not Elo::Calculator.provisional?(100)
    assert_equal 1400, Elo::Calculator.conservative(1600, 100)
  end
end
