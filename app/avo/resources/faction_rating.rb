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

        field :conservative_rating, as: :number, name: 'R - 2·RD (displayed)', only_on: %i[index show]
        field :rating, as: :number, sortable: true
        field :rating_deviation, as: :number, name: 'RD', sortable: true
        field :games_played, as: :number, sortable: true
        field :concentration, as: :number, only_on: %i[index show], format_using: -> { value&.round(2) }
        field :effective_players, as: :number, name: 'Effective players (window)', readonly: true
        field :distinct_players, as: :number, name: 'Players (window)', readonly: true
        field :diversity, as: :number, readonly: true
        field :last_reset_at, as: :date_time, readonly: true
      end

      def filters
        filter Avo::Filters::GameSystemFilter
      end
    end
  end
end
