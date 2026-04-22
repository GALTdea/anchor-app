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

  def admin_preview_sections(template)
    schema = template.schema.to_h.deep_stringify_keys
    sections = Array(schema["sections"]).map do |section|
      section.deep_stringify_keys.merge("questions" => [])
    end

    indexed_sections = sections.index_by { |section| section["id"].to_s }
    fallback = nil

    Array(schema["questions"]).each do |question|
      question = question.deep_stringify_keys
      target = indexed_sections[question["section"].to_s]

      unless target
        fallback ||= begin
          extra = { "id" => "", "title" => "Uncategorized", "description" => "", "questions" => [] }
          sections << extra
          extra
        end
        target = fallback
      end

      target["questions"] << question
    end

    sections
  end

  def admin_preview_total_questions(template)
    Array(template.schema.to_h.deep_stringify_keys["questions"]).size
  end
end
