# frozen_string_literal: true

require "digest"

module Ai
  # When the provider client is stubbed it does not emit anchor_synthesis_v1 JSON. Builds a deterministic
  # validator-safe body from the renderer payload so synthesis can be exercised offline.
  class SynthesisStubText
    def self.from_prompt_result(prompt_result)
      structured = prompt_result.structured_payload
      refs = refs_from(structured)
      digest = Digest::SHA256.hexdigest(JSON.dump(structured))[0, 16]

      body = {
        "synthesis_schema_version" => "anchor_synthesis_v1",
        "summary_plain" =>
          "Anchor synthesized this passage in deterministic stub mode (audit digest #{digest}). " \
          "It reflects the structured findings supplied by the deterministic engine—not new clinical conclusions.",
        "confidence_note" =>
          "Stub mode: treat confidence wording as illustrative until a live synthesis provider is configured.",
        "what_to_watch" => [
          "How the strengths and sensitivities mentioned in Anchor's findings appear day to day."
        ],
        "finding_refs" => refs
      }
      JSON.generate(body)
    end

    def self.refs_from(structured)
      findings = structured.is_a?(Hash) ? structured["findings"] : nil
      Array(findings).filter_map do |row|
        next unless row.is_a?(Hash)
        fk = row["finding_key"].presence
        next if fk.blank?

        { "finding_key" => fk.to_s }
      end
    end
    private_class_method :refs_from
  end
end
