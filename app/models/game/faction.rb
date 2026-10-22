# frozen_string_literal: true

module Game
  class Faction < ApplicationRecord
    self.table_name = 'game_factions'

    belongs_to :game_system, class_name: 'Game::System'

    has_many :game_participations, class_name: 'Game::Participation', dependent: :restrict_with_exception
    has_one :faction_rating, dependent: :delete
    has_many :faction_rating_resets, dependent: :delete_all

    validates :name, presence: true, length: { maximum: 100 }
    validates :name, uniqueness: { scope: :game_system_id }

    def games_count
      game_participations.count
    end

    # Records a balance patch and raises the current rating deviation accordingly.
    def reset_rating_deviation!(deviation = FactionRatingReset::DEFAULT_DEVIATION, at: Time.current)
      transaction do
        faction_rating_resets.create!(reset_at: at, rating_deviation: deviation)
        faction_rating&.with_lock do
          faction_rating.apply_pending_reset(at)
          faction_rating.save!
        end
      end
    end

    def localized_name(locale = I18n.locale)
      translations = Game::Localization.find_faction_translations(game_system&.name, name)
      return name unless translations

      Game::Localization.localized(translations, locale) || name
    end
  end
end
