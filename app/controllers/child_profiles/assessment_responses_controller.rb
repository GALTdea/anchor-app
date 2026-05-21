# frozen_string_literal: true

class ChildProfiles::AssessmentResponsesController < ApplicationController
  before_action :set_space
  before_action :set_child_profile
  before_action :set_assessment
  before_action :set_assessment_response
  before_action :set_runner_context, only: %i[edit update]

  def show
    authorize @assessment_response
  end

  def edit
    authorize @assessment_response
  end

  def update
    authorize @assessment_response

    merge_assessment_response_attributes

    submitting = params[:submit_action] == "submit"
    @assessment_response.submitting = submitting
    if forward_action? && current_step_missing_required_question_ids.any?
      @question_errors = current_step_missing_required_question_ids
      set_runner_context_from_current_response(step_id: params[:current_step_id].presence || params[:step])
      render :edit, status: :unprocessable_content
      return
    end

    if submitting
      runner_with_final_answers = AssessmentRunner.new(
        template: @assessment.assessment_template,
        answers: @assessment_response.answers
      )
      @assessment_response.active_question_ids = runner_with_final_answers.active_question_ids

      prior_submitted_at = @assessment_response.submitted_at
      prior_processing_status = @assessment_response.processing_status
      prior_last_processed_at = @assessment_response.last_processed_at
      prior_last_processing_error = @assessment_response.last_processing_error

      @assessment_response.actor = current_user
      @assessment_response.submitted_at = Time.current
      @assessment_response.processing_status = "queued"
      @assessment_response.last_processed_at = nil
      @assessment_response.last_processing_error = nil
      ActiveRecord::Base.transaction do
        unless @assessment_response.save
          @assessment_response.submitted_at = prior_submitted_at
          @assessment_response.processing_status = prior_processing_status
          @assessment_response.last_processed_at = prior_last_processed_at
          @assessment_response.last_processing_error = prior_last_processing_error
          set_runner_context_from_current_response
          render :edit, status: :unprocessable_content
          return
        end
        @assessment.update!(status: :submitted)
      end

      AssessmentEvidenceExtractorJob.perform_later(@assessment_response.id)

      redirect_to space_child_profile_path(@space, @child_profile),
        notice: "Assessment submitted."
    elsif @assessment_response.save
      render_runner_step
    else
      set_runner_context_from_current_response
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_space
    @space = Space.find(params[:space_id])
  end

  def set_child_profile
    @child_profile = @space.child_profiles.friendly.find(params[:child_profile_id])
  end

  def set_assessment
    @assessment = @child_profile.assessments.find(params[:assessment_id])
  end

  def set_assessment_response
    @assessment_response = @assessment.assessment_response
    raise ActiveRecord::RecordNotFound if @assessment_response.blank?
  end

  def set_runner_context
    set_runner_context_from_current_response
  end

  def set_runner_context_from_current_response(step_id: nil)
    @template = @assessment.assessment_template
    @answers = (@assessment_response.answers || {}).deep_stringify_keys
    @runner = AssessmentRunner.new(template: @template, answers: @answers)
    resolved_step_id = step_id.presence || params[:current_step_id].presence || params[:step]
    @current_step = @runner.current_step(resolved_step_id)
    @next_step = @runner.next_step_for(@current_step)
    @previous_step = @runner.previous_step_for(@current_step)
    @section_progress = @runner.section_progress_for(@current_step)
    @progress = view_context.assessment_progress(@template, @answers)
    @question_errors ||= []
  end

  def render_runner_step
    set_runner_context_from_current_response(step_id: next_step_id)
    render :edit, status: :ok
  end

  def assessment_response_params
    params.require(:assessment_response).permit(:respondent_kind, answers: {})
  end

  def merge_assessment_response_attributes
    permitted = assessment_response_params
    merged_answers = @assessment_response.answers.deep_stringify_keys.merge(
      normalized_answer_params(permitted).transform_keys(&:to_s)
    )

    @assessment_response.assign_attributes(
      respondent_kind: permitted[:respondent_kind].presence || @assessment_response.respondent_kind,
      answers: merged_answers
    )
  end

  def normalized_answer_params(permitted)
    answer_params = permitted[:answers]
    return {} if answer_params.blank?

    if answer_params.respond_to?(:to_unsafe_h)
      answer_params.to_unsafe_h
    else
      answer_params.to_h
    end
  end

  def next_step_id
    refreshed_runner = AssessmentRunner.new(
      template: @assessment.assessment_template,
      answers: @assessment_response.answers
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
    params[:submit_action].in?(%w[next submit])
  end

  def current_step_missing_required_question_ids
    current_step = @runner.current_step(params[:current_step_id].presence || params[:step])
    Array(current_step["questions"]).filter_map do |question|
      normalized = question.stringify_keys
      next unless ActiveModel::Type::Boolean.new.cast(normalized["required"])

      question_id = normalized["id"].to_s
      question_id if @assessment_response.answers.to_h[question_id].blank?
    end
  end
end
