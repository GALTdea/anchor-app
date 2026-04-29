# frozen_string_literal: true

class CreateAiSynthesisRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_synthesis_runs do |t|
      t.references :analysis_run, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :purpose, null: false
      t.string :provider
      t.string :model
      t.string :prompt_version
      t.jsonb :request_payload, null: false, default: {}
      t.jsonb :response_payload, null: false, default: {}
      t.jsonb :output, null: false, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end

    add_index :ai_synthesis_runs,
              [ :analysis_run_id, :purpose, :prompt_version ],
              name: "index_ai_synthesis_runs_analysis_purpose_prompt"
  end
end
