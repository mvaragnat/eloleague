# frozen_string_literal: true

# Resolves the game site from the request host. On a game site, every other game system is hidden:
# lists are filtered, records of other systems are not found (404), and new records are bound to the site's system.
module GameSiteScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_game_site
    helper_method :current_game_site, :game_site?, :available_game_systems
  end

  private

  def set_game_site
    Current.game_site = GameSite.for_host(request.host)
    Current.game_system = Current.game_site&.game_system
  end

  def current_game_site
    Current.game_site
  end

  def game_site?
    Current.game_site.present?
  end

  # Game systems the visitor may see or pick from.
  def available_game_systems
    systems = game_site? ? [Current.game_system] : Game::System.all.to_a
    systems.sort_by(&:localized_name)
  end

  # Restricts a relation having a game_system_id column to the site's game system.
  def scope_to_game_site(relation, column: :game_system_id)
    game_site? ? relation.where(column => Current.game_system.id) : relation
  end
end
