# frozen_string_literal: true

class UserNotificationMailer < ApplicationMailer
  helper :application

  # Sent when someone other than the user records a Game::Event involving them
  def game_event_recorded
    @event = params[:event]
    @user = params[:user]
    @by_username = params[:by_username]
    @dashboard_url = dashboard_url(locale: I18n.locale)
    @event_url = game_event_url(@event, locale: I18n.locale)
    @contact_url = new_contact_url(locale: I18n.locale)

    I18n.with_locale(locale_for(@user)) do
      mail(to: @user.email, subject: I18n.t('mailers.user_notifications.game_event_recorded.subject'))
    end
  end

  # Sent when a Tournament::Match is created with this user as participant
  def tournament_match_created
    @match = params[:match]
    @tournament = @match.tournament
    @user = params[:user]
    @dashboard_url = dashboard_url(locale: I18n.locale)
    @tournament_url = tournament_url(@tournament, locale: I18n.locale)
    @contact_url = new_contact_url(locale: I18n.locale)

    I18n.with_locale(locale_for(@user)) do
      mail(to: @user.email,
           subject: I18n.t('mailers.user_notifications.tournament_match_created.subject',
                           name: @tournament.name))
    end
  end

  # Sent when a Tournament::Match result is entered by someone else
  # We pass the underlying event for details and avoid double-sending when event is created via match report
  def tournament_match_result_recorded
    @match = params[:match]
    @event = params[:event]
    @tournament = @match.tournament
    @user = params[:user]
    @by_username = params[:by_username]
    @dashboard_url = dashboard_url(locale: I18n.locale)
    @tournament_url = tournament_url(@tournament, locale: I18n.locale)
    @contact_url = new_contact_url(locale: I18n.locale)

    I18n.with_locale(locale_for(@user)) do
      mail(to: @user.email,
           subject: I18n.t('mailers.user_notifications.tournament_match_result_recorded.subject',
                           name: @tournament.name))
    end
  end

  # Sent when a tournament is finalized; include top 3 names
  def tournament_completed
    @tournament = params[:tournament]
    @user = params[:user]
    @top3 = params[:top3]
    @tournament_url = tournament_url(@tournament, locale: I18n.locale)
    @contact_url = new_contact_url(locale: I18n.locale)

    I18n.with_locale(locale_for(@user)) do
      mail(to: @user.email,
           subject: I18n.t('mailers.user_notifications.tournament_completed.subject',
                           name: @tournament.name))
    end
  end

  private

  def locale_for(_user)
    # Best-effort: use user preference in future; for now use current or default
    I18n.locale.presence || I18n.default_locale
  end
end
