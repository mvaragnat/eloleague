# frozen_string_literal: true

module Avo
  class TournamentsController < Avo::ResourcesController
    private

    # Override Avo's default record lookup to support slug-based URLs
    # Since Tournament#to_param returns slug, we need to find by slug first
    def set_record
      @record = resource.model_class.find_by(slug: params[:id]) ||
                resource.model_class.find(params[:id])
    end
  end
end
