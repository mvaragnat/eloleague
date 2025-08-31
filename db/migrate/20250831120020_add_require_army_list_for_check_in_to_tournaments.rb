class AddRequireArmyListForCheckInToTournaments < ActiveRecord::Migration[8.0]
  def change
    add_column :tournaments, :require_army_list_for_check_in, :boolean, null: false, default: false
  end
end


