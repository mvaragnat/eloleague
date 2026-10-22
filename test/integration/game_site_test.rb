# frozen_string_literal: true

require 'test_helper'

class GameSiteTest < ActionDispatch::IntegrationTest
  SITE_HOST = 'chess.example.com'

  setup do
    @previous_game_sites = ENV.fetch('GAME_SITES', nil)
    ENV['GAME_SITES'] = "#{SITE_HOST}=chess_site"
    GameSite.config = { 'chess_site' => { 'game_system' => 'Chess', 'og_image' => '/sites/chess/og.png' } }
    I18n.backend.store_translations(:en, game_sites: { chess_site: { app: { name: 'Chess League' } } })

    @user = users(:player_one)
    @chess_tournament = create_tournament('Chess Open', game_systems(:chess))
    @go_tournament = create_tournament('Go Open', game_systems(:go))
  end

  teardown do
    ENV['GAME_SITES'] = @previous_game_sites
    GameSite.config = nil
    I18n.reload!
  end

  test 'host map parses the environment variable' do
    ENV['GAME_SITES'] = ' Chess.Example.com = chess_site , broken,other.example.com=other '
    assert_equal({ 'chess.example.com' => 'chess_site', 'other.example.com' => 'other' }, GameSite.host_map)
  end

  test 'unknown site key raises' do
    ENV['GAME_SITES'] = "#{SITE_HOST}=missing"
    assert_raises(KeyError) { GameSite.for_host(SITE_HOST) }
  end

  test 'base site keeps its texts and lists every game system' do
    get tournaments_path(locale: :en)
    assert_response :success
    assert_select 'title', 'Eloleague'
    assert_select 'body[data-game-site]', count: 0
    assert_includes response.body, 'Chess Open'
    assert_includes response.body, 'Go Open'
  end

  test 'game site overrides texts and images' do
    host! SITE_HOST
    get tournaments_path(locale: :en)
    assert_response :success
    assert_select 'title', 'Chess League'
    assert_select 'body[data-game-site=chess_site]'
    assert_select 'meta[property="og:image"][content=?]', "http://#{SITE_HOST}/sites/chess/og.png"
  end

  test 'game site logo links to the parent site' do
    GameSite.config['chess_site']['parent_url'] = 'https://chess.example.org'
    host! SITE_HOST
    get tournaments_path(locale: :en)
    assert_select 'nav a.site-logo[href=?]', 'https://chess.example.org', text: 'Chess League'
  end

  test 'base site has no logo' do
    get tournaments_path(locale: :en)
    assert_select 'a.site-logo', count: 0
  end

  test 'game site only lists tournaments of its game system' do
    host! SITE_HOST
    get tournaments_path(locale: :en)
    assert_includes response.body, 'Chess Open'
    assert_not_includes response.body, 'Go Open'
  end

  test 'game site hides tournaments of other game systems' do
    host! SITE_HOST
    get tournament_path(@chess_tournament, locale: :en)
    assert_response :success

    get tournament_path(@go_tournament, locale: :en)
    assert_response :not_found
  end

  test 'game site binds new tournaments to its game system' do
    host! SITE_HOST
    sign_in @user
    get new_tournament_path(locale: :en)
    assert_select 'select[name="tournament[game_system_id]"] option', count: 1
    assert_select 'select[name="tournament[game_system_id]"] option[value=?]', game_systems(:chess).id.to_s

    post tournaments_path(locale: :en),
         params: { tournament: { name: 'Sneaky', description: 'x', game_system_id: game_systems(:go).id,
                                 format: 'open' } }
    assert_equal game_systems(:chess), Tournament::Tournament.find_by!(name: 'Sneaky').game_system
  end

  test 'game site preselects its game system in the casual game form' do
    host! SITE_HOST
    sign_in @user
    get new_game_event_path(locale: :en)
    assert_response :success
    assert_select 'select[name="game_event[game_system_id]"] option', count: 1
    assert_select 'select[name="game_event[game_system_id]"] option[selected][value=?]', game_systems(:chess).id.to_s
  end

  test 'game site stats endpoints ignore other game systems' do
    host! SITE_HOST
    sign_in @user
    get stats_path(locale: :en)
    assert_select '#system-select option[value=?]', game_systems(:go).id.to_s, count: 0

    get stats_factions_path(locale: :en), params: { game_system_id: game_systems(:go).id }, as: :json
    assert_response :not_found

    get game_factions_path(locale: :en), params: { game_system_id: game_systems(:go).id }, as: :json
    assert_equal [], response.parsed_body
  end

  test 'game site championships have no system selector' do
    host! SITE_HOST
    get championships_path(locale: :en), params: { game_system_id: game_systems(:go).id }
    assert_response :success
    assert_select 'select[name=game_system_id] option[value]:not([value=""])', count: 1
    assert_select 'select[name=game_system_id] option[selected][value=?]', game_systems(:chess).id.to_s
  end

  private

  def create_tournament(name, system)
    Tournament::Tournament.create!(name: name, description: 'd', game_system: system, creator: @user,
                                   state: 'registration')
  end
end
