# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180703161907) do

  create_table "users", force: :cascade do |t|
    t.integer "uid"
    t.integer "level", default: 0
    t.string "what"
    t.string "howmuch"
    t.string "username"
    t.string "sheet_id"
    t.string "jid"
    t.integer "setup", default: 2
    t.string "who"
    t.boolean "special", default: false
    t.string "note"
    t.string "last_cell"
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "company_id", default: 0
  end

  create_table "work_days", force: :cascade do |t|
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "aasm_state"
    t.date "date"
    t.index ["user_id"], name: "index_work_days_on_user_id"
  end

  create_table "work_sessions", force: :cascade do |t|
    t.integer "user_id"
    t.datetime "start_date"
    t.datetime "end_date"
    t.string "client"
    t.string "activity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "work_day_id"
    t.index ["user_id"], name: "index_work_sessions_on_user_id"
    t.index ["work_day_id"], name: "index_work_sessions_on_work_day_id"
  end

end
