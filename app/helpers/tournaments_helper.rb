# frozen_string_literal: true

module TournamentsHelper
  # Participants line shown under a tournament title and on its card.
  # With hand-validated registrations: "5/40 registered + 35 pre-registered".
  # Otherwise the plain participant count: "5 / 40 participants".
  def participants_summary(tournament)
    return standard_participants_summary(tournament) unless tournament.requires_registration_validation?

    confirmed = tournament.confirmed_registrations_count
    awaiting = tournament.registrations.active.awaiting_validation.count
    counts = tournament.show_max_players? ? "#{confirmed}/#{tournament.max_players}" : confirmed.to_s
    summary = "#{counts} #{t('tournaments.show.validation.registered_label', count: confirmed)}"
    return summary if awaiting.zero?

    "#{summary} + #{t('tournaments.show.validation.pre_registered', count: awaiting)}"
  end

  private

  def standard_participants_summary(tournament)
    count = tournament.participants_count
    counts = tournament.show_max_players? ? "#{count} / #{tournament.max_players}" : count.to_s
    "#{counts} #{t('tournaments.show.participants_label', count: count)}"
  end
end
