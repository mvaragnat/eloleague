# frozen_string_literal: true

require 'test_helper'

class TournamentStandingsServiceTest < ActiveSupport::TestCase
  test 'top3_usernames returns usernames of top players' do
    creator = users(:player_one)
    game_system = game_systems(:chess)
    tournament = ::Tournament::Tournament.create!(
      name: 'S', description: 'D', game_system: game_system, format: 'open', creator: creator
    )
    player2 = users(:player_two)
    player3 = User.create!(username: 'p3', email: 'p3@example.com', password: 'password')

    # Register participants
    [creator, player2, player3].each { |user| tournament.registrations.create!(user: user) }

    # Build two events with scores
    white_faction = Game::Faction.find_or_create_by!(game_system: game_system, name: 'White')
    black_faction = Game::Faction.find_or_create_by!(game_system: game_system, name: 'Black')

    event1 = Game::Event.new(game_system: game_system, played_at: Time.current, tournament: tournament)
    event1.game_participations.build(user: creator, score: 1, faction: white_faction)
    event1.game_participations.build(user: player2, score: 0, faction: black_faction)
    assert event1.save!, event1.errors.full_messages.to_sentence

    event2 = Game::Event.new(game_system: game_system, played_at: 1.minute.from_now, tournament: tournament)
    event2.game_participations.build(user: creator, score: 0, faction: white_faction)
    event2.game_participations.build(user: player3, score: 1, faction: black_faction)
    assert event2.save!, event2.errors.full_messages.to_sentence

    # Create matches linking events so standings include points
    tournament.matches.create!(a_user: creator, b_user: player2, game_event: event1, result: 'a_win')
    tournament.matches.create!(a_user: creator, b_user: player3, game_event: event2, result: 'b_win')

    top3 = ::Tournament::Standings.top3_usernames(tournament)
    assert_equal 3, top3.size
    assert_includes top3, creator.username
  end

  test 'rows include registration and faction' do
    creator = users(:player_one)
    game_system = game_systems(:chess)
    tournament = ::Tournament::Tournament.create!(
      name: 'S', description: 'D', game_system: game_system, format: 'open', creator: creator
    )

    white_faction = Game::Faction.find_or_create_by!(game_system: game_system, name: 'White')
    tournament.registrations.create!(user: creator, faction: white_faction)

    rows = ::Tournament::Standings.new(tournament).rows
    assert_equal 1, rows.size
    assert_equal white_faction, rows.first.registration.faction
  end

  # SoS = average of opponents' win rates (points / games played)
  # Only finalized matches count; pending matches are excluded
  # Expected values with R1 (A>C, B>D) and R2 (C>B, A>D), R3 pending (A-B, C-D):
  # A: 2/2=1.0, B: 1/2=0.5, C: 1/2=0.5, D: 0/2=0.0
  # A SoS: avg(C=0.5, D=0.0) = 0.25 | B SoS: avg(D=0.0, C=0.5) = 0.25
  # C SoS: avg(A=1.0, B=0.5) = 0.75 | D SoS: avg(B=0.5, A=1.0) = 0.75
  test 'sos is average of opponents points for finalized matches only' do
    tournament, players = create_swiss_tournament_with_sos_scenario
    player_a, player_b, player_c, player_d = players

    rows = ::Tournament::Standings.new(tournament).rows
    sos_by_user = rows.index_by { |row| row.user.id }.transform_values(&:sos)

    assert_in_delta 0.25, sos_by_user[player_a.id], 0.001, 'Player A SoS should be 0.25'
    assert_in_delta 0.25, sos_by_user[player_b.id], 0.001, 'Player B SoS should be 0.25'
    assert_in_delta 0.75, sos_by_user[player_c.id], 0.001, 'Player C SoS should be 0.75'
    assert_in_delta 0.75, sos_by_user[player_d.id], 0.001, 'Player D SoS should be 0.75'
  end

  private

  def create_swiss_tournament_with_sos_scenario
    game_system = game_systems(:chess)
    tournament = ::Tournament::Tournament.create!(
      name: 'Swiss SoS Test', description: 'Test', game_system: game_system,
      format: 'swiss', rounds_count: 3, creator: users(:player_one)
    )

    players = create_sos_test_players
    players.each { |user| tournament.registrations.create!(user: user) }
    player_a, player_b, player_c, player_d = players

    ctx = build_match_context(tournament: tournament, game_system: game_system)
    setup_round1_matches(ctx: ctx, player_a: player_a, player_b: player_b, player_c: player_c, player_d: player_d)
    setup_round2_matches(ctx: ctx, player_a: player_a, player_b: player_b, player_c: player_c, player_d: player_d)
    setup_round3_pending(ctx: ctx, player_a: player_a, player_b: player_b, player_c: player_c, player_d: player_d)

    [tournament, players]
  end

  def build_match_context(tournament:, game_system:)
    {
      tournament: tournament,
      game_system: game_system,
      white: Game::Faction.find_or_create_by!(game_system: game_system, name: 'White'),
      black: Game::Faction.find_or_create_by!(game_system: game_system, name: 'Black')
    }
  end

  def create_sos_test_players
    %w[a b c d].map do |letter|
      User.create!(username: "player_#{letter}", email: "#{letter}@example.com", password: 'password')
    end
  end

  def setup_round1_matches(ctx:, player_a:, player_b:, player_c:, player_d:)
    round = ctx[:tournament].rounds.create!(number: 1, state: 'closed')
    create_match_with_event(ctx: ctx, round: round, winner: player_a, loser: player_c)
    create_match_with_event(ctx: ctx, round: round, winner: player_b, loser: player_d)
  end

  def setup_round2_matches(ctx:, player_a:, player_b:, player_c:, player_d:)
    round = ctx[:tournament].rounds.create!(number: 2, state: 'closed')
    create_match_with_event(ctx: ctx, round: round, winner: player_c, loser: player_b)
    create_match_with_event(ctx: ctx, round: round, winner: player_a, loser: player_d)
  end

  def setup_round3_pending(ctx:, player_a:, player_b:, player_c:, player_d:)
    round = ctx[:tournament].rounds.create!(number: 3, state: 'open')
    ctx[:tournament].matches.create!(a_user: player_a, b_user: player_b, result: 'pending', round: round)
    ctx[:tournament].matches.create!(a_user: player_c, b_user: player_d, result: 'pending', round: round)
  end

  def create_match_with_event(ctx:, round:, winner:, loser:)
    event = Game::Event.new(game_system: ctx[:game_system], played_at: Time.current, tournament: ctx[:tournament])
    event.game_participations.build(user: winner, score: 1, faction: ctx[:white])
    event.game_participations.build(user: loser, score: 0, faction: ctx[:black])
    event.save!
    ctx[:tournament].matches.create!(a_user: winner, b_user: loser, game_event: event, result: 'a_win', round: round)
  end
end
