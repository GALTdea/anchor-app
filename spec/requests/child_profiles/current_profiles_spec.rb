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

  it "shows analysis insights when a completed analysis run exists" do
    rubric = create(:analysis_rubric, :published, rubric_key: "cp_view", version: 1, schema: { "version" => 1, "domains" => [] })
    run = create(:analysis_run, :completed, child_profile: child_profile, analysis_rubric: rubric)
    create(
      :analysis_finding,
      analysis_run: run,
      dimension_key: "regulation",
      finding_key: "regulation.support_signal",
      label: "Regulation pattern",
      summary: "Summary for current profile view.",
      confidence: 0.65,
      evidence_refs: { "profile_evidence_ids" => [ 9 ] }
    )

    get space_child_profile_current_profile_path(space, child_profile)

    expect(response).to be_successful
    expect(response.body).to include("What Anchor is noticing")
    expect(response.body).to include("Regulation pattern")
  end
end
