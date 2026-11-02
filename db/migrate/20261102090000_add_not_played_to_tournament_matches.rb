# frozen_string_literal: true

# A match the organizer records without it being played (forfeit, no-show...):
# it counts for the tournament but is excluded from Elo and statistics.
class AddNotPlayedToTournamentMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :tournament_matches, :not_played, :boolean, default: false, null: false
  end
end
