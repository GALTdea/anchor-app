# frozen_string_literal: true

class AssessmentTemplatePolicy < ApplicationPolicy
  Context = Data.define(:template, :space)

  def initialize(user, record)
    super
    @space = record.space
  end

  def index?
    show?
  end

  def show?
    return true if user.admin?

    user.get_role_in_space(@space)&.can_read_assessment? == true
  end
end
