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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_105238) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "card_progresses", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.integer "level", default: 0
    t.date "next_review_at"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_card_progresses_on_card_id"
  end

  create_table "cards", force: :cascade do |t|
    t.bigint "deck_id", null: false
    t.string "front"
    t.string "back"
    t.string "example"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deck_id"], name: "index_cards_on_deck_id"
  end

  create_table "decks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.integer "direction"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_decks_on_user_id"
  end

  create_table "dictionary_entries", force: :cascade do |t|
    t.string "en"
    t.string "ru"
    t.string "part_of_speech"
    t.text "example_en"
    t.text "example_ru"
    t.integer "rank"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["en", "ru"], name: "index_dictionary_entries_on_en_ru_pos", unique: true
  end

  create_table "session_answers", force: :cascade do |t|
    t.bigint "study_session_id", null: false
    t.bigint "card_id", null: false
    t.integer "rating"
    t.boolean "is_correct"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_session_answers_on_card_id"
    t.index ["study_session_id"], name: "index_session_answers_on_study_session_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "study_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "deck_id", null: false
    t.integer "mode"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deck_id"], name: "index_study_sessions_on_deck_id"
    t.index ["user_id"], name: "index_study_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "daily_goal", default: 20
    t.index "lower((email_address)::text)", name: "index_users_on_lower_email_address", unique: true
  end

  add_foreign_key "card_progresses", "cards"
  add_foreign_key "cards", "decks"
  add_foreign_key "decks", "users"
  add_foreign_key "session_answers", "cards"
  add_foreign_key "session_answers", "study_sessions"
  add_foreign_key "sessions", "users"
  add_foreign_key "study_sessions", "decks"
  add_foreign_key "study_sessions", "users"
end
