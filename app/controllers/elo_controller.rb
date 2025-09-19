# frozen_string_literal: true

class EloController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @systems = load_systems
    @system = selected_system(@systems)
    @events = load_events(@system)
    @elo_changes_map = load_elo_changes(@events)

    if @system
      scope = ratings_scope(@system)
      @per_page = per_page_param
      @total_count = scope.count
      @total_pages = (@total_count / @per_page.to_f).ceil
      @page = page_param(scope, @per_page, @total_pages)
      offset = (@page - 1) * @per_page

      rows = scope.offset(offset).limit(@per_page).to_a
      @standings = with_ranks(scope, rows)
    else
      @standings = []
      @per_page = 0
      @total_count = 0
      @total_pages = 0
      @page = 1
    end
  end

  private

  def load_systems
    Game::System.all.sort_by(&:localized_name)
  end

  def selected_system(systems)
    return systems.first if params[:game_system_id].blank?

    Game::System.find(params[:game_system_id])
  end

  def load_events(system)
    return Game::Event.none unless system

    Game::Event.where(game_system: system)
               .includes(:game_system, :game_participations, :players)
               .order(played_at: :desc)
  end

  def load_elo_changes(events)
    return {} if events.blank?

    changes = EloChange.where(game_event_id: events.map(&:id))
    changes.index_by { |ec| [ec.game_event_id, ec.user_id] }
  end

  def ratings_scope(system)
    EloRating.where(game_system: system).includes(:user).order(rating: :desc)
  end

  # currently not a param sent by the front, so ends up at default value
  def per_page_param
    per = params[:per].to_i
    per = 20 if per <= 0 || per > 100
    per
  end

  def page_param(scope, per_page, total_pages)
    return user_page(scope, per_page).clamp(1, total_pages) if params[:page].blank?

    page = params[:page].to_i
    page = 1 if page <= 0
    page = total_pages if total_pages.positive? && page > total_pages
    page
  end

  def user_page(scope, per_page)
    return 1 unless Current.user

    user_row = scope.find_by(user: Current.user)
    return 1 unless user_row

    higher = scope.where('rating > ?', user_row.rating).count
    (higher / per_page) + 1
  end

  def with_ranks(scope, rows)
    rows
      .map { |row| { rank: scope.where('rating > ?', row.rating).count + 1, row: row } }
      .sort_by { |h| h[:rank] }
  end
end
