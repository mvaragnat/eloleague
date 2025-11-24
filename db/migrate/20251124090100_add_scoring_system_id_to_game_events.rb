class AddScoringSystemIdToGameEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :game_events, :scoring_system, foreign_key: { to_table: :game_scoring_systems }
  end
end


