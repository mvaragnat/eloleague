# frozen_string_literal: true

module Tournament
  class RegistrationsController < ApplicationController
    before_action :authenticate_user!
    skip_before_action :authenticate_user!, only: %i[show]
    before_action :set_tournament
    before_action :set_registration, only: %i[show update]

    def show
      return if can_view?(@registration)

      redirect_back(fallback_location: tournament_path(@tournament),
                    alert: t('tournaments.unauthorized', default: 'Not authorized'))
    end

    def update
      registration = @registration
      unless can_update?(registration)
        return redirect_back(fallback_location: tournament_path(@tournament),
                             alert: t('tournaments.unauthorized', default: 'Not authorized'))
      end

      if registration.update(registration_params)
        redirect_to tournament_path(@tournament, tab: 1),
                    notice: t('tournaments.registration_updated', default: 'Registration updated')
      else
        redirect_to tournament_path(@tournament, tab: 1),
                    alert: registration.errors.full_messages.to_sentence
      end
    end

    private

    # Devise provides authentication; Current.user is set at ApplicationController

    def set_tournament
      @tournament = ::Tournament::Tournament.find(params[:tournament_id])
    end

    def set_registration
      @registration = @tournament.registrations.find(params[:id])
    end

    def can_update?(registration)
      return true if @tournament.creator_id == Current.user.id

      registration.user_id == Current.user.id
    end

    def can_view?(registration)
      return true if @tournament.running?
      return true if @tournament.creator_id == Current.user&.id
      return true if Current.user && registration.user_id == Current.user.id

      false
    end

    def registration_params
      params.expect(tournament_registration: %i[faction_id army_list])
    end
  end
end
