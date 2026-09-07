# frozen_string_literal: true

class AddRegistrationValidationToTournaments < ActiveRecord::Migration[8.0]
  def change
    add_column :tournaments, :require_registration_validation, :boolean, null: false, default: false
    add_column :tournament_registrations, :validated, :boolean, null: false, default: false
    add_index :tournament_registrations, %i[tournament_id validated]
  end
end
