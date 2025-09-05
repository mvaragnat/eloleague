# frozen_string_literal: true

class AddNonCompetitiveFlags < ActiveRecord::Migration[8.0]
  def change
    add_column :tournaments, :non_competitive, :boolean, default: false, null: false
    add_column :tournament_matches, :non_competitive, :boolean, default: false, null: false
    add_column :game_events, :non_competitive, :boolean, default: false, null: false

    add_index :tournaments, :non_competitive
    add_index :tournament_matches, :non_competitive
    add_index :game_events, :non_competitive
  end
end


