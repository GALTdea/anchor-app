# frozen_string_literal: true

class OnboardingAssessmentTemplateResolver
  class TemplateNotConfiguredError < StandardError; end

  ONBOARDING_TEMPLATE_KEY = "child-onboarding".freeze

  def call
    configured_onboarding_template ||
      AssessmentTemplate.published
        .where(template_key: ONBOARDING_TEMPLATE_KEY)
        .order(version: :desc)
        .first ||
      AssessmentTemplate.published
        .where(category: "onboarding")
        .order(version: :desc, title: :asc)
        .first ||
      raise(TemplateNotConfiguredError, "Missing published child-onboarding assessment template")
  end

  def onboarding_template?(assessment_template)
    assessment_template.present? &&
      (configured_onboarding_template_match?(assessment_template) ||
        assessment_template.template_key == ONBOARDING_TEMPLATE_KEY ||
        assessment_template.category == "onboarding")
  end

  private

  def configured_onboarding_template
    template_id = AppSettings.onboarding_assessment_template_id.presence
    return if template_id.blank?

    AssessmentTemplate.published.find_by(id: template_id)
  end

  def configured_onboarding_template_match?(assessment_template)
    configured_template = configured_onboarding_template
    configured_template.present? && assessment_template.id == configured_template.id
  end
end
