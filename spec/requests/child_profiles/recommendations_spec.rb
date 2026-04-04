# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Child profile recommendations", type: :request do
  let(:user) { create(:user) }
  let(:space) { create(:space) }
  let(:role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
  let(:child_profile) { create(:child_profile, space: space) }
  let!(:current_profile) { create(:current_profile, child_profile: child_profile) }
  let!(:profile_snapshot) { create(:profile_snapshot, child_profile: child_profile) }
  let!(:recommendation) { create(:recommendation, child_profile: child_profile, source_profile_snapshot: profile_snapshot) }

  before do
    sign_in user
    create(:user_role, user: user, space: space, role: role)
  end

  it "renders the recommendations index" do
    get space_child_profile_recommendations_path(space, child_profile)

    expect(response).to be_successful
    expect(response.body).to include("recommendations")
    expect(response.body).to include(recommendation.title)
  end

  it "renders the recommendation detail page" do
    get space_child_profile_recommendation_path(space, child_profile, recommendation)

    expect(response).to be_successful
    expect(response.body).to include("Why this was suggested")
  end
end
