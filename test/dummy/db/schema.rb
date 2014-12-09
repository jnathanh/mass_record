# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20141208221412) do

  create_table "widgets", force: true do |t|
    t.binary   "binary"
    t.boolean  "boolean"
    t.date     "date"
    t.datetime "datetime"
    t.decimal  "decimal"
    t.float    "float"
    t.integer  "integer"
    t.integer  "references_id"
    t.string   "string"
    t.text     "text"
    t.time     "time"
    t.datetime "timestamp"
    t.text     "hstore"
    t.text     "json"
    t.text     "array"
    t.text     "cidr_address"
    t.text     "ip_address"
    t.text     "mac_address"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "widgets", ["references_id"], name: "index_widgets_on_references_id"

end
