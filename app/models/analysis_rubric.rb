# frozen_string_literal: true

# Anchor-owned rubric definition: versioned, deterministic scoring rules and metadata.
# == Schema Information
#
# Table name: analysis_rubrics
# Database name: primary
#
#  id           :bigint           not null, primary key
#  description  :text
#  name         :string           not null
#  published_at :datetime
#  rubric_key   :string           not null
#  schema       :jsonb            not null
#  status       :integer          default("draft"), not null
#  version      :integer          default(1), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_analysis_rubrics_on_rubric_key_and_version  (rubric_key,version) UNIQUE
#  index_analysis_rubrics_on_status                  (status)
#
class AnalysisRubric < ApplicationRecord
  IMMUTABLE_FIELDS = %w[name rubric_key version status description schema].freeze

  has_many :analysis_runs, dependent: :restrict_with_error

  enum :status, { draft: 0, published: 1, archived: 2 }, default: :draft

  validates :name, :rubric_key, :version, presence: true
  validates :rubric_key, uniqueness: { scope: :version }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validate :schema_must_be_a_hash
  validate :published_rubric_invariants, if: :published?
  validate :published_versions_are_immutable, on: :update

  scope :published, -> { where(status: :published) }

  private

  def schema_must_be_a_hash
    return if schema.is_a?(Hash)

    errors.add(:schema, "must be a hash")
  end

  def published_rubric_invariants
    if published_at.blank?
      errors.add(:published_at, "must be set when the rubric is published")
    end
  end

  def published_versions_are_immutable
    return unless immutable_version_record?

    changed_fields = IMMUTABLE_FIELDS.select { |field| will_save_change_to_attribute?(field) }
    return if changed_fields.empty?

    errors.add(:base, "published rubric versions are immutable; create a new version instead")
  end

  def immutable_version_record?
    persisted? && %w[published archived].include?(attribute_in_database("status"))
  end
end
