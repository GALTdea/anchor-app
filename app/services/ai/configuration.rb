# frozen_string_literal: true

module Ai
  # Loads YAML (`config/ai.yml`) merged with ENV. API keys belong in ENV only.
  class Configuration
    attr_reader :enabled,
                :provider,
                :default_model,
                :escalation_model,
                :validation_retry_model,
                :escalation_enabled,
                :timeout_seconds,
                :api_base_url,
                :api_key

    def self.load
      yaml = Rails.application.config_for(:ai).deep_symbolize_keys
      new(
        enabled: cast_bool(ENV["ANCHOR_AI_ENABLED"], fallback: yaml[:enabled]),
        provider: (ENV["ANCHOR_AI_PROVIDER"].presence || yaml[:provider]).to_s,
        default_model: (ENV["ANCHOR_AI_DEFAULT_MODEL"].presence || yaml[:default_model]).to_s,
        escalation_model: (ENV["ANCHOR_AI_ESCALATION_MODEL"].presence || yaml[:escalation_model]).to_s,
        validation_retry_model: (ENV["ANCHOR_AI_VALIDATION_RETRY_MODEL"].presence || yaml[:validation_retry_model]).to_s,
        escalation_enabled: cast_bool(ENV["ANCHOR_AI_ESCALATION_ENABLED"], fallback: yaml[:escalation_enabled]),
        timeout_seconds: Integer(ENV["ANCHOR_AI_TIMEOUT_SECONDS"].presence || yaml[:timeout_seconds] || 30),
        api_base_url: ENV["ANCHOR_AI_API_BASE_URL"].presence || yaml[:api_base_url],
        api_key: ENV["ANCHOR_AI_API_KEY"].presence
      )
    end

    def self.cast_bool(env_value, fallback:)
      return fallback if env_value.nil?

      ActiveRecord::Type::Boolean.new.cast(env_value)
    end

    def initialize(
      enabled:,
      provider:,
      default_model:,
      timeout_seconds:,
      api_base_url:,
      api_key:,
      escalation_model: "",
      validation_retry_model: "",
      escalation_enabled: false
    )
      @enabled = enabled
      @provider = provider
      @default_model = default_model
      @escalation_model = escalation_model
      @validation_retry_model = validation_retry_model
      @escalation_enabled = escalation_enabled
      @timeout_seconds = timeout_seconds
      @api_base_url = api_base_url
      @api_key = api_key
    end

    def enabled?
      @enabled
    end

    def escalation_enabled?
      @escalation_enabled
    end

    def stub?
      provider.casecmp("stub").zero?
    end
    alias stub_provider? stub?
  end
end
