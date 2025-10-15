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
                          # Resolve tournament's game_system_id without constantizing models
                          via_id = params[:via_record_id]
                          game_system_id = nil
                          if via_id.present?
                            conn = ActiveRecord::Base.connection
                            if via_id.to_s.match?(/\A\d+\z/)
                              game_system_id = conn.select_value("SELECT game_system_id FROM tournaments WHERE id = #{conn.quote(via_id.to_i)} LIMIT 1")
                            else
                              game_system_id = conn.select_value("SELECT game_system_id FROM tournaments WHERE slug = #{conn.quote(via_id)} LIMIT 1")
                            end
                          end

                          if game_system_id.present?
                            query.where(game_system_id: game_system_id).order(:name)
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
    end
  end
end
