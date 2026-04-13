# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin assessment templates", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let!(:draft_template) { create(:assessment_template, :draft, title: "Draft template") }
  let!(:published_template) { create(:assessment_template, title: "Published template") }

  describe "GET /admin/assessment_templates" do
    it "renders successfully for admins" do
      sign_in admin

      get admin_assessment_templates_path

      expect(response).to be_successful
      expect(response.body).to include("Draft template")
      expect(response.body).to include("Published template")
    end

    it "raises for non-admins" do
      sign_in user

      expect {
        get admin_assessment_templates_path
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "POST /admin/assessment_templates" do
    it "creates a draft template for admins" do
      sign_in admin

      expect {
        post admin_assessment_templates_path, params: {
          assessment_template: {
            title: "New manager draft",
            slug: "new-manager-draft",
            template_key: "new-manager-draft",
            version: 1,
            category: "screening",
            respondent_types: [ "parent_proxy", "teacher_report" ]
          }
        }
      }.to change(AssessmentTemplate, :count).by(1)

      template = AssessmentTemplate.order(:id).last
      expect(response).to redirect_to(admin_assessment_template_path(template))
      expect(template).to be_draft
      expect(template.schema).to eq(AssessmentTemplate.default_schema)
      expect(template.respondent_types).to match_array(%w[parent_proxy teacher_report])
    end
  end

  describe "PATCH /admin/assessment_templates/:id" do
    it "updates a draft template" do
      sign_in admin

      patch admin_assessment_template_path(draft_template), params: {
        assessment_template: {
          title: "Updated draft title",
          slug: draft_template.slug,
          template_key: draft_template.template_key,
          version: draft_template.version,
          category: "intake",
          respondent_types: [ "self_report" ]
        }
      }

      expect(response).to redirect_to(admin_assessment_template_path(draft_template))
      expect(draft_template.reload.title).to eq("Updated draft title")
      expect(draft_template.category).to eq("intake")
      expect(draft_template.respondent_types).to eq([ "self_report" ])
    end

    it "builds schema sections and questions from editor params" do
      sign_in admin

      patch admin_assessment_template_path(draft_template), params: {
        assessment_template: {
          title: draft_template.title,
          slug: draft_template.slug,
          template_key: draft_template.template_key,
          version: draft_template.version,
          category: draft_template.category,
          schema_version: 2,
          respondent_types: [ "parent_proxy" ],
          sections_attributes: {
            "0" => {
              id: "communication",
              title: "Communication",
              description: "How the child communicates",
              position: 1,
              questions_attributes: {
                "0" => {
                  id: "expresses_needs",
                  label: "How does your child express needs?",
                  type: "select",
                  required: "1",
                  options_text: "Words\nGestures\nMixed",
                  dimension_key: "communication.expression",
                  concept_key: "expresses_needs",
                  time_window: "typical_two_weeks",
                  evidence_weight: "0.8",
                  extraction_hint: "Capture expressive communication style",
                  position: 1
                }
              }
            }
          }
        }
      }

      expect(response).to redirect_to(admin_assessment_template_path(draft_template))

      schema = draft_template.reload.schema.deep_stringify_keys
      expect(schema["version"]).to eq(2)
      expect(schema["sections"]).to eq([
        {
          "id" => "communication",
          "title" => "Communication",
          "description" => "How the child communicates",
          "position" => 1
        }
      ])
      expect(schema["questions"]).to eq([
        {
          "id" => "expresses_needs",
          "label" => "How does your child express needs?",
          "type" => "select",
          "required" => true,
          "dimension_key" => "communication.expression",
          "concept_key" => "expresses_needs",
          "time_window" => "typical_two_weeks",
          "evidence_weight" => 0.8,
          "extraction_hint" => "Capture expressive communication style",
          "position" => 1,
          "options" => [ "Words", "Gestures", "Mixed" ],
          "section" => "communication"
        }
      ])
    end

    it "does not allow editing a published template in place" do
      sign_in admin

      get edit_admin_assessment_template_path(published_template)

      expect(response).to redirect_to(admin_assessment_template_path(published_template))
      expect(flash[:alert]).to eq("Published templates cannot be edited in place.")
    end
  end

  describe "GET /admin/assessment_templates/:id/edit" do
    it "renders schema authoring fields for draft templates" do
      sign_in admin

      get edit_admin_assessment_template_path(draft_template)

      expect(response).to be_successful
      expect(response.body).to include("Draft structure")
      expect(response.body).to include("Add section")
      expect(response.body).to include("Questions")
      expect(response.body).to include("Dimension key")
    end
  end

  describe "GET /admin/assessment_templates/:id/preview" do
    it "renders a read-only preview" do
      sign_in admin

      get preview_admin_assessment_template_path(draft_template)

      expect(response).to be_successful
      expect(response.body).to include("Assessment preview")
      expect(response.body).to include("Publish rules")
      expect(response.body).to include(draft_template.title)
    end
  end

  describe "POST /admin/assessment_templates/:id/publish" do
    it "publishes a valid draft" do
      sign_in admin

      post publish_admin_assessment_template_path(draft_template)

      expect(response).to redirect_to(admin_assessment_template_path(draft_template))
      expect(draft_template.reload).to be_published
    end

    it "renders edit with errors for an invalid draft" do
      sign_in admin
      draft_template.update_columns(respondent_types: [], schema: { "version" => 1, "questions" => [] })

      post publish_admin_assessment_template_path(draft_template)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("This draft must be fixed before it can be published.")
      expect(draft_template.reload).to be_draft
    end
  end

  describe "POST /admin/assessment_templates/:id/new_version" do
    it "creates a new draft version from a published template" do
      sign_in admin

      expect {
        post new_version_admin_assessment_template_path(published_template)
      }.to change(AssessmentTemplate, :count).by(1)

      new_draft = AssessmentTemplate.order(:id).last
      expect(response).to redirect_to(edit_admin_assessment_template_path(new_draft))
      expect(new_draft).to be_draft
      expect(new_draft.version).to eq(published_template.version + 1)
      expect(new_draft.template_key).to eq(published_template.template_key)
      expect(new_draft.schema).to eq(published_template.schema)
      expect(new_draft.respondent_types).to eq(published_template.respondent_types)
    end

    it "rejects versioning a draft template" do
      sign_in admin

      expect {
        post new_version_admin_assessment_template_path(draft_template)
      }.not_to change(AssessmentTemplate, :count)

      expect(response).to redirect_to(admin_assessment_template_path(draft_template))
      expect(flash[:alert]).to eq("Only published templates can be versioned.")
    end
  end

  describe "POST /admin/assessment_templates/:id/set_as_onboarding" do
    it "sets a published template as the onboarding assessment" do
      sign_in admin

      post set_as_onboarding_admin_assessment_template_path(published_template)

      expect(response).to redirect_to(admin_assessment_template_path(published_template))
      expect(AppSettings.onboarding_assessment_template_id).to eq(published_template.id.to_s)
      expect(flash[:notice]).to eq("#{published_template.title} is now the onboarding assessment.")
    end

    it "rejects draft templates" do
      sign_in admin

      post set_as_onboarding_admin_assessment_template_path(draft_template)

      expect(response).to redirect_to(admin_assessment_template_path(draft_template))
      expect(flash[:alert]).to eq("Only published templates can be used for onboarding.")
    end
  end
end
