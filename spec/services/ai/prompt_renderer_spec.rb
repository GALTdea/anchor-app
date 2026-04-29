# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::PromptRenderer do
  describe "#call" do
    let(:child_profile) { create(:child_profile, first_name: "Sam") }
    let(:rubric) { create(:analysis_rubric, :published, rubric_key: "test_rubric", version: 2, name: "Test rubric") }
    let(:analysis_run) { create(:analysis_run, :completed, child_profile:, analysis_rubric: rubric) }

    before do
      create(
        :analysis_finding,
        analysis_run:,
        dimension_key: "communication.overall_concern",
        finding_key: "communication.overall_concern.support_signal",
        summary: "Pattern from saved answers.",
        label: "Communication support signal",
        severity: "low",
        score: 0.4,
        confidence: 0.8,
        metadata: { "rubric_domain" => "communication" }
      )
    end

    it "returns prompt text, a stable prompt_version, and structured_payload from persisted findings only" do
      result = described_class.new(analysis_run:).call

      expect(result.prompt).to include('"payload_kind"', "anchor_analysis_run_v1")
      expect(result.prompt).to include("communication.overall_concern")
      expect(result.prompt_version).to eq("parent_guidance@v1")
      expect(result.purpose).to eq("parent_guidance_v1")

      payload = result.structured_payload
      expect(payload["payload_kind"]).to eq("anchor_analysis_run_v1")
      expect(payload.dig("rubric", "rubric_key")).to eq("test_rubric")
      expect(payload["findings"].size).to eq(1)
      expect(payload.dig("findings", 0, "summary")).to include("saved answers")

      stub = payload["child_profile"]
      expect(stub["first_name"]).to eq("Sam")
    end

    it "includes packet_meta aggregates for model routing" do
      result = described_class.new(analysis_run:).call
      meta = result.structured_payload["packet_meta"]
      expect(meta["finding_count"]).to eq(1)
      expect(meta["average_confidence"]).to eq(0.8)
      expect(meta["min_confidence"]).to eq(0.8)
      expect(meta["low_confidence_finding_count"]).to eq(0)
      expect(meta["severity_counts"]).to include("low" => 1)
      expect(meta["nonblank_summary_count"]).to eq(1)
      expect(meta["summary_total_bytes"]).to be_positive
      expect(meta["conflict_signal_count"]).to eq(0)
      expect(meta["marked_complex"]).to be false
    end

    it "supports an explicit purpose" do
      result = described_class.new(analysis_run:, purpose: "parent_guidance_v1").call

      expect(result.prompt_version).to eq("parent_guidance@v1")
    end

    it "rejects incomplete runs" do
      incomplete = create(:analysis_run, :running, child_profile:, analysis_rubric: rubric)

      expect do
        described_class.new(analysis_run: incomplete).call
      end.to raise_error(ArgumentError, /completed/)
    end

    it "raises on unknown purpose" do
      expect do
        described_class.new(analysis_run:, purpose: "unknown_purpose").call
      end.to raise_error(ArgumentError, /unknown prompt purpose/)
    end

    it "handles zero findings without error" do
      empty_run = create(:analysis_run, :completed, child_profile:, analysis_rubric: rubric)

      result = described_class.new(analysis_run: empty_run).call

      expect(result.structured_payload["findings"]).to eq([])
    end

    it "reloads the run with includes when associations are not preloaded" do
      run_with_id_only = AnalysisRun.where(id: analysis_run.id).select(:id).first

      result = described_class.new(analysis_run: run_with_id_only).call

      expect(result.structured_payload.dig("findings", 0, "dimension_key")).to eq("communication.overall_concern")
    end
  end
end
