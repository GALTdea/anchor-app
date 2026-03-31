# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssessmentPolicy, type: :policy do
  let(:space) { create(:space) }
  let(:child_profile) { create(:child_profile, space: space) }
  let(:template) { create(:assessment_template) }
  let(:assessment) { create(:assessment, child_profile: child_profile, assessment_template: template) }

  describe "owner role" do
    let(:owner_role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
    let(:owner) { create(:user) }
    let(:policy) { described_class.new(owner, assessment) }

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

    it "grants destroy?" do
      expect(policy.destroy?).to be true
    end
  end

  describe "collaborator role" do
    let(:collaborator_role) do
      create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }.merge(
        "delete_assessment" => "false"
      ))
    end
    let(:collaborator) { create(:user) }
    let(:policy) { described_class.new(collaborator, assessment) }

    before do
      create(:user_role, user: collaborator, space: space, role: collaborator_role)
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be false
    end
  end
end
