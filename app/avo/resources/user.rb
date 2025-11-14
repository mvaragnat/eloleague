# frozen_string_literal: true

module Avo
  module Resources
    class User < Avo::BaseResource
      self.title = :username
      # self.includes = []
      # self.attachments = []
      self.search = {
        query: -> { query.where('username ILIKE ? OR email ILIKE ?', "%#{q}%", "%#{q}%") }
      }

      def fields
        field :id, as: :id
        field :username, as: :text, sortable: true
        field :email, as: :text
        field :password, as: :password, only_on: :create
        field :password_confirmation, as: :password, only_on: :create
        field :game_participations, as: :has_many
        field :game_events, as: :has_many, through: :game_participations
        field :game_systems, as: :has_many, through: :game_events
        field :tournament_registrations, as: :has_many, resource: Avo::Resources::TournamentRegistration
        field :tournament_matches_as_a, as: :has_many, resource: Avo::Resources::TournamentMatch,
                                        name: 'Tournament matches (as A)'
        field :tournament_matches_as_b, as: :has_many, resource: Avo::Resources::TournamentMatch,
                                        name: 'Tournament matches (as B)'
      end
    end
  end
end
