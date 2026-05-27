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

ActiveRecord::Schema[8.1].define(version: 2026_05_26_240000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "job_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "from_status"
    t.bigint "job_id", null: false
    t.text "message"
    t.datetime "occurred_at", null: false
    t.string "to_status"
    t.datetime "updated_at", null: false
    t.index ["job_id", "occurred_at"], name: "index_job_events_on_job_id_and_occurred_at"
    t.index ["job_id"], name: "index_job_events_on_job_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.string "filename", null: false
    t.bigint "owner_id"
    t.bigint "printer_id", null: false
    t.string "prusalink_job_id"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.integer "total_duration_seconds"
    t.decimal "total_filament_grams", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_jobs_on_owner_id"
    t.index ["printer_id", "prusalink_job_id"], name: "idx_jobs_on_printer_and_prusalink_job_id", unique: true, where: "(prusalink_job_id IS NOT NULL)"
    t.index ["printer_id"], name: "index_jobs_on_printer_id"
    t.index ["started_at"], name: "index_jobs_on_started_at"
    t.index ["status"], name: "index_jobs_on_status"
  end

  create_table "photo_captures", force: :cascade do |t|
    t.datetime "captured_at", null: false
    t.datetime "created_at", null: false
    t.bigint "job_event_id"
    t.bigint "job_id"
    t.bigint "printer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["job_event_id"], name: "index_photo_captures_on_job_event_id"
    t.index ["job_id", "captured_at"], name: "index_photo_captures_on_job_id_and_captured_at"
    t.index ["job_id"], name: "index_photo_captures_on_job_id"
    t.index ["printer_id", "captured_at"], name: "index_photo_captures_on_printer_id_and_captured_at"
    t.index ["printer_id"], name: "index_photo_captures_on_printer_id"
  end

  create_table "printer_heads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "high_flow", default: false, null: false
    t.string "material"
    t.decimal "nozzle_size_mm", precision: 4, scale: 2, null: false
    t.bigint "printer_id", null: false
    t.integer "tool_index", null: false
    t.datetime "updated_at", null: false
    t.index ["printer_id", "tool_index"], name: "index_printer_heads_on_printer_id_and_tool_index", unique: true
    t.index ["printer_id"], name: "index_printer_heads_on_printer_id"
  end

  create_table "printers", force: :cascade do |t|
    t.decimal "ambient_temp", precision: 6, scale: 2
    t.string "camera_url"
    t.datetime "created_at", null: false
    t.decimal "enclosure_humidity", precision: 6, scale: 2
    t.decimal "enclosure_temp", precision: 6, scale: 2
    t.datetime "environment_updated_at"
    t.string "ha_base_sensor"
    t.string "hostname", null: false
    t.string "location"
    t.string "model"
    t.string "name", null: false
    t.string "operational_state", default: "unknown", null: false
    t.datetime "prusalink_checked_at"
    t.text "prusalink_key"
    t.boolean "prusalink_reachable"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_printers_on_name", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "telemetry_readings", force: :cascade do |t|
    t.decimal "ambient_temp", precision: 6, scale: 2
    t.decimal "bed_temp", precision: 6, scale: 2
    t.datetime "created_at", null: false
    t.decimal "enclosure_humidity", precision: 6, scale: 2
    t.decimal "enclosure_temp", precision: 6, scale: 2
    t.bigint "job_id", null: false
    t.datetime "recorded_at", null: false
    t.jsonb "tool_temps", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["job_id", "recorded_at"], name: "index_telemetry_readings_on_job_id_and_recorded_at"
    t.index ["job_id"], name: "index_telemetry_readings_on_job_id"
  end

  create_table "tools", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "high_flow", default: false, null: false
    t.bigint "job_id", null: false
    t.string "material"
    t.decimal "nozzle_size_mm", precision: 4, scale: 2, null: false
    t.integer "tool_index", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id", "tool_index"], name: "index_tools_on_job_id_and_tool_index", unique: true
    t.index ["job_id"], name: "index_tools_on_job_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "job_events", "jobs"
  add_foreign_key "jobs", "printers"
  add_foreign_key "jobs", "users", column: "owner_id"
  add_foreign_key "photo_captures", "job_events"
  add_foreign_key "photo_captures", "jobs"
  add_foreign_key "photo_captures", "printers"
  add_foreign_key "printer_heads", "printers"
  add_foreign_key "telemetry_readings", "jobs"
  add_foreign_key "tools", "jobs"
end
