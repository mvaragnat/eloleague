# frozen_string_literal: true

module Avo
  module Resources
    class GameParticipation < Avo::BaseResource
      self.model_class = ::Game::Participation
      self.title = :id

      def fields
        field :id, as: :id
        field :game_event, as: :belongs_to, resource: Avo::Resources::GameEvent
        field :user, as: :belongs_to, resource: Avo::Resources::User, attach_scope: -> { query.order(username: :asc) }
        field :faction, as: :belongs_to, resource: Avo::Resources::GameFaction,
                        attach_scope: lambda {
                          # Prefer scoping by the parent Game::Event when creating via relation
                          # Fallback to alphabetical ordering
                          ev = nil
                          if params[:via_record_id].present?
                            # via_record_id is numeric for Game::Event
                            ev_id = params[:via_record_id].to_s.gsub(/[^0-9]/, '')
                            ev = Game::Event.where(id: ev_id).first if ev_id.present?
                          end

                          if ev&.game_system_id
                            query.where(game_system_id: ev.game_system_id).order(:name)
                          else
                            query.order(:name)
                          end
                        }

        field :score, as: :number
        field :secondary_score, as: :number
        field :army_list, as: :textarea
        field :metadata, as: :code, language: 'json'
      end
    end
  end
end
