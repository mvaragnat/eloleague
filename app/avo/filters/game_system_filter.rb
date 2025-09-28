# frozen_string_literal: true

module Avo
  module Filters
    class GameSystemFilter < Avo::Filters::SelectFilter
      self.name = -> { I18n.t('avo.filters.game_system') }
      self.button_label = -> { I18n.t('avo.filters.game_system_button') }

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
