# frozen_string_literal: true

module Avo
  module Resources
    class FactionRating < Avo::BaseResource
      self.model_class = ::FactionRating
      self.title = :rating

      def fields
        field :id, as: :id
        field :faction, as: :belongs_to, resource: Avo::Resources::GameFaction
        field :game_system, as: :belongs_to, resource: Avo::Resources::GameSystem

        field :rating, as: :number, sortable: true
        field :rating_deviation, as: :number, name: 'RD', sortable: true
        field :games_played, as: :number, sortable: true
        field :effective_players, as: :number, name: 'Effective players (6 months)', readonly: true
        field :distinct_players, as: :number, name: 'Players (6 months)', readonly: true
        field :diversity, as: :number, readonly: true
        field :last_reset_at, as: :date_time, readonly: true
      end

      def filters
        filter Avo::Filters::GameSystemFilter
      end
    end
  end
end
