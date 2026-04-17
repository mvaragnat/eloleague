# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[show search]

  def search
    term = params[:q].to_s.strip

    return render json: [] if term.blank?

    @users = base_scope(term)
    resolved_tid = resolve_tournament_id

    @users = scope_to_tournament(@users, resolved_tid)
    @users = exclude_current_user_if_needed(@users, resolved_tid)
    @users = @users.order(username: :asc).limit(10)

    registrations_by_user_id = registrations_index(resolved_tid, @users)

    render json: @users.map { |u|
      { id: u.id, username: u.username, faction_id: registrations_by_user_id[u.id]&.faction_id }
    }
  end

  def show
    # Public player profile
    Current.user = current_user
    @user = User.find(params[:id])

    # Player stats per system and faction
    stats = Stats::PlayerWinRates.new(user: @user).call
    @stats_system_options = stats.map { |row| [row[:system_name], row[:system_id]] }.sort_by(&:first)
    @selected_system_id = params[:game_system_id].presence&.to_i
    @player_stats = if @selected_system_id.present?
                      stats.select { |row| row[:system_id] == @selected_system_id }
                    else
                      stats
                    end

    # Recent games (all systems)
    @events = @user.game_events.includes(:game_system, :game_participations, :players,
                                         :tournament).order(played_at: :desc)
  end

  private

  def base_scope(term)
    User.where('username ILIKE ?', "%#{term}%")
  end

  def resolve_tournament_id
    return params[:tournament_id].to_s.gsub(/[^0-9]/, '') if params[:tournament_id].present?

    return nil if request.referer.blank?

    m = request.referer.match(%r{/tournaments/([^/?#]+)})
    return nil unless m

    slug = CGI.unescape(m[1])
    t = Tournament::Tournament.find_by(slug: slug) || Tournament::Tournament.where(id: slug.gsub(/[^0-9]/, '')).first
    t&.id&.to_s
  end

  def scope_to_tournament(users, resolved_tid)
    return users if resolved_tid.blank?

    ids = Tournament::Registration.where(tournament_id: resolved_tid).pluck(:user_id)
    users.where(id: ids)
  end

  def exclude_current_user_if_needed(users, resolved_tid)
    return users if resolved_tid.present?
    return users unless Current.user

    users.where.not(id: Current.user.id)
  end

  def registrations_index(resolved_tid, users)
    return {} if resolved_tid.blank?

    regs = Tournament::Registration.where(tournament_id: resolved_tid, user_id: users.pluck(:id))
    regs.index_by(&:user_id)
  end
end
