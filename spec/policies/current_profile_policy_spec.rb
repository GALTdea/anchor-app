# frozen_string_literal: true

require "rails_helper"

RSpec.describe CurrentProfilePolicy, type: :policy do
  let(:space) { create(:space) }
  let(:child_profile) { create(:child_profile, space: space) }
  let(:current_profile) { create(:current_profile, child_profile: child_profile) }

  it "grants show? to a user who can read child profiles" do
    user = create(:user)
    role = create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" })
    create(:user_role, user: user, space: space, role: role)

    expect(described_class.new(user, current_profile).show?).to be true
  end

  it "denies show? without space access" do
    user = create(:user)

    expect(described_class.new(user, current_profile).show?).to be_falsey
  end

  it "grants show? to admins" do
    admin = create(:user, :admin)

    expect(described_class.new(admin, current_profile).show?).to be true
  end
end
