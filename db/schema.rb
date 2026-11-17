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

ActiveRecord::Schema[8.1].define(version: 2026_11_17_150000) do
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
    t.boolean "shared", default: false, null: false
    t.integer "copies_count", default: 0, null: false
    t.bigint "source_deck_id"
    t.boolean "copied", default: false, null: false
    t.index ["source_deck_id"], name: "index_decks_on_source_deck_id"
    t.index ["user_id", "source_deck_id"], name: "index_decks_on_user_id_and_source_deck_id", unique: true
    t.index ["user_id"], name: "index_decks_on_user_id"
    t.check_constraint "NOT shared OR NOT copied AND source_deck_id IS NULL", name: "shared_decks_must_be_originals"
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
    t.integer "popular", default: 0, null: false
    t.index ["en", "ru"], name: "index_dictionary_entries_on_en_ru_pos", unique: true
    t.index ["popular", "rank", "id"], name: "index_dictionary_entries_on_popular_and_rank_and_id", order: { popular: :desc }
  end

  create_table "dictionary_views", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "word", null: false
    t.index ["user_id", "word"], name: "index_dictionary_views_on_user_id_and_word", unique: true
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
    t.string "time_zone", default: "UTC", null: false
    t.date "review_reminder_sent_on"
    t.index "lower((email_address)::text)", name: "index_users_on_lower_email_address", unique: true
  end

  add_foreign_key "card_progresses", "cards"
  add_foreign_key "cards", "decks"
  add_foreign_key "decks", "decks", column: "source_deck_id", on_delete: :nullify
  add_foreign_key "decks", "users"
  add_foreign_key "dictionary_views", "users", on_delete: :cascade
  add_foreign_key "session_answers", "cards"
  add_foreign_key "session_answers", "study_sessions"
  add_foreign_key "sessions", "users"
  add_foreign_key "study_sessions", "decks"
  add_foreign_key "study_sessions", "users"
end
