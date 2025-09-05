# frozen_string_literal: true

module Avo
  module Resources
    class TournamentRound < Avo::BaseResource
      self.model_class = ::Tournament::Round
      self.title = :id

      def fields
        field :id, as: :id
        field :tournament, as: :belongs_to, resource: Avo::Resources::Tournament
        field :number, as: :number
        field :state, as: :text
        field :paired_at, as: :date_time
        field :locked_at, as: :date_time

        field :matches, as: :has_many, resource: Avo::Resources::TournamentMatch
      end
    end
  end
end


