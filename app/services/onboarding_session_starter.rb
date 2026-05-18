# frozen_string_literal: true

class OnboardingSessionStarter
  TemplateNotConfiguredError = OnboardingAssessmentTemplateResolver::TemplateNotConfiguredError

  def initialize(browser_session_id:)
    @browser_session_id = browser_session_id
    @template_resolver = OnboardingAssessmentTemplateResolver.new
  end

  def call
    resumable_session || OnboardingSession.create!(assessment_template: onboarding_template)
  end

  private

  attr_reader :browser_session_id, :template_resolver

  def resumable_session
    return if browser_session_id.blank?

    onboarding_session = OnboardingSession.active.find_by(id: browser_session_id)
    return if onboarding_session.blank?
    return onboarding_session if template_resolver.onboarding_template?(onboarding_session.assessment_template)

    onboarding_session.update!(status: :abandoned)
    nil
  end

  def onboarding_template
    template_resolver.call
  end
end
