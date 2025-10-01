class AddScoreForByeToTournaments < ActiveRecord::Migration[8.0]
  def change
    add_column :tournaments, :score_for_bye, :integer, default: 0, null: false
  end
end
