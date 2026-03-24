# == Schema Information
#
# Table name: user_roles
#
#  id       :integer          not null, primary key
#  role_id  :integer          not null
#  space_id :integer          not null
#  user_id  :integer          not null
#
# Indexes
#
#  index_user_roles_on_role_id               (role_id)
#  index_user_roles_on_user_id_and_space_id  (user_id,space_id) UNIQUE
#
FactoryBot.define do
  factory :user_role do
    association :user
    association :space
    association :role
  end
end
