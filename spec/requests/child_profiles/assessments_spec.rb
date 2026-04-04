# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Child profile assessments", type: :request do
  let(:user) { create(:user) }
  let(:space) { create(:space) }
  let(:role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
  let(:child_profile) { create(:child_profile, space: space) }
  let(:template) { create(:assessment_template) }

  before do
    sign_in user
    create(:user_role, user: user, space: space, role: role)
  end

  describe "GET /index" do
    it "renders successfully" do
      get space_child_profile_assessments_path(space, child_profile)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    it "creates an assessment and response, then redirects to edit response" do
      expect {
        post space_child_profile_assessments_path(space, child_profile),
          params: { assessment: { assessment_template_id: template.id } }
      }.to change(Assessment, :count).by(1)
        .and change(AssessmentResponse, :count).by(1)

      assessment = Assessment.last
      assessment_response = assessment.assessment_response

      expect(response).to redirect_to(
        edit_space_child_profile_assessment_assessment_response_path(space, child_profile, assessment)
      )
      expect(assessment_response.template_slug_snapshot).to eq(template.slug)
      expect(assessment_response.template_version_snapshot).to eq(template.version)
      expect(assessment_response.template_schema_snapshot).to eq(template.schema)
      expect(assessment_response.processing_status).to be_nil
    end
  end

  describe "PATCH /response" do
    let(:assessment) { create(:assessment, child_profile: child_profile, assessment_template: template) }
    let!(:assessment_response) do
      create(:assessment_response, assessment: assessment, actor: user, answers: { "concern_level" => 2 })
    end

    it "submits and marks assessment submitted" do
      assessment_response.update!(last_processing_error: "old failure")

      patch space_child_profile_assessment_assessment_response_path(space, child_profile, assessment),
        params: {
          submit_action: "submit",
          assessment_response: {
            respondent_kind: "parent_proxy",
            answers: {
              "concern_level" => "3",
              "notes" => "Done"
            }
          }
        }

      expect(response).to redirect_to(space_child_profile_assessment_path(space, child_profile, assessment))
      assessment.reload
      assessment_response.reload
      expect(assessment.status).to eq("submitted")
      expect(assessment_response.submitted_at).to be_present
      expect(assessment_response.processing_status).to eq("queued")
      expect(assessment_response.last_processing_error).to be_nil
      expect(assessment_response.template_slug_snapshot).to eq(template.slug)
      expect(assessment_response.template_version_snapshot).to eq(template.version)
    end
  end

  describe "authorization" do
    let(:other_user) { create(:user) }
    let(:child_profile) { create(:child_profile, space: space) }

    before do
      sign_in other_user
    end

    it "denies index without role in space" do
      expect {
        get space_child_profile_assessments_path(space, child_profile)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
