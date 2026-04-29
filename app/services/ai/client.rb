# frozen_string_literal: true

require "digest"

module Ai
  # Abstraction over external AI providers. Controllers/jobs talk to this, not SDKs directly.
  class Client
    def initialize(configuration: Ai.configuration)
      @configuration = configuration
    end

    # Returns a hash usable by synthesis persistence (Step 5+).
    #
    # @param prompt [String]
    # @param model [String, nil]
    # @return [Hash] keys: :text, :provider, :model, :response_payload
    def complete(prompt:, model: nil)
      return complete_stub(prompt, model) if @configuration.stub?

      raise DisabledError, "AI synthesis is disabled" unless @configuration.enabled?

      raise UnsupportedProviderError,
            "Provider #{@configuration.provider.inspect} has no adapter yet."
    end

    private

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
