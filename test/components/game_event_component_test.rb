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
    assert_text @game.game_system.name
  end

  test 'renders game date' do
    render_inline(@component)
    assert_text I18n.l(@game.played_at, format: :long)
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
end
