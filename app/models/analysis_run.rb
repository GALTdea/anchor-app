# frozen_string_literal: true

# A single execution of a rubric against structured profile inputs.
# == Schema Information
#
# Table name: analysis_runs
# Database name: primary
#
#  id                  :bigint           not null, primary key
#  completed_at        :datetime
#  engine_version      :string
#  error_message       :text
#  input_digest        :string
#  started_at          :datetime
#  status              :integer          default("pending"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  analysis_rubric_id  :bigint           not null
#  child_profile_id    :bigint           not null
#  profile_snapshot_id :bigint
#
# Indexes
#
#  index_analysis_runs_idempotency_completed                       (child_profile_id,analysis_rubric_id,input_digest) UNIQUE WHERE ((status = 2) AND (input_digest IS NOT NULL))
#  index_analysis_runs_on_analysis_rubric_id                       (analysis_rubric_id)
#  index_analysis_runs_on_child_profile_id                         (child_profile_id)
#  index_analysis_runs_on_child_profile_id_and_analysis_rubric_id  (child_profile_id,analysis_rubric_id)
#  index_analysis_runs_on_child_profile_id_and_created_at          (child_profile_id,created_at)
#  index_analysis_runs_on_input_digest                             (input_digest)
#  index_analysis_runs_on_profile_snapshot_id                      (profile_snapshot_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_rubric_id => analysis_rubrics.id)
#  fk_rails_...  (child_profile_id => child_profiles.id)
#  fk_rails_...  (profile_snapshot_id => profile_snapshots.id)
#
class AnalysisRun < ApplicationRecord
  belongs_to :child_profile
  belongs_to :analysis_rubric
  belongs_to :profile_snapshot, optional: true

  has_many :analysis_findings, dependent: :destroy
  has_many :ai_synthesis_runs, dependent: :destroy

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

  validate :terminal_fields_for_completed
  validate :chronology

  private

  def terminal_fields_for_completed
    return unless completed?

    errors.add(:input_digest, "can't be blank") if input_digest.blank?
    errors.add(:engine_version, "can't be blank") if engine_version.blank?
    errors.add(:completed_at, "can't be blank") if completed_at.blank?
  end

  def chronology
    if started_at.present? && completed_at.present? && completed_at < started_at
      errors.add(:completed_at, "must be on or after started_at")
    end
  end
end
