# frozen_string_literal: true

# Switches from plain Elo to a Glicko-style player + faction rating.
# Existing ratings are discarded: run `rails elo:rebuild` after deploying.
class AddGlickoRatings < ActiveRecord::Migration[8.0]
  def up
    reset_ratings

    change_table :elo_ratings, bulk: true do |t|
      t.change_default :rating, from: 1200, to: 1500
      t.integer :rating_deviation, null: false, default: 350
      t.rename :last_updated_at, :last_played_at
    end

    change_table :elo_changes, bulk: true do |t|
      t.remove :k_factor, type: :integer
      t.integer :rd_before, null: false, default: 350
      t.integer :rd_after, null: false, default: 350
      t.references :faction, foreign_key: { to_table: :game_factions, on_delete: :nullify }
      t.integer :faction_rating_before
      t.integer :faction_rating_after
      t.integer :faction_rd_before
      t.integer :faction_rd_after
      t.float :faction_diversity
    end

    create_faction_tables
  end

  def down
    drop_table :faction_rating_resets
    drop_table :faction_ratings

    reset_ratings

    change_table :elo_changes, bulk: true do |t|
      t.remove :faction_diversity, type: :float
      t.remove :faction_rd_after, :faction_rd_before, :faction_rating_after, :faction_rating_before,
               type: :integer
      t.remove_references :faction, foreign_key: { to_table: :game_factions }
      t.remove :rd_after, :rd_before, type: :integer
      t.integer :k_factor, null: false, default: 30
    end

    change_table :elo_ratings, bulk: true do |t|
      t.rename :last_played_at, :last_updated_at
      t.remove :rating_deviation, type: :integer
      t.change_default :rating, from: 1500, to: 1200
    end
  end

  private

  def create_faction_tables
    create_table :faction_ratings do |t|
      t.references :faction, null: false, index: { unique: true },
                             foreign_key: { to_table: :game_factions, on_delete: :cascade }
      t.references :game_system, null: false, foreign_key: { to_table: :game_systems }
      t.integer :rating, null: false, default: 1500
      t.integer :rating_deviation, null: false, default: 150
      t.integer :games_played, null: false, default: 0
      # Concentration of the faction's recent games among players (see Elo::Calculator.diversity)
      t.float :effective_players
      t.integer :distinct_players
      t.float :diversity
      t.datetime :last_reset_at
      t.timestamps
    end

    create_table :faction_rating_resets do |t|
      t.references :faction, null: false, index: false,
                             foreign_key: { to_table: :game_factions, on_delete: :cascade }
      t.datetime :reset_at, null: false
      t.integer :rating_deviation, null: false
      t.timestamps
    end
    add_index :faction_rating_resets, %i[faction_id reset_at]
  end

  def reset_ratings
    execute 'DELETE FROM elo_changes'
    execute 'DELETE FROM elo_ratings'
    execute 'UPDATE game_events SET elo_applied = FALSE'
  end
end
