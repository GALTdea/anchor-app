# frozen_string_literal: true

class Onboarding::ResultsController < ApplicationController
  before_action :set_onboarding_session
  before_action :redirect_completed_onboarding_to_child_profile
  before_action :set_results_presenter

  def show
    authorize @current_profile
    authorize Recommendation.new(
      child_profile: @child_profile,
      source_profile_snapshot: @child_profile.profile_snapshots.order(generated_at: :desc, id: :desc).first || @child_profile.profile_snapshots.build(summary: {}, generated_at: Time.current)
    ), :index?
  end

  private

  def redirect_completed_onboarding_to_child_profile
    return unless @onboarding_session.completed?
    return if @onboarding_session.space.blank? || @onboarding_session.child_profile.blank?

    redirect_to space_child_profile_path(@onboarding_session.space, @onboarding_session.child_profile)
  end

  def set_onboarding_session
    @onboarding_session = current_user.onboarding_sessions.find(session[:onboarding_session_id])
  end

  def set_results_presenter
    presenter = OnboardingResultsPresenter.new(@onboarding_session)
    @space = presenter.space
    @child_profile = presenter.child_profile
    @current_profile = presenter.current_profile
    @recommendations = presenter.recommendations
  end
end
