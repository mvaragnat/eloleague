class AddCounterCaches < ActiveRecord::Migration[7.1]
  def up
    add_column :game_factions, :game_participations_count, :integer, null: false, default: 0
    add_column :tournaments, :tournament_registrations_count, :integer, null: false, default: 0

    # Backfill
    say_with_time 'Backfilling game_participations_count' do
      execute <<~SQL
        UPDATE game_factions
        SET game_participations_count = sub.cnt
        FROM (
          SELECT faction_id, COUNT(*) AS cnt
          FROM game_participations
          GROUP BY faction_id
        ) AS sub
        WHERE game_factions.id = sub.faction_id
      SQL
    end

    say_with_time 'Backfilling tournament_registrations_count' do
      execute <<~SQL
        UPDATE tournaments
        SET tournament_registrations_count = sub.cnt
        FROM (
          SELECT tournament_id, COUNT(*) AS cnt
          FROM tournament_registrations
          GROUP BY tournament_id
        ) AS sub
        WHERE tournaments.id = sub.tournament_id
      SQL
    end
  end

  def down
    remove_column :game_factions, :game_participations_count
    remove_column :tournaments, :tournament_registrations_count
  end
end


