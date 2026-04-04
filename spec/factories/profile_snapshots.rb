# frozen_string_literal: true

FactoryBot.define do
  factory :profile_snapshot do
    trigger_source { association :assessment_response }
    child_profile { trigger_source&.assessment&.child_profile || association(:child_profile) }
    summary do
      {
        "stats" => {
          "evidence_count" => 1,
          "dimension_count" => 1
        },
        "dimensions" => {
          "regulation.overall_concern" => {
            "latest_value" => "3"
          }
        }
      }
    end
    narrative { "Sample profile snapshot narrative." }
    generated_at { Time.current }
  end
end
