# frozen_string_literal: true

FactoryBot.define do
  factory :analysis_finding do
    analysis_run factory: %i[analysis_run completed]
    sequence(:dimension_key) { |n| "domain.dimension_#{n}" }
    sequence(:finding_key) { |n| "signal_#{n}" }
    score { 0.62 }
    confidence { 0.75 }
    severity { "medium" }
    label { "Support signal" }
    summary { "Pattern noted from saved answers." }
    evidence_refs { { "profile_evidence_ids" => [ 1, 2 ] } }
    metadata { { "rubric_domain" => "communication" } }
  end
end
