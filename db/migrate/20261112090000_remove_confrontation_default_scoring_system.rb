# frozen_string_literal: true

# Confrontation now has its own "Tournoi" scoring system (see config/game_systems.yml).
# Move the games and tournaments still on the unconstrained "Default" one to it, then delete "Default".
# Both systems decide wins the same way (no minimum difference), so match results are unchanged.
class RemoveConfrontationDefaultScoringSystem < ActiveRecord::Migration[8.0]
  def up
    system_id = select_value("SELECT id FROM game_systems WHERE name = 'Confrontation'")
    return unless system_id

    tournoi_id = scoring_system_id(system_id, 'Tournoi')
    default_id = scoring_system_id(system_id, 'Default')
    return unless tournoi_id && default_id

    execute("UPDATE game_events SET scoring_system_id = #{tournoi_id} WHERE scoring_system_id = #{default_id}")
    execute("UPDATE tournaments SET scoring_system_id = #{tournoi_id} WHERE scoring_system_id = #{default_id}")
    execute("UPDATE game_scoring_systems SET is_default = TRUE WHERE id = #{tournoi_id}")
    execute("DELETE FROM game_scoring_systems WHERE id = #{default_id}")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def scoring_system_id(system_id, name)
    select_value(
      "SELECT id FROM game_scoring_systems WHERE game_system_id = #{system_id.to_i} AND name = #{connection.quote(name)}"
    )
  end
end
