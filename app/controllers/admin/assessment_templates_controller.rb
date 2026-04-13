# frozen_string_literal: true

class Admin::AssessmentTemplatesController < ApplicationController
  before_action :set_assessment_template, only: %i[show edit update preview publish new_version set_as_onboarding]
  before_action :ensure_draft_editable!, only: %i[edit update publish]

  def index
    authorize AssessmentTemplate
    @assessment_templates = policy_scope(AssessmentTemplate).order(updated_at: :desc)
  end

  def show
    authorize @assessment_template
  end

  def new
    @assessment_template = AssessmentTemplate.new(
      status: :draft,
      version: 1,
      schema: AssessmentTemplate.default_schema
    )
    authorize @assessment_template
  end

  def create
    @assessment_template = AssessmentTemplate.new(assessment_template_params)
    @assessment_template.status = :draft
    @assessment_template.schema = AssessmentTemplate.default_schema if @assessment_template.schema.blank?
    @assessment_template.apply_schema_editor_attributes!(
      sections_attributes: schema_sections_attributes,
      schema_version: schema_version_param
    )
    authorize @assessment_template

    if @assessment_template.save
      redirect_to admin_assessment_template_path(@assessment_template), notice: "Draft template created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @assessment_template
  end

  def update
    authorize @assessment_template
    @assessment_template.assign_attributes(assessment_template_params)
    @assessment_template.apply_schema_editor_attributes!(
      sections_attributes: schema_sections_attributes,
      schema_version: schema_version_param
    )

    if @assessment_template.save
      redirect_to admin_assessment_template_path(@assessment_template), notice: "Draft template updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def preview
    authorize @assessment_template
  end

  def publish
    authorize @assessment_template

    if @assessment_template.update(status: :published)
      redirect_to admin_assessment_template_path(@assessment_template), notice: "Template published."
    else
      flash.now[:alert] = "This draft must be fixed before it can be published."
      render :edit, status: :unprocessable_content
    end
  end

  def new_version
    authorize @assessment_template

    unless @assessment_template.published?
      redirect_to admin_assessment_template_path(@assessment_template),
        alert: "Only published templates can be versioned."
      return
    end

    next_draft = @assessment_template.build_next_version_draft

    if next_draft.save
      redirect_to edit_admin_assessment_template_path(next_draft),
        notice: "New draft version created from the published template."
    else
      redirect_to admin_assessment_template_path(@assessment_template),
        alert: next_draft.errors.full_messages.to_sentence.presence || "Could not create the next draft version."
    end
  end

  def set_as_onboarding
    authorize @assessment_template

    unless @assessment_template.published?
      redirect_to admin_assessment_template_path(@assessment_template),
        alert: "Only published templates can be used for onboarding."
      return
    end

    AppSettings.write_setting!("onboarding_assessment_template_id", @assessment_template.id.to_s)

    redirect_to admin_assessment_template_path(@assessment_template),
      notice: "#{@assessment_template.title} is now the onboarding assessment."
  end

  private

  def set_assessment_template
    @assessment_template = AssessmentTemplate.find(params[:id])
  end

  def ensure_draft_editable!
    return if @assessment_template.draft_editable?

    redirect_to admin_assessment_template_path(@assessment_template),
      alert: "Published templates cannot be edited in place."
  end

  def assessment_template_params
    permitted = params.require(:assessment_template).permit(
      :title,
      :slug,
      :template_key,
      :version,
      :category,
      respondent_types: []
    )
    permitted[:respondent_types] = Array(permitted[:respondent_types]).reject(&:blank?)
    permitted
  end

  def schema_sections_attributes
    sections = params.fetch(:assessment_template, ActionController::Parameters.new)[:sections_attributes]
    return [] if sections.blank?

    sections.permit!.to_h.values
  end

  def schema_version_param
    params.fetch(:assessment_template, {})[:schema_version]
  end
end
