# frozen_string_literal: true

module Tournament
  class RegistrationsController < ApplicationController
    before_action :authenticate_user!
    skip_before_action :authenticate_user!, only: %i[show]
    before_action :set_tournament
    before_action :set_registration, only: %i[show update]

    layout 'army_list', only: %i[show]

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

      attrs = registration_params
      if (blocker = validation_blocker(registration, attrs))
        return redirect_to tournament_path(@tournament, tab: params[:tab].presence || 2), alert: blocker
      end

      if registration.update(attrs)
        redirect_to tournament_path(@tournament, tab: params[:tab].presence || 2),
                    notice: t('tournaments.registration_updated', default: 'Registration updated')
      else
        redirect_to tournament_path(@tournament, tab: params[:tab].presence || 2),
                    alert: registration.errors.full_messages.to_sentence
      end
    end

    private

    # Devise provides authentication; Current.user is set at ApplicationController

    def set_tournament
      @tournament = ::Tournament::Tournament.find_by(slug: params[:tournament_id]) ||
                    ::Tournament::Tournament.find(params[:tournament_id])
    end

    def set_registration
      @registration = @tournament.registrations.find(params[:id])
    end

    def can_update?(registration)
      return true if @tournament.creator_id == Current.user.id

      registration.user_id == Current.user.id
    end

    def army_list_editable?
      !@tournament.army_list_locked? || @tournament.creator_id == Current.user.id
    end

    def can_view?(registration)
      return true if @tournament.running? || @tournament.completed?
      return true if @tournament.creator_id == Current.user&.id
      return true if Current.user && registration.user_id == Current.user.id

      false
    end

    def registration_params
      permitted = params.expect(tournament_registration: %i[faction_id army_list status affiliation_name validated])
      permitted.delete(:army_list) unless army_list_editable?
      permitted.delete(:affiliation_name) unless @tournament.affiliation_editable?
      # Only the organizer validates registrations, and only while they are open.
      permitted.delete(:validated) unless organizer? && @tournament.registration_settings_editable?
      permitted
    end

    def organizer?
      @tournament.creator_id == Current.user&.id
    end

    # Returns an error message when the requested change conflicts with the
    # organizer validation workflow, nil otherwise.
    def validation_blocker(registration, attrs)
      return nil unless @tournament.requires_registration_validation?

      if validating?(attrs) && !registration.validated? && @tournament.confirmed_registrations_full?
        return t('tournaments.confirmed_full',
                 default: 'The maximum number of confirmed players is reached; raise the cap first')
      end

      return nil unless attrs[:status].to_s == 'checked_in'
      return nil if registration.validated? || validating?(attrs)

      t('tournaments.validation_required_before_check_in',
        default: 'This registration must be validated before check-in')
    end

    def validating?(attrs)
      ActiveModel::Type::Boolean.new.cast(attrs[:validated]).present?
    end
  end
end
