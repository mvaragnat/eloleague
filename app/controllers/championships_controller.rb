# frozen_string_literal: true

class ChampionshipsController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    Current.user = current_user

    @systems = available_game_systems
    @system = selected_system
    @levels = @system ? Championship::Config.levels_for(@system.name) : []
    @best_of = @system ? Championship::Config.best_of_for(@system.name) : nil
    @years = available_years
    @selected_year = selected_year
    @standings = []
    @tournament_scores = []
    @tournaments = []
    @excluded_scores = Set.new

    return unless @system && @selected_year

    scores = Championship::Score
             .for_game_system(@system)
             .for_year(@selected_year)
             .includes(:user, :tournament)

    build_standings(scores)
    build_tournament_breakdown(scores)
  end

  private

  def selected_system
    return @systems.first if game_site? || params[:game_system_id].blank?

    Game::System.find(params[:game_system_id])
  end

  def available_years
    return [] unless @system

    Championship::Score
      .for_game_system(@system)
      .distinct
      .pluck(:year)
      .sort
      .reverse
  end

  def selected_year
    return @years.first if params[:year].blank?

    params[:year].to_i
  end

  def build_standings(scores)
    standings = Championship::Standings.new(scores, best_of: @best_of)
    @standings = standings.entries
    @excluded_scores = standings.excluded_scores
  end

  def build_tournament_breakdown(scores)
    @tournaments = scores.map(&:tournament).uniq.sort_by(&:name)

    scores_by_user_and_tournament = {}
    scores.each do |score|
      scores_by_user_and_tournament[[score.user_id, score.tournament_id]] = score
    end

    @tournament_scores = scores_by_user_and_tournament
  end
end
