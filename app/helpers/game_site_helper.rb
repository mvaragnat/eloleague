# frozen_string_literal: true

module GameSiteHelper
  # On a game site, `game_sites.<site key>.<key>` overrides `<key>` when it exists.
  def translate(key, **)
    super(game_site_translation_key(key) || key, **)
  end
  alias t translate

  def game_site_icon_path
    Current.game_site&.icon || '/icon.png'
  end

  def game_site_og_image_url
    "#{request.base_url}#{Current.game_site&.og_image || '/og-image.png'}"
  end

  private

  def game_site_translation_key(key)
    site = Current.game_site
    return unless site && (key.is_a?(String) || key.is_a?(Symbol)) && !key.to_s.start_with?('.')

    override = "game_sites.#{site.key}.#{key}"
    override if I18n.exists?(override)
  end
end
