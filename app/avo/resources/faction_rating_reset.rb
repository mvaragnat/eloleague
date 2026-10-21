# frozen_string_literal: true

module Avo
  module Resources
    class FactionRatingReset < Avo::BaseResource
      self.model_class = ::FactionRatingReset
      self.title = :reset_at

      def fields
        field :id, as: :id
        field :faction, as: :belongs_to, resource: Avo::Resources::GameFaction
        field :reset_at, as: :date_time, sortable: true
        field :rating_deviation, as: :number, name: 'RD'
      end
    end
  end
end
