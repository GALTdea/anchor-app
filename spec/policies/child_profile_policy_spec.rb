require 'rails_helper'

RSpec.describe ChildProfilePolicy, type: :policy do
  let(:space) { create(:space) }
  let(:child_profile) { create(:child_profile, space: space) }

  describe "owner role" do
    let(:owner_role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
    let(:owner) { create(:user) }
    let(:policy) { described_class.new(owner, child_profile) }

    before do
      create(:user_role, user: owner, space: space, role: owner_role)
    end

    it "grants index?" do
      expect(policy.index?).to be true
    end

    it "grants show?" do
      expect(policy.show?).to be true
    end

    it "grants create?" do
      expect(policy.create?).to be true
    end

    it "grants update?" do
      expect(policy.update?).to be true
    end

    it "grants destroy?" do
      expect(policy.destroy?).to be true
    end
  end

  describe "caregiver role" do
    let(:caregiver_role) do
      create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }.merge(
        "delete_child_profile" => "false"
      ))
    end
    let(:caregiver) { create(:user) }
    let(:policy) { described_class.new(caregiver, child_profile) }

    before do
      create(:user_role, user: caregiver, space: space, role: caregiver_role)
    end

    it "grants index?" do
      expect(policy.index?).to be true
    end

    it "grants show?" do
      expect(policy.show?).to be true
    end

    it "grants create?" do
      expect(policy.create?).to be true
    end

    it "grants update?" do
      expect(policy.update?).to be true
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be false
    end
  end

  describe "collaborator role" do
    let(:collaborator_role) do
      create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }.merge(
        "create_child_profile" => "false",
        "update_child_profile" => "false",
        "delete_child_profile" => "false"
      ))
    end
    let(:collaborator) { create(:user) }
    let(:policy) { described_class.new(collaborator, child_profile) }

    before do
      create(:user_role, user: collaborator, space: space, role: collaborator_role)
    end

    it "grants index?" do
      expect(policy.index?).to be true
    end

    it "grants show?" do
      expect(policy.show?).to be true
    end

    it "denies create?" do
      expect(policy.create?).to be false
    end

    it "denies update?" do
      expect(policy.update?).to be false
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be false
    end
  end

  describe "no role in space" do
    let(:outsider) { create(:user) }
    let(:policy) { described_class.new(outsider, child_profile) }

    it "denies index?" do
      expect(policy.index?).to be_falsey
    end

    it "denies show?" do
      expect(policy.show?).to be_falsey
    end

    it "denies create?" do
      expect(policy.create?).to be_falsey
    end

    it "denies update?" do
      expect(policy.update?).to be_falsey
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be_falsey
    end
  end

  describe "admin user" do
    let(:admin) { create(:user, :admin) }

    it "grants access via role check when role exists" do
      owner_role = create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" })
      create(:user_role, user: admin, space: space, role: owner_role)
      policy = described_class.new(admin, child_profile)
      expect(policy.show?).to be true
    end
  end

  describe "Scope" do
    let(:user) { create(:user) }
    let(:other_space) { create(:space) }
    let!(:accessible_profile) { create(:child_profile, space: space) }
    let!(:inaccessible_profile) { create(:child_profile, space: other_space) }

    before do
      create(:user_role, user: user, space: space, role: create(:role, :common))
    end

    it "returns only child profiles from spaces user has access to" do
      resolved_scope = Pundit.policy_scope(user, ChildProfile)
      expect(resolved_scope).to include(accessible_profile)
      expect(resolved_scope).not_to include(inaccessible_profile)
    end

    context "when user is admin" do
      let(:admin) { create(:user, :admin) }

      it "returns all child profiles" do
        resolved_scope = Pundit.policy_scope(admin, ChildProfile)
        expect(resolved_scope).to include(accessible_profile, inaccessible_profile)
      end
    end
  end
end
