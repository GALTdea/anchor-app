# frozen_string_literal: true

class OnboardingResultsPresenter
  def initialize(onboarding_session)
    @onboarding_session = onboarding_session
  end

  def child_profile
    onboarding_session.child_profile
  end

  def current_profile
    child_profile.current_profile || child_profile.build_current_profile(
      summary: {},
      generated_at: Time.current,
      profile_version: 1
    )
  end

  def recommendations
    child_profile.recommendations.active.order(generated_at: :desc, id: :desc)
  end

  def space
    onboarding_session.space
  end

  private

  attr_reader :onboarding_session
end
