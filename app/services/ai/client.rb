# frozen_string_literal: true

require "digest"

module Ai
  # Abstraction over external AI providers. Controllers/jobs talk to this, not SDKs directly.
  class Client
    def initialize(configuration: Ai.configuration, openai_adapter: nil)
      @configuration = configuration
      @openai_adapter = openai_adapter
    end

    # Returns a hash usable by synthesis persistence (Step 5+).
    #
    # @param prompt [String]
    # @param model [String, nil]
    # @return [Hash] keys: :text, :provider, :model, :response_payload
    def complete(prompt:, model: nil)
      return complete_stub(prompt, model) if @configuration.stub?

      raise DisabledError, "AI synthesis is disabled" unless @configuration.enabled?

      if openai_provider?
        return complete_openai(prompt, model) if @configuration.api_key.present?

        raise DisabledError, "ANCHOR_AI_API_KEY is required for OpenAI"
      end

      raise UnsupportedProviderError,
            "Provider #{@configuration.provider.inspect} has no adapter yet."
    end

    private

    def openai_provider?
      @configuration.provider.casecmp("openai").zero?
    end

    def complete_openai(prompt, model)
      adapter = @openai_adapter || OpenaiResponsesAdapter.new(configuration: @configuration)
      adapter.complete(prompt:, model:)
    end

    def complete_stub(prompt, model)
      {
        text: stub_text_for(prompt),
        provider: "stub",
        model: model.presence || @configuration.default_model,
        response_payload: {
          "stub" => true,
          "digest" => Digest::SHA256.hexdigest(prompt)[0..16]
        }
      }
    end

    def stub_text_for(prompt)
      hash = Digest::SHA256.hexdigest(prompt)
      { stub_completion: hash[0..7], echo_length: prompt.bytesize }.to_json
    end
  end
end
