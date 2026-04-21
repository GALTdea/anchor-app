# frozen_string_literal: true

class OnboardingProgressUpdater
  def initialize(onboarding_session:, child_attributes: nil, assessment_attributes: nil, validation_context: nil)
    @onboarding_session = onboarding_session
    @child_attributes = child_attributes
    @assessment_attributes = assessment_attributes
    @validation_context = validation_context
  end

  def call
    onboarding_session.assign_attributes(child_attributes) if child_attributes.present?
    merge_assessment_attributes if assessment_attributes.present?

    if validation_context == :assessment
      runner = AssessmentRunner.new(
        template: onboarding_session.assessment_template,
        answers: onboarding_session.assessment_answers
      )
      onboarding_session.active_question_ids = runner.active_question_ids
    end

    onboarding_session.save(context: validation_context)
  end

  private

  attr_reader :onboarding_session, :child_attributes, :assessment_attributes, :validation_context

  def merge_assessment_attributes
    existing = onboarding_session.draft_answers.deep_stringify_keys
    answers = existing.fetch("answers", {}).merge(normalized_answers)

    onboarding_session.draft_answers = existing.merge(
      "respondent_kind" => assessment_attributes[:respondent_kind].presence || onboarding_session.respondent_kind,
      "answers" => answers
    )
  end

  def normalized_answers
    assessment_attributes.fetch(:answers, {}).to_h.transform_keys(&:to_s)
  end
end
