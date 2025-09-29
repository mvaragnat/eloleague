# frozen_string_literal: true

module Avo
  module Actions
    class BulkDestroyFactions < Avo::BaseAction
      # Evaluate the name at runtime so i18n is loaded and current locale is respected
      self.name = 'Bulk destroy'

      self.message = lambda {
        count = query.count

        tag.div do
          safe_join([
                      I18n.t('avo.actions.bulk_destroy_factions.confirm_title', count: count),
                      tag.div(class: 'text-sm text-gray-500 mt-2 mb-2 font-bold') do
                        I18n.t('avo.actions.bulk_destroy_factions.confirm_list_intro')
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
                        I18n.t('avo.actions.bulk_destroy_factions.confirm_warning')
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
          succeed I18n.t('avo.actions.bulk_destroy_factions.success', count: destroyed_count)
        else
          # Cancelled entirely because at least one record is referenced
          destroyed_count = 0
          warn I18n.t('avo.actions.bulk_destroy_factions.cancelled_warning')
          self.fail I18n.t('avo.actions.bulk_destroy_factions.cancelled', error: errors.first)
        end
      end
    end
  end
end
