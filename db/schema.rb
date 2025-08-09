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

ActiveRecord::Schema[8.0].define(version: 2025_08_09_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.index ["elo_applied"], name: "index_game_events_on_elo_applied"
    t.index ["game_system_id"], name: "index_game_events_on_game_system_id"
    t.index ["played_at"], name: "index_game_events_on_played_at"
    t.index ["tournament_id"], name: "index_game_events_on_tournament_id"
  end

  create_table "game_participations", force: :cascade do |t|
    t.bigint "game_event_id", null: false
    t.bigint "user_id", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "score"
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

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tournament_matches", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.bigint "tournament_round_id"
    t.bigint "a_user_id", null: false
    t.bigint "b_user_id", null: false
    t.string "result", default: "pending", null: false
    t.datetime "reported_at"
    t.bigint "game_event_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["a_user_id"], name: "index_tournament_matches_on_a_user_id"
    t.index ["b_user_id"], name: "index_tournament_matches_on_b_user_id"
    t.index ["game_event_id"], name: "index_tournament_matches_on_game_event_id"
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
    t.string "format", null: false
    t.integer "rounds_count"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.string "state", default: "draft", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_tournaments_on_creator_id"
    t.index ["game_system_id"], name: "index_tournaments_on_game_system_id"
    t.index ["slug"], name: "index_tournaments_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "email_address", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "elo_changes", "game_events"
  add_foreign_key "elo_changes", "game_systems"
  add_foreign_key "elo_changes", "users"
  add_foreign_key "elo_ratings", "game_systems"
  add_foreign_key "elo_ratings", "users"
  add_foreign_key "game_events", "game_systems"
  add_foreign_key "game_events", "tournaments"
  add_foreign_key "game_participations", "game_events"
  add_foreign_key "game_participations", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "tournament_matches", "game_events"
  add_foreign_key "tournament_matches", "tournament_rounds"
  add_foreign_key "tournament_matches", "tournaments"
  add_foreign_key "tournament_matches", "users", column: "a_user_id"
  add_foreign_key "tournament_matches", "users", column: "b_user_id"
  add_foreign_key "tournament_registrations", "tournaments"
  add_foreign_key "tournament_registrations", "users"
  add_foreign_key "tournament_rounds", "tournaments"
  add_foreign_key "tournaments", "game_systems"
  add_foreign_key "tournaments", "users", column: "creator_id"
end
