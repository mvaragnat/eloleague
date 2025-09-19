# frozen_string_literal: true

class AddPrimaryStrategyKeyToTournaments < ActiveRecord::Migration[7.2]
  def change
    add_column :tournaments, :primary_strategy_key, :string, null: false, default: 'points'
  end
end


