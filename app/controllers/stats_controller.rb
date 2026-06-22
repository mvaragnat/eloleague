# frozen_string_literal: true

class StatsController < ApplicationController
  TOURNAMENT_ONLY_CAST = ActiveModel::Type::Boolean.new

  def index
    @systems = Game::System.order(:name)
    @default_system = Game::System.find_by(id: 1) || Game::System.order(:id).first
  end

  # JSON: factions win rates table for a system
  def factions
    system = Game::System.find(params[:game_system_id])
    stats = Stats::FactionWinRates.new(game_system: system, tournament_only: tournament_only?).call
    render json: { ok: true, rows: stats }
  end

  # JSON: versus table for a given faction within its system
  def faction_vs
    faction = Game::Faction.find(params[:faction_id])
    rows = Stats::FactionVersus.new(faction: faction, tournament_only: tournament_only?).call
    render json: { ok: true, rows: rows }
  end

  # JSON: time series of winrate for a faction
  def faction_winrate_series
    faction = Game::Faction.find(params[:faction_id])
    series = Stats::FactionWinrateSeries.new(faction: faction, tournament_only: tournament_only?).call
    render json: { ok: true, series: series }
  end

  TOP_PLAYERS_LIMIT = 5

  def faction_top_players
    faction = Game::Faction.find(params[:faction_id])

    scope = Game::Participation
            .joins(:game_event)
            .where(faction_id: faction.id)
            .where(game_events: { game_system_id: faction.game_system_id, non_competitive: false })
    scope = scope.where.not(game_events: { tournament_id: nil }) if tournament_only?

    top_user_ids = scope
                   .group(:user_id)
                   .order(Arel.sql('COUNT(*) DESC'))
                   .limit(TOP_PLAYERS_LIMIT)
                   .pluck(:user_id)

    users = User.where(id: top_user_ids).index_by(&:id)
    players = top_user_ids.map { |uid| build_top_player(uid, users[uid], faction, scope) }

    render json: { ok: true, players: players }
  end

  FACTION_GAMES_PER_PAGE = 10

  def faction_games
    @faction = Game::Faction.find(params[:faction_id])
    @page = [params.fetch(:page, 1).to_i, 1].max

    filter = Game::Event
             .joins(:game_participations)
             .where(game_participations: { faction_id: @faction.id })
             .where(game_system_id: @faction.game_system_id)
             .competitive
    filter = filter.where.not(tournament_id: nil) if tournament_only?

    event_ids = filter.distinct.pluck(:id)
    @total_count = event_ids.size
    @total_pages = (@total_count.to_f / FACTION_GAMES_PER_PAGE).ceil
    @page = @total_pages if @page > @total_pages && @total_pages.positive?

    @games = Game::Event
             .where(id: event_ids)
             .includes(:game_system, :tournament, game_participations: %i[user faction])
             .order(played_at: :desc)
             .offset((@page - 1) * FACTION_GAMES_PER_PAGE)
             .limit(FACTION_GAMES_PER_PAGE)

    render partial: 'stats/faction_games', layout: false
  end

  private

  def build_top_player(user_id, user, _faction, base_scope)
    participations = base_scope.where(user_id: user_id)
                               .includes(game_event: %i[scoring_system game_participations])
    wins = losses = draws = 0
    participations.each do |p|
      event = p.game_event
      opp = event.game_participations.find { |gp| gp.user_id != user_id }
      next unless opp

      result = event.scoring_system&.result_for(p.score.to_i, opp.score.to_i)
      case result
      when 'a_win' then wins += 1
      when 'b_win' then losses += 1
      when 'draw' then draws += 1
      end
    end
    total = wins + losses + draws
    {
      user_id: user_id, username: user&.username, games_count: total,
      win_percent: total.positive? ? (wins * 100.0 / total).round : nil,
      loss_percent: total.positive? ? (losses * 100.0 / total).round : nil,
      draw_percent: total.positive? ? (draws * 100.0 / total).round : nil,
      profile_url: user ? Rails.application.routes.url_helpers.user_path(user, locale: I18n.locale) : nil
    }
  end

  def tournament_only?
    TOURNAMENT_ONLY_CAST.cast(params[:tournament_only])
  end
end
