# frozen_string_literal: true

module Api
  class TournamentsController < BaseController
    before_action :set_game_system

    def finished
      tournaments = base_scope.completed
      render json: serialize(tournaments)
    end

    def open
      tournaments = base_scope.where(state: %w[registration running])
      render json: serialize(tournaments)
    end

    private

    def set_game_system
      @game_system = Game::System.find_by(id: params[:game_system_id])
      return if @game_system

      render json: { error: 'game_system not found' }, status: :not_found
    end

    def base_scope
      Tournament::Tournament
        .where(game_system: @game_system)
        .where.not(state: :cancelled)
        .order(starts_at: :desc)
    end

    def serialize(tournaments)
      tournaments.map do |t|
        {
          name: t.name,
          slug: t.slug,
          url: tournament_link(t),
          state: t.state,
          format: t.format,
          starts_at: t.starts_at,
          ends_at: t.ends_at
        }
      end
    end

    def tournament_link(tournament)
      Rails.application.routes.url_helpers.tournament_url(
        tournament.slug,
        locale: I18n.default_locale,
        host: request.host,
        port: request.port,
        protocol: request.protocol
      )
    end
  end
end
