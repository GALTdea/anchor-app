# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/home", type: :request do
  describe "GET /home" do
    context "when not signed in" do
      it "redirects to sign in" do
        get home_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user, password: "password123") }

      it "returns success" do
        sign_in user
        get home_path
        expect(response).to have_http_status(:ok)
      end

      it "provisions a default space when the user has none" do
        sign_in user
        expect { get home_path }.to change { user.reload.spaces.count }.from(0).to(1)
      end

      it "lists active child profiles in the default space" do
        sign_in user
        space = user.default_space
        create(:child_profile, space: space, first_name: "Ada", last_name: "Lovelace")
        get home_path
        expect(response.body).to include("Ada")
      end

      it "shows empty state when there are no child profiles" do
        sign_in user
        get home_path
        expect(response.body).to include("No child profiles yet")
      end

      it 'does not expose a primary nav link labeled Spaces when multi-tenant is off' do
        allow(AppSettings).to receive(:multi_tenant_mode).and_return(false)
        sign_in user
        get home_path
        expect(response.body).not_to match(/>\s*Spaces\s*</)
        expect(response.body).to match(/>\s*Home\s*</)
      end
    end
  end
end
