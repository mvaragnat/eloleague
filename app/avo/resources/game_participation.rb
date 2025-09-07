# frozen_string_literal: true

module Avo
  module Resources
    class GameParticipation < Avo::BaseResource
      self.model_class = ::Game::Participation
      self.title = :id

      def fields
        field :id, as: :id
        field :game_event, as: :belongs_to, resource: Avo::Resources::GameEvent
        field :user, as: :belongs_to, resource: Avo::Resources::User
        field :faction, as: :belongs_to, resource: Avo::Resources::GameFaction

        field :score, as: :number
        field :secondary_score, as: :number
        field :army_list, as: :textarea
        field :metadata, as: :code, language: 'json'
      end
    end
  end
end
