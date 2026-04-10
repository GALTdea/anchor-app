# frozen_string_literal: true

class Onboarding::SessionsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    authorize_onboarding_session(nil, :new?)
  end

  def create
    authorize_onboarding_session(nil, :create?)

    onboarding_session = OnboardingSessionStarter.new(
      browser_session_id: session[:onboarding_session_id]
    ).call

    session[:onboarding_session_id] = onboarding_session.id

    redirect_to onboarding_child_path, notice: "Let's start with a few details about your child."
  rescue OnboardingSessionStarter::TemplateNotConfiguredError
    redirect_to new_onboarding_session_path,
      alert: "Onboarding is not configured yet. Run the latest seeds to install the child onboarding template."
  end

  def show
    onboarding_session = current_onboarding_session
    authorize_onboarding_session(onboarding_session)

    redirect_to onboarding_child_path
  end

  private

  def current_onboarding_session
    OnboardingSession.find_by(id: session[:onboarding_session_id])
  end

  def authorize_onboarding_session(onboarding_session, query = :show?)
    authorize(
      OnboardingSessionPolicy::Context.new(onboarding_session, session[:onboarding_session_id]),
      query,
      policy_class: OnboardingSessionPolicy
    )
  end
end
