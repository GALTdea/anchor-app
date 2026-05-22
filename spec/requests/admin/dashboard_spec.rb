# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe "GET /admin" do
    it "renders the admin home page for admins" do
      sign_in admin

      get admin_root_path

      expect(response).to be_successful
      expect(response.body).to include("Admin")
      expect(response.body).to include(admin_assessment_templates_path)
      expect(response.body).to include(edit_setup_path)
    end

    it "raises for non-admins" do
      sign_in user

      expect {
        get admin_root_path
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "renders the admin sidebar" do
      sign_in admin

      get admin_root_path

      expect(response.body).to include('id="drawer-toggle"')
      expect(response.body).to include("Admin Home")
      expect(response.body).not_to match(/drawer-side[\s\S]*>\s*Home\s*</)
      expect(response.body).not_to match(/drawer-side[\s\S]*>\s*Spaces\s*</)
    end
  end

  describe "layout behavior for admin users" do
    before { sign_in admin }

    it "renders the admin sidebar on assessment template pages" do
      get admin_assessment_templates_path

      expect(response.body).to include('id="drawer-toggle"')
      expect(response.body).to include("Assessments")
    end

    it "does not render the admin sidebar on home" do
      get home_path

      expect(response.body).not_to include('id="drawer-toggle"')
      expect(response.body).to match(/>\s*Home\s*</)
    end

    it "does not render the admin sidebar on spaces" do
      get spaces_path

      expect(response.body).not_to include('id="drawer-toggle"')
    end
  end
end
