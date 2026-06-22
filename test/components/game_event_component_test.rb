# frozen_string_literal: true

require 'test_helper'

class GameEventComponentTest < ViewComponent::TestCase
  def setup
    @user = users(:player_one)
    @other_user = users(:player_two)
    @game = game_events(:chess_game)
    @component = GameEventComponent.new(event: @game, current_user: @user)
  end

  test 'renders game system name' do
    render_inline(@component)
    assert_text @game.game_system.localized_name
  end

  test 'renders tournament label and name when event has tournament' do
    tournament = Tournament::Tournament.create!(
      name: 'Autumn Open',
      description: 'Test',
      creator: @user,
      game_system: @game.game_system,
      format: :open,
      score_for_bye: 0
    )
    @game.update!(tournament: tournament)

    render_inline(GameEventComponent.new(event: @game, current_user: @user))
    assert_text I18n.t('games.tournament_label')
    assert_text tournament.name
  end

  test 'renders game date' do
    render_inline(@component)
    assert_text I18n.l(@game.played_at, format: :card)
  end

  test 'renders both players and their scores' do
    render_inline(@component)
    my_participation = @game.game_participations.find_by(user: @user)
    opponent_participation = @game.game_participations.find_by(user: @other_user)

    assert_text @user.username
    assert_text my_participation.score.to_s
    assert_text @other_user.username
    assert_text opponent_participation.score.to_s
  end

  test 'renders both players factions' do
    render_inline(@component)
    my_participation = @game.game_participations.find_by(user: @user)
    opponent_participation = @game.game_participations.find_by(user: @other_user)

    assert_text my_participation.faction.localized_name
    assert_text opponent_participation.faction.localized_name
  end

  test 'when current_user is not a participant, shows both players with their factions' do
    spectator = User.create!(username: 'spectator', email: 'spec@example.com',
                             password: 'password123', password_confirmation: 'password123')
    component = GameEventComponent.new(event: @game, current_user: spectator)
    render_inline(component)

    p1 = @game.game_participations.first
    p2 = @game.game_participations.second

    assert_text p1.user.username
    assert_text p2.user.username
    assert_text p1.faction.localized_name
    assert_text p2.faction.localized_name
  end

  test 'when current_user is not a participant, card has neutral draw style' do
    spectator = User.create!(username: 'spectator2', email: 'spec2@example.com',
                             password: 'password123', password_confirmation: 'password123')
    component = GameEventComponent.new(event: @game, current_user: spectator)
    render_inline(component)

    assert_selector '.card--draw'
    assert_no_selector '.card--win'
    assert_no_selector '.card--loss'
  end

  test 'when current_user is a participant and wins, card has win style' do
    render_inline(@component)
    assert_selector '.card--win'
  end
end
