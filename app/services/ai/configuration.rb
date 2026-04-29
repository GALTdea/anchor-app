# frozen_string_literal: true

module Ai
  # Loads YAML (`config/ai.yml`) merged with ENV. API keys belong in ENV only.
  class Configuration
    attr_reader :enabled,
                :provider,
                :default_model,
                :timeout_seconds,
                :api_base_url,
                :api_key

    def self.load
      yaml = Rails.application.config_for(:ai).deep_symbolize_keys
      new(
        enabled: cast_bool(ENV["ANCHOR_AI_ENABLED"], fallback: yaml[:enabled]),
        provider: (ENV["ANCHOR_AI_PROVIDER"].presence || yaml[:provider]).to_s,
        default_model: (ENV["ANCHOR_AI_DEFAULT_MODEL"].presence || yaml[:default_model]).to_s,
        timeout_seconds: Integer(ENV["ANCHOR_AI_TIMEOUT_SECONDS"].presence || yaml[:timeout_seconds] || 30),
        api_base_url: ENV["ANCHOR_AI_API_BASE_URL"].presence || yaml[:api_base_url],
        api_key: ENV["ANCHOR_AI_API_KEY"].presence
      )
    end

    def self.cast_bool(env_value, fallback:)
      return fallback if env_value.nil?

      ActiveRecord::Type::Boolean.new.cast(env_value)
    end

    def initialize(enabled:, provider:, default_model:, timeout_seconds:, api_base_url:, api_key:)
      @enabled = enabled
      @provider = provider
      @default_model = default_model
      @timeout_seconds = timeout_seconds
      @api_base_url = api_base_url
      @api_key = api_key
    end

    def enabled?
      @enabled
    end

    def stub?
      provider.casecmp("stub").zero?
    end
    alias stub_provider? stub?
  end
end
