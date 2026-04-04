class AddSecondBrainSnapshotFieldsToAssessmentResponses < ActiveRecord::Migration[8.1]
  def up
    add_column :assessment_responses, :template_slug_snapshot, :string
    add_column :assessment_responses, :template_version_snapshot, :integer
    add_column :assessment_responses, :template_schema_snapshot, :jsonb, null: false, default: {}
    add_column :assessment_responses, :processing_status, :string
    add_column :assessment_responses, :last_processed_at, :datetime
    add_column :assessment_responses, :last_processing_error, :text

    execute <<~SQL
      UPDATE assessment_responses responses
      SET
        template_slug_snapshot = templates.slug,
        template_version_snapshot = templates.version,
        template_schema_snapshot = templates.schema,
        processing_status = CASE
          WHEN responses.submitted_at IS NULL THEN NULL
          ELSE 'queued'
        END
      FROM assessments
      INNER JOIN assessment_templates templates
        ON templates.id = assessments.assessment_template_id
      WHERE responses.assessment_id = assessments.id
    SQL

    change_column_null :assessment_responses, :template_slug_snapshot, false
    change_column_null :assessment_responses, :template_version_snapshot, false
  end

  def down
    remove_column :assessment_responses, :last_processing_error
    remove_column :assessment_responses, :last_processed_at
    remove_column :assessment_responses, :processing_status
    remove_column :assessment_responses, :template_schema_snapshot
    remove_column :assessment_responses, :template_version_snapshot
    remove_column :assessment_responses, :template_slug_snapshot
  end
end
