# Space represents a family or care-circle workspace (tenant) in the multi-tenant
# architecture. It owns child profiles, user memberships (via UserRole), and subscriptions.
# Authorization is space-scoped: users can only access resources within spaces where they
# have an assigned role (owner, caregiver, collaborator). The space acts as the primary
# tenant boundary, ensuring families' data remains isolated from each other.

# frozen_string_literal: true

# == Schema Information
#
# Table name: spaces
# Database name: primary
#
#  id         :bigint           not null, primary key
#  name       :string
#  status     :integer          default("active")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Space < ApplicationRecord
  has_many :user_roles, -> { includes(:role) }
  has_many :users, through: :user_roles

  has_many :subscriptions, -> { includes(:plan) }
  has_many :plans, through: :subscriptions

  has_many :child_profiles, dependent: :restrict_with_error

  validates :name, presence: true

  enum :status, [ :active, :archived ]

  def all_roles
    Role.where(space_id: [ nil, id ])
  end

  def active_subscription
    subscriptions.active.last || Subscription.new(plan: Plan.free_plan)
  end
end
