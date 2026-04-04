# frozen_string_literal: true

class RecommendationPolicy < ApplicationPolicy
  def initialize(user, record)
    super
    @child_profile = record.child_profile
    @role = user.get_role_in_space(@child_profile.space)
  end

  def index?
    return true if user.admin?

    @role&.can_read_child_profile? == true
  end

  def show?
    return true if user.admin?

    @role&.can_read_child_profile? == true
  end
end
