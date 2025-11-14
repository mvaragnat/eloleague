# frozen_string_literal: true

module Avo
  module Filters
    class TournamentGameSystemFilter < Avo::Filters::SelectFilter
      def apply(_request, query, value)
        return query if value.blank?

        query.joins(:tournament).where(tournaments: { game_system_id: value })
      end

      def options
        Game::System.order(:name).to_h { |gs| [gs.id, gs.localized_name] }
      end
    end
  end
end
