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

ActiveRecord::Schema[8.1].define(version: 2026_11_25_120000) do
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

  create_table "api_token_events", force: :cascade do |t|
    t.bigint "api_token_id"
    t.bigint "actor_id"
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "action", null: false
    t.string "ip"
    t.jsonb "detail", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_api_token_events_on_actor_id"
    t.index ["api_token_id", "occurred_at"], name: "index_api_token_events_on_api_token_id_and_occurred_at"
    t.index ["occurred_at"], name: "index_api_token_events_on_occurred_at"
    t.index ["subject_type", "subject_id"], name: "index_api_token_events_on_subject"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "created_by_id"
    t.string "name", null: false
    t.string "kind", default: "personal", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.string "access_level", default: "read", null: false
    t.datetime "expires_at"
    t.integer "lifetime_days"
    t.datetime "paused_at"
    t.datetime "revoked_at"
    t.string "allowed_cidrs", default: [], null: false, array: true
    t.datetime "last_used_at"
    t.string "last_used_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_token_id"
    t.boolean "can_display_login_links", default: false, null: false
    t.index ["created_by_id"], name: "index_api_tokens_on_created_by_id"
    t.index ["kind", "expires_at"], name: "index_api_tokens_on_kind_and_expires_at"
    t.index ["kind"], name: "index_api_tokens_on_kind"
    t.index ["parent_token_id"], name: "index_api_tokens_on_parent_token_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
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
    t.jsonb "connect_detail"
    t.index ["job_id", "occurred_at"], name: "index_job_events_on_job_id_and_occurred_at"
    t.index ["job_id"], name: "index_job_events_on_job_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.datetime "claim_hold_at"
    t.text "clear_failure_detail"
    t.string "clear_failure_reason"
    t.string "clear_outcome"
    t.datetime "cleared_at"
    t.bigint "cleared_by_id"
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.datetime "estimated_finish_at"
    t.string "filename", null: false
    t.datetime "finished_notified_at"
    t.bigint "owner_id"
    t.bigint "printer_id", null: false
    t.boolean "private", default: false, null: false
    t.decimal "progress_percent", precision: 5, scale: 2
    t.string "prusalink_job_id"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.integer "time_printing_seconds"
    t.integer "total_duration_seconds"
    t.decimal "total_filament_grams", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["claim_hold_at"], name: "index_jobs_on_claim_hold_at", where: "(claim_hold_at IS NOT NULL)"
    t.index ["cleared_by_id"], name: "index_jobs_on_cleared_by_id"
    t.index ["owner_id"], name: "index_jobs_on_owner_id"
    t.index ["printer_id", "prusalink_job_id"], name: "idx_jobs_on_printer_and_prusalink_job_id", unique: true, where: "(prusalink_job_id IS NOT NULL)"
    t.index ["printer_id"], name: "index_jobs_on_printer_id"
    t.index ["private"], name: "index_jobs_on_private"
    t.index ["started_at"], name: "index_jobs_on_started_at"
    t.index ["status"], name: "index_jobs_on_status"
  end

  create_table "label_printers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cups_printer_name", null: false
    t.string "cups_printer_server"
    t.boolean "default_printer", default: false, null: false
    t.string "description"
    t.string "health_status", default: "unknown", null: false
    t.datetime "last_health_check_at"
    t.string "last_health_error"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "thermal_roll_width_mm"
    t.datetime "updated_at", null: false
    t.index ["cups_printer_name", "cups_printer_server"], name: "idx_on_cups_printer_name_cups_printer_server_8a21ab59a5", unique: true
    t.index ["name"], name: "index_label_printers_on_name", unique: true
  end

  create_table "login_links", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "requested_by_token_id"
    t.string "token_digest", null: false
    t.string "return_to", default: "/", null: false
    t.string "delivery", default: "email", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_login_links_on_expires_at"
    t.index ["requested_by_token_id"], name: "index_login_links_on_requested_by_token_id"
    t.index ["token_digest"], name: "index_login_links_on_token_digest", unique: true
    t.index ["user_id", "created_at"], name: "index_login_links_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_login_links_on_user_id"
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

  create_table "printer_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "from_material"
    t.text "message"
    t.datetime "occurred_at", null: false
    t.bigint "printer_id", null: false
    t.string "to_material"
    t.integer "tool_index"
    t.datetime "updated_at", null: false
    t.index ["occurred_at"], name: "index_printer_events_on_occurred_at"
    t.index ["printer_id", "occurred_at"], name: "index_printer_events_on_printer_id_and_occurred_at"
    t.index ["printer_id"], name: "index_printer_events_on_printer_id"
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
    t.string "prusa_connect_fingerprint"
    t.datetime "prusa_connect_last_uploaded_at"
    t.text "prusa_connect_token"
    t.datetime "prusalink_checked_at"
    t.text "prusalink_key"
    t.boolean "prusalink_reachable"
    t.datetime "updated_at", null: false
    t.string "prusa_connect_uuid"
    t.string "printer_type", default: "prusa", null: false
    t.string "bambu_serial"
    t.text "bambu_access_code"
    t.datetime "out_of_service_since"
    t.string "firmware_version"
    t.datetime "firmware_checked_at"
    t.jsonb "firmware_components", default: {}, null: false
    t.index ["name"], name: "index_printers_on_name", unique: true
    t.index ["out_of_service_since"], name: "index_printers_on_out_of_service_since", where: "(out_of_service_since IS NOT NULL)"
    t.index ["prusa_connect_uuid"], name: "index_printers_on_prusa_connect_uuid"
  end

  create_table "prusa_connect_credentials", force: :cascade do |t|
    t.text "refresh_token"
    t.text "access_token"
    t.datetime "access_token_expires_at"
    t.datetime "last_synced_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "service_entries", force: :cascade do |t|
    t.boolean "counts_toward_reliability", default: true, null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.boolean "automatic", default: false, null: false
    t.string "kind", null: false
    t.datetime "occurred_at", null: false
    t.bigint "printer_id", null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.bigint "resolving_repair_id"
    t.string "summary", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["kind", "occurred_at"], name: "index_service_entries_on_kind_and_occurred_at"
    t.index ["occurred_at"], name: "index_service_entries_on_occurred_at"
    t.index ["printer_id", "occurred_at"], name: "index_service_entries_on_printer_id_and_occurred_at"
    t.index ["printer_id"], name: "index_service_entries_on_open_problems", where: "((kind)::text = 'problem'::text) AND (resolved_at IS NULL)"
    t.index ["printer_id"], name: "index_service_entries_on_printer_id"
    t.index ["resolved_by_id"], name: "index_service_entries_on_resolved_by_id"
    t.index ["resolving_repair_id"], name: "index_service_entries_on_resolving_repair_id"
    t.index ["user_id"], name: "index_service_entries_on_user_id"
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
    t.text "email", null: false
    t.datetime "last_login_at"
    t.text "name"
    t.boolean "notify_via_email", default: true, null: false
    t.boolean "notify_via_slack", default: true, null: false
    t.string "provider", null: false
    t.text "slack_handle"
    t.text "slack_id"
    t.integer "total_print_seconds", default: 0, null: false
    t.boolean "trained_on_prusa"
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.text "username"
    t.text "member_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_login_at"], name: "index_users_on_last_login_at"
    t.index ["member_id"], name: "index_users_on_member_id", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_token_events", "api_tokens", on_delete: :nullify
  add_foreign_key "api_token_events", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "api_tokens", "api_tokens", column: "parent_token_id", on_delete: :cascade
  add_foreign_key "api_tokens", "users"
  add_foreign_key "api_tokens", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "job_events", "jobs"
  add_foreign_key "jobs", "printers"
  add_foreign_key "jobs", "users", column: "cleared_by_id"
  add_foreign_key "jobs", "users", column: "owner_id"
  add_foreign_key "login_links", "api_tokens", column: "requested_by_token_id", on_delete: :nullify
  add_foreign_key "login_links", "users", on_delete: :cascade
  add_foreign_key "photo_captures", "job_events"
  add_foreign_key "photo_captures", "jobs"
  add_foreign_key "photo_captures", "printers"
  add_foreign_key "printer_events", "printers"
  add_foreign_key "printer_heads", "printers"
  add_foreign_key "service_entries", "printers"
  add_foreign_key "service_entries", "service_entries", column: "resolving_repair_id", on_delete: :nullify
  add_foreign_key "service_entries", "users", column: "resolved_by_id", on_delete: :nullify
  add_foreign_key "service_entries", "users", column: "user_id", on_delete: :nullify
  add_foreign_key "telemetry_readings", "jobs"
  add_foreign_key "tools", "jobs"
end
