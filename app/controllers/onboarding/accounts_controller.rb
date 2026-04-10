# frozen_string_literal: true

class Onboarding::AccountsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_onboarding_session
  before_action :redirect_completed_session

  def show
    authorize_onboarding_session(@onboarding_session)
    @account = account_defaults
  end

  def create
    authorize_onboarding_session(@onboarding_session)
    @account = account_params.to_h.symbolize_keys

    finalizer = OnboardingFinalizer.new(
      onboarding_session: @onboarding_session,
      account_attributes: @account
    )

    if finalizer.call
      sign_in(finalizer.user)
      redirect_to onboarding_results_path, notice: "Your child's first profile is ready."
    else
      finalizer.errors.full_messages.each { |message| @onboarding_session.errors.add(:base, message) }
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
      redirect_to onboarding_results_path
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

  def account_params
    params.require(:onboarding_account).permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end

  def account_defaults
    parent_name = @onboarding_session.parent_name.to_s
    first_name, last_name = parent_name.split(" ", 2)

    {
      first_name: first_name,
      last_name: last_name,
      email: @onboarding_session.email
    }
  end
end
