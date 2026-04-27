# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfileSnapshotBuilderJob, type: :job do
  include ActiveJob::TestHelper

  let(:assessment_response) { create(:assessment_response, submitted_at: Time.current, processing_status: "processing") }
  let(:child_profile) { assessment_response.assessment.child_profile }
  let(:current_profile) { create(:current_profile, child_profile: child_profile) }

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

  it "creates a snapshot and enqueues analysis and recommendation jobs" do
    expect {
      described_class.perform_now(
        current_profile.id,
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: assessment_response.id
      )
    }.to change(ProfileSnapshot, :count).by(1)
      .and have_enqueued_job(AnalysisRunJob).with(
        child_profile.id,
        profile_snapshot_id: kind_of(Integer),
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: assessment_response.id
      )
      .and have_enqueued_job(RecommendationGeneratorJob).with(
        child_profile.id,
        source_profile_snapshot_id: kind_of(Integer),
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: assessment_response.id
      )

    snapshot = child_profile.profile_snapshots.last
    expect(snapshot.trigger_source).to eq(assessment_response)

    assessment_response.reload
    expect(assessment_response.processing_status).to eq("processing")
    expect(assessment_response.last_processed_at).to be_nil
  end

  it "does not create a duplicate snapshot when the profile has not changed" do
    create(
      :profile_snapshot,
      child_profile: child_profile,
      summary: current_profile.summary,
      narrative: current_profile.narrative,
      generated_at: 1.hour.ago
    )

    expect {
      described_class.perform_now(
        current_profile.id,
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: assessment_response.id
      )
    }.not_to change(ProfileSnapshot, :count)

    expect(AnalysisRunJob).to have_been_enqueued.with(
      child_profile.id,
      profile_snapshot_id: kind_of(Integer),
      trigger_source_type: "AssessmentResponse",
      trigger_source_id: assessment_response.id
    )
    expect(RecommendationGeneratorJob).to have_been_enqueued.with(
      child_profile.id,
      source_profile_snapshot_id: kind_of(Integer),
      trigger_source_type: "AssessmentResponse",
      trigger_source_id: assessment_response.id
    )

    expect(assessment_response.reload.processing_status).to eq("processing")
  end
end
