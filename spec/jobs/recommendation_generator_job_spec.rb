# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecommendationGeneratorJob, type: :job do
  let(:assessment_response) { create(:assessment_response, submitted_at: Time.current, processing_status: "processing") }
  let(:child_profile) { assessment_response.assessment.child_profile }
  let!(:current_profile) do
    create(
      :current_profile,
      child_profile: child_profile,
      summary: {
        "stats" => {
          "evidence_count" => 2,
          "dimension_count" => 2
        },
        "dimensions" => {
          "regulation.overall_concern" => {
            "concept_key" => "overall_concern_level",
            "latest_value" => "4",
            "value_type" => "integer",
            "confidence" => 0.8,
            "respondent_kind" => "parent_proxy",
            "recorded_at" => Time.current.iso8601,
            "evidence_count" => 1,
            "latest_source_type" => "AssessmentResponse",
            "metadata" => {}
          },
          "regulation.support" => {
            "concept_key" => "support_style",
            "latest_value" => "quiet_space",
            "value_type" => "selection",
            "confidence" => 0.6,
            "respondent_kind" => "parent_proxy",
            "recorded_at" => Time.current.iso8601,
            "evidence_count" => 1,
            "latest_source_type" => "AssessmentResponse",
            "metadata" => { "selected_option_label" => "Quiet space" }
          }
        }
      }
    )
  end
  let!(:profile_snapshot) { create(:profile_snapshot, child_profile: child_profile, summary: current_profile.summary, narrative: current_profile.narrative, trigger_source: assessment_response) }

  it "generates recommendations and marks processing complete" do
    expect {
      described_class.perform_now(
        child_profile.id,
        source_profile_snapshot_id: profile_snapshot.id,
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: assessment_response.id
      )
    }.to change(Recommendation, :count).by(2)

    expect(child_profile.recommendations.active.count).to eq(2)
    expect(assessment_response.reload.processing_status).to eq("completed")
    expect(assessment_response.last_processed_at).to be_present
  end

  it "replaces prior recommendations when regenerated" do
    create(:recommendation, child_profile: child_profile, source_profile_snapshot: profile_snapshot)

    expect {
      described_class.perform_now(
        child_profile.id,
        source_profile_snapshot_id: profile_snapshot.id
      )
    }.to change(Recommendation, :count).by(1)
  end

  context "when a completed analysis run exists for the same snapshot" do
    let(:rubric) { create(:analysis_rubric, :published) }
    let!(:analysis_run) do
      create(
        :analysis_run, :completed,
        child_profile: child_profile,
        analysis_rubric: rubric,
        profile_snapshot: profile_snapshot
      )
    end
    let!(:regulation_finding) do
      create(
        :analysis_finding,
        analysis_run: analysis_run,
        dimension_key: "regulation",
        finding_key: "reg_baseline"
      )
    end

    it "persists analysis grounding in each recommendation rationale" do
      described_class.perform_now(
        child_profile.id,
        source_profile_snapshot_id: profile_snapshot.id,
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: assessment_response.id
      )

      child_profile.recommendations.each do |rec|
        expect(rec.rationale["analysis_run_id"]).to eq(analysis_run.id)
        expect(rec.rationale["analysis_finding_id"]).to eq(regulation_finding.id)
        expect(rec.rationale["analysis_finding_key"]).to eq("reg_baseline")
        expect(rec.rationale["analysis_rubric_key"]).to eq(rubric.rubric_key)
      end
    end
  end
end
