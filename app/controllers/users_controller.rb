# frozen_string_literal: true

class UsersController < ApplicationController
  def search
    term = params[:q].to_s.strip
    @users = if term.present?
               User.where('username ILIKE ?', "%#{term}%")
             else
               User.all
             end

    # Resolve tournament id either from param or from referer path (fallback)
    resolved_tid = nil
    if params[:tournament_id].present?
      resolved_tid = params[:tournament_id].to_s.gsub(/[^0-9]/, '')
    elsif request.referer.present?
      # Try to parse "/tournaments/:slug" from referer (works for Open matches modal)
      m = request.referer.match(%r{/tournaments/([^/?#]+)})
      if m
        slug = CGI.unescape(m[1])
        t = Tournament::Tournament.find_by(slug: slug) || Tournament::Tournament.where(id: slug.gsub(/[^0-9]/,
                                                                                                     '')).first
        resolved_tid = t&.id&.to_s if t
      end
    end

    if resolved_tid.present?
      ids = Tournament::Registration.where(tournament_id: resolved_tid).pluck(:user_id)
      @users = @users.where(id: ids)
      # In tournament context, include the current user if registered (e.g., organizer who is checked in)
    elsif Current.user
      # Outside tournament context (e.g., casual games), exclude the current user from results
      @users = @users.where.not(id: Current.user.id)
    end

    @users = @users.limit(10)

    # When searching within a tournament, include registered faction_id to preselect factions in the UI
    registrations_by_user_id = {}
    if resolved_tid.present?
      regs = Tournament::Registration.where(tournament_id: resolved_tid, user_id: @users.pluck(:id))
      registrations_by_user_id = regs.index_by(&:user_id)
    end

    render json: @users.map { |u|
      { id: u.id, username: u.username, faction_id: registrations_by_user_id[u.id]&.faction_id }
    }
  end
end
