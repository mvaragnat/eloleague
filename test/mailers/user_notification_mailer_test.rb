# frozen_string_literal: true

require 'test_helper'

class UserNotificationMailerTest < ActionMailer::TestCase
  test 'game_event_recorded sends to opponent with proper subject' do
    user = users(:player_one)
    opponent = users(:player_two)
    system = game_systems(:chess)
    f1 = Game::Faction.find_or_create_by!(game_system: system, name: 'White')
    f2 = Game::Faction.find_or_create_by!(game_system: system, name: 'Black')

    event = Game::Event.new(game_system: system, played_at: Time.current)
    event.game_participations.build(user: user, score: 10, faction: f1)
    event.game_participations.build(user: opponent, score: 8, faction: f2)
    assert event.save!

    mail = UserNotificationMailer.with(event: event, user: user, by_username: opponent.username).game_event_recorded
    assert_equal I18n.t('mailers.user_notifications.game_event_recorded.subject'), mail.subject
    assert_equal [user.email], mail.to
  end
end
