# frozen_string_literal: true

FactoryBot.define do
  factory :onboarding_session do
    association :assessment_template
    status { :active }
    draft_answers { {} }
    started_at { Time.current }
    child_first_name { "Ava" }
    child_last_name { "Stone" }
    child_date_of_birth { 5.years.ago.to_date }
  end
end
