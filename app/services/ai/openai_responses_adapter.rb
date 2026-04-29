# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Ai
  # Calls OpenAI POST /v1/responses with Net::HTTP. Parses assistant output_text into { text:, response_payload: }.
  class OpenaiResponsesAdapter
    DEFAULT_API_BASE = "https://api.openai.com/v1"

    HttpResult = Struct.new(:code, :body, :latency_ms, keyword_init: true)

    def initialize(configuration:, http_post: nil)
      @configuration = configuration
      @http_post = http_post || method(:perform_http_post)
    end

    # @return [Hash] keys :text, :provider, :model, :response_payload
    def complete(prompt:, model:)
      resolved_model = model.presence || @configuration.default_model
      if resolved_model.blank?
        raise ProviderError.new(
          "OpenAI request failed: model is blank",
          retryable: false,
          metadata: base_metadata(resolved_model).merge(
            "http_status" => nil,
            "error_class" => "Ai::OpenaiResponsesAdapter",
            "retry_classification" => "non_retryable"
          ).compact
        )
      end

      body = request_body(prompt, resolved_model)
      uri = responses_uri
      headers = {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@configuration.api_key}"
      }

      result = perform_with_transport_rescue(resolved_model) do
        @http_post.call(uri, headers, JSON.generate(body), @configuration.timeout_seconds)
      end
      handle_http_result(result, resolved_model)
    end

    private

    def perform_with_transport_rescue(resolved_model)
      yield
    rescue Timeout::Error, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
           Errno::ENETUNREACH, SocketError, OpenSSL::SSL::SSLError => e
      raise ProviderError.new(
        "OpenAI transport error: #{e.class}",
        retryable: true,
        metadata: base_metadata(resolved_model).merge(
          "http_status" => nil,
          "error_class" => e.class.name,
          "retry_classification" => "retryable"
        ).compact
      )
    end

    def responses_uri
      base = @configuration.api_base_url.presence || DEFAULT_API_BASE
      base = base.chomp("/")
      URI("#{base}/responses")
    end

    def request_body(prompt, model_name)
      {
        "model" => model_name,
        "input" => prompt,
        "text" => {
          "format" => {
            "type" => "json_object"
          }
        }
      }
    end

    def perform_http_post(uri, headers, json_body, timeout_seconds)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout_seconds
      http.read_timeout = timeout_seconds

      request = Net::HTTP::Post.new(uri.request_uri)
      headers.each { |k, v| request[k] = v }
      request.body = json_body

      response = http.request(request)
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      HttpResult.new(code: response.code.to_i, body: response.body.to_s, latency_ms: latency_ms)
    end

    def handle_http_result(result, resolved_model)
      code = result.code
      latency_ms = result.latency_ms

      if code == 408 || code == 429 || code >= 500
        raise provider_error(
          message_from_http(code, result.body),
          retryable: true,
          resolved_model:,
          http_status: code,
          body: result.body,
          latency_ms:
        )
      end

      if (400...500).cover?(code)
        raise provider_error(
          message_from_http(code, result.body),
          retryable: false,
          resolved_model:,
          http_status: code,
          body: result.body,
          latency_ms:
        )
      end

      unless (200...300).cover?(code)
        raise provider_error(
          "OpenAI returned HTTP #{code}",
          retryable: false,
          resolved_model:,
          http_status: code,
          body: result.body,
          latency_ms:
        )
      end

      parsed = parse_json_body(result.body)
      unless parsed.is_a?(Hash)
        raise provider_error(
          "OpenAI response was not a JSON object",
          retryable: false,
          resolved_model:,
          http_status: code,
          body: nil,
          latency_ms:
        )
      end

      text = extract_output_text(parsed)
      if text.to_s.strip.empty?
        raise provider_error(
          "OpenAI response contained no assistant text",
          retryable: false,
          resolved_model:,
          http_status: code,
          body: nil,
          latency_ms:,
          extra_meta: { "openai_response_id" => parsed["id"], "response_status" => parsed["status"] }
        )
      end

      {
        text: text.to_s,
        provider: "openai",
        model: parsed["model"].presence || resolved_model,
        response_payload: success_metadata(parsed, latency_ms)
      }
    end

    def parse_json_body(raw)
      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end

    def extract_output_text(parsed)
      parts = []
      Array(parsed["output"]).each do |item|
        next unless item.is_a?(Hash) && item["type"] == "message"

        Array(item["content"]).each do |segment|
          next unless segment.is_a?(Hash) && segment["type"] == "output_text"

          parts << segment["text"].to_s
        end
      end
      parts.join
    end

    def success_metadata(parsed, latency_ms)
      usage = parsed["usage"]
      usage = usage.deep_stringify_keys if usage.is_a?(Hash)

      {
        "provider" => "openai",
        "openai_response_id" => parsed["id"],
        "response_status" => parsed["status"],
        "model" => parsed["model"],
        "usage" => usage,
        "latency_ms" => latency_ms,
        "retry_classification" => "not_applicable"
      }.compact
    end

    def base_metadata(resolved_model)
      {
        "provider" => "openai",
        "model" => resolved_model
      }
    end

    def provider_error(message, retryable:, resolved_model:, http_status:, body:, latency_ms:, extra_meta: {})
      meta = base_metadata(resolved_model).merge(
        "http_status" => http_status,
        "latency_ms" => latency_ms,
        "error_class" => self.class.name,
        "retry_classification" => retryable ? "retryable" : "non_retryable"
      ).merge(stringify_keys(extra_meta))
      meta["openai_error_type"] = openai_error_type(body) if body.present?
      meta["openai_error_message_truncated"] = openai_error_message_truncated(body) if body.present?

      raise ProviderError.new(message, retryable:, metadata: meta.compact)
    end

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end

    def openai_error_type(body)
      parsed = JSON.parse(body)
      parsed.dig("error", "type") if parsed.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end

    def openai_error_message_truncated(body)
      parsed = JSON.parse(body)
      msg = parsed.dig("error", "message") if parsed.is_a?(Hash)
      msg.to_s.byteslice(0, 500)
    rescue JSON::ParserError
      body.to_s.byteslice(0, 500)
    end

    def message_from_http(code, body)
      detail = openai_error_message_truncated(body)
      base = "OpenAI request failed (HTTP #{code})"
      detail.present? ? "#{base}: #{detail}" : base
    end
  end
end
