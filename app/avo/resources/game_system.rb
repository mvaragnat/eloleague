# frozen_string_literal: true

module Avo
  module Resources
    class GameSystem < Avo::BaseResource
      self.model_class = ::Game::System
      self.title = :name

      def fields
        field :id, as: :id
        field :name, as: :text, required: true
        field :description, as: :textarea, required: true

        field :factions, as: :has_many, resource: Avo::Resources::GameFaction
        field :events, as: :has_many, resource: Avo::Resources::GameEvent
      end
    end
  end
end
