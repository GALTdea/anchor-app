# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::SynthesisRunner do
  let(:child_profile) { create(:child_profile) }
  let(:rubric) { create(:analysis_rubric, :published, rubric_key: "runner_rubric", version: 1) }
  let!(:analysis_run) { create(:analysis_run, :completed, child_profile:, analysis_rubric: rubric) }

  before do
    create(
      :analysis_finding,
      analysis_run:,
      dimension_key: "communication.x",
      finding_key: "communication.x.support_signal"
    )
  end

  it "writes a completed AiSynthesisRun in stub/offline provider mode with validated output" do
    result = described_class.new(analysis_run:, purpose: Ai::PromptRenderer::DEFAULT_PURPOSE).call

    expect(result.success).to be true
    expect(result.skipped).to be false
    synthesis = result.synthesis_run
    expect(synthesis).to be_completed
    expect(synthesis.output["summary_plain"]).to be_present
    expect(synthesis.request_payload["prompt_sha256"]).to match(/\A\h{64}\z/)
    expect(synthesis.response_payload["validation_errors"]).to eq([])
  end

  it "skips work when an identical prompt_version already succeeded" do
    described_class.new(analysis_run:, purpose: Ai::PromptRenderer::DEFAULT_PURPOSE).call

    second = described_class.new(analysis_run:, purpose: Ai::PromptRenderer::DEFAULT_PURPOSE).call

    expect(second.skipped).to be true
    expect(AiSynthesisRun.where(analysis_run:, status: :completed).count).to eq(1)
  end

  it "runs again when forced even if completed exists" do
    described_class.new(analysis_run:).call

    forced = described_class.new(analysis_run:, force: true).call

    expect(forced.skipped).to be false
    expect(forced.success).to be true
    expect(AiSynthesisRun.where(analysis_run:, status: :completed).count).to eq(2)
  end

  it "records failed synthesis with safe provider metadata when the client raises ProviderError" do
    secret = "sk-test-#{SecureRandom.hex(16)}"
    cfg = Ai::Configuration.new(
      enabled: true,
      provider: "openai",
      default_model: "gpt-x",
      timeout_seconds: 5,
      api_base_url: nil,
      api_key: secret
    )
    adapter = instance_double(Ai::OpenaiResponsesAdapter)
    allow(adapter).to receive(:complete).and_raise(
      Ai::ProviderError.new(
        "upstream failed",
        retryable: true,
        metadata: {
          "provider" => "openai",
          "model" => "gpt-x",
          "http_status" => 503,
          "latency_ms" => 12,
          "retry_classification" => "retryable"
        }
      )
    )
    client = Ai::Client.new(configuration: cfg, openai_adapter: adapter)

    result = described_class.new(analysis_run:, client:, configuration: cfg).call

    expect(result.success).to be false
    syn = result.synthesis_run
    expect(syn).to be_failed
    leaked = syn.response_payload.merge(syn.request_payload).to_json
    expect(leaked).not_to include(secret)
    expect(syn.response_payload["upstream"]["retry_classification"]).to eq("retryable")
    expect(syn.response_payload["upstream"]["latency_ms"]).to eq(12)
  end

  it "validates live provider JSON text; upstream metadata does not bypass the validator" do
    cfg = Ai::Configuration.new(
      enabled: true,
      provider: "openai",
      default_model: "gpt-x",
      timeout_seconds: 5,
      api_base_url: nil,
      api_key: "sk-test-fixed"
    )
    adapter = instance_double(Ai::OpenaiResponsesAdapter)
    allow(adapter).to receive(:complete).and_return(
      text: "{}",
      provider: "openai",
      model: "gpt-x",
      response_payload: { "would_be_valid" => true, "latency_ms" => 1 }
    )
    client = Ai::Client.new(configuration: cfg, openai_adapter: adapter)

    result = described_class.new(analysis_run:, client:, configuration: cfg).call

    expect(result.success).to be false
    expect(result.synthesis_run.failed?).to be true
    expect(result.synthesis_run.response_payload["validation_errors"]).not_to be_empty
  end

  it "writes completed synthesis using live provider text when it passes validation" do
    cfg = Ai::Configuration.new(
      enabled: true,
      provider: "openai",
      default_model: "gpt-x",
      timeout_seconds: 5,
      api_base_url: nil,
      api_key: "sk-test-fixed"
    )
    live_text = {
      "synthesis_schema_version" => "anchor_synthesis_v1",
      "summary_plain" =>
        "Anchor noticed patterns in the profile worth summarizing for parents in plain language with enough length here.",
      "confidence_note" => nil,
      "what_to_watch" => [ "Day to day" ],
      "finding_refs" => [ { "finding_key" => "communication.x.support_signal", "summary_gist" => nil } ]
    }.to_json
    adapter = instance_double(Ai::OpenaiResponsesAdapter)
    allow(adapter).to receive(:complete).and_return(
      text: live_text,
      provider: "openai",
      model: "gpt-x",
      response_payload: { "latency_ms" => 33, "openai_response_id" => "resp_1" }
    )
    client = Ai::Client.new(configuration: cfg, openai_adapter: adapter)

    result = described_class.new(analysis_run:, client:, configuration: cfg).call

    expect(result.success).to be true
    expect(result.synthesis_run.output["summary_plain"]).to include("Anchor noticed")
    expect(result.synthesis_run.response_payload["upstream"]["latency_ms"]).to eq(33)
  end

  it "records failed synthesis when validator rejects model text (non-stub path)" do
    cfg = Ai::Configuration.new(
      enabled: true,
      provider: "test",
      default_model: "test",
      timeout_seconds: 5,
      api_base_url: nil,
      api_key: nil
    )
    client = instance_double(Ai::Client)
    allow(client).to receive(:complete).and_return(
      {
        text: "{}",
        provider: "fixture",
        model: "fixture-1",
        response_payload: { "upstream" => true }
      }
    )

    result = described_class.new(analysis_run:, client:, configuration: cfg).call

    expect(result.success).to be false
    expect(result.synthesis_run.failed?).to be true
    expect(result.synthesis_run.error_message).to be_present
    expect(result.synthesis_run.response_payload["validation_errors"]).not_to be_empty
  end

  it "returns an error payload when analysis run is not completed" do
    incomplete = create(:analysis_run, :running, child_profile:, analysis_rubric: rubric)
    create(:analysis_finding, analysis_run: incomplete)

    result = described_class.new(analysis_run: incomplete.id).call

    expect(result.success).to be false
    expect(result.synthesis_run).to be_nil
  end
end
