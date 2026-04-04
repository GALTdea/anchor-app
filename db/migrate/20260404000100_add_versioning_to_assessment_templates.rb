class AddVersioningToAssessmentTemplates < ActiveRecord::Migration[8.1]
  def up
    add_column :assessment_templates, :template_key, :string
    add_column :assessment_templates, :version, :integer, null: false, default: 1

    execute <<~SQL
      UPDATE assessment_templates
      SET template_key = slug
      WHERE template_key IS NULL
    SQL

    change_column_null :assessment_templates, :template_key, false
    add_index :assessment_templates, [ :template_key, :version ], unique: true
  end

  def down
    remove_index :assessment_templates, [ :template_key, :version ]
    remove_column :assessment_templates, :version
    remove_column :assessment_templates, :template_key
  end
end
