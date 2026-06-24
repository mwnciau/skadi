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

ActiveRecord::Schema[8.1].define(version: 2026_06_06_201634) do
  create_table "dummy_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
  end

  create_table "skadi_demographics", force: :cascade do |t|
    t.integer "count", default: 0, null: false
    t.string "name", null: false
    t.date "recorded_on", null: false
    t.string "uri", null: false
    t.string "value", null: false
    t.index ["uri", "name", "value", "recorded_on"], name: "idx_on_uri_name_value_recorded_on_79f5412e49", unique: true
  end

  create_table "skadi_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.json "properties"
    t.integer "view_id"
    t.integer "visit_id"
    t.index ["name", "created_at"], name: "index_skadi_events_on_name_and_created_at"
    t.index ["view_id", "created_at"], name: "index_skadi_events_on_view_id_and_created_at"
    t.index ["visit_id", "created_at"], name: "index_skadi_events_on_visit_id_and_created_at"
  end

  create_table "skadi_views", force: :cascade do |t|
    t.string "action", null: false
    t.string "controller", null: false
    t.datetime "created_at", null: false
    t.text "exit_page"
    t.text "path", null: false
    t.json "query_params"
    t.text "referrer"
    t.datetime "updated_at", null: false
    t.string "verb", null: false
    t.boolean "verified", default: false, null: false
    t.string "version"
    t.string "view_token", limit: 36, null: false
    t.integer "visit_id"
    t.index ["path", "created_at"], name: "index_skadi_views_on_path_and_created_at"
    t.index ["view_token"], name: "index_skadi_views_on_view_token", unique: true
    t.index ["visit_id", "created_at"], name: "index_skadi_views_on_visit_id_and_created_at"
  end

  create_table "skadi_visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "landing_page"
    t.text "referrer"
    t.string "tracking_token", limit: 36
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.text "utm_campaign"
    t.text "utm_content"
    t.text "utm_medium"
    t.text "utm_source"
    t.text "utm_term"
    t.boolean "verified", default: false, null: false
    t.string "visit_token", limit: 36, null: false
    t.index ["created_at"], name: "index_skadi_visits_on_created_at"
    t.index ["tracking_token", "created_at"], name: "index_skadi_visits_on_tracking_token_and_created_at"
    t.index ["user_id", "created_at"], name: "index_skadi_visits_on_user_id_and_created_at"
    t.index ["visit_token"], name: "index_skadi_visits_on_visit_token", unique: true
  end

  add_foreign_key "skadi_events", "skadi_views", column: "view_id", on_delete: :cascade
  add_foreign_key "skadi_events", "skadi_visits", column: "visit_id", on_delete: :cascade
  add_foreign_key "skadi_views", "skadi_visits", column: "visit_id", on_delete: :cascade
end
