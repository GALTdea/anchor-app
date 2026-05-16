require 'rails_helper'

RSpec.describe "/spaces", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /index" do
    it "renders a successful response for multi-tenant mode" do
      Space.create!(name: "Test Space")
      get spaces_url
      expect(response).to be_successful
    end

    it "redirects single-family parents to home" do
      allow(AppSettings).to receive(:multi_tenant_mode).and_return(false)
      Space.create!(name: "Test Space")
      get spaces_url
      expect(response).to redirect_to(home_path)
    end

    it "allows admins to access index when multi-tenant mode is off" do
      admin = create(:user, :admin)
      sign_in admin
      allow(AppSettings).to receive(:multi_tenant_mode).and_return(false)
      Space.create!(name: "Test Space")
      get spaces_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "redirects to child profiles" do
      space = Space.create!(name: "Test Space")
      get space_url(space)
      expect(response).to redirect_to(space_child_profiles_path(space))
    end

    it "redirects single-family parents to home" do
      allow(AppSettings).to receive(:multi_tenant_mode).and_return(false)
      space = Space.create!(name: "Test Space")
      get space_url(space)
      expect(response).to redirect_to(home_path)
    end
  end

  describe "GET /new" do
    it "renders a successful response for multi-tenant mode" do
      get new_space_url
      expect(response).to be_successful
    end

    it "redirects single-family parents to home" do
      allow(AppSettings).to receive(:multi_tenant_mode).and_return(false)
      get new_space_url
      expect(response).to redirect_to(home_path)
    end
  end

  describe "POST /create" do
    it "redirects single-family parents to home" do
      allow(AppSettings).to receive(:multi_tenant_mode).and_return(false)
      post spaces_url, params: { space: { name: "Nope", status: "active" } }
      expect(response).to redirect_to(home_path)
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      space = Space.create!(name: "Test Space")
      get edit_space_url(space)
      expect(response).to be_successful
    end
  end
end
