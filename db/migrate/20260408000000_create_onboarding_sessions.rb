# frozen_string_literal: true

class CreateOnboardingSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_sessions do |t|
      t.integer :status, null: false, default: 0
      t.string :email
      t.string :parent_name
      t.string :child_first_name
      t.string :child_last_name
      t.date :child_date_of_birth
      t.jsonb :draft_answers, null: false, default: {}
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.references :assessment_template, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :space, foreign_key: true
      t.references :child_profile, foreign_key: true
      t.references :assessment, foreign_key: true
      t.references :assessment_response, foreign_key: true

      t.timestamps
    end

    add_index :onboarding_sessions, :status
  end
end
