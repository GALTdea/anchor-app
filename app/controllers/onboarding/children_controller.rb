# frozen_string_literal: true

class Onboarding::ChildrenController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_onboarding_session
  before_action :redirect_completed_session

  def show
    authorize_onboarding_session(@onboarding_session)
  end

  def update
    authorize_onboarding_session(@onboarding_session)

    if OnboardingProgressUpdater.new(
      onboarding_session: @onboarding_session,
      child_attributes: child_params,
      validation_context: :child_basics
    ).call
      redirect_to onboarding_assessment_path, notice: "Child details saved."
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_onboarding_session
    @onboarding_session = OnboardingSession.find_by(id: session[:onboarding_session_id])
  end

  def redirect_completed_session
    return unless @onboarding_session&.completed?

    if user_signed_in? && @onboarding_session.user == current_user
      redirect_to space_child_profile_path(@onboarding_session.space, @onboarding_session.child_profile)
    else
      session.delete(:onboarding_session_id)
      redirect_to new_onboarding_session_path, alert: "That onboarding session is already complete. Start a new profile to continue."
    end
  end

  def authorize_onboarding_session(onboarding_session, query = :show?)
    authorize(
      OnboardingSessionPolicy::Context.new(onboarding_session, session[:onboarding_session_id]),
      query,
      policy_class: OnboardingSessionPolicy
    )
  end

  def child_params
    params.require(:onboarding_session).permit(:child_first_name, :child_last_name, :child_date_of_birth)
  end
end
