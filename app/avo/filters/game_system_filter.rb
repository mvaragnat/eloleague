# frozen_string_literal: true

module Avo
  module Filters
    class GameSystemFilter < Avo::Filters::SelectFilter
      self.name = I18n.t('avo.filters.game_system')

      def apply(_request, query, value)
        return query if value.blank?

        query.where(game_system_id: value)
      end

      def options
        Game::System.order(:name).pluck(:name, :id).to_h
      end
    end
  end
end
