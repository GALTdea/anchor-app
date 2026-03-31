# frozen_string_literal: true

# == Schema Information
#
# Table name: assessment_templates
# Database name: primary
#
#  id               :bigint           not null, primary key
#  category         :string
#  respondent_types :jsonb            not null
#  schema           :jsonb            not null
#  slug             :string           not null
#  status           :integer          default("draft"), not null
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_assessment_templates_on_slug  (slug) UNIQUE
#
class AssessmentTemplate < ApplicationRecord
  include AssessmentRespondentKinds

  enum :status, { draft: 0, published: 1, archived: 2 }, default: :draft

  validates :title, :slug, presence: true
  validates :slug, uniqueness: true
  validate :published_templates_have_valid_respondent_types, if: :published?
  validate :published_templates_have_questions_schema, if: :published?

  scope :published, -> { where(status: :published) }

  def question_ids
    Array(schema&.dig("questions")).filter_map { |q| q["id"].presence }.map(&:to_s)
  end

  private

  def published_templates_have_valid_respondent_types
    types = respondent_types
    unless types.is_a?(Array) && types.present?
      errors.add(:respondent_types, "must be a non-empty array for published templates")
      return
    end

    invalid = types.reject { |k| CANONICAL.include?(k.to_s) }
    return if invalid.empty?

    errors.add(:respondent_types, "contains invalid values: #{invalid.join(', ')}")
  end

  def published_templates_have_questions_schema
    questions = schema&.dig("questions")
    return if questions.is_a?(Array) && questions.present?

    errors.add(:schema, "must include a non-empty questions array for published templates")
  end
end
