# frozen_string_literal: true

module Avo
  module Resources
    class EloRating < Avo::BaseResource
      self.model_class = ::EloRating
      self.title = :rating

      def fields
        field :id, as: :id
        field :user, as: :belongs_to, resource: Avo::Resources::User, attach_scope: -> { query.order(username: :asc) }
        field :game_system, as: :belongs_to, resource: Avo::Resources::GameSystem

        field :conservative_rating, as: :number, name: 'R - 2·RD (seeding)', only_on: %i[index show]
        field :rating, as: :number, sortable: true
        field :rating_deviation, as: :number, name: 'RD', sortable: true
        field :games_played, as: :number
        field :last_played_at, as: :date_time, readonly: true
      end

      def filters
        filter Avo::Filters::GameSystemFilter
      end
    end
  end
end
