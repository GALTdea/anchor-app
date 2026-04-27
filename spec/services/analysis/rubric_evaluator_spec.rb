# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analysis::RubricEvaluator, type: :model do
  let(:time) { Time.zone.parse("2026-02-01 08:00:00") }
  let(:rubric) do
    create(
      :analysis_rubric, :published,
      rubric_key: "rubric_eval_spec",
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
            "parent_labels" => { "anchor" => "How your child expresses needs" }
          }
        ]
      }
    )
  end

  it "returns no findings for a draft rubric" do
    draft = create(
      :analysis_rubric,
      status: :draft,
      published_at: nil,
      rubric_key: "draft_only",
      version: 1,
      schema: rubric.schema
    )
    input = { "evidence" => [ { "dimension_key" => "communication.x", "value" => "3", "confidence" => 0.8, "id" => 1, "metadata" => {} } ] }
    out = described_class.new(rubric: draft, input:).call
    expect(out).to eq([])
  end

  it "emits a stable domain finding for matching evidence" do
    travel_to(time) do
      child = create(:child_profile)
      e = create(
        :profile_evidence,
        child_profile: child,
        dimension_key: "communication.expressive",
        value: "3",
        value_type: "integer",
        confidence: 0.8,
        metadata: { "evidence_weight" => 0.5 }
      )
      build(:current_profile, child_profile: child, summary: { "stats" => {} }, generated_at: time).save!
      input = Analysis::InputBuilder.new(child_profile: child).build

      f = described_class.new(rubric:, input:).call.first
      expect(f).to be_present
      expect(f["dimension_key"]).to eq("communication")
      expect(f["finding_key"]).to eq("communication.support_signal")
      expect(f["score"]).to eq(0.5) # (3-1)/4
      expect(f["evidence_refs"]["profile_evidence_ids"]).to eq([ e.id ])
      expect(f["metadata"]["rubric_key"]).to eq("rubric_eval_spec")
    end
  end

  it "returns nothing when no evidence matches any domain" do
    input = { "evidence" => [ { "dimension_key" => "other.dim", "value" => "1", "id" => 1, "confidence" => 0.5, "metadata" => {} } ] }
    out = described_class.new(rubric:, input:).call
    expect(out).to eq([])
  end
end
