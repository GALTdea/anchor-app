# frozen_string_literal: true

class AssessmentPolicy < ApplicationPolicy
  def initialize(user, record)
    super
    @role = user.get_role_in_space(record.child_profile.space)
  end

  def index?
    @role&.can_read_assessment? == true
  end

  def show?
    @role&.can_read_assessment? == true
  end

  def create?
    @role&.can_create_assessment? == true
  end

  def destroy?
    @role&.can_delete_assessment? == true
  end
end
