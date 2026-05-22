# frozen_string_literal: true

class Admin::DashboardController < ApplicationController
  def show
    authorize :admin_dashboard, policy_class: Admin::DashboardPolicy
  end
end
