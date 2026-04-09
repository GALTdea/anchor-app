# frozen_string_literal: true

class OnboardingSpaceNamer
  def initialize(onboarding_session)
    @onboarding_session = onboarding_session
  end

  def call
    first_name = onboarding_session.child_first_name.to_s.strip
    return "Family" if first_name.blank?

    "#{first_name}'s Family"
  end

  private

  attr_reader :onboarding_session
end
