# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Client do
  let(:stub_config) do
    Ai::Configuration.new(
      enabled: enabled_flag,
      provider: provider_name,
      default_model: "stub-mini",
      timeout_seconds: 5,
      api_base_url: nil,
      api_key: nil
    )
  end
  let(:enabled_flag) { true }
  let(:provider_name) { "stub" }
  let(:prompt) { "summarize deterministic findings about regulation" }

  subject(:client) { described_class.new(configuration: stub_config) }

  describe "#complete" do
    context "with stub provider" do
      it "returns text and metadata without issuing network calls" do
        first = client.complete(prompt: prompt)
        second = client.complete(prompt: prompt)

        expect(first[:provider]).to eq("stub")
        expect(first[:model]).to eq("stub-mini")
        expect(first[:response_payload]["stub"]).to be true
        expect(first[:text]).to eq(second[:text])
        expect(first[:text]).to include("stub_completion")
      end

      it "uses overridden model when given" do
        result = client.complete(prompt: prompt, model: "custom")

        expect(result[:model]).to eq("custom")
      end

      it "still completes when feature is marked disabled (stub ignores gate)" do
        disabled = Ai::Configuration.new(
          enabled: false,
          provider: "stub",
          default_model: "stub-mini",
          timeout_seconds: 5,
          api_base_url: nil,
          api_key: nil
        )

        result = described_class.new(configuration: disabled).complete(prompt: prompt)

        expect(result[:response_payload]["stub"]).to be true
      end
    end

    context "with the openai provider" do
      let(:provider_name) { "openai" }
      let(:enabled_flag) { true }
      let(:stub_config) do
        Ai::Configuration.new(
          enabled: enabled_flag,
          provider: provider_name,
          default_model: "gpt-fixture",
          timeout_seconds: 5,
          api_base_url: nil,
          api_key: api_key
        )
      end
      let(:api_key) { "sk-test-#{SecureRandom.hex(6)}" }

      it "raises when synthesis is disabled before checking the API key" do
        disabled = Ai::Configuration.new(
          enabled: false,
          provider: "openai",
          default_model: "gpt-fixture",
          timeout_seconds: 5,
          api_base_url: nil,
          api_key: nil
        )

        expect do
          described_class.new(configuration: disabled).complete(prompt: prompt)
        end.to raise_error(Ai::DisabledError, /disabled/i)
      end

      it "raises when the API key is missing" do
        no_key = Ai::Configuration.new(
          enabled: true,
          provider: "openai",
          default_model: "gpt-fixture",
          timeout_seconds: 5,
          api_base_url: nil,
          api_key: nil
        )

        expect do
          described_class.new(configuration: no_key).complete(prompt: prompt)
        end.to raise_error(Ai::DisabledError, /ANCHOR_AI_API_KEY/)
      end

      it "delegates to the OpenAI adapter and returns the stable contract" do
        adapter = instance_double(Ai::OpenaiResponsesAdapter)
        allow(adapter).to receive(:complete).with(prompt: prompt, model: nil).and_return(
          text: '{"ok":true}',
          provider: "openai",
          model: "gpt-fixture",
          response_payload: { "latency_ms" => 9 }
        )

        result = described_class.new(configuration: stub_config, openai_adapter: adapter).complete(prompt: prompt)

        expect(result[:text]).to eq('{"ok":true}')
        expect(result[:provider]).to eq("openai")
        expect(result[:model]).to eq("gpt-fixture")
        expect(result[:response_payload]["latency_ms"]).to eq(9)
      end
    end

    context "with a non-stub provider" do
      let(:provider_name) { "future_provider" }
      let(:enabled_flag) { false }

      it "raises when synthesis is disabled" do
        expect do
          client.complete(prompt: prompt)
        end.to raise_error(Ai::DisabledError, /disabled/i)
      end

      context "when enabled is true" do
        let(:enabled_flag) { true }

        it "raises unsupported provider until an adapter ships" do
          expect do
            client.complete(prompt: prompt)
          end.to raise_error(Ai::UnsupportedProviderError, /future_provider/)
        end
      end
    end
  end
end
