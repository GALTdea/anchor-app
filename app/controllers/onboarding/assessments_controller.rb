# frozen_string_literal: true

class Onboarding::AssessmentsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_onboarding_session
  before_action :redirect_completed_session
  before_action :set_runner_context, only: %i[show update]

  def show
    authorize_onboarding_session(@onboarding_session)
  end

  def update
    authorize_onboarding_session(@onboarding_session)

    validation_context = params[:submit_action] == "continue" ? :assessment : nil
    updater = OnboardingProgressUpdater.new(
      onboarding_session: @onboarding_session,
      assessment_attributes: assessment_params,
      validation_context: validation_context
    )

    if updater.call
      if forward_action? && current_step_missing_required_question_ids.any?
        @question_errors = current_step_missing_required_question_ids
        set_runner_context_from_current_session(step_id: params[:current_step_id].presence || params[:step])
        render :show, status: :unprocessable_content
        return
      end

      if params[:submit_action] == "continue"
        redirect_to onboarding_account_path, notice: "Assessment progress saved."
      else
        render_runner_step
      end
    else
      set_runner_context_from_current_session
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

  def set_runner_context
    set_runner_context_from_current_session
  end

  def set_runner_context_from_current_session(step_id: nil)
    @assessment_template = @onboarding_session.assessment_template
    @answers = @onboarding_session.assessment_answers.deep_stringify_keys
    @runner = AssessmentRunner.new(template: @assessment_template, answers: @answers)
    @current_step = @runner.current_step(step_id.presence || params[:step])
    @next_step = @runner.next_step_for(@current_step)
    @previous_step = @runner.previous_step_for(@current_step)
    @section_progress = @runner.section_progress_for(@current_step)
    @progress = view_context.assessment_progress(@assessment_template, @answers)
    @question_errors ||= []
  end

  def render_runner_step
    set_runner_context_from_current_session(step_id: next_step_id)
    @save_status = "Saved" if params[:submit_action] == "stay"
    render :show, status: :ok
  end

  def assessment_params
    params.require(:onboarding_assessment).permit(:respondent_kind, answers: {})
  end

  def next_step_id
    refreshed_runner = AssessmentRunner.new(
      template: @onboarding_session.assessment_template,
      answers: @onboarding_session.assessment_answers
    )
    current_step = refreshed_runner.current_step(params[:current_step_id].presence || params[:step])

    return current_step["id"] if params[:submit_action] == "stay"

    if params[:submit_action] == "back"
      refreshed_runner.previous_step_for(current_step)&.dig("id") || current_step["id"]
    else
      refreshed_runner.next_step_for(current_step)&.dig("id") || current_step["id"]
    end
  end

  def forward_action?
    params[:submit_action].in?(%w[next continue])
  end

  def current_step_missing_required_question_ids
    current_step = @runner.current_step(params[:current_step_id].presence || params[:step])
    answers = @onboarding_session.assessment_answers

    Array(current_step["questions"]).filter_map do |question|
      normalized = question.stringify_keys
      next unless ActiveModel::Type::Boolean.new.cast(normalized["required"])

      question_id = normalized["id"].to_s
      question_id if answers[question_id].blank?
    end
  end
end
