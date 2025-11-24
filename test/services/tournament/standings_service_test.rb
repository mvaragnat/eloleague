# frozen_string_literal: true

require 'test_helper'

class TournamentStandingsServiceTest < ActiveSupport::TestCase
  test 'top3_usernames returns usernames of top players' do
    creator = users(:player_one)
    system = game_systems(:chess)
    t = ::Tournament::Tournament.create!(name: 'S', description: 'D', game_system: system, format: 'open',
                                         creator: creator)
    p2 = users(:player_two)
    p3 = User.create!(username: 'p3', email: 'p3@example.com', password: 'password')

    # Register participants
    [creator, p2, p3].each { |u| t.registrations.create!(user: u) }

    # Build two events with scores
    f1 = Game::Faction.find_or_create_by!(game_system: system, name: 'White')
    f2 = Game::Faction.find_or_create_by!(game_system: system, name: 'Black')

    e1 = Game::Event.new(game_system: system, played_at: Time.current, tournament: t)
    e1.game_participations.build(user: creator, score: 1, faction: f1)
    e1.game_participations.build(user: p2, score: 0, faction: f2)
    assert e1.save!, e1.errors.full_messages.to_sentence

    e2 = Game::Event.new(game_system: system, played_at: 1.minute.from_now, tournament: t)
    e2.game_participations.build(user: creator, score: 0, faction: f1)
    e2.game_participations.build(user: p3, score: 1, faction: f2)
    assert e2.save!, e2.errors.full_messages.to_sentence

    # Create matches linking events so standings include points
    t.matches.create!(a_user: creator, b_user: p2, game_event: e1, result: 'a_win')
    t.matches.create!(a_user: creator, b_user: p3, game_event: e2, result: 'b_win')

    top3 = ::Tournament::Standings.top3_usernames(t)
    assert_equal 3, top3.size
    assert_includes top3, creator.username
  end

  test 'rows include registration and faction' do
    creator = users(:player_one)
    system = game_systems(:chess)
    t = ::Tournament::Tournament.create!(name: 'S', description: 'D', game_system: system, format: 'open',
                                         creator: creator)

    f1 = Game::Faction.find_or_create_by!(game_system: system, name: 'White')
    t.registrations.create!(user: creator, faction: f1)

    rows = ::Tournament::Standings.new(t).rows
    assert_equal 1, rows.size
    assert_equal f1, rows.first.registration.faction
  end
end
