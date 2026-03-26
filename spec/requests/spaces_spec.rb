require 'rails_helper'

RSpec.describe "/spaces", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /index" do
    it "renders a successful response" do
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
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_space_url
      expect(response).to be_successful
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
