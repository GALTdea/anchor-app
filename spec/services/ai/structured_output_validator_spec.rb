# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::StructuredOutputValidator do
  let(:payload) do
    {
      "payload_kind" => "anchor_analysis_run_v1",
      "findings" => [
        {
          "finding_key" => "domain.a.support_signal",
          "dimension_key" => "domain.a",
          "summary" => "x"
        }
      ]
    }
  end

  def build_valid_hash(extra = {})
    {
      "synthesis_schema_version" => "anchor_synthesis_v1",
      "summary_plain" =>
        "Anchor noticed several profile signals worth tracking together for this child here today.",
      "finding_refs" => [
        { "finding_key" => "domain.a.support_signal", "summary_gist" => "Noted pattern." }
      ],
      "confidence_note" => "Signals are modest-confidence for now.",
      "what_to_watch" => [
        "How communication shows up during transitions."
      ]
    }.merge(extra.stringify_keys)
  end

  def build_valid_text(extra = {})
    JSON.generate(build_valid_hash(extra))
  end

  describe "#call" do
    it "accepts fenced JSON" do
      text = <<~TXT
        ```json
        #{build_valid_text}
        ```
      TXT
      result = described_class.new(prompt_version: "parent_guidance@v1", raw_text: text,
        structured_analysis_payload: payload).call

      expect(result.success).to be true
      expect(result.output["summary_plain"]).to include("Anchor noticed")
    end

    it "surfaces unsupported prompt versions" do
      result = described_class.new(prompt_version: "unknown@v999", raw_text: "{}",
        structured_analysis_payload: payload).call

      expect(result.success).to be false
      expect(result.errors.join).to include("unsupported prompt_version")
    end

    it "rejects malformed JSON" do
      result = described_class.new(prompt_version: "parent_guidance@v1", raw_text: "not json",
        structured_analysis_payload: payload).call

      expect(result.success).to be false
      expect(result.errors.join).to include("could not parse")
    end

    it "rejects schema violations" do
      result = described_class.new(
        prompt_version: "parent_guidance@v1",
        raw_text: JSON.generate({}),
        structured_analysis_payload: payload
      ).call

      expect(result.success).to be false
      expect(result.errors).not_to be_empty
    end

    it "rejects extra top-level keys (strict envelope)" do
      h = build_valid_hash
      h["extra_field"] = "nope"
      result = described_class.new(
        prompt_version: "parent_guidance@v1",
        raw_text: JSON.generate(h),
        structured_analysis_payload: payload
      ).call

      expect(result.success).to be false
      expect(result.errors.join).to match(/schema|additionalProperties|The property/i)
    end

    it "rejects finding_keys absent from deterministic analysis" do
      h = build_valid_hash
      h["finding_refs"] = [ { "finding_key" => "made.up.signal" } ]

      result = described_class.new(
        prompt_version: "parent_guidance@v1",
        raw_text: JSON.generate(h),
        structured_analysis_payload: payload
      ).call

      expect(result.success).to be false
      expect(result.errors.join).to include("unknown finding_key")
    end

    it "rejects anchored refs when deterministic findings are empty" do
      h = build_valid_hash
      empty_payload = payload.merge("findings" => [])

      result = described_class.new(
        prompt_version: "parent_guidance@v1",
        raw_text: JSON.generate(h),
        structured_analysis_payload: empty_payload
      ).call

      expect(result.success).to be false
      expect(result.errors.join).to match(/empty|finding_refs/i)
    end

    it "allows empty finding_refs when deterministic findings are empty" do
      h = build_valid_hash
      h["finding_refs"] = []

      result = described_class.new(
        prompt_version: "parent_guidance@v1",
        raw_text: JSON.generate(h),
        structured_analysis_payload: { "findings" => [] }
      ).call

      expect(result.success).to be true
    end

    it "blocks discouraged phrasing clusters" do
      h = build_valid_hash
      h["summary_plain"] =
        "This text uses the word diagnosis which we try to avoid in parent-facing copy here today."

      result = described_class.new(
        prompt_version: "parent_guidance@v1",
        raw_text: JSON.generate(h),
        structured_analysis_payload: payload
      ).call

      expect(result.success).to be false
      expect(result.errors.join).to match(/unsafe|diagnosis/i)
    end

    it "returns deep-string-keyed hashes on success" do
      result = described_class.new(
        prompt_version: "parent_guidance@v1",
        raw_text: build_valid_text,
        structured_analysis_payload: payload
      ).call

      expect(result.success).to be true
      expect(result.output.keys.all? { |k| k.is_a?(String) }).to be true
    end
  end
end
