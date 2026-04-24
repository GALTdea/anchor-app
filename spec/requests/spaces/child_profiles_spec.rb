require 'rails_helper'

RSpec.describe "/spaces/:space_id/child_profiles", type: :request do
  let(:user) { create(:user) }
  let(:space) { create(:space) }
  let(:role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }

  before do
    sign_in user
    create(:user_role, user: user, space: space, role: role)
  end

  describe "GET /index" do
    it "renders a successful response" do
      create(:child_profile, space: space)
      get space_child_profiles_url(space)
      expect(response).to be_successful
    end

    it "shows only active child profiles" do
      active = create(:child_profile, space: space, status: :active)
      archived = create(:child_profile, space: space, status: :archived)
      get space_child_profiles_url(space)
      expect(response.body).to include(active.name)
      expect(response.body).not_to include(archived.name)
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      child_profile = create(:child_profile, space: space)
      get space_child_profile_url(space, child_profile)
      expect(response).to be_successful
    end

    it "renders the child profile as the profile results home" do
      child_profile = create(:child_profile, space: space, first_name: "Maya", last_name: "Rivera")
      create(:current_profile, child_profile: child_profile, narrative: "Maya has a profile narrative.", summary: {
        "dimensions" => {
          "strengths.interests" => {
            "latest_value" => "Dinosaurs",
            "confidence" => 0.8,
            "respondent_kind" => "parent_proxy",
            "recorded_at" => Time.current.iso8601
          },
          "communication.expressive" => {
            "latest_value" => "Uses short phrases",
            "confidence" => 0.8,
            "respondent_kind" => "parent_proxy",
            "recorded_at" => Time.current.iso8601,
            "evidence_count" => 1
          }
        }
      })
      snapshot = create(:profile_snapshot, child_profile: child_profile)
      create(
        :recommendation,
        child_profile: child_profile,
        source_profile_snapshot: snapshot,
        title: "Use visual supports",
        body: "Try one visual support during transitions.",
        rationale: { "display_value" => "Uses short phrases" }
      )
      template = create(:assessment_template, title: "Anchor Onboarding Profile")
      assessment = create(:assessment, child_profile: child_profile, assessment_template: template, status: :submitted)
      create(:assessment_response, assessment: assessment, submitted_at: Time.current, processing_status: "completed")

      get space_child_profile_url(space, child_profile)

      expect(response).to be_successful
      expect(response.body).to include("Maya Rivera Profile")
      expect(response.body).to include("Maya has a profile narrative.")
      expect(response.body).to include("This profile is a support guide")
      expect(response.body).to include("Strengths and motivators")
      expect(response.body).to include("Dinosaurs")
      expect(response.body).to include("Communication")
      expect(response.body).to include("Uses short phrases")
      expect(response.body).to include("Use visual supports")
      expect(response.body).to include("Anchor Onboarding Profile")
      expect(response.body).to include("View submitted answers")
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_space_child_profile_url(space)
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      child_profile = create(:child_profile, space: space)
      get edit_space_child_profile_url(space, child_profile)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          first_name: "Emma",
          last_name: "Watson",
          date_of_birth: 5.years.ago.to_date,
          notes: "Sample notes"
        }
      end

      it "creates a new ChildProfile" do
        expect {
          post space_child_profiles_url(space), params: { child_profile: valid_attributes }
        }.to change(ChildProfile, :count).by(1)
      end

      it "redirects to the created child_profile" do
        post space_child_profiles_url(space), params: { child_profile: valid_attributes }
        expect(response).to redirect_to(space_child_profile_url(space, ChildProfile.last))
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          first_name: "",
          last_name: "",
          date_of_birth: nil
        }
      end

      it "does not create a new ChildProfile" do
        expect {
          post space_child_profiles_url(space), params: { child_profile: invalid_attributes }
        }.not_to change(ChildProfile, :count)
      end

      it "renders the new template with unprocessable_content status" do
        post space_child_profiles_url(space), params: { child_profile: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    let(:child_profile) { create(:child_profile, space: space) }

    context "with valid parameters" do
      let(:new_attributes) do
        {
          first_name: "Updated",
          last_name: "Name",
          notes: "Updated notes"
        }
      end

      it "updates the child_profile" do
        patch space_child_profile_url(space, child_profile), params: { child_profile: new_attributes }
        child_profile.reload
        expect(child_profile.first_name).to eq("Updated")
        expect(child_profile.last_name).to eq("Name")
        expect(child_profile.notes).to eq("Updated notes")
      end

      it "redirects to the child_profile" do
        patch space_child_profile_url(space, child_profile), params: { child_profile: new_attributes }
        expect(response).to redirect_to(space_child_profile_url(space, child_profile))
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          first_name: "",
          last_name: ""
        }
      end

      it "renders the edit template with unprocessable_content status" do
        patch space_child_profile_url(space, child_profile), params: { child_profile: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    let!(:child_profile) { create(:child_profile, space: space) }

    it "archives the child_profile" do
      delete space_child_profile_url(space, child_profile)
      child_profile.reload
      expect(child_profile.status).to eq("archived")
    end

    it "redirects to the child_profiles list" do
      delete space_child_profile_url(space, child_profile)
      expect(response).to redirect_to(space_child_profiles_url(space))
    end
  end

  describe "authorization" do
    let(:unauthorized_user) { create(:user) }
    let(:child_profile) { create(:child_profile, space: space) }

    before do
      sign_in unauthorized_user
    end

    it "denies access to index without role in space" do
      expect {
        get space_child_profiles_url(space)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "denies access to show without role in space" do
      expect {
        get space_child_profile_url(space, child_profile)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "denies access to new without role in space" do
      expect {
        get new_space_child_profile_url(space)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
