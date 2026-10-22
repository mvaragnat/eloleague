# frozen_string_literal: true

# A game site is the application served on a dedicated domain and locked on a single game system,
# with its own texts and theme. Sites are described in config/game_sites.yml and bound to domains
# through the GAME_SITES environment variable ("host=site_key,other.host=other_key").
class GameSite
  CONFIG_PATH = Rails.root.join('config/game_sites.yml')

  attr_reader :key, :game_system_name, :theme, :icon, :og_image, :parent_url

  class << self
    attr_writer :config

    def config
      @config ||= (YAML.load_file(CONFIG_PATH) || {}).transform_keys(&:to_s)
    end

    def for_host(host)
      key = host_map[host.to_s.downcase]
      return nil unless key

      attrs = config.fetch(key) { raise KeyError, "GAME_SITES maps #{host} to unknown game site '#{key}'" }
      new(key, attrs)
    end

    # Parsed on each call so that the environment stays the single source of truth.
    def host_map
      ENV.fetch('GAME_SITES', '').split(',').filter_map do |pair|
        host, key = pair.split('=', 2).map(&:strip)
        [host.downcase, key] if host.present? && key.present?
      end.to_h
    end
  end

  def initialize(key, attrs)
    @key = key.to_s
    @game_system_name = attrs.fetch('game_system')
    @theme = attrs['theme'].presence
    @icon = attrs['icon'].presence
    @og_image = attrs['og_image'].presence
    @parent_url = attrs['parent_url'].presence
  end

  def game_system
    Game::System.find_by(name: game_system_name) ||
      raise(ActiveRecord::RecordNotFound, "Game site '#{key}' targets unknown game system '#{game_system_name}'")
  end
end
