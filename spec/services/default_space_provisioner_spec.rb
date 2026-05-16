# frozen_string_literal: true

require "rails_helper"

RSpec.describe DefaultSpaceProvisioner do
  let(:user) { create(:user) }

  let(:owner_role) do
    Roles::Common.find_or_create_by!(name: "Owner") do |role|
      role.value = "owner"
      role.permissions = Role::AVAILABLE_PERMISSIONS.index_with { "true" }
    end
  end

  describe ".call" do
    it "returns the user's first space when one exists" do
      space = create(:space)
      UserRole.create!(user: user, space: space, role: owner_role)

      expect(described_class.call(user: user)).to eq(space)
    end

    it "creates a space and owner membership when the user has none" do
      expect do
        described_class.call(user: user)
      end.to change(Space, :count).by(1).and change(UserRole, :count).by(1)

      expect(user.reload.spaces).to be_present
    end

    it "does not create a duplicate space when called twice" do
      first = described_class.call(user: user)
      second = described_class.call(user: user)
      expect(second).to eq(first)
      expect(user.reload.spaces.count).to eq(1)
    end
  end
end
