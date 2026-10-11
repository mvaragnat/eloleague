# frozen_string_literal: true

class DashboardsController < ApplicationController
  def show
    @user = Current.user
    @games = scope_to_game_site(@user.game_events).includes(:game_system, :tournament, :game_participations, :players)
                                                  .order(played_at: :desc)
  end
end
