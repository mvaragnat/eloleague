# frozen_string_literal: true

module Avo
  module Resources
    class TournamentRegistration < Avo::BaseResource
      self.model_class = ::Tournament::Registration
      self.title = :registration_label

      def fields
        field :id, as: :id
        field :tournament, as: :belongs_to, resource: Avo::Resources::Tournament
        field :user, as: :belongs_to, resource: Avo::Resources::User, attach_scope: -> { query.order(username: :asc) }
        field :faction, as: :belongs_to, resource: Avo::Resources::GameFaction,
                        attach_scope: lambda {
                          gsid = Avo::Resources::TournamentRegistration
                                 .resolve_tournament_game_system_id(params)

                          if gsid.present?
                            query.where(game_system_id: gsid).order(:name)
                          else
                            query.order(:name)
                          end
                        }

        field :seed, as: :number
        field :status, as: :text
        field :army_list, as: :textarea
        field :created_at, as: :date_time, readonly: true
        field :updated_at, as: :date_time, readonly: true
      end

      # Keep helper minimal and isolated to reduce fields method complexity.
      def self.resolve_tournament_game_system_id(params)
        conn = ActiveRecord::Base.connection

        via_id = params[:via_record_id]
        if via_id.present?
          if via_id.to_s.match?(/\A\d+\z/)
            return conn.select_value(
              "SELECT game_system_id FROM tournaments WHERE id = #{conn.quote(via_id.to_i)} LIMIT 1"
            )
          end
          return conn.select_value(
            "SELECT game_system_id FROM tournaments WHERE slug = #{conn.quote(via_id)} LIMIT 1"
          )
        end

        reg_id = params[:id]
        return nil unless reg_id.present? && reg_id.to_s.match?(/\A\d+\z/)

        conn.select_value(
          "SELECT t.game_system_id
             FROM tournament_registrations tr
             JOIN tournaments t ON tr.tournament_id = t.id
            WHERE tr.id = #{conn.quote(reg_id.to_i)}
            LIMIT 1"
        )
      end
    end
  end
end
