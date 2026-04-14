# frozen_string_literal: true

class AssessmentRunner
  DEFAULT_SECTION_SUMMARY_TITLE = "What we captured so far".freeze
  DEFAULT_SECTION_SUMMARY_BODY = "You can continue or go back and adjust anything before moving on.".freeze

  def initialize(template:, answers: {})
    @template = template
    @answers = answers.to_h.deep_stringify_keys
  end

  def sections
    @sections ||= begin
      schema_sections = Array(schema["sections"]).filter_map do |section|
        next unless section.respond_to?(:stringify_keys)

        normalized = section.stringify_keys
        next if normalized["id"].blank?

        normalized.merge("questions" => [])
      end

      if schema_sections.any?
        build_declared_sections(schema_sections)
      else
        [ fallback_section ]
      end
    end
  end

  def steps
    @steps ||= sections.flat_map.with_index do |section, section_index|
      build_section_steps(section, section_index)
    end
  end

  private

  attr_reader :template, :answers

  def schema
    @schema ||= template.schema.to_h.deep_stringify_keys
  end

  def questions
    @questions ||= Array(schema["questions"]).filter_map.with_index do |question, index|
      next unless question.respond_to?(:stringify_keys)

      normalized = question.stringify_keys
      next if normalized["id"].blank?

      normalized["position"] = normalized_position(normalized["position"], index + 1)
      normalized
    end
  end

  def build_declared_sections(schema_sections)
    indexed_sections = schema_sections.index_by { |section| section["id"].to_s }

    questions.each do |question|
      section_id = question["section"].to_s
      target_section = if section_id.present? && indexed_sections.key?(section_id)
        indexed_sections[section_id]
      else
        fallback = schema_sections.find { |section| section["id"] == fallback_section["id"] }
        unless fallback
          fallback = fallback_section
          schema_sections << fallback
        end
        fallback
      end

      target_section["questions"] << question
    end

    schema_sections.reject { |section| section["questions"].blank? }
  end

  def build_section_steps(section, section_index)
    question_steps = grouped_questions(section).map.with_index do |group, group_index|
      build_question_step(section, section_index, group, group_index)
    end

    [
      build_section_intro_step(section, section_index),
      *question_steps,
      build_section_summary_step(section, section_index)
    ]
  end

  def grouped_questions(section)
    Array(section["questions"])
      .sort_by { |question| normalized_position(question["position"], 9_999) }
      .group_by { |question| question["step_group"].presence || question["id"].to_s }
      .values
  end

  def build_section_intro_step(section, section_index)
    {
      "id" => "section-#{section['id']}-intro",
      "kind" => "section_intro",
      "section_id" => section["id"],
      "section_position" => section_index + 1,
      "title" => section["transition_title"].presence || section["title"],
      "body" => section["transition_body"].presence || section["description"]
    }.compact
  end

  def build_question_step(section, section_index, question_group, group_index)
    first_question = question_group.first

    {
      "id" => "section-#{section['id']}-step-#{group_index + 1}",
      "kind" => "questions",
      "section_id" => section["id"],
      "section_position" => section_index + 1,
      "position" => group_index + 1,
      "question_ids" => question_group.map { |question| question["id"].to_s },
      "questions" => question_group,
      "answered" => question_group.all? { |question| question_answered?(question) }
    }
  end

  def build_section_summary_step(section, section_index)
    {
      "id" => "section-#{section['id']}-summary",
      "kind" => "section_summary",
      "section_id" => section["id"],
      "section_position" => section_index + 1,
      "title" => section["summary_title"].presence || DEFAULT_SECTION_SUMMARY_TITLE,
      "body" => section["summary_body"].presence || DEFAULT_SECTION_SUMMARY_BODY,
      "answered" => Array(section["questions"]).count { |question| question_answered?(question) },
      "total" => Array(section["questions"]).size
    }
  end

  def fallback_section
    @fallback_section ||= {
      "id" => "questions",
      "title" => "Questions",
      "description" => nil,
      "questions" => questions
    }
  end

  def question_answered?(question)
    answers[question["id"].to_s].present?
  end

  def normalized_position(value, fallback)
    position = Integer(value, exception: false)
    position.present? && position.positive? ? position : fallback
  end
end
