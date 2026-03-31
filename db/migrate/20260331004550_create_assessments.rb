class CreateAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :assessments do |t|
      t.references :child_profile, null: false, foreign_key: true
      t.references :assessment_template, null: false, foreign_key: true
      t.integer :assigned_to_user_id
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_foreign_key :assessments, :users, column: :assigned_to_user_id
  end
end
