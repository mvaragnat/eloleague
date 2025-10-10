# frozen_string_literal: true

class UsersController < ApplicationController
  def search
    @users = User.where('username ILIKE ?', "%#{params[:q]}%")

    if params[:tournament_id].present?
      ids = Tournament::Registration.where(tournament_id: params[:tournament_id]).pluck(:user_id)
      @users = @users.where(id: ids)
      # In tournament context, include the current user if registered (e.g., organizer who is checked in)
    elsif Current.user
      # Outside tournament context (e.g., casual games), exclude the current user from results
      @users = @users.where.not(id: Current.user.id)
    end

    @users = @users.limit(10)

    # When searching within a tournament, include registered faction_id to preselect factions in the UI
    registrations_by_user_id = {}
    if params[:tournament_id].present?
      regs = Tournament::Registration.where(tournament_id: params[:tournament_id], user_id: @users.pluck(:id))
      registrations_by_user_id = regs.index_by(&:user_id)
    end

    render json: @users.map { |u| { id: u.id, username: u.username, faction_id: registrations_by_user_id[u.id]&.faction_id } }
  end
end
