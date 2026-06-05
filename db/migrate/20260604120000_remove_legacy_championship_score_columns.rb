# frozen_string_literal: true

class RemoveLegacyChampionshipScoreColumns < ActiveRecord::Migration[8.0]
  def change
    remove_column :championship_scores, :match_points, :integer, default: 0, null: false
    remove_column :championship_scores, :placement_bonus, :integer, default: 0, null: false
  end
end
