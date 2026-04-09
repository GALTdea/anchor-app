# frozen_string_literal: true

class OnboardingSessionStarter
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

    OnboardingSession.active.find_by(id: browser_session_id)
  end

  def onboarding_template
    AssessmentTemplate.published.order(:title).first!
  end
end
