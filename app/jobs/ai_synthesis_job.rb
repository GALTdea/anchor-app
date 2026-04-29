# frozen_string_literal: true

class AiSynthesisJob < ApplicationJob
  queue_as :default

  def perform(analysis_run_id, purpose: Ai::PromptRenderer::DEFAULT_PURPOSE, force: false)
    Ai::SynthesisRunner.new(analysis_run: analysis_run_id, purpose:, force:).call
  end
end
