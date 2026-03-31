# frozen_string_literal: true

class ChildProfiles::AssessmentsController < ApplicationController
  before_action :set_space
  before_action :set_child_profile
  before_action :set_assessment, only: %i[show destroy]

  def index
    authorize Assessment.new(child_profile: @child_profile), :index?
    @assessments = @child_profile.assessments.not_archived.order(updated_at: :desc)
  end

  def show
    authorize @assessment
  end

  def new
    authorize Assessment.new(child_profile: @child_profile), :create?
    authorize AssessmentTemplatePolicy::Context.new(nil, @space), :index?, policy_class: AssessmentTemplatePolicy
    @templates = AssessmentTemplate.published.order(:title)
    @assessment = @child_profile.assessments.build
  end

  def create
    authorize Assessment.new(child_profile: @child_profile), :create?
    template = AssessmentTemplate.published.find(assessment_params[:assessment_template_id])
    authorize AssessmentTemplatePolicy::Context.new(template, @space), :show?, policy_class: AssessmentTemplatePolicy

    @assessment = @child_profile.assessments.build(assessment_template: template)
    @assessment.build_assessment_response(
      actor: current_user,
      respondent_kind: Array(template.respondent_types).first.to_s,
      answers: {}
    )

    if @assessment.save
      redirect_to edit_space_child_profile_assessment_assessment_response_path(@space, @child_profile, @assessment),
        notice: "Assessment started. Complete the questions below."
    else
      @templates = AssessmentTemplate.published.order(:title)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @assessment
    @assessment.update!(status: :archived)

    redirect_to space_child_profile_assessments_path(@space, @child_profile), notice: "Assessment archived."
  end

  private

  def set_space
    @space = Space.find(params[:space_id])
  end

  def set_child_profile
    @child_profile = @space.child_profiles.friendly.find(params[:child_profile_id])
  end

  def set_assessment
    @assessment = @child_profile.assessments.find(params[:id])
  end

  def assessment_params
    params.require(:assessment).permit(:assessment_template_id)
  end
end
