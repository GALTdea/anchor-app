# frozen_string_literal: true

class DefaultSpaceProvisioner
  def self.call(user:)
    new(user:).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    existing = user.spaces.order(:created_at).first
    return existing if existing

    ActiveRecord::Base.transaction do
      space = Space.create!(name: default_space_name)
      UserRole.create!(user: user, space: space, role: owner_role)
      space
    end
  end

  private

  attr_reader :user

  def default_space_name
    label = [ user.first_name, user.last_name ].compact_blank.join(" ").presence
    label ? "#{label}'s family" : "My family"
  end

  def owner_role
    Roles::Common.find_or_create_by!(name: "Owner") do |role|
      role.value = "owner"
      role.permissions = Role::AVAILABLE_PERMISSIONS.index_with { "true" }
    end
  end
end
