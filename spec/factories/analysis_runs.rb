# frozen_string_literal: true

FactoryBot.define do
  factory :analysis_run do
    child_profile
    analysis_rubric { association :analysis_rubric, :published }
    status { :pending }
    input_digest { nil }
    engine_version { nil }
    started_at { nil }
    completed_at { nil }
    error_message { nil }
    profile_snapshot { nil }

    trait :running do
      status { :running }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      input_digest { SecureRandom.hex(16) }
      engine_version { "1.0.0" }
      started_at { 2.minutes.ago }
      completed_at { Time.current }
    end

    trait :failed do
      status { :failed }
      started_at { 2.minutes.ago }
      error_message { "Test failure" }
    end
  end
end
