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

    it "does not allow editing a published template in place" do
      sign_in admin

      get edit_admin_assessment_template_path(published_template)

      expect(response).to redirect_to(admin_assessment_template_path(published_template))
      expect(flash[:alert]).to eq("Published templates cannot be edited in place.")
    end
  end
end
