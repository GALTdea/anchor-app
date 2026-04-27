# frozen_string_literal: true

class AnalysisRunJob < ApplicationJob
  queue_as :default

  # `run_inline` is accepted for a consistent call shape with other second-brain jobs.
  def perform(child_profile_id, profile_snapshot_id:, trigger_source_type: nil, trigger_source_id: nil, run_inline: false) # rubocop:disable Lint/UnusedMethodArgument
    child_profile = ChildProfile.find(child_profile_id)
    snapshot = child_profile.profile_snapshots.find_by(id: profile_snapshot_id)
    return if snapshot.blank?
    return if child_profile.current_profile.blank?

    AnalysisRubric.published.find_each do |rubric|
      Analysis::RunCreator.new(
        child_profile:,
        analysis_rubric: rubric,
        profile_snapshot: snapshot
      ).call
    end
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => e
    update_failure_state(trigger_source_type, trigger_source_id, e)
    raise
  end

  private

  def update_failure_state(trigger_source_type, trigger_source_id, error)
    return unless trigger_source_type == "AssessmentResponse" && trigger_source_id.present?

    assessment_response = AssessmentResponse.find_by(id: trigger_source_id)
    return if assessment_response.blank?

    assessment_response.update(
      processing_status: "failed",
      last_processing_error: error.message
    )
  end
end
