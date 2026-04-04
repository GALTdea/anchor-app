# frozen_string_literal: true

FactoryBot.define do
  factory :profile_evidence do
    association :source, factory: :assessment_response
    child_profile { source.assessment.child_profile }
    dimension_key { "regulation.overall_concern" }
    concept_key { "overall_concern_level" }
    value { "3" }
    value_type { "integer" }
    confidence { 0.8 }
    respondent_kind { "parent_proxy" }
    recorded_at { Time.current }
    metadata do
      {
        "question_id" => "concern_level",
        "question_label" => "Overall level of concern",
        "question_type" => "scale",
        "time_window" => "typical_week",
        "evidence_weight" => 0.8,
        "template_slug" => source.template_slug_snapshot,
        "template_version" => source.template_version_snapshot
      }
    end
    inferred { false }
  end
end
