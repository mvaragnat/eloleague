# frozen_string_literal: true

module Avo
  module Resources
    class EloChange < Avo::BaseResource
      self.model_class = ::EloChange
      self.title = :id

      def fields
        field :id, as: :id
        field :game_event, as: :belongs_to, resource: Avo::Resources::GameEvent
        field :user, as: :belongs_to, resource: Avo::Resources::User
        field :game_system, as: :belongs_to, resource: Avo::Resources::GameSystem

        field :rating_before, as: :number
        field :rating_after, as: :number
        field :expected_score, as: :number
        field :actual_score, as: :number
        field :k_factor, as: :number
        field :created_at, as: :date_time, readonly: true
        field :updated_at, as: :date_time, readonly: true
      end
    end
  end
end


