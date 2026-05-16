# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :set_space

  def index
    @child_profile = @space.child_profiles.build
    authorize @child_profile, :index?
    @child_profiles = policy_scope(ChildProfile).where(space_id: @space.id).active.order(first_name: :asc)
  end

  private

  def set_space
    @space = current_user.default_space
  end
end
