# frozen_string_literal: true

class CurrentProfileRebuilderJob < ApplicationJob
  queue_as :default

  def perform(child_profile_id, trigger_source_type: nil, trigger_source_id: nil, run_inline: false)
    child_profile = ChildProfile.find(child_profile_id)
    payload = CurrentProfileBuilder.new(child_profile).call

    current_profile = child_profile.current_profile || child_profile.build_current_profile
    current_profile.summary = payload[:summary]
    current_profile.narrative = payload[:narrative]
    current_profile.generated_at = Time.current
    current_profile.profile_version = next_profile_version(current_profile)
    current_profile.save!

    enqueue_next_job(
      ProfileSnapshotBuilderJob,
      current_profile.id,
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

  def next_profile_version(current_profile)
    return 1 if current_profile.new_record?

    current_profile.profile_version.to_i + 1
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
