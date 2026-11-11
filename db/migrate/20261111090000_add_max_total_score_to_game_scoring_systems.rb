# frozen_string_literal: true

class AddMaxTotalScoreToGameScoringSystems < ActiveRecord::Migration[8.0]
  def change
    add_column :game_scoring_systems, :max_total_score, :integer
  end
end
