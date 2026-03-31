class CreateAssessmentResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :assessment_responses do |t|
      t.references :assessment, null: false, foreign_key: true, index: { unique: true }
      t.integer :actor_id, null: false
      t.string :respondent_kind, null: false
      t.jsonb :answers, null: false, default: {}
      t.datetime :submitted_at

      t.timestamps
    end

    add_foreign_key :assessment_responses, :users, column: :actor_id
  end
end
