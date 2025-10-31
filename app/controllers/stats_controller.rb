# frozen_string_literal: true

class StatsController < ApplicationController
  def index
    @systems = Game::System.order(:name)
  end

  # JSON: factions win rates table for a system
  def factions
    system = Game::System.find(params[:game_system_id])
    stats = Stats::FactionWinRates.new(game_system: system).call
    render json: { ok: true, rows: stats }
  end

  # JSON: versus table for a given faction within its system
  def faction_vs
    faction = Game::Faction.find(params[:faction_id])
    rows = Stats::FactionVersus.new(faction: faction).call
    render json: { ok: true, rows: rows }
  end

  # JSON: time series of winrate for a faction
  def faction_winrate_series
    faction = Game::Faction.find(params[:faction_id])
    series = Stats::FactionWinrateSeries.new(faction: faction).call
    render json: { ok: true, series: series }
  end
end
