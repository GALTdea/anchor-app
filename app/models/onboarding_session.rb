# frozen_string_literal: true

class OnboardingSession < ApplicationRecord
  belongs_to :assessment_template
  belongs_to :user, optional: true
  belongs_to :space, optional: true
  belongs_to :child_profile, optional: true
  belongs_to :assessment, optional: true
  belongs_to :assessment_response, optional: true

  attr_accessor :active_question_ids

  enum :status, { active: 0, completed: 1, abandoned: 2 }, default: :active

  before_validation :set_started_at, on: :create

  validates :assessment_template, presence: true
  validates :started_at, presence: true
  validates :child_first_name, :child_date_of_birth, presence: true, on: :child_basics
  validate :draft_answers_must_match_schema, on: :assessment

  def child_name
    [ child_first_name, child_last_name ].compact_blank.join(" ")
  end

  def respondent_kind
    draft_answers.fetch("respondent_kind", nil).presence || Array(assessment_template.respondent_types).first.to_s
  end

  def assessment_answers
    draft_answers.fetch("answers", {}).stringify_keys
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  def draft_answers_must_match_schema
    validator = AssessmentAnswerValidator.new(
      schema: assessment_template.schema,
      answers: assessment_answers,
      active_question_ids: active_question_ids
    )
    return if validator.valid?

    validator.error_messages.each { |message| errors.add(:draft_answers, message) }
  end
end
