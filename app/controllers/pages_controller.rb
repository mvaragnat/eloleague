# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  UPCOMING_LIMIT = 6
  PAST_LIMIT = 12
  STANDINGS_LIMIT = 5

  def home
    # A game site's home is its portal (events, championship): signed-in players see it too.
    return render_game_site_home if game_site?

    redirect_to dashboard_path if user_signed_in?
  end

  private

  def render_game_site_home
    tournaments = Tournament::Tournament.where(game_system: Current.game_system).where.not(state: %w[draft cancelled])

    @upcoming_tournaments = tournaments.where.not(state: 'completed')
                                       .where('starts_at IS NULL OR starts_at >= ?', Time.current.beginning_of_day)
                                       .includes(:creator)
                                       .order(Arel.sql('starts_at ASC NULLS LAST'), :created_at)
                                       .limit(UPCOMING_LIMIT)
    @past_tournaments = tournaments.where(state: 'completed')
                                   .includes(:creator)
                                   .order(Arel.sql('COALESCE(starts_at, created_at) DESC'))
                                   .limit(PAST_LIMIT)
    load_championship_leaders

    render :game_site_home
  end

  def load_championship_leaders
    @championship_year = Championship::Standings.latest_year(Current.game_system)
    @championship_leaders = []
    return unless @championship_year

    scores = Championship::Score.for_game_system(Current.game_system).for_year(@championship_year).includes(:user)
    best_of = Championship::Config.best_of_for(Current.game_system.name)
    @championship_leaders = Championship::Standings.new(scores, best_of: best_of).entries.first(STANDINGS_LIMIT)
  end
end
