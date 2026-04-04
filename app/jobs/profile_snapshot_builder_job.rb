# frozen_string_literal: true

class ProfileSnapshotBuilderJob < ApplicationJob
  queue_as :default

  def perform(current_profile_id, trigger_source_type: nil, trigger_source_id: nil)
    current_profile = CurrentProfile.find(current_profile_id)
    child_profile = current_profile.child_profile

    latest_snapshot = child_profile.profile_snapshots.order(generated_at: :desc, id: :desc).first

    snapshot = latest_snapshot

    unless latest_snapshot.present? &&
           latest_snapshot.summary == current_profile.summary &&
           latest_snapshot.narrative == current_profile.narrative
      snapshot = child_profile.profile_snapshots.create!(
        summary: current_profile.summary,
        narrative: current_profile.narrative,
        generated_at: current_profile.generated_at,
        trigger_source_type: trigger_source_type,
        trigger_source_id: trigger_source_id
      )
    end

    return if snapshot.blank?

    RecommendationGeneratorJob.perform_later(
      child_profile.id,
      source_profile_snapshot_id: snapshot.id,
      trigger_source_type: trigger_source_type,
      trigger_source_id: trigger_source_id
    )
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => error
    update_failure_state(trigger_source_type, trigger_source_id, error)
    raise
  end

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
