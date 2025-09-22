# frozen_string_literal: true

module Avo
  module Resources
    class User < Avo::BaseResource
      self.title = :username
      # self.includes = []
      # self.attachments = []
      # self.search = {
      #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
      # }

      def fields
        field :id, as: :id
        field :username, as: :text
        field :email, as: :text
        field :password, as: :password, only_on: :forms
        field :password_confirmation, as: :password, only_on: :forms
        field :game_participations, as: :has_many
        field :game_events, as: :has_many, through: :game_participations
        field :game_systems, as: :has_many, through: :game_events
      end
    end
  end
end
