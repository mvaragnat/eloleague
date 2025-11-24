class CreateGameScoringSystems < ActiveRecord::Migration[7.1]
  def change
    create_table :game_scoring_systems do |t|
      t.references :game_system, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :max_score_per_player
      t.integer :fix_total_score
      t.integer :min_difference_for_win
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end

    add_index :game_scoring_systems, %i[game_system_id is_default], name: 'idx_game_scoring_systems_default'
  end
end


