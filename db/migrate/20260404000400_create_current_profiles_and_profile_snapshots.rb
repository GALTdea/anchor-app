class CreateCurrentProfilesAndProfileSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :current_profiles do |t|
      t.references :child_profile, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :summary, null: false, default: {}
      t.text :narrative
      t.datetime :generated_at, null: false
      t.integer :profile_version, null: false, default: 1

      t.timestamps
    end

    create_table :profile_snapshots do |t|
      t.references :child_profile, null: false, foreign_key: true
      t.jsonb :summary, null: false, default: {}
      t.text :narrative
      t.datetime :generated_at, null: false
      t.references :trigger_source, polymorphic: true

      t.timestamps
    end

    add_index :profile_snapshots, [ :child_profile_id, :generated_at ]
  end
end
