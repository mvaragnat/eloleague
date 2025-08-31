class AddArmyListToGameParticipations < ActiveRecord::Migration[8.0]
  def change
    add_column :game_participations, :army_list, :text
  end
end


