# frozen_string_literal: true

class AssessmentEvidenceExtractorJob < ApplicationJob
  queue_as :default

  def perform(assessment_response_id)
    assessment_response = AssessmentResponse.find(assessment_response_id)
    return unless assessment_response.submitted?

    assessment_response.update!(
      processing_status: "processing",
      last_processing_error: nil
    )

    AssessmentEvidenceExtractor.new(assessment_response).call

    assessment_response.update!(
      processing_status: "completed",
      last_processed_at: Time.current,
      last_processing_error: nil
    )
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => error
    update_failure_state(assessment_response_id, error)
    raise
  end

  private

  def update_failure_state(assessment_response_id, error)
    assessment_response = AssessmentResponse.find_by(id: assessment_response_id)
    return if assessment_response.blank?

    assessment_response.update(
      processing_status: "failed",
      last_processing_error: error.message
    )
  end
end
