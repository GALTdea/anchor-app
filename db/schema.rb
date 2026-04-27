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

ActiveRecord::Schema[8.1].define(version: 2026_04_27_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_findings", force: :cascade do |t|
    t.bigint "analysis_run_id", null: false
    t.float "confidence"
    t.datetime "created_at", null: false
    t.string "dimension_key", null: false
    t.jsonb "evidence_refs", default: {}, null: false
    t.string "finding_key", null: false
    t.string "label"
    t.jsonb "metadata", default: {}, null: false
    t.float "score"
    t.string "severity"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["analysis_run_id", "dimension_key"], name: "index_analysis_findings_on_analysis_run_id_and_dimension_key"
    t.index ["analysis_run_id", "finding_key"], name: "index_analysis_findings_on_analysis_run_id_and_finding_key", unique: true
    t.index ["analysis_run_id"], name: "index_analysis_findings_on_analysis_run_id"
  end

  create_table "analysis_rubrics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "published_at"
    t.string "rubric_key", null: false
    t.jsonb "schema", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["rubric_key", "version"], name: "index_analysis_rubrics_on_rubric_key_and_version", unique: true
    t.index ["status"], name: "index_analysis_rubrics_on_status"
  end

  create_table "analysis_runs", force: :cascade do |t|
    t.bigint "analysis_rubric_id", null: false
    t.bigint "child_profile_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "engine_version"
    t.text "error_message"
    t.string "input_digest"
    t.bigint "profile_snapshot_id"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_rubric_id"], name: "index_analysis_runs_on_analysis_rubric_id"
    t.index ["child_profile_id", "analysis_rubric_id", "input_digest"], name: "index_analysis_runs_idempotency_completed", unique: true, where: "((status = 2) AND (input_digest IS NOT NULL))"
    t.index ["child_profile_id", "analysis_rubric_id"], name: "index_analysis_runs_on_child_profile_id_and_analysis_rubric_id"
    t.index ["child_profile_id", "created_at"], name: "index_analysis_runs_on_child_profile_id_and_created_at"
    t.index ["child_profile_id"], name: "index_analysis_runs_on_child_profile_id"
    t.index ["input_digest"], name: "index_analysis_runs_on_input_digest"
    t.index ["profile_snapshot_id"], name: "index_analysis_runs_on_profile_snapshot_id"
  end

  create_table "app_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["settings"], name: "index_app_settings_on_settings", using: :gin
  end

  create_table "assessment_responses", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.jsonb "answers", default: {}, null: false
    t.bigint "assessment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_processed_at"
    t.text "last_processing_error"
    t.string "processing_status"
    t.string "respondent_kind", null: false
    t.datetime "submitted_at"
    t.jsonb "template_schema_snapshot", default: {}, null: false
    t.string "template_slug_snapshot", null: false
    t.integer "template_version_snapshot", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_id"], name: "index_assessment_responses_on_assessment_id", unique: true
  end

  create_table "assessment_templates", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.jsonb "respondent_types", default: [], null: false
    t.jsonb "schema", default: {}, null: false
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.string "template_key", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["slug"], name: "index_assessment_templates_on_slug", unique: true
    t.index ["template_key", "version"], name: "index_assessment_templates_on_template_key_and_version", unique: true
  end

  create_table "assessments", force: :cascade do |t|
    t.bigint "assessment_template_id", null: false
    t.integer "assigned_to_user_id"
    t.bigint "child_profile_id", null: false
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_template_id"], name: "index_assessments_on_assessment_template_id"
    t.index ["child_profile_id"], name: "index_assessments_on_child_profile_id"
  end

  create_table "child_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.text "notes"
    t.string "slug"
    t.bigint "space_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_child_profiles_on_slug", unique: true
    t.index ["space_id"], name: "index_child_profiles_on_space_id"
  end

  create_table "current_profiles", force: :cascade do |t|
    t.bigint "child_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.text "narrative"
    t.integer "profile_version", default: 1, null: false
    t.jsonb "summary", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["child_profile_id"], name: "index_current_profiles_on_child_profile_id", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "onboarding_sessions", force: :cascade do |t|
    t.bigint "assessment_id"
    t.bigint "assessment_response_id"
    t.bigint "assessment_template_id", null: false
    t.date "child_date_of_birth"
    t.string "child_first_name"
    t.string "child_last_name"
    t.bigint "child_profile_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.jsonb "draft_answers", default: {}, null: false
    t.string "email"
    t.string "parent_name"
    t.bigint "space_id"
    t.datetime "started_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["assessment_id"], name: "index_onboarding_sessions_on_assessment_id"
    t.index ["assessment_response_id"], name: "index_onboarding_sessions_on_assessment_response_id"
    t.index ["assessment_template_id"], name: "index_onboarding_sessions_on_assessment_template_id"
    t.index ["child_profile_id"], name: "index_onboarding_sessions_on_child_profile_id"
    t.index ["space_id"], name: "index_onboarding_sessions_on_space_id"
    t.index ["status"], name: "index_onboarding_sessions_on_status"
    t.index ["user_id"], name: "index_onboarding_sessions_on_user_id"
  end

  create_table "plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "crm_id"
    t.string "currency", null: false
    t.string "description"
    t.string "duration", null: false
    t.string "name", null: false
    t.float "price", null: false
    t.datetime "updated_at", null: false
  end

  create_table "profile_evidences", force: :cascade do |t|
    t.bigint "child_profile_id", null: false
    t.string "concept_key", null: false
    t.float "confidence", null: false
    t.datetime "created_at", null: false
    t.string "dimension_key", null: false
    t.boolean "inferred", default: false, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "respondent_kind", null: false
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.string "value_type", null: false
    t.index ["child_profile_id", "concept_key"], name: "index_profile_evidences_on_child_profile_id_and_concept_key"
    t.index ["child_profile_id", "dimension_key"], name: "index_profile_evidences_on_child_profile_id_and_dimension_key"
    t.index ["child_profile_id"], name: "index_profile_evidences_on_child_profile_id"
    t.index ["source_type", "source_id"], name: "index_profile_evidences_on_source"
  end

  create_table "profile_snapshots", force: :cascade do |t|
    t.bigint "child_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.text "narrative"
    t.jsonb "summary", default: {}, null: false
    t.bigint "trigger_source_id"
    t.string "trigger_source_type"
    t.datetime "updated_at", null: false
    t.index ["child_profile_id", "generated_at"], name: "index_profile_snapshots_on_child_profile_id_and_generated_at"
    t.index ["child_profile_id"], name: "index_profile_snapshots_on_child_profile_id"
    t.index ["trigger_source_type", "trigger_source_id"], name: "index_profile_snapshots_on_trigger_source"
  end

  create_table "recommendations", force: :cascade do |t|
    t.text "body", null: false
    t.string "category", null: false
    t.bigint "child_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.jsonb "rationale", default: {}, null: false
    t.bigint "source_profile_snapshot_id", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["child_profile_id", "category"], name: "index_recommendations_on_child_profile_id_and_category"
    t.index ["child_profile_id"], name: "index_recommendations_on_child_profile_id"
    t.index ["source_profile_snapshot_id"], name: "index_recommendations_on_source_profile_snapshot_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.json "permissions", default: "{}", null: false
    t.integer "space_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["space_id"], name: "index_roles_on_space_id"
  end

  create_table "spaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "end_date"
    t.integer "plan_id", null: false
    t.integer "seats"
    t.integer "space_id", null: false
    t.datetime "start_date", null: false
    t.index ["end_date"], name: "index_subscriptions_on_end_date"
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["space_id"], name: "index_subscriptions_on_space_id"
  end

  create_table "user_roles", force: :cascade do |t|
    t.integer "role_id", null: false
    t.integer "space_id", null: false
    t.integer "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "space_id"], name: "index_user_roles_on_user_id_and_space_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_created_at"
    t.integer "invitation_limit"
    t.datetime "invitation_sent_at"
    t.string "invitation_token"
    t.integer "invited_by_id"
    t.string "invited_by_type"
    t.string "last_name"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "session_token"
    t.string "slug"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  add_foreign_key "analysis_findings", "analysis_runs"
  add_foreign_key "analysis_runs", "analysis_rubrics"
  add_foreign_key "analysis_runs", "child_profiles"
  add_foreign_key "analysis_runs", "profile_snapshots"
  add_foreign_key "assessment_responses", "assessments"
  add_foreign_key "assessment_responses", "users", column: "actor_id"
  add_foreign_key "assessments", "assessment_templates"
  add_foreign_key "assessments", "child_profiles"
  add_foreign_key "assessments", "users", column: "assigned_to_user_id"
  add_foreign_key "child_profiles", "spaces"
  add_foreign_key "current_profiles", "child_profiles"
  add_foreign_key "onboarding_sessions", "assessment_responses"
  add_foreign_key "onboarding_sessions", "assessment_templates"
  add_foreign_key "onboarding_sessions", "assessments"
  add_foreign_key "onboarding_sessions", "child_profiles"
  add_foreign_key "onboarding_sessions", "spaces"
  add_foreign_key "onboarding_sessions", "users"
  add_foreign_key "profile_evidences", "child_profiles"
  add_foreign_key "profile_snapshots", "child_profiles"
  add_foreign_key "recommendations", "child_profiles"
  add_foreign_key "recommendations", "profile_snapshots", column: "source_profile_snapshot_id"
  add_foreign_key "roles", "spaces"
end
