# frozen_string_literal: true

# One deterministic finding from an analysis run (score, confidence, evidence refs).
# == Schema Information
#
# Table name: analysis_findings
# Database name: primary
#
#  id              :bigint           not null, primary key
#  confidence      :float
#  dimension_key   :string           not null
#  evidence_refs   :jsonb            not null
#  finding_key     :string           not null
#  label           :string
#  metadata        :jsonb            not null
#  score           :float
#  severity        :string
#  summary         :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  analysis_run_id :bigint           not null
#
# Indexes
#
#  index_analysis_findings_on_analysis_run_id                    (analysis_run_id)
#  index_analysis_findings_on_analysis_run_id_and_dimension_key  (analysis_run_id,dimension_key)
#  index_analysis_findings_on_analysis_run_id_and_finding_key    (analysis_run_id,finding_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (analysis_run_id => analysis_runs.id)
#
class AnalysisFinding < ApplicationRecord
  belongs_to :analysis_run

  validates :dimension_key, :finding_key, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
    allow_nil: true
  validate :evidence_refs_must_be_a_hash
  validate :metadata_must_be_a_hash

  private

  def evidence_refs_must_be_a_hash
    return if evidence_refs.is_a?(Hash)

    errors.add(:evidence_refs, "must be a hash")
  end

  def metadata_must_be_a_hash
    return if metadata.is_a?(Hash)

    errors.add(:metadata, "must be a hash")
  end
end
