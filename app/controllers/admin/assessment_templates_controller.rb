# frozen_string_literal: true

class Admin::AssessmentTemplatesController < ApplicationController
  before_action :set_assessment_template, only: %i[show edit update preview publish]
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
