# frozen_string_literal: true

class Onboarding::AssessmentsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_onboarding_session
  before_action :redirect_completed_session

  def show
    authorize_onboarding_session(@onboarding_session)
    @assessment_template = @onboarding_session.assessment_template
    @answers = @onboarding_session.assessment_answers
  end

  def update
    authorize_onboarding_session(@onboarding_session)
    @assessment_template = @onboarding_session.assessment_template

    validation_context = params[:submit_action] == "continue" ? :assessment : nil

    if OnboardingProgressUpdater.new(
      onboarding_session: @onboarding_session,
      assessment_attributes: assessment_params,
      validation_context: validation_context
    ).call
      if params[:submit_action] == "continue"
        redirect_to onboarding_account_path, notice: "Assessment progress saved."
      else
        redirect_to onboarding_assessment_path, notice: "Draft saved."
      end
    else
      @answers = @onboarding_session.assessment_answers
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

  def assessment_params
    params.require(:onboarding_assessment).permit(:respondent_kind, answers: {})
  end
end
