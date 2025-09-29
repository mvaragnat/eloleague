# frozen_string_literal: true

module Avo
  module Resources
    class GameFaction < Avo::BaseResource
      self.model_class = ::Game::Faction
      self.title = :name

      def fields
        field :id, as: :id
        field :name, as: :text, required: true, sortable: true
        field :game_system, as: :belongs_to, resource: Avo::Resources::GameSystem

        field :games_count, as: :number, name: I18n.t('avo.fields.games_played'), readonly: true
        field :game_participations, as: :has_many, resource: Avo::Resources::GameParticipation
      end

      def filters
        filter Avo::Filters::GameSystemFilter
      end

      def actions
        action Avo::Actions::BulkDestroyFactions
      end
    end
  end
end
