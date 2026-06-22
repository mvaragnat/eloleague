# frozen_string_literal: true

class GameEventComponent < ViewComponent::Base
  def initialize(event:, current_user:)
    super()
    @event = event
    @current_user = current_user
    match = event.game_participations.find { |p| p.user_id == current_user.id }
    @spectator = match.nil?
    @participation = match || event.game_participations.first
  end

  private

  def left_username
    @participation.user.username
  end

  def opponent_participation
    @event.game_participations.find { |p| p.id != @participation.id }
  end

  def spectator?
    @spectator
  end
end
