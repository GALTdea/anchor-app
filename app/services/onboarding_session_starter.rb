# frozen_string_literal: true

class OnboardingSessionStarter
  class TemplateNotConfiguredError < StandardError; end

  ONBOARDING_TEMPLATE_KEY = "child-onboarding".freeze

  def initialize(browser_session_id:)
    @browser_session_id = browser_session_id
  end

  def call
    resumable_session || OnboardingSession.create!(assessment_template: onboarding_template)
  end

  private

  attr_reader :browser_session_id

  def resumable_session
    return if browser_session_id.blank?

    onboarding_session = OnboardingSession.active.find_by(id: browser_session_id)
    return if onboarding_session.blank?
    return onboarding_session if onboarding_template_match?(onboarding_session.assessment_template)

    onboarding_session.update!(status: :abandoned)
    nil
  end

  def onboarding_template
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

  def onboarding_template_match?(assessment_template)
    assessment_template.present? &&
      (configured_onboarding_template_match?(assessment_template) ||
      assessment_template.template_key == ONBOARDING_TEMPLATE_KEY || assessment_template.category == "onboarding")
  end

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
