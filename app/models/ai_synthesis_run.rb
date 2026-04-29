# frozen_string_literal: true

# Single attempt at AI-powered synthesis for a deterministic analysis run.
#
# Stores provider metadata, payloads, validated output shape, status, and error
# state for auditability. Does not substitute rubric reasoning.
#
# == Schema Information
#
# Table name: ai_synthesis_runs
# Database name: primary
#
#  id               :bigint           not null, primary key
#  completed_at     :datetime
#  error_message    :text
#  model            :string
#  output           :jsonb            not null
#  prompt_version   :string
#  provider         :string
#  purpose          :string           not null
#  request_payload  :jsonb            not null
#  response_payload :jsonb            not null
#  started_at       :datetime
#  status           :integer          default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  analysis_run_id  :bigint           not null
#
# Indexes
#
#  index_ai_synthesis_runs_analysis_purpose_prompt  (analysis_run_id,purpose,prompt_version)
#  index_ai_synthesis_runs_on_analysis_run_id       (analysis_run_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_run_id => analysis_runs.id)
#
class AiSynthesisRun < ApplicationRecord
  belongs_to :analysis_run

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

  validates :purpose, presence: true

  validate :terminal_fields_for_completed
  validate :terminal_fields_for_failed
  validate :chronology

  private

  def terminal_fields_for_completed
    return unless completed?

    errors.add(:provider, "can't be blank") if provider.blank?
    errors.add(:model, "can't be blank") if model.blank?
    errors.add(:prompt_version, "can't be blank") if prompt_version.blank?
    errors.add(:completed_at, "can't be blank") if completed_at.blank?
    errors.add(:output, "must be present") unless output.present?
  end

  def terminal_fields_for_failed
    return unless failed?

    errors.add(:error_message, "can't be blank") if error_message.blank?
  end

  def chronology
    return if started_at.blank? || completed_at.blank?
    return if completed_at >= started_at

    errors.add(:completed_at, "must be on or after started_at")
  end
end
