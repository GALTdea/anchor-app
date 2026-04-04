class CreateProfileEvidences < ActiveRecord::Migration[8.1]
  def change
    create_table :profile_evidences do |t|
      t.references :child_profile, null: false, foreign_key: true
      t.references :source, polymorphic: true, null: false
      t.string :dimension_key, null: false
      t.string :concept_key, null: false
      t.text :value, null: false
      t.string :value_type, null: false
      t.float :confidence, null: false
      t.string :respondent_kind, null: false
      t.datetime :recorded_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.boolean :inferred, null: false, default: false

      t.timestamps
    end

    add_index :profile_evidences, [ :child_profile_id, :dimension_key ]
    add_index :profile_evidences, [ :child_profile_id, :concept_key ]
  end
end
