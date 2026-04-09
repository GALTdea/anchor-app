# frozen_string_literal: true

require "rails_helper"

RSpec.describe OnboardingSessionPolicy, type: :policy do
  let(:onboarding_session) { create(:onboarding_session) }
  let(:context) { described_class::Context.new(onboarding_session, browser_session_id) }
  let(:policy) { described_class.new(nil, context) }

  describe "when the browser owns the onboarding session" do
    let(:browser_session_id) { onboarding_session.id }

    it "grants show?" do
      expect(policy.show?).to be true
    end

    it "grants update?" do
      expect(policy.update?).to be true
    end
  end

  describe "when the browser does not own the onboarding session" do
    let(:browser_session_id) { onboarding_session.id + 1 }

    it "denies show?" do
      expect(policy.show?).to be false
    end
  end

  describe "for starting a funnel" do
    let(:context) { described_class::Context.new(nil, nil) }

    it "allows create?" do
      expect(policy.create?).to be true
    end
  end
end
