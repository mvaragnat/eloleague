# frozen_string_literal: true

class AddFirstRoundPairingStrategyKeyToTournaments < ActiveRecord::Migration[8.0]
  def change
    add_column :tournaments, :first_round_pairing_strategy_key, :string,
               null: false, default: 'random_avoid_same_affiliation'
  end
end
