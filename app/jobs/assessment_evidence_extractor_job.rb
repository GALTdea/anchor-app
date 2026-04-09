# frozen_string_literal: true

class AssessmentEvidenceExtractorJob < ApplicationJob
  queue_as :default

  def perform(assessment_response_id, run_inline: false)
    assessment_response = AssessmentResponse.find(assessment_response_id)
    return unless assessment_response.submitted?

    assessment_response.update!(
      processing_status: "processing",
      last_processing_error: nil
    )

    AssessmentEvidenceExtractor.new(assessment_response).call

    enqueue_next_job(
      CurrentProfileRebuilderJob,
      assessment_response.assessment.child_profile_id,
      trigger_source_type: assessment_response.class.name,
      trigger_source_id: assessment_response.id,
      run_inline: run_inline
    )
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => error
    update_failure_state(assessment_response_id, error)
    raise
  end

  private

  def enqueue_next_job(job_class, *args, run_inline:, **kwargs)
    if run_inline
      job_class.perform_now(*args, **kwargs, run_inline: true)
    else
      job_class.perform_later(*args, **kwargs)
    end
  end

  def update_failure_state(assessment_response_id, error)
    assessment_response = AssessmentResponse.find_by(id: assessment_response_id)
    return if assessment_response.blank?

    assessment_response.update(
      processing_status: "failed",
      last_processing_error: error.message
    )
  end
end
