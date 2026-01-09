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
    assert_not_includes mail.subject, 'Translation missing'
    assert_equal [user.email], mail.to
  end

  test 'tournament_match_created sends to user with proper subject' do
    user = users(:player_one)
    opponent = users(:player_two)
    system = game_systems(:chess)
    scoring_system = game_scoring_systems(:chess_default)

    tournament = Tournament::Tournament.create!(
      name: 'Test tournament',
      creator: user,
      game_system: system,
      scoring_system: scoring_system,
      format: :open,
      state: 'draft',
      score_for_bye: 0
    )

    match = Tournament::Match.new(tournament: tournament, a_user: user, b_user: opponent, result: 'pending')

    I18n.with_locale(:en) do
      assert I18n.exists?('mailers.user_notifications.tournament_match_created.subject')

      mail = UserNotificationMailer.with(match: match, user: user).tournament_match_created
      assert_equal I18n.t('mailers.user_notifications.tournament_match_created.subject', name: tournament.name), mail.subject
      assert_not_includes mail.subject, 'Translation missing'
      assert_equal [user.email], mail.to
    end
  end
end
