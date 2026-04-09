# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding flow", type: :request do
  let!(:template) { create(:assessment_template, title: "Parent onboarding") }

  describe "GET /" do
    it "shows the child-first CTA on the landing page" do
      get root_path

      expect(response).to be_successful
      expect(response.body).to include("Start your child&#39;s profile")
    end
  end

  describe "POST /onboarding/session" do
    it "creates an onboarding session and redirects to child basics" do
      expect {
        post onboarding_session_path
      }.to change(OnboardingSession, :count).by(1)

      expect(response).to redirect_to(onboarding_child_path)
      follow_redirect!
      expect(response.body).to include("Tell us a little about your child.")
    end

    it "reuses the current browser session instead of creating another record" do
      post onboarding_session_path

      expect {
        post onboarding_session_path
      }.not_to change(OnboardingSession, :count)
    end
  end

  describe "PATCH /onboarding/child" do
    it "saves child basics and redirects to the onboarding assessment step" do
      post onboarding_session_path

      patch onboarding_child_path, params: {
        onboarding_session: {
          child_first_name: "Maya",
          child_last_name: "Rivera",
          child_date_of_birth: "2021-04-14"
        }
      }

      expect(response).to redirect_to(onboarding_assessment_path)
      follow_redirect!
      expect(response.body).to include("Answer a few questions to build a clearer picture.")
      expect(response.body).to include("Overall level of concern")
    end

    it "rejects access without an onboarding session in the browser" do
      expect {
        patch onboarding_child_path, params: {
          onboarding_session: {
            child_first_name: "Maya",
            child_date_of_birth: "2021-04-14"
          }
        }
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
