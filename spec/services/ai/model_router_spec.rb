# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ModelRouter do
  def cfg(**attrs)
    defaults = {
      enabled: true,
      provider: "openai",
      default_model: "model-a",
      timeout_seconds: 5,
      api_base_url: nil,
      api_key: "k",
      escalation_model: "model-b",
      validation_retry_model: "",
      escalation_enabled: false
    }
    Ai::Configuration.new(**defaults.merge(attrs))
  end

  def payload_with_meta(meta)
    { "payload_kind" => "anchor_analysis_run_v1", "packet_meta" => meta, "findings" => [] }
  end

  describe "#call" do
    it "returns default tier when escalation is disabled" do
      router = described_class.new(
        configuration: cfg(escalation_enabled: false),
        structured_payload: payload_with_meta("marked_complex" => true),
        validation_retry: false
      )
      result = router.call
      expect(result.tier).to eq("default")
      expect(result.model).to eq("model-a")
      expect(result.routing_reason).to eq("escalation_disabled")
    end

    it "escalates when packet_meta is marked complex" do
      router = described_class.new(
        configuration: cfg(escalation_enabled: true, escalation_model: "model-b"),
        structured_payload: payload_with_meta("marked_complex" => true),
        validation_retry: false
      )
      result = router.call
      expect(result.tier).to eq("escalated")
      expect(result.model).to eq("model-b")
      expect(result.routing_reason).to include("marked_complex")
    end

    it "stays on default when signals fire but escalation model is blank" do
      router = described_class.new(
        configuration: cfg(escalation_enabled: true, escalation_model: ""),
        structured_payload: payload_with_meta(
          "marked_complex" => true,
          "finding_count" => 99
        ),
        validation_retry: false
      )
      result = router.call
      expect(result.tier).to eq("default")
      expect(result.model).to eq("model-a")
      expect(result.routing_reason).to eq("escalation_signals_present_but_no_escalation_model")
    end

    it "returns validation_retry tier when retry is requested with distinct models" do
      router = described_class.new(
        configuration: cfg(
          escalation_enabled: true,
          escalation_model: "model-b",
          validation_retry_model: "model-c"
        ),
        structured_payload: payload_with_meta({}),
        validation_retry: true,
        prior_attempt_model: "model-a"
      )
      result = router.call
      expect(result.tier).to eq("validation_retry")
      expect(result.model).to eq("model-c")
    end

    it "falls back to escalation_model for validation retry when validation_retry_model is unset" do
      router = described_class.new(
        configuration: cfg(
          escalation_enabled: true,
          escalation_model: "model-b",
          validation_retry_model: ""
        ),
        structured_payload: payload_with_meta({}),
        validation_retry: true,
        prior_attempt_model: "model-a"
      )
      result = router.call
      expect(result.model).to eq("model-b")
    end

    it "skips validation retry when escalation is disabled" do
      router = described_class.new(
        configuration: cfg(escalation_enabled: false),
        structured_payload: payload_with_meta({}),
        validation_retry: true,
        prior_attempt_model: "model-a"
      )
      result = router.call
      expect(result.tier).to eq("default")
      expect(result.routing_reason).to eq("validation_retry_skipped_escalation_disabled")
    end

    it "uses no_retry tier when prior attempt already used the retry model" do
      router = described_class.new(
        configuration: cfg(escalation_enabled: true, escalation_model: "same", validation_retry_model: ""),
        structured_payload: payload_with_meta({}),
        validation_retry: true,
        prior_attempt_model: "same"
      )
      result = router.call
      expect(result.tier).to eq("no_retry")
    end
  end
end
