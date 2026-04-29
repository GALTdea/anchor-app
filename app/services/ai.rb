# frozen_string_literal: true

# Namespace for external AI integration (synthesis layer on deterministic analysis).
module Ai
  class Error < StandardError; end

  # Feature is off or credentials are missing for a non-stub provider.
  class DisabledError < Error; end

  # Provider is selected but not implemented yet.
  class UnsupportedProviderError < Error; end

  # HTTP or response-shape failure from a live provider (OpenAI, future adapters).
  class ProviderError < Error
    attr_reader :retryable, :metadata

    def initialize(message, retryable:, metadata: {})
      super(message)
      @retryable = retryable
      @metadata = metadata
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.load
    end

    attr_writer :configuration
  end
end
