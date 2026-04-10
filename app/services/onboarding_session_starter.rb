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
      (assessment_template.template_key == ONBOARDING_TEMPLATE_KEY || assessment_template.category == "onboarding")
  end
end
