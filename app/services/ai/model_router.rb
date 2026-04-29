# frozen_string_literal: true

module Ai
  # Picks a model tier from compact packet metadata only. Does not query extra DB rows or expand payloads.
  class ModelRouter
    Result = Struct.new(:model, :tier, :routing_reason, :signals, keyword_init: true)

    LOW_CONF_FINDING_THRESHOLD = 0.4
    LOW_AVG_CONF_THRESHOLD = 0.55
    DEEP_SUMMARY_BYTES = 2500
    MANY_SUMMARIES = 8
    MANY_FINDINGS = 10

    def initialize(configuration:, structured_payload:, validation_retry: false, prior_attempt_model: nil)
      @configuration = configuration
      @structured_payload = structured_payload.deep_stringify_keys
      @validation_retry = validation_retry
      @prior_attempt_model = prior_attempt_model&.to_s
    end

    # @return [Result]
    def call
      return validation_retry_branch if @validation_retry

      initial_branch
    end

    private

    def validation_retry_branch
      unless @configuration.escalation_enabled?
        return routine_result("validation_retry_skipped_escalation_disabled")
      end

      retry_model = @configuration.validation_retry_model.presence ||
                    @configuration.escalation_model.presence
      if retry_model.blank?
        return routine_result("validation_retry_skipped_no_escalation_model")
      end

      if @prior_attempt_model.present? && @prior_attempt_model == retry_model
        return Result.new(
          model: retry_model,
          tier: "no_retry",
          routing_reason: "validation_retry_skipped_same_as_first_model",
          signals: { "prior_model" => @prior_attempt_model }
        )
      end

      Result.new(
        model: retry_model,
        tier: "validation_retry",
        routing_reason: "validator_rejected_output_retry",
        signals: { "prior_model" => @prior_attempt_model }.compact
      )
    end

    def initial_branch
      unless @configuration.escalation_enabled?
        return routine_result("escalation_disabled")
      end

      meta = @structured_payload["packet_meta"] || {}
      triggers = escalation_triggers(meta)

      if triggers.empty? || @configuration.escalation_model.to_s.strip.empty?
        return routine_result(triggers.empty? ? "routine_packet" : "escalation_signals_present_but_no_escalation_model")
      end

      Result.new(
        model: @configuration.escalation_model,
        tier: "escalated",
        routing_reason: triggers.join("; "),
        signals: { "escalation_triggers" => triggers }
      )
    end

    def routine_result(reason)
      Result.new(
        model: @configuration.default_model,
        tier: "default",
        routing_reason: reason,
        signals: {}
      )
    end

    def escalation_triggers(meta)
      list = []
      list << "marked_complex" if truthy?(meta["marked_complex"])

      c_conflict = meta["conflict_signal_count"].to_i
      list << "conflict_signals" if c_conflict.positive?

      avg = meta["average_confidence"]
      if avg.is_a?(Numeric) && avg < LOW_AVG_CONF_THRESHOLD
        list << "low_average_confidence"
      end

      low_c = meta["low_confidence_finding_count"].to_i
      list << "multiple_low_confidence_findings" if low_c >= 2

      min_c = meta["min_confidence"]
      list << "very_low_confidence_finding" if min_c.is_a?(Numeric) && min_c < 0.35

      bytes = meta["summary_total_bytes"].to_i
      summaries = meta["nonblank_summary_count"].to_i
      list << "high_summary_volume" if bytes > DEEP_SUMMARY_BYTES || summaries > MANY_SUMMARIES

      list << "many_findings" if meta["finding_count"].to_i >= MANY_FINDINGS

      sev = meta["severity_counts"]
      if sev.is_a?(Hash)
        down = sev.transform_keys { |k| k.to_s.downcase }
        highs = (down["high"] || 0).to_i + (down["critical"] || 0).to_i
        list << "multiple_high_severity_findings" if highs >= 2
      end

      list.uniq
    end

    def truthy?(value)
      value == true || value.to_s == "true"
    end
  end
end
