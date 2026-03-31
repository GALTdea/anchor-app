# frozen_string_literal: true

module AssessmentResponsesHelper
  RESPONDENT_LABELS = {
    "parent_proxy" => "Parent / caregiver (on behalf of child)",
    "self_report" => "Self-report",
    "therapist_report" => "Therapist",
    "teacher_report" => "Teacher"
  }.freeze

  def respondent_kind_label(kind)
    RESPONDENT_LABELS[kind.to_s] || kind.to_s.humanize
  end
end
