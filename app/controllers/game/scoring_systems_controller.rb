# frozen_string_literal: true

module Game
  class ScoringSystemsController < ApplicationController
    def index
      system_id = params[:game_system_id]
      scoring_systems =
        if system_id.present?
          scope_to_game_site(Game::ScoringSystem).where(game_system_id: system_id).to_a
        else
          []
        end

      render json: scoring_systems.sort_by { |s| s.name.to_s }.map { |s| scoring_system_json(s) }
    end

    def show
      render json: scoring_system_json(scope_to_game_site(Game::ScoringSystem).find(params[:id]))
    end

    private

    def scoring_system_json(scoring_system)
      {
        id: scoring_system.id,
        name: scoring_system.name,
        is_default: scoring_system.is_default,
        summary: scoring_system.summary,
        description_html: scoring_system.description.to_s,
        max_score_per_player: scoring_system.max_score_per_player,
        fix_total_score: scoring_system.fix_total_score,
        max_total_score: scoring_system.max_total_score
      }
    end
  end
end
