class ChildProfilePolicy < ApplicationPolicy
  def initialize(user, record)
    super
    @role = user.get_role_in_space(record.space)
  end

  def index?
    show?
  end

  def show?
    @role&.can_read_child_profile?
  end

  def create?
    @role&.can_create_child_profile?
  end

  def update?
    @role&.can_update_child_profile?
  end

  def destroy?
    @role&.can_delete_child_profile?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        space_ids = user.user_roles.pluck(:space_id)
        scope.where(space_id: space_ids)
      end
    end
  end
end
