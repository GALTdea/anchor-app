# frozen_string_literal: true

class AssessmentTemplatePolicy < ApplicationPolicy
  Context = Data.define(:template, :space)

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?

      scope.none
    end
  end

  def initialize(user, record)
    super
    @template = record.template if record.respond_to?(:template)
    @space = record.space if record.respond_to?(:space)
  end

  def index?
    return user.admin? if admin_record?

    show?
  end

  def show?
    return true if user.admin?
    return false if @space.blank?

    user.get_role_in_space(@space)&.can_read_assessment? == true
  end

  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def preview?
    user.admin?
  end

  def publish?
    user.admin?
  end

  def new_version?
    user.admin?
  end

  private

  def admin_record?
    record == AssessmentTemplate || record.is_a?(AssessmentTemplate)
  end
end
