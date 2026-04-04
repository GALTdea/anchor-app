# frozen_string_literal: true

class ChildProfiles::AssessmentResponsesController < ApplicationController
  before_action :set_space
  before_action :set_child_profile
  before_action :set_assessment
  before_action :set_assessment_response

  def show
    authorize @assessment_response
  end

  def edit
    authorize @assessment_response
  end

  def update
    authorize @assessment_response

    @assessment_response.assign_attributes(assessment_response_params)

    submitting = params[:submit_action] == "submit"
    @assessment_response.submitting = submitting

    if submitting
      @assessment_response.actor = current_user
      @assessment_response.submitted_at = Time.current
      @assessment_response.processing_status = "queued"
      @assessment_response.last_processed_at = nil
      @assessment_response.last_processing_error = nil
      ActiveRecord::Base.transaction do
        unless @assessment_response.save
          render :edit, status: :unprocessable_content
          return
        end
        @assessment.update!(status: :submitted)
      end

      redirect_to space_child_profile_assessment_path(@space, @child_profile, @assessment),
        notice: "Assessment submitted."
    elsif @assessment_response.save
      redirect_to edit_space_child_profile_assessment_assessment_response_path(@space, @child_profile, @assessment),
        notice: "Draft saved."
    else
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

  def assessment_response_params
    params.require(:assessment_response).permit(:respondent_kind, answers: {})
  end
end
