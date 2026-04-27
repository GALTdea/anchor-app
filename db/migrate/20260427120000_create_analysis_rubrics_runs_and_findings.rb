# frozen_string_literal: true

class CreateAnalysisRubricsRunsAndFindings < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_rubrics do |t|
      t.string :name, null: false
      t.string :rubric_key, null: false
      t.integer :version, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.text :description
      t.jsonb :schema, null: false, default: {}
      t.datetime :published_at

      t.timestamps
    end

    add_index :analysis_rubrics, %i[rubric_key version], unique: true
    add_index :analysis_rubrics, :status

    create_table :analysis_runs do |t|
      t.references :child_profile, null: false, foreign_key: true
      t.references :analysis_rubric, null: false, foreign_key: true
      t.references :profile_snapshot, null: true, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.string :input_digest
      t.string :engine_version

      t.timestamps
    end

    add_index :analysis_runs, %i[child_profile_id analysis_rubric_id]
    add_index :analysis_runs, %i[child_profile_id created_at]
    add_index :analysis_runs, :input_digest

    # One successful run per (child, rubric, input) for idempotency
    add_index :analysis_runs, %i[child_profile_id analysis_rubric_id input_digest],
      unique: true,
      where: "status = 2 AND input_digest IS NOT NULL",
      name: "index_analysis_runs_idempotency_completed"

    create_table :analysis_findings do |t|
      t.references :analysis_run, null: false, foreign_key: true
      t.string :dimension_key, null: false
      t.string :finding_key, null: false
      t.float :score
      t.float :confidence
      t.string :severity
      t.string :label
      t.text :summary
      t.jsonb :evidence_refs, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :analysis_findings, %i[analysis_run_id finding_key], unique: true
    add_index :analysis_findings, %i[analysis_run_id dimension_key]
  end
end
