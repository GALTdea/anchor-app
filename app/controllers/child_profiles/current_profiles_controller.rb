# frozen_string_literal: true

class ChildProfiles::CurrentProfilesController < ApplicationController
  before_action :set_space
  before_action :set_child_profile
  before_action :set_current_profile

  def show
    authorize @current_profile
  end

  private

  def set_space
    @space = Space.find(params[:space_id])
  end

  def set_child_profile
    @child_profile = @space.child_profiles.friendly.find(params[:child_profile_id])
  end

  def set_current_profile
    @current_profile = @child_profile.current_profile || @child_profile.build_current_profile(
      summary: {},
      generated_at: Time.current,
      profile_version: 1
    )
  end
end
