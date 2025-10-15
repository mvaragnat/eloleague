# frozen_string_literal: true

module Avo
  module Resources
    class GameEvent < Avo::BaseResource
      self.model_class = ::Game::Event
      self.title = :id
      self.search = {
        query: -> { query.ransack(id_eq: q, m: 'or').result(distinct: false) }
      }

      def fields
        field :id, as: :id
        field :game_system, as: :belongs_to, resource: Avo::Resources::GameSystem
        field :played_at, as: :date_time, required: true
        # Keep the explicit flag but hide ELO resources
        field :elo_applied, as: :boolean
        field :non_competitive, as: :boolean
        field :metadata, as: :code, language: 'json'

        field :participants_summary, as: :text, name: I18n.t('avo.fields.participants_with_scores'), readonly: true

        field :game_participations, as: :has_many, resource: Avo::Resources::GameParticipation
        field :players, as: :has_many, through: :game_participations, resource: Avo::Resources::User
        # ELO changes resource removed from Avo
      end
    end
  end
end
