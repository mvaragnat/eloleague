# frozen_string_literal: true

module Avo
  module Actions
    class BulkDestroyFactions < Avo::BaseAction
      # Static English label per Avo dashboard convention
      self.name = 'Delete selected factions'

      self.message = lambda {
        count = query.count

        tag.div do
          safe_join([
                      "Delete #{count} selected factions?",
                      tag.div(class: 'text-sm text-gray-500 mt-2 mb-2 font-bold') do
                        'These factions will be permanently deleted:'
                      end,
                      tag.ul(class: 'ml-4 overflow-y-scroll max-h-64') do
                        safe_join(query.map do |record|
                          resource = ::Avo.resource_manager.get_resource_by_model_class(record.class)
                          title = resource.new(record: record).record_title

                          tag.li(class: 'text-sm text-gray-500') do
                            "- #{title}"
                          end
                        end)
                      end,
                      tag.div(class: 'text-sm text-red-500 mt-2 font-bold') do
                        'This action cannot be undone.'
                      end
                    ])
        end
      }

      def handle(query:, **)
        errors = []
        destroyed_count = 0

        records = query.respond_to?(:find_each) ? query.to_a : Array(query)

        ActiveRecord::Base.transaction do
          records.each do |record|
            record.destroy!
            destroyed_count += 1
          rescue StandardError => e
            errors << e.message
            raise ActiveRecord::Rollback
          end
        end

        if errors.empty?
          succeed "Deleted #{destroyed_count} faction(s)"
        else
          # Cancelled entirely because at least one record is referenced
          warn 'No faction deleted. Some selected factions are referenced.'
          succeed "Deletion cancelled: #{errors.first}"
        end
      end
    end
  end
end
