# frozen_string_literal: true

class AffiliationsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[search]

  # Autocomplete endpoint used when a player types their affiliation
  def search
    term = params[:q].to_s.strip

    return render json: [] if term.blank?

    affiliations = Affiliation.matching(term).order(:name).limit(10)
    render json: affiliations.map { |a| { id: a.id, name: a.name } }
  end
end
