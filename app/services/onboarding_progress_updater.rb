# frozen_string_literal: true

class OnboardingProgressUpdater
  def initialize(onboarding_session:, attributes:)
    @onboarding_session = onboarding_session
    @attributes = attributes
  end

  def call
    onboarding_session.assign_attributes(attributes)
    onboarding_session.save(context: :child_basics)
  end

  private

  attr_reader :onboarding_session, :attributes
end
