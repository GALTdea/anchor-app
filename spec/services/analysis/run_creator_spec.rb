# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analysis::RunCreator, type: :model do
  let(:time) { Time.zone.parse("2026-03-01 10:00:00") }
  let(:rubric) do
    create(
      :analysis_rubric, :published,
      rubric_key: "rubric_run_spec",
      version: 1,
      schema: {
        "version" => 1,
        "domains" => [
          {
            "key" => "regulation",
            "title" => "Regulation",
            "dimension_key_prefixes" => [ "regulation." ],
            "scoring" => { "higher_is_more_support" => true },
            "confidence" => { "base_cap" => 0.9, "low_confidence_if_below" => 0.35 },
            "evidence_minimums" => { "min_rows" => 1 },
            "parent_labels" => { "anchor" => "Regulation" }
          }
        ]
      }
    )
  end

  it "rejects a non-published rubric" do
    draft = create(:analysis_rubric, rubric_key: "draft_r", version: 2, status: :draft, schema: rubric.schema)
    child = create(:child_profile)
    expect { described_class.new(child_profile: child, analysis_rubric: draft).call }.to raise_error(ArgumentError, /published/)
  end

  it "creates a completed run and findings" do
    travel_to(time) do
      child = create(:child_profile)
      create(
        :profile_evidence,
        child_profile: child,
        dimension_key: "regulation.stress",
        value: "4",
        value_type: "integer",
        confidence: 0.7
      )
      build(
        :current_profile,
        child_profile: child,
        summary: { "stats" => { "evidence_count" => 1 } },
        generated_at: time
      ).save!

      run = described_class.new(child_profile: child, analysis_rubric: rubric).call
      expect(run).to be_completed
      expect(run.analysis_findings.size).to eq(1)
      expect(run.input_digest).to be_present
      expect(run.engine_version).to eq(Analysis::RunCreator::ENGINE_VERSION)
    end
  end

  it "is idempotent for the same inputs" do
    travel_to(time) do
      child = create(:child_profile)
      create(
        :profile_evidence,
        child_profile: child,
        dimension_key: "regulation.stress",
        value: "2",
        value_type: "integer",
        confidence: 0.6
      )
      build(
        :current_profile,
        child_profile: child,
        summary: { "stats" => { "evidence_count" => 1 } },
        generated_at: time
      ).save!

      a = described_class.new(child_profile: child, analysis_rubric: rubric).call
      b = described_class.new(child_profile: child, analysis_rubric: rubric).call
      expect(b.id).to eq(a.id)
      expect(AnalysisRun.where(child_profile: child, analysis_rubric: rubric, status: :completed).count).to eq(1)
    end
  end
end
