class AddTableNumberToTournamentMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :tournament_matches, :table_number, :integer
    add_index :tournament_matches, [:tournament_round_id, :table_number], name: 'idx_round_table_number'
  end
end


