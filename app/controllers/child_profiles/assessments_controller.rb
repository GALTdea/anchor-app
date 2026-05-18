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
      render :new, status: :unprocessable_content
    end
  end

  def start_onboarding
    authorize Assessment.new(child_profile: @child_profile), :create?

    assessment = resumable_onboarding_assessment || build_onboarding_assessment(onboarding_template)
    authorize AssessmentTemplatePolicy::Context.new(assessment.assessment_template, @space), :show?, policy_class: AssessmentTemplatePolicy

    if assessment.save
      redirect_to edit_space_child_profile_assessment_assessment_response_path(@space, @child_profile, assessment),
        notice: onboarding_start_notice(assessment)
    else
      redirect_to space_child_profile_path(@space, @child_profile),
        alert: assessment.errors.full_messages.to_sentence.presence || "Unable to start onboarding assessment."
    end
  rescue OnboardingAssessmentTemplateResolver::TemplateNotConfiguredError => error
    redirect_to space_child_profile_path(@space, @child_profile), alert: error.message
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

  def resumable_onboarding_assessment
    @child_profile.assessments
      .draft
      .joins(:assessment_response, :assessment_template)
      .includes(:assessment_response, :assessment_template)
      .order(updated_at: :desc, id: :desc)
      .detect { |assessment| onboarding_template_resolver.onboarding_template?(assessment.assessment_template) }
  end

  def build_onboarding_assessment(template)
    @child_profile.assessments.build(assessment_template: template).tap do |assessment|
      assessment.build_assessment_response(
        actor: current_user,
        respondent_kind: Array(template.respondent_types).first.to_s,
        answers: {}
      )
    end
  end

  def onboarding_template_resolver
    @onboarding_template_resolver ||= OnboardingAssessmentTemplateResolver.new
  end

  def onboarding_template
    @onboarding_template ||= onboarding_template_resolver.call
  end

  def onboarding_start_notice(assessment)
    if assessment.previously_new_record?
      "Assessment started. Complete the questions below."
    else
      "Assessment resumed. Continue the questions below."
    end
  end
end
