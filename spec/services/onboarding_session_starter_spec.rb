# frozen_string_literal: true

require "rails_helper"

RSpec.describe OnboardingSessionStarter do
  describe "#call" do
    it "prefers the child-onboarding template over other published templates" do
      create(
        :assessment_template,
        title: "Care intake",
        template_key: "care-intake",
        category: "intake"
      )
      onboarding_template = create(
        :assessment_template,
        title: "Child onboarding",
        template_key: "child-onboarding",
        category: "onboarding"
      )

      onboarding_session = described_class.new(browser_session_id: nil).call

      expect(onboarding_session.assessment_template).to eq(onboarding_template)
    end

    it "abandons an old resumable session that points at a non-onboarding template" do
      wrong_template = create(
        :assessment_template,
        title: "Care intake",
        template_key: "care-intake",
        category: "intake"
      )
      onboarding_template = create(
        :assessment_template,
        title: "Child onboarding",
        template_key: "child-onboarding",
        category: "onboarding"
      )
      stale_session = create(:onboarding_session, assessment_template: wrong_template, status: :active)

      onboarding_session = described_class.new(browser_session_id: stale_session.id).call

      expect(onboarding_session.assessment_template).to eq(onboarding_template)
      expect(onboarding_session).not_to eq(stale_session)
      expect(stale_session.reload).to be_abandoned
    end
  end
end
