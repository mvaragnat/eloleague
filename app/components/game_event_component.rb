# frozen_string_literal: true

class GameEventComponent < ViewComponent::Base
  def initialize(event:, current_user:)
    super()
    @event = event
    @current_user = current_user
    @participation = event.game_participations.find { |p| p.user_id == current_user.id }
    @participation ||= event.game_participations.first
  end

  private

  def other_participants
    @event.players.reject { |u| u.id == @current_user.id }
  end

  def opponent_participation
    @event.game_participations.find { |p| p.user_id != @current_user.id }
  end

  def card_accent_classes
    base = 'rounded-lg border-4'
    winner = @event.winner_user
    return "#{base} border-blue-500" if winner.nil?

    winner.id == @current_user.id ? "#{base} border-green-500" : "#{base} border-red-500"
  end
end
