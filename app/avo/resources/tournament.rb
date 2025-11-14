# frozen_string_literal: true

module Avo
  module Resources
    class Tournament < Avo::BaseResource
      self.model_class = ::Tournament::Tournament
      self.title = :name

      class << self
        # Override find_record to support slug-based URLs
        def find_record(id, **_args)
          model_class.find_by(slug: id) || model_class.find(id)
        end
      end

      def fields
        field :id, as: :id
        field :name, as: :text, required: true
        field :description, as: :textarea
        field :creator, as: :belongs_to, resource: Avo::Resources::User
        field :game_system, as: :belongs_to, resource: Avo::Resources::GameSystem

        field :format, as: :select, options: ::Tournament::Tournament.formats.keys
        field :rounds_count, as: :number
        field :starts_at, as: :date_time
        field :ends_at, as: :date_time
        field :state, as: :select, options: ::Tournament::Tournament.states.keys
        field :slug, as: :text
        field :require_army_list_for_check_in, as: :boolean
        field :online, as: :boolean
        field :location, as: :text
        field :max_players, as: :number
        field :pairing_strategy_key, as: :text
        field :tiebreak1_strategy_key, as: :text
        field :tiebreak2_strategy_key, as: :text
        field :score_for_bye, as: :number, help: 'Score awarded for bye (Swiss tournaments only)'
        field :settings, as: :code, language: 'json'

        field :tournament_registrations_count, as: :number, name: I18n.t('tournaments.show.registrations')

        field :registrations, as: :has_many, resource: Avo::Resources::TournamentRegistration
        field :rounds, as: :has_many, resource: Avo::Resources::TournamentRound
        field :matches, as: :has_many, resource: Avo::Resources::TournamentMatch
      end

      def filters
        filter Avo::Filters::GameSystemFilter
      end
    end
  end
end
