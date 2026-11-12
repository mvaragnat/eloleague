# frozen_string_literal: true

require 'test_helper'

class GameScoringSystemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:player_one)
    @scoring = game_scoring_systems(:chess_capped_total)
    @scoring.update!(description: '<table><tr><td>2 – 1</td></tr></table>')
  end

  test 'index lists each scoring system with its summary and description' do
    get game_scoring_systems_path(locale: 'en', game_system_id: game_systems(:chess).id), as: :json

    assert_response :success
    item = response.parsed_body.find { |s| s['id'] == @scoring.id }
    assert_equal 'Capped total', item['name']
    assert_equal @scoring.summary(:en), item['summary']
    assert_equal '<table><tr><td>2 – 1</td></tr></table>', item['description_html']
    assert_equal 3, item['max_total_score']
    assert_not item.key?('description')
  end

  test 'show returns the scoring system details' do
    get game_scoring_system_path(@scoring, locale: 'en'), as: :json

    assert_response :success
    assert_equal '<table><tr><td>2 – 1</td></tr></table>', response.parsed_body['description_html']
    assert_equal 3, response.parsed_body['max_total_score']
  end
end
