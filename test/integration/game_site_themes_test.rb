# frozen_string_literal: true

require 'test_helper'

# Guards the look of every site of config/game_sites.yml: see "Adding a game site" in context.md.
class GameSiteThemesTest < ActionDispatch::IntegrationTest
  THEMES_DIR = Rails.root.join('app/assets/stylesheets/themes')
  # Tokens whose base value only suits the base site: each theme has to set them.
  REQUIRED_TOKENS = %w[--blue-500 --gray-100 --text-strong --text-muted --surface --on-primary --highlight-bg
                       --table-line --font-body --hero-image].freeze

  setup { GameSite.config = nil }

  test 'every game site has a theme setting the palette tokens' do
    sites.each do |key, attrs|
      path = THEMES_DIR.join("#{attrs['theme']}.css")
      assert path.exist?, "#{key}: missing theme #{path}"

      css = path.read
      REQUIRED_TOKENS.each { |token| assert_match(/#{token}:/, css, "#{key}: theme does not set #{token}") }
    end
  end

  test 'every game site has its icon and the images of its theme' do
    sites.each do |key, attrs|
      assert Rails.public_path.join(attrs['icon'].delete_prefix('/')).exist?, "#{key}: missing icon #{attrs['icon']}"

      THEMES_DIR.join("#{attrs['theme']}.css").read.scan(%r{url\('(/sites/[^']+)'\)}).flatten.each do |image|
        assert Rails.public_path.join(image.delete_prefix('/')).exist?, "#{key}: missing image #{image}"
      end
    end
  end

  test 'every game site has its own link preview image and color' do
    sites.each do |key, attrs|
      assert attrs['og_image'].present?, "#{key}: missing og_image"
      assert Rails.public_path.join(attrs['og_image'].delete_prefix('/')).exist?, "#{key}: missing #{attrs['og_image']}"
      assert_match(/\A#\h{6}\z/, attrs['theme_color'].to_s, "#{key}: theme_color must be a hex color")
    end
  end

  test 'every game site has its texts in French and English' do
    sites.each_key do |key|
      %i[fr en].each do |locale|
        %w[app.name app.logo app.description game_site_home.intro_html].each do |text|
          assert I18n.exists?("game_sites.#{key}.#{text}", locale), "#{key}: missing #{locale} text #{text}"
        end
      end
    end
  end

  test 'every game site targets a game system of the catalog' do
    names = YAML.load_file(Rails.root.join('config/game_systems.yml')).fetch('game_systems').pluck('name')
    sites.each { |key, attrs| assert_includes names, attrs['game_system'], "#{key}: unknown game system" }
  end

  test 'the trench crusade theme embeds no image' do
    assert_no_match(%r{url\('/sites}, THEMES_DIR.join('trench_crusade.css').read)
  end

  test 'ranking table highlight comes from the theme' do
    view = Rails.root.join('app/views/tournaments/_ranking_table.html.erb').read
    assert_no_match(/background-color:\s*#/, view)
    assert_includes view, 'ranking-cell--highlight'
  end

  private

  def sites
    GameSite.config
  end
end
