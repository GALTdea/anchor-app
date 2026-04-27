# frozen_string_literal: true

class RecommendationGeneratorJob < ApplicationJob
  queue_as :default

  def perform(child_profile_id, source_profile_snapshot_id:, trigger_source_type: nil, trigger_source_id: nil, run_inline: false)
    child_profile = ChildProfile.find(child_profile_id)
    current_profile = child_profile.current_profile
    source_profile_snapshot = child_profile.profile_snapshots.find(source_profile_snapshot_id)
    return if current_profile.blank?

    analysis_run = AnalysisRun
      .includes(:analysis_rubric, :analysis_findings)
      .find_by(
        child_profile_id: child_profile_id,
        profile_snapshot_id: source_profile_snapshot_id,
        status: :completed
      )

    recommendations = RecommendationBuilder.new(
      current_profile: current_profile,
      source_profile_snapshot: source_profile_snapshot,
      analysis_run: analysis_run
    ).call

    Recommendation.transaction do
      child_profile.recommendations.delete_all
      recommendations.each do |attributes|
        child_profile.recommendations.create!(attributes)
      end
    end

    mark_processing_complete(trigger_source_type, trigger_source_id)
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => error
    update_failure_state(trigger_source_type, trigger_source_id, error)
    raise
  end

  private

  def mark_processing_complete(trigger_source_type, trigger_source_id)
    return unless trigger_source_type == "AssessmentResponse" && trigger_source_id.present?

    assessment_response = AssessmentResponse.find_by(id: trigger_source_id)
    return if assessment_response.blank?

    assessment_response.update!(
      processing_status: "completed",
      last_processed_at: Time.current,
      last_processing_error: nil
    )
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
