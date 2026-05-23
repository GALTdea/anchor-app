# frozen_string_literal: true

class ChildProfiles::SupportPlansController < ApplicationController
  before_action :set_space
  before_action :set_child_profile
  before_action :set_current_profile

  def show
    authorize @child_profile
    authorize @current_profile

    @results_presenter = ChildProfileResultsPresenter.new(@child_profile)
  end

  private

  def set_space
    @space = Space.find(params[:space_id])
  end

  def set_child_profile
    @child_profile = ChildProfile.where(space_id: @space.id).friendly.find(params[:child_profile_id])
  end

  def set_current_profile
    @current_profile = @child_profile.current_profile || @child_profile.build_current_profile(
      summary: {},
      generated_at: Time.current,
      profile_version: 1
    )
  end
end
