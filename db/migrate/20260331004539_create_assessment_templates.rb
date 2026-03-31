class CreateAssessmentTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :assessment_templates do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.string :category
      t.jsonb :schema, null: false, default: {}
      t.jsonb :respondent_types, null: false, default: []
      t.integer :status, null: false, default: 0

      t.timestamps
    end
    add_index :assessment_templates, :slug, unique: true
  end
end
