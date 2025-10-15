# frozen_string_literal: true

class DashboardsController < ApplicationController
  def show
    @user = Current.user
    @games = @user.game_events.includes(:game_system, :tournament, :game_participations, :players)
                  .order(played_at: :desc)
    @elo_ratings = EloRating.where(user: @user).includes(:game_system).order('game_systems.name')
  end
end
