# frozen_string_literal: true

module Avo
  module Resources
    class EloRating < Avo::BaseResource
      self.model_class = ::EloRating
      self.title = :id

      def fields
        field :id, as: :id
        field :user, as: :belongs_to, resource: Avo::Resources::User
        field :game_system, as: :belongs_to, resource: Avo::Resources::GameSystem

        field :rating, as: :number, sortable: true
        field :games_played, as: :number
        field :last_updated_at, as: :date_time
        field :created_at, as: :date_time, readonly: true
        field :updated_at, as: :date_time, readonly: true
      end
    end
  end
end
