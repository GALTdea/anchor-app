# frozen_string_literal: true

module Admin
  class DashboardPolicy < ApplicationPolicy
    def show?
      user.admin?
    end
  end
end
