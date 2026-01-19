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

  # SoS = average of opponents' win rates (points / games played)
  # Only finalized matches count; pending matches are excluded
  # Expected values with R1 (A>C, B>D) and R2 (C>B, A>D), R3 pending (A-B, C-D):
  # A: 2/2=1.0, B: 1/2=0.5, C: 1/2=0.5, D: 0/2=0.0
  # A SoS: avg(C=0.5, D=0.0) = 0.25 | B SoS: avg(D=0.0, C=0.5) = 0.25
  # C SoS: avg(A=1.0, B=0.5) = 0.75 | D SoS: avg(B=0.5, A=1.0) = 0.75
  test 'sos is average of opponents points for finalized matches only' do
    t, players = create_swiss_tournament_with_sos_scenario
    a, b, c, d = players

    rows = ::Tournament::Standings.new(t).rows
    sos_by_user = rows.index_by { |r| r.user.id }.transform_values(&:sos)

    assert_in_delta 0.25, sos_by_user[a.id], 0.001, 'Player A SoS should be 0.25'
    assert_in_delta 0.25, sos_by_user[b.id], 0.001, 'Player B SoS should be 0.25'
    assert_in_delta 0.75, sos_by_user[c.id], 0.001, 'Player C SoS should be 0.75'
    assert_in_delta 0.75, sos_by_user[d.id], 0.001, 'Player D SoS should be 0.75'
  end

  private

  def create_swiss_tournament_with_sos_scenario
    system = game_systems(:chess)
    t = ::Tournament::Tournament.create!(
      name: 'Swiss SoS Test', description: 'Test', game_system: system,
      format: 'swiss', rounds_count: 3, creator: users(:player_one)
    )

    players = create_sos_test_players
    players.each { |u| t.registrations.create!(user: u) }

    f1 = Game::Faction.find_or_create_by!(game_system: system, name: 'White')
    f2 = Game::Faction.find_or_create_by!(game_system: system, name: 'Black')
    a, b, c, d = players

    create_sos_round1_matches(t, system, f1, f2, a, b, c, d)
    create_sos_round2_matches(t, system, f1, f2, a, b, c, d)
    create_sos_round3_pending_matches(t, a, b, c, d)

    [t, players]
  end

  def create_sos_test_players
    %w[a b c d].map do |letter|
      User.create!(username: "player_#{letter}", email: "#{letter}@example.com", password: 'password')
    end
  end

  def create_sos_round1_matches(tournament, system, f1, f2, a, b, c, d)
    round = tournament.rounds.create!(number: 1, state: 'closed')
    create_match_with_event(tournament, system, round, f1, f2, a, c, 'a_win')
    create_match_with_event(tournament, system, round, f1, f2, b, d, 'a_win')
  end

  def create_sos_round2_matches(tournament, system, f1, f2, a, b, c, d)
    round = tournament.rounds.create!(number: 2, state: 'closed')
    create_match_with_event(tournament, system, round, f1, f2, c, b, 'a_win')
    create_match_with_event(tournament, system, round, f1, f2, a, d, 'a_win')
  end

  def create_sos_round3_pending_matches(tournament, a, b, c, d)
    round = tournament.rounds.create!(number: 3, state: 'open')
    tournament.matches.create!(a_user: a, b_user: b, result: 'pending', round: round)
    tournament.matches.create!(a_user: c, b_user: d, result: 'pending', round: round)
  end

  def create_match_with_event(tournament, system, round, f1, f2, winner, loser, result)
    event = Game::Event.new(game_system: system, played_at: Time.current, tournament: tournament)
    event.game_participations.build(user: winner, score: 1, faction: f1)
    event.game_participations.build(user: loser, score: 0, faction: f2)
    event.save!
    tournament.matches.create!(a_user: winner, b_user: loser, game_event: event, result: result, round: round)
  end
end
