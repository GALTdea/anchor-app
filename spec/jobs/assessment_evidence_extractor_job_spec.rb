# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssessmentEvidenceExtractorJob, type: :job do
  include ActiveJob::TestHelper

  let(:template) do
    create(
      :assessment_template,
      schema: {
        "version" => 1,
        "sections" => [
          { "id" => "regulation", "title" => "Regulation" }
        ],
        "questions" => [
          {
            "id" => "concern_level",
            "label" => "Overall level of concern",
            "type" => "scale",
            "section" => "regulation",
            "dimension_key" => "regulation.overall_concern",
            "concept_key" => "overall_concern_level",
            "time_window" => "typical_week",
            "evidence_weight" => 0.8,
            "min" => 1,
            "max" => 5
          },
          {
            "id" => "support_style",
            "label" => "Best support style",
            "type" => "select",
            "section" => "regulation",
            "dimension_key" => "regulation.support",
            "concept_key" => "support_style",
            "time_window" => "current",
            "evidence_weight" => 0.6,
            "options" => [
              { "value" => "quiet_space", "label" => "Quiet space" },
              { "value" => "movement_break", "label" => "Movement break" }
            ]
          },
          {
            "id" => "notes",
            "label" => "Notes",
            "type" => "textarea",
            "section" => "regulation",
            "dimension_key" => "regulation.context",
            "concept_key" => "caregiver_context_notes",
            "time_window" => "recent_pattern",
            "evidence_weight" => 0.4,
            "extraction_hint" => "Capture direct caregiver language"
          }
        ]
      }
    )
  end
  let(:assessment) { create(:assessment, assessment_template: template) }
  let(:assessment_response) do
    create(
      :assessment_response,
      assessment: assessment,
      answers: {
        "concern_level" => "4",
        "support_style" => "quiet_space",
        "notes" => "A calm room helps after school."
      },
      submitted_at: Time.current,
      processing_status: "queued"
    )
  end

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "extracts evidence from the submitted response and marks processing complete" do
    expect {
      described_class.perform_now(assessment_response.id)
    }.to change(ProfileEvidence, :count).by(3)
      .and have_enqueued_job(CurrentProfileRebuilderJob).with(
        assessment.child_profile_id,
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: assessment_response.id
      )

    assessment_response.reload
    expect(assessment_response.processing_status).to eq("processing")
    expect(assessment_response.last_processed_at).to be_nil

    select_evidence = ProfileEvidence.find_by!(concept_key: "support_style")
    expect(select_evidence.value_type).to eq("selection")
    expect(select_evidence.metadata["selected_option_label"]).to eq("Quiet space")
  end

  it "is idempotent when rerun for the same response" do
    described_class.perform_now(assessment_response.id)

    expect {
      described_class.perform_now(assessment_response.id)
    }.not_to change(ProfileEvidence, :count)
  end

  it "marks processing failed when extraction raises" do
    allow_any_instance_of(AssessmentEvidenceExtractor).to receive(:call).and_raise("boom")

    expect {
      described_class.perform_now(assessment_response.id)
    }.to raise_error(RuntimeError, "boom")

    assessment_response.reload
    expect(assessment_response.processing_status).to eq("failed")
    expect(assessment_response.last_processing_error).to eq("boom")
  end
end
