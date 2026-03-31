# frozen_string_literal: true

# == Schema Information
#
# Table name: assessment_responses
# Database name: primary
#
#  id              :bigint           not null, primary key
#  answers         :jsonb            not null
#  respondent_kind :string           not null
#  submitted_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  actor_id        :integer          not null
#  assessment_id   :bigint           not null
#
# Indexes
#
#  index_assessment_responses_on_assessment_id  (assessment_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (assessment_id => assessments.id)
#
class AssessmentResponse < ApplicationRecord
  include AssessmentRespondentKinds

  belongs_to :assessment
  belongs_to :actor, class_name: "User"

  attr_accessor :submitting

  validate :respondent_kind_must_be_canonical
  validate :respondent_kind_allowed_by_template
  validate :answers_must_match_schema_when_submitting, if: :submitting

  def draft?
    submitted_at.nil?
  end

  def submitted?
    submitted_at.present?
  end

  private

  def respondent_kind_must_be_canonical
    return if respondent_kind.blank?

    return if CANONICAL.include?(respondent_kind.to_s)

    errors.add(:respondent_kind, "is not a valid respondent type")
  end

  def respondent_kind_allowed_by_template
    template = assessment&.assessment_template
    return if template.blank? || respondent_kind.blank?

    allowed = Array(template.respondent_types).map(&:to_s)
    return if allowed.include?(respondent_kind.to_s)

    errors.add(:respondent_kind, "is not allowed for this template")
  end

  def answers_must_match_schema_when_submitting
    validator = AssessmentAnswerValidator.new(
      schema: assessment.assessment_template.schema,
      answers: answers
    )
    return if validator.valid?

    validator.error_messages.each { |msg| errors.add(:answers, msg) }
  end
end
