# frozen_string_literal: true

module Avo
  module Actions
    # Balance patch: raises the rating deviation of the selected factions so their
    # ratings recalibrate quickly. The reset is recorded and replayed by elo:rebuild.
    class ResetFactionRatingDeviation < Avo::BaseAction
      self.name = 'Reset rating deviation (balance patch)'
      self.message = 'Raise the rating deviation of the selected factions? Their ratings will move faster ' \
                     'over the next games.'

      def fields
        field :rating_deviation, as: :number, name: 'RD', default: ::FactionRatingReset::DEFAULT_DEVIATION
      end

      def handle(query:, fields:, **)
        deviation = fields[:rating_deviation].presence&.to_i || ::FactionRatingReset::DEFAULT_DEVIATION
        records = query.respond_to?(:find_each) ? query.to_a : Array(query)

        ActiveRecord::Base.transaction do
          records.each { |faction| faction.reset_rating_deviation!(deviation) }
        end

        succeed "Rating deviation reset to #{deviation} for #{records.size} faction(s)"
      rescue ActiveRecord::RecordInvalid => e
        error e.message
      end
    end
  end
end
