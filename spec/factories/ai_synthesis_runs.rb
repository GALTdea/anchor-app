# frozen_string_literal: true

FactoryBot.define do
  factory :ai_synthesis_run do
    analysis_run factory: %i[analysis_run completed]
    purpose { "parent_guidance_v1" }
    status { :pending }
    provider { nil }
    model { nil }
    prompt_version { nil }
    request_payload { {} }
    response_payload { {} }
    output { {} }
    started_at { nil }
    completed_at { nil }
    error_message { nil }

    trait :running do
      status { :running }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      provider { "stub" }
      model { "stub-mini" }
      prompt_version { "parent_guidance@v1" }
      started_at { 2.minutes.ago }
      completed_at { Time.current }
      output do
        {
          "summary_plain" =>
            "Anchor synthesized this passage in deterministic stub mode (audit digest placeholder).",
          "synthesis_schema_version" => "anchor_synthesis_v1",
          "finding_refs" => []
        }
      end
    end

    trait :failed do
      status { :failed }
      started_at { 2.minutes.ago }
      error_message { "Provider unavailable" }
    end
  end
end
