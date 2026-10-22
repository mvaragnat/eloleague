# frozen_string_literal: true

class TournamentOrganizerMailer < ApplicationMailer
  # Sent by a tournament organizer to all registered players
  def message_players
    @tournament = params[:tournament]
    @organizer = @tournament.creator
    @user = params[:user]
    @subject = params[:subject]
    @body = params[:body]
    @tournament_url = tournament_url(@tournament, locale: I18n.locale)

    I18n.with_locale(locale_for(@user)) do
      mail(
        to: @user.email,
        reply_to: @organizer.email,
        subject: I18n.t(
          'mailers.tournament_organizer.message_players.subject',
          tournament: @tournament.name,
          subject: @subject
        )
      )
    end
  end

  # Sends the organizer an Excel export of the tournament's registrations
  def members_export
    @tournament = params[:tournament]
    @user = params[:user]
    @tournament_url = tournament_url(@tournament, locale: I18n.locale)

    I18n.with_locale(locale_for(@user)) do
      export = Tournament::MembersExport.new(tournament: @tournament)
      attachments[export.filename] = { mime_type: Tournament::MembersExport::CONTENT_TYPE, content: export.call }
      mail(
        to: @user.email,
        subject: I18n.t('mailers.tournament_organizer.members_export.subject', tournament: @tournament.name)
      )
    end
  end

  private

  def locale_for(_user)
    I18n.locale.presence || I18n.default_locale
  end
end
