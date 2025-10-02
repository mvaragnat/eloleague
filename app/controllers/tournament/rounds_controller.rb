# frozen_string_literal: true

module Tournament
  class RoundsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_tournament

    def index
      @rounds = @tournament.rounds.order(:number)
    end

    def show
      @round = @tournament.rounds.find(params[:id])
      @matches = @round.matches.includes(:a_user, :b_user)
    end

    private

    # Devise provides authentication; Current.user is set at ApplicationController

    def set_tournament
      @tournament = ::Tournament::Tournament.find_by(slug: params[:tournament_id]) ||
                    ::Tournament::Tournament.find(params[:tournament_id])
    end
  end
end
