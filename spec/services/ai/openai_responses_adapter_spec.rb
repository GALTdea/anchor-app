# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::OpenaiResponsesAdapter do
  let(:api_key) { "sk-test-#{SecureRandom.hex(8)}" }
  let(:configuration) do
    Ai::Configuration.new(
      enabled: true,
      provider: "openai",
      default_model: "gpt-test-mini",
      timeout_seconds: 5,
      api_base_url: nil,
      api_key: api_key
    )
  end

  let(:successful_openai_body) do
    {
      "id" => "resp_test_1",
      "object" => "response",
      "status" => "completed",
      "model" => "gpt-test-mini",
      "output" => [
        {
          "type" => "message",
          "role" => "assistant",
          "content" => [
            { "type" => "output_text", "text" => '{"hello":"world"}' }
          ]
        }
      ],
      "usage" => { "input_tokens" => 10, "output_tokens" => 5, "total_tokens" => 15 }
    }
  end

  describe "#complete" do
    it "returns text and safe metadata including latency_ms" do
      http_post = proc do |_uri, headers, _body, _timeout|
        expect(headers["Authorization"]).to eq("Bearer #{api_key}")
        Ai::OpenaiResponsesAdapter::HttpResult.new(code: 200, body: JSON.generate(successful_openai_body), latency_ms: 42)
      end

      ad = described_class.new(configuration:, http_post: http_post)
      result = ad.complete(prompt: "instructions", model: nil)

      expect(result[:text]).to eq('{"hello":"world"}')
      expect(result[:provider]).to eq("openai")
      expect(result[:model]).to eq("gpt-test-mini")
      expect(result[:response_payload]["latency_ms"]).to eq(42)
      expect(result[:response_payload]["openai_response_id"]).to eq("resp_test_1")
      expect(result[:response_payload]["usage"]).to eq({ "input_tokens" => 10, "output_tokens" => 5, "total_tokens" => 15 })
      expect(result[:response_payload]["retry_classification"]).to eq("not_applicable")
    end

    it "classifies HTTP 429 as retryable" do
      http_post = proc do
        Ai::OpenaiResponsesAdapter::HttpResult.new(code: 429, body: '{"error":{"message":"rate"}}', latency_ms: 1)
      end

      ad = described_class.new(configuration:, http_post: http_post)

      expect do
        ad.complete(prompt: "p", model: nil)
      end.to raise_error(Ai::ProviderError) do |e|
        expect(e.retryable).to be true
        expect(e.metadata["retry_classification"]).to eq("retryable")
        expect(e.metadata["http_status"]).to eq(429)
      end
    end

    it "classifies HTTP 401 as non-retryable" do
      http_post = proc do
        Ai::OpenaiResponsesAdapter::HttpResult.new(code: 401, body: '{"error":{"message":"bad key"}}', latency_ms: 2)
      end

      ad = described_class.new(configuration:, http_post: http_post)

      expect do
        ad.complete(prompt: "p", model: nil)
      end.to raise_error(Ai::ProviderError) do |e|
        expect(e.retryable).to be false
        expect(e.metadata["retry_classification"]).to eq("non_retryable")
        expect(e.metadata["http_status"]).to eq(401)
      end
    end

    it "raises non-retryable error when output text is empty" do
      empty_output = successful_openai_body.merge(
        "output" => [
          { "type" => "message", "content" => [ { "type" => "output_text", "text" => "   " } ] }
        ]
      )
      http_post = proc do
        Ai::OpenaiResponsesAdapter::HttpResult.new(code: 200, body: JSON.generate(empty_output), latency_ms: 0)
      end
      ad = described_class.new(configuration:, http_post: http_post)

      expect do
        ad.complete(prompt: "p", model: nil)
      end.to raise_error(Ai::ProviderError) do |e|
        expect(e.retryable).to be false
        expect(e.message).to match(/no assistant text/i)
      end
    end

    it "classifies transport failures as retryable" do
      failing_http = proc { raise Errno::ECONNRESET, "reset" }
      ad = described_class.new(configuration:, http_post: failing_http)

      expect do
        ad.complete(prompt: "p", model: nil)
      end.to raise_error(Ai::ProviderError) do |e|
        expect(e.retryable).to be true
        expect(e.metadata["retry_classification"]).to eq("retryable")
      end
    end
  end
end
