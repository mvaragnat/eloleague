# frozen_string_literal: true

class CreateChampionshipScores < ActiveRecord::Migration[8.0]
  def change
    create_table :championship_scores do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tournament, null: false, foreign_key: true
      t.references :game_system, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :match_points, null: false, default: 0
      t.integer :placement_bonus, null: false, default: 0
      t.integer :total_points, null: false, default: 0

      t.timestamps
    end

    add_index :championship_scores, %i[user_id tournament_id], unique: true
    add_index :championship_scores, %i[game_system_id year]
  end
end
