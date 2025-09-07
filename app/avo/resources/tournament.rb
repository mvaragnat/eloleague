# frozen_string_literal: true

module Avo
  module Resources
    class Tournament < Avo::BaseResource
      self.model_class = ::Tournament::Tournament
      self.title = :name

      def fields
        field :id, as: :id
        field :name, as: :text, required: true
        field :description, as: :textarea
        field :creator, as: :belongs_to, resource: Avo::Resources::User
        field :game_system, as: :belongs_to, resource: Avo::Resources::GameSystem

        field :format, as: :text
        field :rounds_count, as: :number
        field :starts_at, as: :date_time
        field :ends_at, as: :date_time
        field :state, as: :text
        field :require_army_list_for_check_in, as: :boolean
        field :pairing_strategy_key, as: :text
        field :tiebreak1_strategy_key, as: :text
        field :tiebreak2_strategy_key, as: :text
        field :slug, as: :text, readonly: true
        field :settings, as: :code, language: 'json'

        field :registrations, as: :has_many, resource: Avo::Resources::TournamentRegistration
        field :rounds, as: :has_many, resource: Avo::Resources::TournamentRound
        field :matches, as: :has_many, resource: Avo::Resources::TournamentMatch
      end
    end
  end
end
