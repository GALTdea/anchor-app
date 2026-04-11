# frozen_string_literal: true

module Admin::AssessmentTemplatesHelper
  QUESTION_TYPE_OPTIONS = AssessmentTemplate::SUPPORTED_QUESTION_TYPES.map { |type| [ type.humanize, type ] }.freeze

  def schema_editor_sections(template)
    template.editor_sections
  end

  def question_type_options
    QUESTION_TYPE_OPTIONS
  end
end
