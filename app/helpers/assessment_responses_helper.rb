# frozen_string_literal: true

module AssessmentResponsesHelper
  RESPONDENT_LABELS = {
    "parent_proxy" => "Parent / caregiver (on behalf of child)",
    "self_report" => "Self-report",
    "therapist_report" => "Therapist",
    "teacher_report" => "Teacher"
  }.freeze
  PROCESSING_STATUS_LABELS = {
    "queued" => "Profile update queued",
    "processing" => "Profile update in progress",
    "completed" => "Profile updated",
    "failed" => "Profile update needs retry"
  }.freeze

  def respondent_kind_label(kind)
    RESPONDENT_LABELS[kind.to_s] || kind.to_s.humanize
  end

  def assessment_intro_title(template)
    schema = template.schema.to_h.deep_stringify_keys
    schema["intro_title"].presence || "Let’s build a starting picture of your child"
  end

  def assessment_intro_body(template)
    schema = template.schema.to_h.deep_stringify_keys
    schema["intro_body"].presence || "These questions help the app understand your child’s patterns, strengths, and support needs."
  end

  def assessment_sections(template)
    AssessmentRunner.new(template: template).sections
  end

  def assessment_runner_steps(template, answers: {})
    AssessmentRunner.new(template: template, answers: answers).steps
  end

  def assessment_progress(template, answers)
    questions = assessment_sections(template).flat_map { |section| section["questions"] }
    answered = questions.count { |question| assessment_answered?(answers[question["id"].to_s]) }
    total = questions.count
    percentage = total.zero? ? 0 : ((answered.to_f / total) * 100).round

    {
      answered: answered,
      total: total,
      percentage: percentage
    }
  end

  def assessment_section_progress(section, answers)
    questions = Array(section["questions"])
    answered = questions.count { |question| assessment_answered?(answers[question["id"].to_s]) }

    {
      answered: answered,
      total: questions.count
    }
  end

  def assessment_answered?(value)
    value.present?
  end

  def assessment_question_options(question)
    Array(question["options"]).map do |option|
      if option.respond_to?(:stringify_keys)
        normalized = option.stringify_keys
        [ normalized["label"].presence || normalized["value"].to_s.humanize, normalized["value"].to_s ]
      else
        [ option.to_s.humanize, option.to_s ]
      end
    end
  end

  def assessment_answer_display(question, value)
    return "—" unless assessment_answered?(value)

    if question["type"].to_s == "select"
      option_map = assessment_question_options(question).to_h.invert
      option_map[value.to_s] || value.to_s.humanize
    else
      value
    end
  end

  def assessment_step_highlights(step, answers, limit: 3)
    return [] if step.blank?

    Array(step["questions"]).filter_map do |question|
      question = question.stringify_keys
      value = answers[question["id"].to_s]
      next unless assessment_answered?(value)

      {
        label: question["short_label"].presence || question["label"],
        value: assessment_answer_display(question, value)
      }
    end.first(limit)
  end

  def assessment_processing_status_label(status)
    return nil if status.blank?

    PROCESSING_STATUS_LABELS[status.to_s] || status.to_s.humanize
  end

  def assessment_processing_badge_class(status)
    case status.to_s
    when "queued"
      "badge badge-warning badge-outline"
    when "processing"
      "badge badge-info badge-outline"
    when "completed"
      "badge badge-success badge-outline"
    when "failed"
      "badge badge-error badge-outline"
    else
      "badge badge-ghost"
    end
  end
end
