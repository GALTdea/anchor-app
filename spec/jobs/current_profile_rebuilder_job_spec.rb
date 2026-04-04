# frozen_string_literal: true

require "rails_helper"

RSpec.describe CurrentProfileRebuilderJob, type: :job do
  include ActiveJob::TestHelper

  let(:assessment_response) { create(:assessment_response, submitted_at: Time.current, processing_status: "processing") }
  let(:child_profile) { assessment_response.assessment.child_profile }

  before do
    create(
      :profile_evidence,
      source: assessment_response,
      child_profile: child_profile,
      dimension_key: "regulation.overall_concern",
      concept_key: "overall_concern_level",
      value: "4",
      value_type: "integer",
      confidence: 0.8,
      metadata: { "question_id" => "concern_level" }
    )
    create(
      :profile_evidence,
      source: assessment_response,
      child_profile: child_profile,
      dimension_key: "regulation.support",
      concept_key: "support_style",
      value: "quiet_space",
      value_type: "selection",
      confidence: 0.6,
      metadata: { "selected_option_label" => "Quiet space" }
    )
  end

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "rebuilds the current profile and enqueues snapshot creation" do
    expect {
      described_class.perform_now(
        child_profile.id,
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: assessment_response.id
      )
    }.to change(CurrentProfile, :count).by(1)
      .and have_enqueued_job(ProfileSnapshotBuilderJob)

    current_profile = child_profile.reload.current_profile
    expect(current_profile.profile_version).to eq(1)
    expect(current_profile.summary.dig("stats", "evidence_count")).to eq(2)
    expect(current_profile.narrative).to include(child_profile.name)
    expect(current_profile.narrative).to include("Quiet space")
  end

  it "increments profile_version when the profile is rebuilt again" do
    create(:current_profile, child_profile: child_profile, profile_version: 3)

    described_class.perform_now(
      child_profile.id,
      trigger_source_type: "AssessmentResponse",
      trigger_source_id: assessment_response.id
    )

    expect(child_profile.reload.current_profile.profile_version).to eq(4)
  end
end
