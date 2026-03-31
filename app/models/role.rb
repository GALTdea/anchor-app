# frozen_string_literal: true

# == Schema Information
#
# Table name: roles
# Database name: primary
#
#  id          :bigint           not null, primary key
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
#  fk_rails_...  (space_id => spaces.id)
#
class Role < ApplicationRecord
  self.store_full_sti_class = false

  attribute :permissions, :json, default: {}

  belongs_to :space, optional: true

  COMMON_TYPE = "common".freeze
  CUSTOM_TYPE = "custom".freeze
  AVAILABLE_TYPES = [ COMMON_TYPE, CUSTOM_TYPE ].freeze
  AVAILABLE_PERMISSION_VALUES = [ "true", "false", nil ].freeze
  AVAILABLE_PERMISSIONS = %w[
    create_user
    read_user
    update_user
    delete_user
    create_space
    read_space
    update_space
    delete_space
    create_child_profile
    read_child_profile
    update_child_profile
    delete_child_profile
    create_observation
    read_observation
    update_observation
    delete_observation
    create_assessment
    read_assessment
    update_assessment
    delete_assessment
    manage_collaborators
  ].freeze

  validates_inclusion_of :type, in: AVAILABLE_TYPES
  validate :check_permissions

  def self.find_sti_class(type_name)
    super("Roles::#{type_name.classify}")
  end

  AVAILABLE_PERMISSIONS.each do |p|
    define_method("can_#{p}?") { permissions[p] == "true" }
  end

  def common?
    type == COMMON_TYPE
  end

  def custom?
    type == CUSTOM_TYPE
  end

  private

  def check_permissions
    permissions.each do |key, val|
      errors.add(:permissions, "Invalid permission key '#{key}'") unless AVAILABLE_PERMISSIONS.include?(key)
      errors.add(:permissions, "Invalid permission value '#{val}'") unless AVAILABLE_PERMISSION_VALUES.include?(val)
    end
  end
end
