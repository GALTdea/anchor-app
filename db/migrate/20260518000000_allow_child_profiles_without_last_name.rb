class AllowChildProfilesWithoutLastName < ActiveRecord::Migration[8.1]
  def change
    change_column_null :child_profiles, :last_name, true
  end
end
