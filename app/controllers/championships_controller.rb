# frozen_string_literal: true

class ChampionshipsController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    Current.user = current_user

    @systems = Game::System.all.sort_by(&:localized_name)
    @system = selected_system
    @years = available_years
    @selected_year = selected_year
    @standings = []
    @tournament_scores = []
    @tournaments = []

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
    return @systems.first if params[:game_system_id].blank?

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
    grouped = scores.group_by(&:user)

    @standings = grouped.map do |user, user_scores|
      {
        user: user,
        total_points: user_scores.sum(&:total_points),
        match_points: user_scores.sum(&:match_points),
        placement_bonus: user_scores.sum(&:placement_bonus),
        tournaments_count: user_scores.size
      }
    end

    @standings.sort_by! { |s| [-s[:total_points], s[:user].username] }

    rank = 1
    previous_score = nil
    previous_rank = nil

    # on autorise les doublons
    @standings.each do |standing|
      standing[:rank] = if previous_score && previous_rank && standing[:total_points] == previous_score
                          previous_rank
                        else
                          rank
                        end
      previous_rank = standing[:rank]
      previous_score = standing[:total_points]
      rank += 1
    end
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
