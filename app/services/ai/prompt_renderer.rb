# frozen_string_literal: true

module Ai
  # Renders versioned LLM prompts from a completed deterministic {AnalysisRun} and its persisted
  # {AnalysisFinding} rows—never from ad-hoc DB reads of raw evidence.
  class PromptRenderer
    DEFAULT_PURPOSE = "parent_guidance_v1"

    PURPOSE_TO_TEMPLATE = {
      "parent_guidance_v1" => PromptTemplates::ParentGuidanceV1
    }.freeze

    Result = Struct.new(:prompt, :prompt_version, :structured_payload, :purpose, keyword_init: true)

    def initialize(analysis_run:, purpose: DEFAULT_PURPOSE)
      @analysis_run = load_run(analysis_run)
      @purpose = purpose.to_s
    end

    # @return [Result]
    def call
      raise ArgumentError, "analysis run must be completed" unless analysis_run.completed?

      template_mod = template_for(purpose)
      payload = structured_payload
      json = JSON.pretty_generate(payload)
      rendered = format(template_mod.template, structured_json: json)

      Result.new(
        prompt: rendered,
        prompt_version: template_mod::PROMPT_VERSION,
        structured_payload: payload,
        purpose: purpose
      )
    end

    private

    attr_reader :analysis_run, :purpose

    def load_run(run)
      return run if run.is_a?(AnalysisRun) && run.association(:analysis_findings).loaded? &&
        run.association(:analysis_rubric).loaded? && run.association(:child_profile).loaded?

      AnalysisRun.includes(:analysis_rubric, :analysis_findings, :child_profile).find(run.id)
    end

    def template_for(name)
      mod = PURPOSE_TO_TEMPLATE.fetch(name) do
        raise ArgumentError, "unknown prompt purpose: #{name.inspect}"
      end

      mod
    end

    # @return [Hash]
    def structured_payload
      run = analysis_run
      profile = run.child_profile
      findings = run.analysis_findings.order(:id).map { |row| serialize_finding(row) }

      {
        "payload_kind" => "anchor_analysis_run_v1",
        "analysis_run" => {
          "id" => run.id,
          "completed_at" => run.completed_at&.utc&.iso8601(6),
          "engine_version" => run.engine_version,
          "input_digest" => run.input_digest
        },
        "child_profile" => profile ? serialize_child_profile_stub(profile) : nil,
        "rubric" => {
          "id" => run.analysis_rubric.id,
          "rubric_key" => run.analysis_rubric.rubric_key,
          "version" => run.analysis_rubric.version,
          "name" => run.analysis_rubric.name
        },
        "findings" => findings,
        "packet_meta" => packet_meta_for(findings)
      }
    end

    def packet_meta_for(findings)
      rows = Array(findings)
      confidences = rows.filter_map { |f| f["confidence"] }
      avg = confidences.empty? ? nil : (confidences.sum.to_f / confidences.size).round(4)
      min_c = confidences.empty? ? nil : confidences.map(&:to_f).min
      low_thr = Ai::ModelRouter::LOW_CONF_FINDING_THRESHOLD
      low_conf_count = rows.count do |f|
        f["confidence"].is_a?(Numeric) && f["confidence"] < low_thr
      end

      severity_counts = rows.group_by { |f| f["severity"].to_s.presence || "unknown" }.transform_values(&:count)
      nonblank_summary_count = rows.count { |f| f["summary"].to_s.strip.present? }
      summary_total_bytes = rows.sum { |f| f["summary"].to_s.bytesize }
      conflict_signal_count = rows.sum { |f| conflict_signal_score(f) }
      marked_complex = rows.any? { |f| packet_flag_complex?(f) }

      {
        "finding_count" => rows.size,
        "average_confidence" => avg,
        "min_confidence" => min_c,
        "low_confidence_finding_count" => low_conf_count,
        "severity_counts" => severity_counts,
        "nonblank_summary_count" => nonblank_summary_count,
        "summary_total_bytes" => summary_total_bytes,
        "conflict_signal_count" => conflict_signal_count,
        "marked_complex" => marked_complex
      }
    end

    def packet_flag_complex?(finding)
      m = finding["metadata"]
      return false unless m.is_a?(Hash)

      ActiveModel::Type::Boolean.new.cast(m["anchor_routing_complex"]) ||
        ActiveModel::Type::Boolean.new.cast(m["complex_case"])
    end

    def conflict_signal_score(finding)
      score = 0
      m = finding["metadata"]
      if m.is_a?(Hash)
        score += 1 if truthy_conflict_meta?(m)
        score += 1 if deep_string_match?(m, /conflict|contradict/i)
      end
      score += 1 if finding["summary"].to_s.match?(/conflict|contradictory|inconsistent/i)
      score += 1 if finding["label"].to_s.match?(/conflict|contradict/i)
      ev = finding["evidence_refs"]
      score += 1 if ev.is_a?(Hash) && deep_string_match?(ev, /conflict|contradict/i)
      score
    end

    def truthy_conflict_meta?(h)
      keys = %w[conflict evidence_conflict conflicting_positions]
      keys.any? do |key|
        next false unless h.key?(key)

        ActiveModel::Type::Boolean.new.cast(h[key]) || (h[key].is_a?(Numeric) && !h[key].zero?)
      end
    end

    def deep_string_match?(obj, pattern)
      case obj
      when Hash
        obj.any? { |_, v| deep_string_match?(v, pattern) }
      when Array
        obj.any? { |v| deep_string_match?(v, pattern) }
      when String
        obj.match?(pattern)
      else
        false
      end
    end

    def serialize_child_profile_stub(profile)
      {
        "id" => profile.id,
        "first_name" => profile.first_name,
        "last_name_initial" => last_name_initial(profile.last_name)
      }
    end

    def last_name_initial(last_name)
      s = last_name.to_s.strip
      return nil if s.blank?

      "#{s.first.upcase}."
    end

    def serialize_finding(row)
      {
        "dimension_key" => row.dimension_key,
        "finding_key" => row.finding_key,
        "score" => row.score,
        "confidence" => row.confidence,
        "severity" => row.severity,
        "label" => row.label,
        "summary" => row.summary,
        "evidence_refs" => deep_stringify(row.evidence_refs),
        "metadata" => deep_stringify(row.metadata)
      }
    end

    def deep_stringify(value)
      case value
      when Hash then value.deep_stringify_keys
      when Array then value
      else
        value
      end
    end
  end
end
