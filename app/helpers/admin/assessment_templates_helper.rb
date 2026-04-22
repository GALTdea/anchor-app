# frozen_string_literal: true

module Admin::AssessmentTemplatesHelper
  QUESTION_TYPE_OPTIONS = AssessmentTemplate::SUPPORTED_QUESTION_TYPES.map { |type| [ type.humanize, type ] }.freeze

  def schema_editor_sections(template)
    template.editor_sections
  end

  def question_type_options
    QUESTION_TYPE_OPTIONS
  end

  def onboarding_template_selected?(template)
    onboarding_assessment_template_id == template.id.to_s
  end

  def visible_if_editor_value(owner)
    return owner["visible_if_raw"].to_s if owner["visible_if_raw"].present?
    return "" if owner["visible_if"].blank?

    JSON.pretty_generate(owner["visible_if"])
  end
end
