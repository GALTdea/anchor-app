# frozen_string_literal: true

class AssessmentResponsePolicy < ApplicationPolicy
  def initialize(user, record)
    super
    @role = user.get_role_in_space(record.assessment.child_profile.space)
  end

  def show?
    @role&.can_read_assessment? == true
  end

  def update?
    return false unless @role&.can_update_assessment? == true
    return true if user.admin?

    !record.assessment.submitted?
  end
end
