# frozen_string_literal: true

class OnboardingSessionPolicy < ApplicationPolicy
  Context = Data.define(:onboarding_session, :browser_session_id)

  def new?
    true
  end

  def create?
    true
  end

  def show?
    session_owned?
  end

  def update?
    session_owned?
  end

  private

  def session_owned?
    onboarding_session = record.onboarding_session
    onboarding_session.present? && onboarding_session.id == record.browser_session_id
  end
end
