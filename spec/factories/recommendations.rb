# frozen_string_literal: true

FactoryBot.define do
  factory :recommendation do
    source_profile_snapshot { association :profile_snapshot }
    child_profile { source_profile_snapshot.child_profile }
    status { :active }
    category { "regulation" }
    title { "Support regulation with predictable recovery space" }
    body { "Try a short recovery routine after demanding moments and track whether it helps." }
    rationale do
      {
        "dimension_key" => "regulation.overall_concern",
        "concept_key" => "overall_concern_level",
        "latest_value" => "4",
        "display_value" => "4",
        "confidence" => 0.8,
        "respondent_kind" => "parent_proxy"
      }
    end
    generated_at { Time.current }
  end
end
