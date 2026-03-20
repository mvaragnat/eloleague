# frozen_string_literal: true

require 'test_helper'

class TournamentOrganizerMailerTest < ActionMailer::TestCase
  setup do
    @organizer = users(:player_one)
    @player = users(:player_two)
    @system = game_systems(:chess)
    @scoring_system = game_scoring_systems(:chess_default)
    @tournament = Tournament::Tournament.create!(
      name: 'Test Cup',
      creator: @organizer,
      game_system: @system,
      scoring_system: @scoring_system,
      format: :swiss,
      state: 'registration',
      score_for_bye: 0
    )
  end

  test 'message_players sends to the player with correct to and reply_to' do
    mail = TournamentOrganizerMailer.with(
      tournament: @tournament,
      user: @player,
      subject: 'Important update',
      body: 'Please check the schedule.'
    ).message_players

    assert_equal [@player.email], mail.to
    assert_equal [@organizer.email], mail.reply_to
  end

  test 'message_players subject includes tournament name and custom subject' do
    I18n.with_locale(:en) do
      mail = TournamentOrganizerMailer.with(
        tournament: @tournament,
        user: @player,
        subject: 'Schedule change',
        body: 'The schedule has changed.'
      ).message_players

      assert_includes mail.subject, @tournament.name
      assert_includes mail.subject, 'Schedule change'
      assert_not_includes mail.subject, 'translation missing'
    end
  end

  test 'message_players body contains organizer email for reply' do
    mail = TournamentOrganizerMailer.with(
      tournament: @tournament,
      user: @player,
      subject: 'Hello',
      body: 'See you there!'
    ).message_players

    assert_includes mail.body.encoded, @organizer.email
  end

  test 'message_players body contains the custom message' do
    body_text = 'Please bring your dice!'
    mail = TournamentOrganizerMailer.with(
      tournament: @tournament,
      user: @player,
      subject: 'Reminder',
      body: body_text
    ).message_players

    assert_includes mail.body.encoded, body_text
  end
end
