# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecommendationPolicy, type: :policy do
  let(:space) { create(:space) }
  let(:child_profile) { create(:child_profile, space: space) }
  let(:profile_snapshot) { create(:profile_snapshot, child_profile: child_profile) }
  let(:recommendation) { create(:recommendation, child_profile: child_profile, source_profile_snapshot: profile_snapshot) }

  it "grants index? and show? to a user who can read child profiles" do
    user = create(:user)
    role = create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" })
    create(:user_role, user: user, space: space, role: role)
    policy = described_class.new(user, recommendation)

    expect(policy.index?).to be true
    expect(policy.show?).to be true
  end

  it "denies access without space access" do
    user = create(:user)
    policy = described_class.new(user, recommendation)

    expect(policy.index?).to be_falsey
    expect(policy.show?).to be_falsey
  end

  it "grants access to admins" do
    admin = create(:user, :admin)
    policy = described_class.new(admin, recommendation)

    expect(policy.index?).to be true
    expect(policy.show?).to be true
  end
end
