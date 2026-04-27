# frozen_string_literal: true

FactoryBot.define do
  factory :analysis_rubric do
    name { "Anchor child profile" }
    sequence(:rubric_key) { |n| "rubric_#{n}" }
    version { 1 }
    status { :draft }
    description { "Deterministic child profile analysis rubric." }
    schema { { "version" => 1, "domains" => [] } }
    published_at { nil }

    trait :published do
      status { :published }
      published_at { Time.current }
    end
  end
end
