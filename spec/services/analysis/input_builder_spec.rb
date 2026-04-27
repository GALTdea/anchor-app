# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analysis::InputBuilder, type: :model do
  let(:child_profile) { create(:child_profile) }
  let(:time) { Time.zone.parse("2026-01-10 12:00:00") }

  it "builds a stable, ordered evidence payload" do
    travel_to(time) do
      e1 = create(:profile_evidence, child_profile:, dimension_key: "communication.receptive", value: "1")
      _e2 = create(:profile_evidence, child_profile:, dimension_key: "communication.expressive", value: "2")

      payload = described_class.new(child_profile:).build
      expect(payload["builder_version"]).to eq(1)
      expect(payload["evidence"].map { |e| e["id"] }).to eq([ e1, _e2 ].map(&:id).sort)
      expect(payload["evidence"].first).to include(
        "dimension_key" => "communication.receptive",
        "value" => e1.value
      )
    end
  end

  it "is deterministic: same data yields the same digest" do
    travel_to(time) do
      create(
        :current_profile,
        child_profile:,
        profile_version: 1,
        generated_at: time,
        summary: { "stats" => { "evidence_count" => 1 } }
      )
      _e = create(
        :profile_evidence,
        child_profile:,
        dimension_key: "communication.receptive",
        value: "3",
        concept_key: "c",
        recorded_at: time
      )

      d1 = described_class.new(child_profile:).digest
      d2 = described_class.new(child_profile:).digest
      expect(d1).to eq(d2)
      expect(d1.length).to eq(64)
    end
  end

  it "changes the digest when evidence changes" do
    travel_to(time) do
      build(:current_profile, child_profile:).save!
      e = create(
        :profile_evidence,
        child_profile:,
        dimension_key: "social.test",
        value: "1"
      )
      a = described_class.new(child_profile:).digest
      e.update!(value: "5")
      b = described_class.new(child_profile:).digest
      expect(a).not_to eq(b)
    end
  end

  it "embeds a profile snapshot when provided" do
    travel_to(time) do
      snap = create(:profile_snapshot, child_profile:, generated_at: time)
      p = described_class.new(child_profile:, profile_snapshot: snap).build
      expect(p["profile_snapshot"]).to include(
        "id" => snap.id
      )
    end
  end
end
