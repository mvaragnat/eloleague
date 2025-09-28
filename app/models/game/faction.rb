# frozen_string_literal: true

module Game
  class Faction < ApplicationRecord
    self.table_name = 'game_factions'

    belongs_to :game_system, class_name: 'Game::System'

    has_many :game_participations, class_name: 'Game::Participation', dependent: :restrict_with_exception

    validates :name, presence: true, length: { maximum: 100 }
    validates :name, uniqueness: { scope: :game_system_id }

    def games_count
      game_participations.count
    end

    def localized_name(locale = I18n.locale)
      translations = Game::Localization.find_faction_translations(game_system&.name, name)
      return name unless translations

      Game::Localization.localized(translations, locale) || name
    end
  end
end
