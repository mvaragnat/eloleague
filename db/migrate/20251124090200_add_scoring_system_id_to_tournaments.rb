class AddScoringSystemIdToTournaments < ActiveRecord::Migration[7.1]
  def change
    add_reference :tournaments, :scoring_system, foreign_key: { to_table: :game_scoring_systems }
  end
end


