# frozen_string_literal: true

class AddChampionshipLevelToTournaments < ActiveRecord::Migration[8.0]
  def change
    add_column :tournaments, :championship_level, :string
  end
end
