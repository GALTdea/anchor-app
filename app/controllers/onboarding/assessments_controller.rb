# frozen_string_literal: true

class Onboarding::AssessmentsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_onboarding_session

  def show
    authorize_onboarding_session(@onboarding_session)
    @assessment_template = @onboarding_session.assessment_template
  end

  private

  def set_onboarding_session
    @onboarding_session = OnboardingSession.find_by(id: session[:onboarding_session_id])
  end

  def authorize_onboarding_session(onboarding_session, query = :show?)
    authorize(
      OnboardingSessionPolicy::Context.new(onboarding_session, session[:onboarding_session_id]),
      query,
      policy_class: OnboardingSessionPolicy
    )
  end
end
