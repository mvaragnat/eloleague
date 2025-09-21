# frozen_string_literal: true

module Avo
  module Resources
    class TournamentRegistration < Avo::BaseResource
      self.model_class = ::Tournament::Registration
      self.title = :registration_label

      def fields
        field :id, as: :id
        field :tournament, as: :belongs_to, resource: Avo::Resources::Tournament
        field :user, as: :belongs_to, resource: Avo::Resources::User
        field :faction, as: :belongs_to, resource: Avo::Resources::GameFaction

        field :seed, as: :number
        field :status, as: :text
        field :army_list, as: :textarea
        field :created_at, as: :date_time, readonly: true
        field :updated_at, as: :date_time, readonly: true
      end
    end
  end
end
