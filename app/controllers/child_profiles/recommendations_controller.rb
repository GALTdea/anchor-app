# frozen_string_literal: true

class ChildProfiles::RecommendationsController < ApplicationController
  before_action :set_space
  before_action :set_child_profile
  before_action :set_recommendation, only: :show

  def index
    @recommendation_context = Recommendation.new(child_profile: @child_profile, source_profile_snapshot: latest_snapshot)
    authorize @recommendation_context, :index?
    @current_profile = @child_profile.current_profile
    @recommendations = @child_profile.recommendations.active.order(generated_at: :desc, id: :desc)
  end

  def show
    authorize @recommendation
  end

  private

  def set_space
    @space = Space.find(params[:space_id])
  end

  def set_child_profile
    @child_profile = @space.child_profiles.friendly.find(params[:child_profile_id])
  end

  def set_recommendation
    @recommendation = @child_profile.recommendations.find(params[:id])
  end

  def latest_snapshot
    @child_profile.profile_snapshots.order(generated_at: :desc, id: :desc).first ||
      @child_profile.profile_snapshots.build(summary: {}, generated_at: Time.current)
  end
end
