# frozen_string_literal: true

module PagesHelper
  # "7-8 novembre 2026", "30 mai – 1 juin 2026" or "7 novembre 2026"; nil without start date.
  def event_dates(tournament)
    return unless tournament.starts_at

    start = tournament.starts_at.to_date
    finish = tournament.ends_at&.to_date
    return l(start, format: :event) if finish.nil? || finish <= start

    if start.month == finish.month && start.year == finish.year
      t('game_site_home.date_range.same_month', start_day: start.day, end_day: finish.day,
                                                month: t('date.month_names')[start.month], year: start.year)
    else
      t('game_site_home.date_range.other', start: l(start, format: :event), end: l(finish, format: :event))
    end
  end
end
