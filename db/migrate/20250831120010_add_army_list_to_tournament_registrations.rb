class AddArmyListToTournamentRegistrations < ActiveRecord::Migration[8.0]
  def change
    add_column :tournament_registrations, :army_list, :text
  end
end


