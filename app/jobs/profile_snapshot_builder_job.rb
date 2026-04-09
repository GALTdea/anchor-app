# frozen_string_literal: true

class ProfileSnapshotBuilderJob < ApplicationJob
  queue_as :default

  def perform(current_profile_id, trigger_source_type: nil, trigger_source_id: nil, run_inline: false)
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

    enqueue_next_job(
      RecommendationGeneratorJob,
      child_profile.id,
      source_profile_snapshot_id: snapshot.id,
      trigger_source_type: trigger_source_type,
      trigger_source_id: trigger_source_id,
      run_inline: run_inline
    )
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => error
    update_failure_state(trigger_source_type, trigger_source_id, error)
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
