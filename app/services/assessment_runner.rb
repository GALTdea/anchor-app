# frozen_string_literal: true

# Interprets an AssessmentTemplate schema + current answers to build a linear
# sequence of steps (sections, questions, summaries) suitable for a guided
# runner UI.
#
# When questions or sections define +visible_if+ predicates, only those whose
# predicates match the current answers are included in the output. Step IDs
# are stable (based on question id, not position) so that adding/hiding
# questions does not break existing URLs mid-run.
class AssessmentRunner
  def initialize(template:, answers: {})
    @template = template
    @answers = answers.to_h.deep_stringify_keys
    @evaluator = AssessmentSchema::PredicateEvaluator.new(@answers)
  end

  def sections
    @sections ||= begin
      schema_sections = Array(schema["sections"]).filter_map do |section|
        next unless section.respond_to?(:stringify_keys)

        normalized = section.stringify_keys
        next if normalized["id"].blank?
        next unless visible?(normalized)

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

  def active_question_ids
    @active_question_ids ||= questions.map { |q| q["id"].to_s }
  end

  def current_step(step_id = nil)
    requested_step = find_step(step_id)
    return requested_step if requested_step.present?

    default_step
  end

  def next_step_for(step_or_id)
    step = step_or_id.is_a?(Hash) ? step_or_id : find_step(step_or_id)
    return nil if step.blank?

    index = steps.index { |candidate| candidate["id"] == step["id"] }
    return nil if index.nil?

    steps[index + 1]
  end

  def previous_step_for(step_or_id)
    step = step_or_id.is_a?(Hash) ? step_or_id : find_step(step_or_id)
    return nil if step.blank?

    index = steps.index { |candidate| candidate["id"] == step["id"] }
    return nil if index.nil? || index.zero?

    steps[index - 1]
  end

  private

  attr_reader :template, :answers, :evaluator

  def schema
    @schema ||= template.schema.to_h.deep_stringify_keys
  end

  def questions
    @questions ||= Array(schema["questions"]).filter_map.with_index do |question, index|
      next unless question.respond_to?(:stringify_keys)

      normalized = question.stringify_keys
      next if normalized["id"].blank?
      next unless visible?(normalized)

      normalized["position"] = normalized_position(normalized["position"], index + 1)
      normalized
    end
  end

  def visible?(item)
    predicate = item["visible_if"]
    return true if predicate.nil?

    evaluator.match?(predicate)
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
    grouped_questions(section).map.with_index do |group, group_index|
      build_question_step(section, section_index, group, group_index)
    end
  end

  def grouped_questions(section)
    Array(section["questions"])
      .sort_by { |question| normalized_position(question["position"], 9_999) }
      .group_by { |question| question["step_group"].presence || question["id"].to_s }
      .values
  end

  def build_question_step(section, section_index, question_group, group_index)
    first_question_id = question_group.first["id"].to_s

    {
      "id" => "q-#{first_question_id}",
      "kind" => "questions",
      "section_id" => section["id"],
      "section_position" => section_index + 1,
      "position" => group_index + 1,
      "section_title" => section["title"],
      "section_description" => section["description"],
      "transition_title" => section["transition_title"],
      "transition_body" => section["transition_body"],
      "question_ids" => question_group.map { |question| question["id"].to_s },
      "questions" => question_group,
      "answered" => question_group.all? { |question| question_answered?(question) }
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

  def find_step(step_id)
    return nil if step_id.blank?

    steps.find { |step| step["id"] == step_id.to_s }
  end

  def default_step
    steps.find { |step| !step["answered"] } || steps.last
  end

  def normalized_position(value, fallback)
    position = Integer(value, exception: false)
    position.present? && position.positive? ? position : fallback
  end
end
