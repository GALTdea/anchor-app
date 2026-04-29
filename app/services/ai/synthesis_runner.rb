# frozen_string_literal: true

require "digest"

module Ai
  class SynthesisRunner
    DEFAULT_PURPOSE = PromptRenderer::DEFAULT_PURPOSE

    Result = Struct.new(:success, :skipped, :synthesis_run, :error_message, keyword_init: true)

    def initialize(
      analysis_run:,
      purpose: DEFAULT_PURPOSE,
      force: false,
      client: Ai::Client.new,
      configuration: Ai.configuration
    )
      @analysis_run_id = analysis_run.is_a?(AnalysisRun) ? analysis_run.id : analysis_run.to_i
      @purpose = purpose.to_s
      @force = force
      @client = client
      @configuration = configuration
    end

    # @return [Result]
    def call
      run = AnalysisRun.includes(:analysis_rubric, :analysis_findings, :child_profile).find(@analysis_run_id)
      unless run.completed?
        return Result.new(success: false, skipped: false, synthesis_run: nil,
                          error_message: "analysis run is not completed")
      end

      render = PromptRenderer.new(analysis_run: run, purpose: @purpose).call

      if !@force && duplicate_completed?(run.id, render.purpose, render.prompt_version)
        winner = AiSynthesisRun.where(
          analysis_run_id: run.id,
          purpose: render.purpose,
          prompt_version: render.prompt_version,
          status: :completed
        ).order(id: :desc).first
        return Result.new(success: true, skipped: true, synthesis_run: winner, error_message: nil)
      end

      initial_route = ModelRouter.new(
        configuration: @configuration,
        structured_payload: render.structured_payload,
        validation_retry: false
      ).call

      first_attempt = complete_and_validate(render, initial_route.model)
      if first_attempt[:provider_error]
        return persist_provider_failure(run, render, first_attempt[:provider_error], initial_route)
      end

      if first_attempt[:validation].success
        return persist_success(run, render, first_attempt, initial_route)
      end

      retry_route = ModelRouter.new(
        configuration: @configuration,
        structured_payload: render.structured_payload,
        validation_retry: true,
        prior_attempt_model: first_attempt[:completion][:model].to_s
      ).call

      if retry_route.tier == "validation_retry"
        persist_validation_failure(run, render, first_attempt, initial_route)

        second_attempt = complete_and_validate(render, retry_route.model)
        if second_attempt[:provider_error]
          return persist_provider_failure(run, render, second_attempt[:provider_error], retry_route)
        end

        if second_attempt[:validation].success
          persist_success(run, render, second_attempt, retry_route)
        else
          persist_validation_failure(run, render, second_attempt, retry_route)
        end
      else
        persist_validation_failure(run, render, first_attempt, initial_route)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, skipped: false, synthesis_run: e.record, error_message: e.message)
    rescue StandardError => e
      Result.new(success: false, skipped: false, synthesis_run: nil, error_message: e.message)
    end

    private

    def complete_and_validate(render, model)
      completion = @client.complete(prompt: render.prompt, model: model)
      raw_text = @configuration.stub? ? SynthesisStubText.from_prompt_result(render) : completion.fetch(:text)
      validation = StructuredOutputValidator.new(
        prompt_version: render.prompt_version,
        raw_text: raw_text,
        structured_analysis_payload: render.structured_payload
      ).call
      { completion: completion, raw_text: raw_text, validation: validation, provider_error: nil }
    rescue Ai::ProviderError => e
      { completion: nil, raw_text: nil, validation: nil, provider_error: e }
    end

    def persist_success(run, render, attempt, routing)
      completion = attempt[:completion]
      raw_text = attempt[:raw_text]
      validation = attempt[:validation]
      request = request_payload(render, routing)
      response = response_payload(completion, raw_text, validation)

      base_attrs = synthesis_base_attrs(run, render, request, response, completion)
      synthesis = AiSynthesisRun.create!(base_attrs.merge(
        status: :completed,
        completed_at: Time.current,
        output: validation.output,
        error_message: nil
      ))
      Result.new(success: true, skipped: false, synthesis_run: synthesis, error_message: nil)
    end

    def persist_validation_failure(run, render, attempt, routing)
      completion = attempt[:completion]
      raw_text = attempt[:raw_text]
      validation = attempt[:validation]
      request = request_payload(render, routing)
      response = response_payload(completion, raw_text, validation)

      base_attrs = synthesis_base_attrs(run, render, request, response, completion)
      synthesis = AiSynthesisRun.new(base_attrs.merge(
        status: :failed,
        completed_at: Time.current,
        error_message: validation.errors.first(120).join(" | ").truncate(10_000),
        output: {}
      ))
      synthesis.save!(validate: false)
      Result.new(success: false, skipped: false, synthesis_run: synthesis, error_message: synthesis.error_message)
    end

    def synthesis_base_attrs(run, render, request, response, completion)
      {
        analysis_run: run,
        purpose: render.purpose,
        prompt_version: render.prompt_version,
        request_payload: request,
        response_payload: response,
        started_at: Time.current,
        provider: completion[:provider].to_s,
        model: completion[:model].to_s
      }
    end

    def persist_provider_failure(run, render, error, routing)
      upstream = (error.metadata || {}).deep_stringify_keys
      request = request_payload(render, routing)
      response = {
        "upstream" => upstream,
        "raw_model_text_truncated" => "",
        "validation_errors" => []
      }
      base_attrs = {
        analysis_run: run,
        purpose: render.purpose,
        prompt_version: render.prompt_version,
        request_payload: request,
        response_payload: response,
        started_at: Time.current,
        completed_at: Time.current,
        provider: upstream["provider"].presence || @configuration.provider.to_s,
        model: upstream["model"].presence || routing.model.to_s
      }
      synthesis = AiSynthesisRun.new(base_attrs.merge(
        status: :failed,
        error_message: error.message.to_s.truncate(10_000),
        output: {}
      ))
      synthesis.save!(validate: false)
      Result.new(success: false, skipped: false, synthesis_run: synthesis, error_message: synthesis.error_message)
    end

    def duplicate_completed?(analysis_run_id, purpose, prompt_version)
      AiSynthesisRun.exists?(
        analysis_run_id:,
        purpose:,
        prompt_version:,
        status: AiSynthesisRun.statuses[:completed]
      )
    end

    def request_payload(render, routing)
      {
        "purpose" => render.purpose,
        "prompt_version" => render.prompt_version,
        "structured_payload" => render.structured_payload,
        "prompt_sha256" => Digest::SHA256.hexdigest(render.prompt),
        "prompt_bytesize" => render.prompt.bytesize,
        "model_routing" => {
          "tier" => routing.tier,
          "routing_reason" => routing.routing_reason,
          "requested_model" => routing.model,
          "signals" => routing.signals.deep_stringify_keys
        }
      }
    end

    def response_payload(completion, raw_text, validation)
      {
        "upstream" => (completion[:response_payload] || {}),
        "raw_model_text_truncated" => raw_text.to_s.byteslice(0, 65_534),
        "validation_errors" => validation.success ? [] : validation.errors.first(160)
      }.deep_stringify_keys
    end
  end
end
