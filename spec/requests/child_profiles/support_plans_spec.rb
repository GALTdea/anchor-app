require 'rails_helper'

RSpec.describe "Child profile support plans", type: :request do
  let(:user) { create(:user) }
  let(:space) { create(:space) }
  let(:role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }

  before do
    sign_in user
    create(:user_role, user: user, space: space, role: role)
  end

  describe "GET /spaces/:space_id/child_profiles/:child_profile_id/support_plan" do
    it "renders the support plan for an authorized user" do
      child_profile = create(:child_profile, space: space, first_name: "Maya", last_name: "Rivera")
      create(:current_profile, child_profile: child_profile, summary: {
        "dimensions" => {
          "strengths.interests" => dimension_details("Dinosaurs"),
          "communication.expressive" => dimension_details("Uses short phrases"),
          "regulation.recovery" => dimension_details("Needs quiet recovery")
        }
      })

      get space_child_profile_support_plan_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).to include("Maya&#39;s Support Plan")
      expect(response.body).to include("A practical playbook for preparing, supporting, and adjusting")
      expect(response.body).to include("Overview")
      expect(response.body).to include("Support Plan")
      expect(response.body).to include(space_child_profile_path(space, child_profile))
      expect(response.body).to include(space_child_profile_support_plan_path(space, child_profile))
      expect(response.body).to include("When Things Get Hard")
      expect(response.body).to include("What to Plan Around")
      expect(response.body).to include("Best Support Style")
      expect(response.body).to include("Focus Right Now")
      expect(response.body).to include("What We're Still Learning")
      expect(response.body).to include("Dinosaurs")
      expect(response.body).to include("Recovery after big feelings")
      expect(response.body).to include("Make uncertain moments more predictable")
      expect(response.body).to include("What helps Maya recover?")
      expect(response.body).not_to include("Profile Calibration Looks Current")
    end

    it "renders fallback guidance before a current profile exists" do
      child_profile = create(:child_profile, space: space, first_name: "Noah", last_name: "Lee")

      get space_child_profile_support_plan_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).to include("Noah&#39;s Support Plan")
      expect(response.body).to include("What may make things harder")
      expect(response.body).to include("Transitions between activities")
      expect(response.body).to include("Lead with warmth and curiosity")
      expect(response.body).to include("Make uncertain moments more predictable")
      expect(response.body).to include("What helps Noah recover?")
    end

    it "denies access without a role in the space" do
      child_profile = create(:child_profile, space: space)
      unauthorized_user = create(:user)
      sign_in unauthorized_user

      expect {
        get space_child_profile_support_plan_url(space, child_profile)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "does not show a child profile through the wrong space" do
      child_profile = create(:child_profile, space: space)
      other_space = create(:space)
      create(:user_role, user: user, space: other_space, role: role)

      get space_child_profile_support_plan_url(other_space, child_profile)

      expect(response).to have_http_status(:not_found)
    end
  end

  def dimension_details(value)
    {
      "latest_value" => value,
      "confidence" => 0.8,
      "respondent_kind" => "parent_proxy",
      "recorded_at" => Time.current.iso8601,
      "evidence_count" => 1
    }
  end
end
