# == Schema Information
#
# Table name: roles
#
#  id          :integer          not null, primary key
#  name        :string
#  permissions :json             not null
#  type        :string
#  value       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  space_id    :integer
#
# Indexes
#
#  index_roles_on_space_id  (space_id)
#
# Foreign Keys
#
#  space_id  (space_id => spaces.id)
#
FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "Role #{n}" }
    permissions { {} }
    type { "common" }

    trait :common do
      type { "common" }
      name { "admin" }
      permissions { { "create_user" => "true", "read_user" => "true", "update_user" => "true", "delete_user" => "true" } }
    end

    trait :custom do
      type { "custom" }
      name { "member" }
      permissions { { "read_user" => "true" } }
    end
  end
end
