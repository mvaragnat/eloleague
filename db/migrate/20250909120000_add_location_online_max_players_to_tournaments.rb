# frozen_string_literal: true

class AddLocationOnlineMaxPlayersToTournaments < ActiveRecord::Migration[7.1]
  def change
    add_column :tournaments, :location, :string
    add_column :tournaments, :online, :boolean, null: false, default: false
    add_column :tournaments, :max_players, :integer

    add_index :tournaments, :online
  end
end


