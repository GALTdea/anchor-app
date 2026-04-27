# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecommendationBuilder do
  let(:child_profile) { create(:child_profile) }
  let(:source_profile_snapshot) { create(:profile_snapshot, child_profile: child_profile) }
  let(:summary) do
    {
      "stats" => { "evidence_count" => 1, "dimension_count" => 1 },
      "dimensions" => {
        "regulation.overall_concern" => {
          "concept_key" => "overall_concern_level",
          "latest_value" => "3",
          "value_type" => "integer",
          "confidence" => 0.8,
          "respondent_kind" => "parent_proxy",
          "recorded_at" => Time.current.iso8601,
          "metadata" => {}
        }
      }
    }
  end
  let(:current_profile) { create(:current_profile, child_profile: child_profile, summary: summary) }
  let(:rubric) { create(:analysis_rubric, :published, rubric_key: "test_anchor_v1", version: 1) }

  def recommendations_for(analysis_run: nil)
    described_class.new(
      current_profile: current_profile,
      source_profile_snapshot: source_profile_snapshot,
      analysis_run: analysis_run
    ).call
  end

  it "returns recommendation hashes without analysis keys when no analysis run is given" do
    recs = recommendations_for(analysis_run: nil)
    expect(recs.size).to eq(1)
    expect(recs.first[:rationale].keys).not_to include("analysis_run_id", "analysis_finding_id")
  end

  it "does not ground rationale when the analysis run is not completed" do
    run = create(:analysis_run, child_profile: child_profile, analysis_rubric: rubric, profile_snapshot: source_profile_snapshot, status: :running, started_at: Time.current)
    recs = recommendations_for(analysis_run: run)
    expect(recs.first[:rationale].keys).not_to include("analysis_run_id")
  end

  it "merges analysis finding refs when a completed run has a matching domain finding" do
    run = create(
      :analysis_run, :completed,
      child_profile: child_profile,
      analysis_rubric: rubric,
      profile_snapshot: source_profile_snapshot
    )
    finding = create(
      :analysis_finding,
      analysis_run: run,
      dimension_key: "regulation",
      finding_key: "reg_baseline"
    )
    recs = recommendations_for(analysis_run: run)
    r = recs.first[:rationale]
    expect(r["analysis_run_id"]).to eq(run.id)
    expect(r["analysis_rubric_key"]).to eq(rubric.rubric_key)
    expect(r["analysis_rubric_version"]).to eq(rubric.version)
    expect(r["analysis_finding_id"]).to eq(finding.id)
    expect(r["analysis_finding_key"]).to eq("reg_baseline")
  end

  it "maps regulation.routine profile dimensions to the flexibility rubric domain" do
    summary = current_profile.summary.deep_dup
    summary["dimensions"] = {
      "regulation.routine" => {
        "concept_key" => "routine",
        "latest_value" => "yes",
        "value_type" => "selection",
        "confidence" => 0.7,
        "respondent_kind" => "parent_proxy",
        "recorded_at" => Time.current.iso8601,
        "metadata" => {}
      }
    }
    current_profile.update!(summary: summary)
    run = create(
      :analysis_run, :completed,
      child_profile: child_profile,
      analysis_rubric: rubric,
      profile_snapshot: source_profile_snapshot
    )
    create(:analysis_finding, analysis_run: run, dimension_key: "flexibility", finding_key: "flex_1")
    recs = recommendations_for(analysis_run: run)
    expect(recs.first[:rationale]["analysis_finding_key"]).to eq("flex_1")
  end
end
