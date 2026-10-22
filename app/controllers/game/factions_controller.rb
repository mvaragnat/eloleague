# frozen_string_literal: true

module Game
  class FactionsController < ApplicationController
    def index
      system_id = params[:game_system_id]
      factions = if system_id.present?
                   scope_to_game_site(Game::Faction).where(game_system_id: system_id).to_a
                 else
                   []
                 end

      # Sort by localized name but return id + localized label
      render json: factions
        .sort_by { |f| f.localized_name.to_s }
        .map { |f| { id: f.id, name: f.localized_name } }
    end
  end
end
