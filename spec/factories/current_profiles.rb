# frozen_string_literal: true

FactoryBot.define do
  factory :current_profile do
    child_profile
    summary do
      {
        "stats" => {
          "evidence_count" => 1,
          "dimension_count" => 1
        },
        "dimensions" => {
          "regulation.overall_concern" => {
            "latest_value" => "3",
            "value_type" => "integer",
            "confidence" => 0.8,
            "respondent_kind" => "parent_proxy",
            "recorded_at" => Time.current.iso8601
          }
        }
      }
    end
    narrative { "Sample current profile narrative." }
    generated_at { Time.current }
    profile_version { 1 }
  end
end
