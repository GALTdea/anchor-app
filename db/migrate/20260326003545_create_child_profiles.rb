class CreateChildProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :child_profiles do |t|
      t.references :space, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.date :date_of_birth, null: false
      t.integer :status, null: false, default: 0
      t.text :notes
      t.string :slug

      t.timestamps
    end
    add_index :child_profiles, :slug, unique: true
  end
end
