# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_18_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admins", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "elo_changes", force: :cascade do |t|
    t.bigint "game_event_id", null: false
    t.bigint "user_id", null: false
    t.bigint "game_system_id", null: false
    t.integer "rating_before", null: false
    t.integer "rating_after", null: false
    t.decimal "expected_score", precision: 5, scale: 3, null: false
    t.decimal "actual_score", precision: 3, scale: 2, null: false
    t.integer "k_factor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_event_id", "user_id"], name: "index_elo_changes_on_game_event_id_and_user_id", unique: true
    t.index ["game_event_id"], name: "index_elo_changes_on_game_event_id"
    t.index ["game_system_id"], name: "index_elo_changes_on_game_system_id"
    t.index ["user_id", "game_system_id"], name: "index_elo_changes_on_user_id_and_game_system_id"
    t.index ["user_id"], name: "index_elo_changes_on_user_id"
  end

  create_table "elo_ratings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "game_system_id", null: false
    t.integer "rating", default: 1200, null: false
    t.integer "games_played", default: 0, null: false
    t.datetime "last_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_system_id"], name: "index_elo_ratings_on_game_system_id"
    t.index ["user_id", "game_system_id"], name: "index_elo_ratings_on_user_id_and_game_system_id", unique: true
    t.index ["user_id"], name: "index_elo_ratings_on_user_id"
  end

  create_table "game_events", force: :cascade do |t|
    t.bigint "game_system_id", null: false
    t.datetime "played_at", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "elo_applied", default: false, null: false
    t.bigint "tournament_id"
    t.boolean "non_competitive", default: false, null: false
    t.index ["elo_applied"], name: "index_game_events_on_elo_applied"
    t.index ["game_system_id"], name: "index_game_events_on_game_system_id"
    t.index ["non_competitive"], name: "index_game_events_on_non_competitive"
    t.index ["played_at"], name: "index_game_events_on_played_at"
    t.index ["tournament_id"], name: "index_game_events_on_tournament_id"
  end

  create_table "game_factions", force: :cascade do |t|
    t.bigint "game_system_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_system_id", "name"], name: "index_game_factions_on_game_system_id_and_name", unique: true
    t.index ["game_system_id"], name: "index_game_factions_on_game_system_id"
  end

  create_table "game_participations", force: :cascade do |t|
    t.bigint "game_event_id", null: false
    t.bigint "user_id", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "score"
    t.bigint "faction_id"
    t.integer "secondary_score"
    t.text "army_list"
    t.index ["faction_id"], name: "index_game_participations_on_faction_id"
    t.index ["game_event_id", "user_id"], name: "index_game_participations_on_game_event_id_and_user_id", unique: true
    t.index ["game_event_id"], name: "index_game_participations_on_game_event_id"
    t.index ["user_id"], name: "index_game_participations_on_user_id"
  end

  create_table "game_systems", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_game_systems_on_name", unique: true
  end

  create_table "tournament_matches", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.bigint "tournament_round_id"
    t.bigint "a_user_id"
    t.bigint "b_user_id"
    t.string "result", default: "pending", null: false
    t.datetime "reported_at"
    t.bigint "game_event_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_match_id"
    t.string "child_slot"
    t.boolean "non_competitive", default: false, null: false
    t.index ["a_user_id"], name: "index_tournament_matches_on_a_user_id"
    t.index ["b_user_id"], name: "index_tournament_matches_on_b_user_id"
    t.index ["game_event_id"], name: "index_tournament_matches_on_game_event_id"
    t.index ["non_competitive"], name: "index_tournament_matches_on_non_competitive"
    t.index ["parent_match_id"], name: "index_tournament_matches_on_parent_match_id"
    t.index ["tournament_id", "tournament_round_id"], name: "idx_on_tournament_id_tournament_round_id_e9fc8dbd6c"
    t.index ["tournament_id"], name: "index_tournament_matches_on_tournament_id"
    t.index ["tournament_round_id"], name: "index_tournament_matches_on_tournament_round_id"
  end

  create_table "tournament_registrations", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.bigint "user_id", null: false
    t.integer "seed"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "faction_id"
    t.text "army_list"
    t.index ["faction_id"], name: "index_tournament_registrations_on_faction_id"
    t.index ["tournament_id", "user_id"], name: "index_tournament_registrations_on_tournament_id_and_user_id", unique: true
    t.index ["tournament_id"], name: "index_tournament_registrations_on_tournament_id"
    t.index ["user_id"], name: "index_tournament_registrations_on_user_id"
  end

  create_table "tournament_rounds", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.integer "number", null: false
    t.string "state", default: "pending", null: false
    t.datetime "paired_at"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tournament_id", "number"], name: "index_tournament_rounds_on_tournament_id_and_number", unique: true
    t.index ["tournament_id"], name: "index_tournament_rounds_on_tournament_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "creator_id", null: false
    t.bigint "game_system_id", null: false
    t.integer "format", default: 0, null: false
    t.integer "rounds_count"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.string "state", default: "draft", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pairing_strategy_key", default: "by_points_random_within_group", null: false
    t.string "tiebreak1_strategy_key", default: "score_sum", null: false
    t.string "tiebreak2_strategy_key", default: "none", null: false
    t.boolean "require_army_list_for_check_in", default: false, null: false
    t.boolean "non_competitive", default: false, null: false
    t.string "location"
    t.boolean "online", default: false, null: false
    t.integer "max_players"
    t.string "primary_strategy_key", default: "points", null: false
    t.index ["creator_id"], name: "index_tournaments_on_creator_id"
    t.index ["format"], name: "index_tournaments_on_format"
    t.index ["game_system_id"], name: "index_tournaments_on_game_system_id"
    t.index ["non_competitive"], name: "index_tournaments_on_non_competitive"
    t.index ["online"], name: "index_tournaments_on_online"
    t.index ["slug"], name: "index_tournaments_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "elo_changes", "game_events"
  add_foreign_key "elo_changes", "game_systems"
  add_foreign_key "elo_changes", "users"
  add_foreign_key "elo_ratings", "game_systems"
  add_foreign_key "elo_ratings", "users"
  add_foreign_key "game_events", "game_systems"
  add_foreign_key "game_events", "tournaments"
  add_foreign_key "game_factions", "game_systems"
  add_foreign_key "game_participations", "game_events"
  add_foreign_key "game_participations", "game_factions", column: "faction_id"
  add_foreign_key "game_participations", "users"
  add_foreign_key "tournament_matches", "game_events"
  add_foreign_key "tournament_matches", "tournament_matches", column: "parent_match_id"
  add_foreign_key "tournament_matches", "tournament_rounds"
  add_foreign_key "tournament_matches", "tournaments"
  add_foreign_key "tournament_matches", "users", column: "a_user_id"
  add_foreign_key "tournament_matches", "users", column: "b_user_id"
  add_foreign_key "tournament_registrations", "game_factions", column: "faction_id"
  add_foreign_key "tournament_registrations", "tournaments"
  add_foreign_key "tournament_registrations", "users"
  add_foreign_key "tournament_rounds", "tournaments"
  add_foreign_key "tournaments", "game_systems"
  add_foreign_key "tournaments", "users", column: "creator_id"
end
