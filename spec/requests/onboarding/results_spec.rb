# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding results handoff", type: :request do
  let!(:template) do
    create(
      :assessment_template,
      title: "Parent onboarding",
      template_key: "child-onboarding",
      category: "onboarding"
    )
  end

  def finish_onboarding_signup!
    post onboarding_session_path
    patch onboarding_child_path, params: {
      onboarding_session: {
        child_first_name: "Maya",
        child_last_name: "Rivera",
        child_date_of_birth: "2021-04-14"
      }
    }
    patch onboarding_assessment_path, params: {
      submit_action: "continue",
      onboarding_assessment: {
        respondent_kind: "parent_proxy",
        answers: {
          concern_level: "3",
          notes: "Transitions are hardest after school."
        }
      }
    }
    post onboarding_account_path, params: {
      onboarding_account: {
        first_name: "Ariana",
        last_name: "Rivera",
        email: "ariana-onboarding-results@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
  end

  describe "GET /onboarding/results" do
    it "redirects to the durable child profile once onboarding is finalized" do
      finish_onboarding_signup!

      onboarding_session = OnboardingSession.last
      expect(response).to redirect_to(space_child_profile_path(onboarding_session.space, onboarding_session.child_profile))

      get onboarding_results_path
      expect(response).to redirect_to(space_child_profile_path(onboarding_session.space, onboarding_session.child_profile))
    end

    it "returns not found when the signed-in user has no onboarding browser session" do
      sign_in create(:user)

      get onboarding_results_path

      expect(response).to have_http_status(:not_found)
    end
  end
end
