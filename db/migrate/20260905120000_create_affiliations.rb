# frozen_string_literal: true

class CreateAffiliations < ActiveRecord::Migration[8.0]
  def change
    create_table :affiliations do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :affiliations, 'LOWER(name)', unique: true, name: 'index_affiliations_on_lower_name'

    add_reference :tournament_registrations, :affiliation, foreign_key: true
  end
end
