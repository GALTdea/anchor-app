# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Child profile current profile", type: :request do
  let(:user) { create(:user) }
  let(:space) { create(:space) }
  let(:role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
  let(:child_profile) { create(:child_profile, space: space) }
  let!(:current_profile) { create(:current_profile, child_profile: child_profile) }

  before do
    sign_in user
    create(:user_role, user: user, space: space, role: role)
  end

  it "renders the current profile" do
    get space_child_profile_current_profile_path(space, child_profile)

    expect(response).to be_successful
    expect(response.body).to include("current profile")
    expect(response.body).to include("Tracked dimensions")
  end
end
