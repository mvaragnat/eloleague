# frozen_string_literal: true

module Avo
  module Resources
    class Affiliation < Avo::BaseResource
      self.model_class = ::Affiliation
      self.title = :name

      def fields
        field :id, as: :id
        field :name, as: :text, required: true, sortable: true

        field :registrations, as: :has_many, resource: Avo::Resources::TournamentRegistration
      end
    end
  end
end
