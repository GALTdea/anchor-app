# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalysisRunJob, type: :job do
  let(:rubric) do
    create(
      :analysis_rubric, :published,
      rubric_key: "job_analysis_r",
      version: 1,
      schema: {
        "version" => 1,
        "domains" => [
          {
            "key" => "communication",
            "title" => "Communication",
            "dimension_key_prefixes" => [ "communication." ],
            "scoring" => { "higher_is_more_support" => true },
            "confidence" => { "base_cap" => 0.9, "low_confidence_if_below" => 0.35 },
            "evidence_minimums" => { "min_rows" => 1 },
            "parent_labels" => { "anchor" => "Comms" }
          }
        ]
      }
    )
  end

  it "creates a completed analysis run for each published rubric" do
    rubric
    child = create(:child_profile)
    create(
      :profile_evidence,
      child_profile: child,
      dimension_key: "communication.expressive",
      value: "3",
      value_type: "integer",
      confidence: 0.7
    )
    create(
      :current_profile,
      child_profile: child,
      summary: { "stats" => { "evidence_count" => 1 } }
    )
    snap = create(:profile_snapshot, child_profile: child)

    expect {
      described_class.perform_now(
        child.id,
        profile_snapshot_id: snap.id,
        trigger_source_type: "AssessmentResponse",
        trigger_source_id: 0,
        run_inline: true
      )
    }.to change { AnalysisRun.where(child_profile: child, status: :completed).count }.by(1)
      .and change(AnalysisFinding, :count).by(1)
      .and change(AiSynthesisRun, :count).by(1)
  end

  it "no-ops when the snapshot is missing" do
    rubric
    child = create(:child_profile)
    create(:current_profile, child_profile: child, summary: { "stats" => {} })

    expect {
      described_class.perform_now(
        child.id,
        profile_snapshot_id: 0,
        run_inline: false
      )
    }.not_to change(AnalysisRun, :count)
  end

  it "no-ops when the current profile is missing" do
    rubric
    child = create(:child_profile)
    snap = create(:profile_snapshot, child_profile: child)
    child.current_profile&.destroy

    expect {
      described_class.perform_now(
        child.id,
        profile_snapshot_id: snap.id
      )
    }.not_to change(AnalysisRun, :count)
  end

  it "no-ops when there are no published rubrics" do
    child = create(:child_profile)
    create(
      :current_profile,
      child_profile: child,
      summary: { "stats" => {} }
    )
    snap = create(:profile_snapshot, child_profile: child)

    expect {
      described_class.perform_now(
        child.id,
        profile_snapshot_id: snap.id
      )
    }.not_to change(AnalysisRun, :count)
  end
end
