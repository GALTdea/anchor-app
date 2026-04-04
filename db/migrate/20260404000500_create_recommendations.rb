class CreateRecommendations < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendations do |t|
      t.references :child_profile, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :category, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.jsonb :rationale, null: false, default: {}
      t.datetime :generated_at, null: false
      t.references :source_profile_snapshot, foreign_key: { to_table: :profile_snapshots }, null: false

      t.timestamps
    end

    add_index :recommendations, [ :child_profile_id, :category ]
  end
end
