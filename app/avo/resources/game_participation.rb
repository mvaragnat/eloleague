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
                          gsid = Avo::Resources::GameParticipation
                                 .resolve_event_game_system_id(params)

                          if gsid.present?
                            query.where(game_system_id: gsid).order(:name)
                          else
                            query.order(:name)
                          end
                        }

        field :score, as: :number
        field :secondary_score, as: :number
        field :army_list, as: :textarea
        field :metadata, as: :code, language: 'json'
      end

      def self.resolve_event_game_system_id(params)
        conn = ActiveRecord::Base.connection

        ev_id = params[:via_record_id]
        if ev_id.present? && ev_id.to_s.match?(/\A\d+\z/)
          return conn.select_value(
            "SELECT game_system_id FROM game_events WHERE id = #{conn.quote(ev_id.to_i)} LIMIT 1"
          )
        end

        gp_id = params[:id]
        return nil unless gp_id.present? && gp_id.to_s.match?(/\A\d+\z/)

        conn.select_value(
          "SELECT ge.game_system_id
             FROM game_participations gp
             JOIN game_events ge ON gp.game_event_id = ge.id
            WHERE gp.id = #{conn.quote(gp_id.to_i)}
            LIMIT 1"
        )
      end
    end
  end
end
