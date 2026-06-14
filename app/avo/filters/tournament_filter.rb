# frozen_string_literal: true

module Avo
  module Filters
    class TournamentFilter < Avo::Filters::SelectFilter
      def apply(_request, query, value)
        return query if value.blank?

        query.where(tournament_id: value)
      end

      def options
        ::Tournament::Tournament.order(starts_at: :desc).to_h { |t| [t.id, t.name] }
      end
    end
  end
end
