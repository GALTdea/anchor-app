# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Configuration do
  describe "#initialize" do
    it "defaults escalation to off and blank models" do
      cfg = described_class.new(
        enabled: true,
        provider: "stub",
        default_model: "stub-mini",
        timeout_seconds: 5,
        api_base_url: nil,
        api_key: nil
      )
      expect(cfg.escalation_enabled?).to be false
      expect(cfg.escalation_model).to eq("")
      expect(cfg.validation_retry_model).to eq("")
    end

    it "stores escalation attributes" do
      cfg = described_class.new(
        enabled: true,
        provider: "openai",
        default_model: "a",
        timeout_seconds: 5,
        api_base_url: nil,
        api_key: "k",
        escalation_model: "b",
        validation_retry_model: "c",
        escalation_enabled: true
      )
      expect(cfg.escalation_enabled?).to be true
      expect(cfg.escalation_model).to eq("b")
      expect(cfg.validation_retry_model).to eq("c")
    end
  end

  describe ".load" do
    let(:yaml_base) do
      {
        "enabled" => false,
        "provider" => "stub",
        "default_model" => "stub-mini",
        "escalation_model" => "",
        "validation_retry_model" => "",
        "escalation_enabled" => false,
        "timeout_seconds" => 30,
        "api_base_url" => nil
      }
    end

    it "merges ANCHOR_AI_ESCALATION_* and ANCHOR_AI_VALIDATION_RETRY_MODEL from ENV over yaml" do
      allow(Rails.application).to receive(:config_for).with(:ai).and_return(yaml_base)
      allow(described_class).to receive(:credentials_openai_api_key).and_return(nil)
      saved = ENV.to_h
      begin
        ENV.replace(saved.merge(
          "ANCHOR_AI_ESCALATION_MODEL" => "esc-from-env",
          "ANCHOR_AI_VALIDATION_RETRY_MODEL" => "retry-from-env",
          "ANCHOR_AI_ESCALATION_ENABLED" => "true"
        ))
        cfg = described_class.load
        expect(cfg.escalation_model).to eq("esc-from-env")
        expect(cfg.validation_retry_model).to eq("retry-from-env")
        expect(cfg.escalation_enabled?).to be true
      ensure
        ENV.replace(saved)
      end
    end

    it "uses the OpenAI API key from credentials when ENV is blank" do
      allow(Rails.application).to receive(:config_for).with(:ai).and_return(yaml_base)
      allow(described_class).to receive(:credentials_openai_api_key).and_return("sk-from-credentials")
      saved = ENV.to_h
      begin
        ENV.replace(saved.except("ANCHOR_AI_API_KEY"))

        cfg = described_class.load

        expect(cfg.api_key).to eq("sk-from-credentials")
      ensure
        ENV.replace(saved)
      end
    end

    it "prefers ANCHOR_AI_API_KEY over credentials" do
      allow(Rails.application).to receive(:config_for).with(:ai).and_return(yaml_base)
      allow(described_class).to receive(:credentials_openai_api_key).and_return("sk-from-credentials")
      saved = ENV.to_h
      begin
        ENV.replace(saved.merge("ANCHOR_AI_API_KEY" => "sk-from-env"))

        cfg = described_class.load

        expect(cfg.api_key).to eq("sk-from-env")
      ensure
        ENV.replace(saved)
      end
    end
  end
end
