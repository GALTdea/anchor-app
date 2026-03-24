# frozen_string_literal: true

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
class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :space
  belongs_to :role

  validate :role_belongs_to_space

  private

  def role_belongs_to_space
    return if role.common?
    return if role.space == space

    errors.add(:base, "invalid role for space")
  end
end
