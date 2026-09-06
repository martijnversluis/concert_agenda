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

ActiveRecord::Schema[8.1].define(version: 2026_07_22_204512) do
  create_table "artists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "genres", default: []
    t.string "image_url"
    t.string "name", null: false
    t.string "name_normalized", null: false
    t.json "similar_artist_names"
    t.string "spotify_id"
    t.datetime "spotify_looked_up_at"
    t.datetime "updated_at", null: false
    t.index ["name_normalized"], name: "index_artists_on_name_normalized"
    t.index ["spotify_id"], name: "index_artists_on_spotify_id", unique: true
  end

  create_table "concerts", force: :cascade do |t|
    t.integer "artist_id"
    t.string "artist_name"
    t.string "artist_name_normalized"
    t.string "cover_band_name"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "image_url"
    t.decimal "max_price", precision: 10, scale: 2
    t.decimal "min_price", precision: 10, scale: 2
    t.string "price_currency", limit: 3
    t.string "source", null: false
    t.datetime "starts_at"
    t.date "starts_on"
    t.string "title"
    t.boolean "tribute"
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "venue_id"
    t.index ["artist_id"], name: "index_concerts_on_artist_id"
    t.index ["artist_name_normalized"], name: "index_concerts_on_artist_name_normalized"
    t.index ["source", "external_id"], name: "index_concerts_on_source_and_external_id", unique: true
    t.index ["starts_on"], name: "index_concerts_on_starts_on"
    t.index ["venue_id"], name: "index_concerts_on_venue_id"
  end

  create_table "hidden_artists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "image_url"
    t.string "name"
    t.string "spotify_artist_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "spotify_artist_id"], name: "index_hidden_artists_on_user_id_and_spotify_artist_id", unique: true
    t.index ["user_id"], name: "index_hidden_artists_on_user_id"
  end

  create_table "top_artists", force: :cascade do |t|
    t.integer "best_rank"
    t.datetime "created_at", null: false
    t.json "genres"
    t.string "image_url"
    t.boolean "manual", default: false, null: false
    t.string "name", null: false
    t.string "name_normalized", null: false
    t.string "spotify_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["name_normalized"], name: "index_top_artists_on_name_normalized"
    t.index ["user_id", "spotify_id"], name: "index_top_artists_on_user_id_and_spotify_id", unique: true
    t.index ["user_id"], name: "index_top_artists_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "access_token"
    t.datetime "concerts_synced_at"
    t.datetime "concerts_syncing_since"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email"
    t.string "image_url"
    t.string "refresh_token"
    t.string "spotify_id"
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.index ["spotify_id"], name: "index_users_on_spotify_id", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  add_foreign_key "concerts", "artists"
  add_foreign_key "concerts", "venues"
  add_foreign_key "hidden_artists", "users"
  add_foreign_key "top_artists", "users"
end
