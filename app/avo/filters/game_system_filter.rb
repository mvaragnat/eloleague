# frozen_string_literal: true

module Avo
  module Filters
    class GameSystemFilter < Avo::Filters::SelectFilter
      def apply(_request, query, value)
        return query if value.blank?

        query.where(game_system_id: value)
      end

      def options
        # Avo SelectFilter expects a Hash of { value => label }
        Game::System.order(:name).to_h { |gs| [gs.id, gs.localized_name] }
      end
    end
  end
end
