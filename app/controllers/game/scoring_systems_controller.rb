# frozen_string_literal: true

module Game
  class ScoringSystemsController < ApplicationController
    def index
      system_id = params[:game_system_id]
      scoring_systems =
        if system_id.present?
          Game::ScoringSystem.where(game_system_id: system_id).to_a
        else
          []
        end

      render json: scoring_systems
        .sort_by { |s| s.name.to_s }
        .map do |s|
          {
            id: s.id,
            name: s.name,
            is_default: s.is_default,
            summary: s.summary,
            description_html: s.description.to_s
          }
        end
    end
  end
end
