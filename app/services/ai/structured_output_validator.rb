# frozen_string_literal: true

require "json-schema"
require "set"

module Ai
  # Validates raw model output before persistence/display. Raises nothing; returns a {Result}.
  class StructuredOutputValidator
    PARENT_GUIDANCE_V1_SCHEMA = {
      "type" => "object",
      "required" => %w[synthesis_schema_version summary_plain finding_refs],
      "additionalProperties" => false,
      "properties" => {
        "synthesis_schema_version" => {
          "type" => "string",
          "enum" => [ "anchor_synthesis_v1" ]
        },
        "summary_plain" => { "type" => "string", "minLength" => 16, "maxLength" => 12_000 },
        "confidence_note" => { "type" => [ "string", "null" ] },
        "what_to_watch" => {
          "type" => "array",
          "maxItems" => 12,
          "items" => { "type" => "string", "minLength" => 2, "maxLength" => 1400 }
        },
        "finding_refs" => {
          "type" => "array",
          "items" => {
            "type" => "object",
            "additionalProperties" => false,
            "required" => [ "finding_key" ],
            "properties" => {
              "finding_key" => { "type" => "string", "minLength" => 2, "maxLength" => 500 },
              "summary_gist" => { "type" => [ "string", "null" ] }
            }
          }
        }
      }
    }.freeze

    SCHEMA_BY_PROMPT_VERSION = {
      "parent_guidance@v1" => PARENT_GUIDANCE_V1_SCHEMA
    }.freeze

    BANNED_PHRASE_CHECKS = [
      { pattern: /\bthe\s+ai\s+decided\b/i, label: "discouraged voice (AI authority)" },
      { pattern: /\bdiagnosis\b/i, label: '"diagnosis" framing' },
      { pattern: /\bdeficit\b/i, label: '"deficit" framing' },
      { pattern: /\bautism\s+score\b/i, label: '"autism score" framing' },
      { pattern: /\bseverity\s+score\b/i, label: '"severity score" framing' },
      { pattern: /\bclinically\s+indicates\b/i, label: '"clinically indicates" framing' }
    ].freeze

    Result = Struct.new(:success, :output, :errors, keyword_init: true)

    # @param prompt_version [String] e.g. "parent_guidance@v1"
    # @param raw_text [String] model output (prefer single JSON object; markdown fences tolerated)
    # @param structured_analysis_payload [Hash, nil] same structure as PromptRenderer emits; used for finding_key grounding
    def initialize(prompt_version:, raw_text:, structured_analysis_payload: nil)
      @prompt_version = prompt_version.to_s
      @raw_text = raw_text
      @structured_analysis_payload = structured_analysis_payload
    end

    # @return [Result]
    def call
      schema = SCHEMA_BY_PROMPT_VERSION[@prompt_version]
      return invalid([ "unsupported prompt_version for synthesis validation: #{@prompt_version.inspect}" ]) unless schema

      parsed = parse_json(@raw_text)
      return invalid([ "could not parse model output as JSON" ]) unless parsed.is_a?(Hash)

      errs = validation_errors(parsed, schema)
      errs.concat(ground_finding_refs(parsed))
      errs.concat(unsafe_language_errors(parsed))

      errs.empty? ? valid(parsed) : invalid(errs)
    end

    private

    def valid(output)
      Result.new(success: true, output: deep_stringify_keys(output), errors: [])
    end

    def invalid(errors)
      Result.new(success: false, output: nil, errors: errors)
    end

    def parse_json(raw)
      text = raw.to_s.strip
      text = text.sub(/\A```(?:json)?\s*\n/i, "").sub(/\n```\s*\z/i, "").strip
      hash = JSON.parse(text)
      hash.is_a?(Hash) ? hash.deep_stringify_keys : nil
    rescue JSON::ParserError
      nil
    end

    def validation_errors(data, schema)
      JSON::Validator.fully_validate(schema, data)
    end

    def ground_finding_refs(parsed)
      return [] if @structured_analysis_payload.blank?

      refs = Array(parsed["finding_refs"])
      allowed = allowed_finding_keys
      errs = []

      if allowed.empty?
        return [ "finding_refs must be empty when deterministic findings are empty" ] if refs.any?

        return []
      end

      refs.each do |ref|
        next unless ref.is_a?(Hash)

        key = ref["finding_key"].to_s
        next if key.blank?

        errs << "finding_refs contains unknown finding_key #{key.inspect}" unless allowed.include?(key)
      end

      errs
    end

    def allowed_finding_keys
      @allowed_finding_keys ||= begin
        findings = @structured_analysis_payload.is_a?(Hash) ? @structured_analysis_payload["findings"] : nil
        Array(findings).filter_map { |row| row.is_a?(Hash) ? row["finding_key"].presence : nil }.map(&:to_s).to_set
      end
    end

    def unsafe_language_errors(parsed)
      blob = collect_string_values(parsed).join("\n")
      bad = []
      BANNED_PHRASE_CHECKS.each do |check|
        bad << "unsafe or off-brand phrasing: #{check[:label]}" if check[:pattern].match?(blob)
      end
      bad
    end

    def collect_string_values(obj)
      case obj
      when String
        [ obj ]
      when Hash
        obj.flat_map { |_, v| collect_string_values(v) }
      when Array
        obj.flat_map { |v| collect_string_values(v) }
      else
        []
      end
    end

    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.to_h { |k, v| [ k.to_s, deep_stringify_keys(v) ] }
      when Array
        obj.map { |v| deep_stringify_keys(v) }
      else
        obj
      end
    end
  end
end
