# frozen_string_literal: true

module Avo
  module Resources
    class TournamentMatch < Avo::BaseResource
      self.model_class = ::Tournament::Match
      self.title = :id

      def fields
        field :id, as: :id
        field :tournament, as: :belongs_to, resource: Avo::Resources::Tournament
        field :round, as: :belongs_to, resource: Avo::Resources::TournamentRound
        field :a_user, as: :belongs_to, resource: Avo::Resources::User
        field :b_user, as: :belongs_to, resource: Avo::Resources::User
        field :game_event, as: :belongs_to, resource: Avo::Resources::GameEvent

        field :result, as: :select, options: ::Tournament::Match::RESULTS
        field :reported_at, as: :date_time
        field :metadata, as: :code, language: 'json'

        field :parent_match, as: :belongs_to, resource: Avo::Resources::TournamentMatch
        field :child_slot, as: :select, options: %w[a b]
        field :child_matches, as: :has_many, resource: Avo::Resources::TournamentMatch
      end
    end
  end
end
