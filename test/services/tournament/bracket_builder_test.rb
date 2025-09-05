# frozen_string_literal: true

require 'test_helper'

class TournamentBracketBuilderTest < ActiveSupport::TestCase
  setup do
    @system = game_systems(:chess)
    @creator = users(:player_one)
  end

  def create_users(count)
    (1..count).map do |i|
      User.create!(
        username: "u#{i}_#{SecureRandom.hex(2)}",
        email: "u#{i}_#{SecureRandom.hex(2)}@example.com",
        password: 'password'
      )
    end
  end

  def ensure_elo(user, rating)
    EloRating.find_or_create_by!(user: user, game_system: @system) do |row|
      row.rating = rating
      row.games_played = 0
    end
  end

  def build_tournament
    Tournament::Tournament.create!(
      name: 'Test',
      description: 'x',
      game_system: @system,
      format: :elimination,
      creator: @creator,
      state: :registration
    )
  end

  def register_users(tournament, users)
    users.each do |user|
      Tournament::Registration.create!(tournament: tournament, user: user, status: 'checked_in')
    end
  end

  def build_and_return_levels(tournament)
    levels = Tournament::BracketBuilder.new(tournament).call
    tournament.reload
    levels
  end

  test '5 players -> 8-size bracket, 3 byes, correct match counts, highest Elo gets bye' do
    t = build_tournament
    users = create_users(5)
    users.each_with_index { |u, idx| ensure_elo(u, 1500 + (idx * 10)) }
    register_users(t, users)

    levels = build_and_return_levels(t)

    # 8 slots -> 4 leaf matches; since 3 byes, 3 leaf matches have single player
    leaf = levels.first
    assert_equal 4, leaf.size

    # Total matches in a full 8-player bracket tree: 7
    assert_equal 7, t.matches.count

    # Count byes: leaf matches where one side is nil
    bye_count = leaf.count { |m| m.a_user_id.present? ^ m.b_user_id.present? }
    assert_equal 3, bye_count

    # Highest Elo should be present and advanced via bye to parent
    top_user = users.last # highest rating due to increment
    leaf_with_top = leaf.find { |m| [m.a_user_id, m.b_user_id].compact.include?(top_user.id) }
    assert leaf_with_top.present?
    assert leaf_with_top.parent_match.present?
    parent = leaf_with_top.parent_match
    assert [parent.a_user_id, parent.b_user_id].compact.include?(top_user.id)
  end

  test '16 players -> 16-size bracket, no byes, match counts' do
    t = build_tournament
    users = create_users(16)
    users.each_with_index { |u, idx| ensure_elo(u, 1400 + (idx * 5)) }
    register_users(t, users)

    build_and_return_levels(t)

    # Full 16-player bracket has 15 matches
    assert_equal 15, t.matches.count

    leaves = t.matches.select { |m| m.child_matches.empty? }
    assert_equal 8, leaves.size

    # No byes
    bye_leafs = leaves.count { |m| m.a_user_id.present? ^ m.b_user_id.present? }
    assert_equal 0, bye_leafs
  end

  test 'non-competitive tournament propagates flag to all created matches' do
    t = Tournament::Tournament.create!(
      name: 'NC', description: 'x', game_system: @system, format: :elimination, creator: @creator,
      state: :registration, non_competitive: true
    )
    users = create_users(4)
    register_users(t, users)

    build_and_return_levels(t)

    assert t.matches.any?
    assert_equal 0, t.matches.where(non_competitive: false).count
    assert_equal t.matches.count, t.matches.where(non_competitive: true).count
  end

  test '33 players -> 64-size bracket, 31 byes, match counts, Elo bye' do
    t = build_tournament
    users = create_users(33)
    users.each_with_index { |u, idx| ensure_elo(u, 1300 + (idx * 2)) }
    register_users(t, users)

    levels = build_and_return_levels(t)

    # 64 slots -> 32 leaf matches
    leaf = levels.first
    assert_equal 32, leaf.size

    # Total matches in full 64-player tree: 63
    assert_equal 63, t.matches.count

    # Byes = 64 - 33 = 31
    bye_count = leaf.count { |m| m.a_user_id.present? ^ m.b_user_id.present? }
    assert_equal 31, bye_count

    # Highest Elo should be present and get a bye
    top_user = users.last
    leaf_with_top = leaf.find { |m| [m.a_user_id, m.b_user_id].compact.include?(top_user.id) }
    assert leaf_with_top.present?
    assert leaf_with_top.parent_match.present?
    parent = leaf_with_top.parent_match
    assert [parent.a_user_id, parent.b_user_id].compact.include?(top_user.id)
  end
end
