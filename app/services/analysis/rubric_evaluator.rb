# frozen_string_literal: true

module Analysis
  # Deterministic: maps ProfileEvidence (via {InputBuilder} payload) to rubric domain findings.
  class RubricEvaluator
    def initialize(rubric:, input:)
      @rubric = rubric
      @input = input
    end

    def call
      return [] unless rubric.published?
      return [] if schema["domains"].blank?

      items = input["evidence"] || []
      Array(schema["domains"]).filter_map { |domain| build_finding(domain, items) }
    end

    private

    attr_reader :rubric, :input

    def schema
      raw = rubric.schema
      hash = raw.is_a?(Hash) ? raw : {}
      hash.stringify_keys
    end

    def build_finding(domain, evidence_items)
      domain = domain.to_h.stringify_keys
      domain_key = domain["key"]
      return nil if domain_key.blank?

      rows = Array(evidence_items).select { |e| match_domain?(domain, e) }
      return nil if rows.empty?

      weights = rows.map { |e| row_weight(e, domain) }
      raw_scores = rows.map { |e| row_score(e, domain) }
      sum_w = weights.sum
      mean_score = sum_w.positive? ? (raw_scores.zip(weights).sum { |s, w| s * w } / sum_w) : 0.0
      mean_score = mean_score.clamp(0.0, 1.0).round(4)

      confidence = finding_confidence(rows, domain).round(4)
      severity = severity_for(mean_score, confidence, domain)
      {
        "dimension_key" => domain_key,
        "finding_key" => "#{domain_key}.support_signal",
        "score" => mean_score,
        "confidence" => confidence,
        "severity" => severity,
        "label" => domain.dig("parent_labels", "anchor") || domain["title"] || humanize_key(domain_key),
        "summary" => build_summary(domain, rows, mean_score, confidence),
        "evidence_refs" => {
          "profile_evidence_ids" => rows.map { |e| e["id"] }.compact
        },
        "metadata" => {
          "rubric_id" => rubric.id,
          "rubric_key" => rubric.rubric_key,
          "rubric_version" => rubric.version,
          "schema_version" => schema["version"],
          "rubric_domain" => domain_key,
          "evidence_count" => rows.size
        }
      }
    end

    def match_domain?(domain, evidence_row)
      key = evidence_row["dimension_key"].to_s
      return false if key.blank?

      Array(domain["dimension_key_prefixes"]).any? { |p| match_prefix?(key, p.to_s) }
    end

    def match_prefix?(dimension_key, prefix)
      return true if prefix.blank?

      if prefix.end_with?(".")
        base = prefix.delete_suffix(".")
        dimension_key == base || dimension_key.start_with?("#{base}.")
      else
        dimension_key == prefix || dimension_key.start_with?("#{prefix}.")
      end
    end

    def row_score(row, domain)
      higher = domain.dig("scoring", "higher_is_more_support")
      value = row["value"]
      vtype = row["value_type"].to_s
      if vtype == "integer" || (vtype.empty? && value.to_s.match?(/\A-?\d+\z/))
        norm = concern_norm(value)
        if higher == false
          (1.0 - norm).round(4)
        else
          norm
        end
      else
        0.5
      end
    end

    def concern_norm(value)
      f = value.to_f
      f = 1.0 if f < 1.0
      f = 5.0 if f > 5.0
      (f - 1.0) / 4.0
    end

    def row_weight(row, domain)
      base = row["confidence"].to_f
      w = row.dig("metadata", "evidence_weight") || row.dig("metadata", :evidence_weight)
      w = w.to_f
      w = 0.5 if w <= 0.0
      (base * w).clamp(0.001, 1.0)
    end

    def finding_confidence(rows, domain)
      base = rows.sum { |e| e["confidence"].to_f } / rows.size
      min_rows = domain.dig("evidence_minimums", "min_rows")&.to_i
      min_rows = 1 if min_rows.to_i < 1
      penalty = rows.size < min_rows ? 0.85 : 1.0
      cap = domain.dig("confidence", "base_cap")
      cap = 0.9 if cap.nil?
      [ base * penalty, cap.to_f ].min
    end

    def severity_for(score, confidence, domain)
      low = domain.dig("confidence", "low_confidence_if_below")
      low = 0.35 if low.nil?
      return "low" if confidence < low

      s = case score
      when ...0.35 then "low"
      when ...0.65 then "medium"
      else "high"
      end
      s
    end

    def build_summary(domain, rows, mean_score, confidence)
      title = domain["title"] || humanize_key(domain["key"])
      n = rows.size
      band = if mean_score < 0.35
        "lower"
      elsif mean_score < 0.65
        "moderate"
      else
        "higher"
      end
      <<~TXT.squish
        Based on #{n} saved observation#{'s' if n != 1} in the #{title} area,
        Anchor sees a #{band} support signal. This is a working pattern from your answers, not a diagnosis
        (confidence: #{round_pct(confidence)}).
      TXT
    end

    def round_pct(x)
      (x * 100).round
    end

    def humanize_key(k)
      k.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
    end
  end
end
