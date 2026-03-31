# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssessmentResponsePolicy, type: :policy do
  let(:space) { create(:space) }
  let(:child_profile) { create(:child_profile, space: space) }
  let(:template) { create(:assessment_template) }
  let(:assessment) { create(:assessment, child_profile: child_profile, assessment_template: template) }
  let(:response_record) { create(:assessment_response, assessment: assessment) }

  describe "owner role" do
    let(:owner_role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
    let(:owner) { create(:user) }
    let(:policy) { described_class.new(owner, response_record) }

    before do
      create(:user_role, user: owner, space: space, role: owner_role)
    end

    it "grants show?" do
      expect(policy.show?).to be true
    end

    it "grants update? when assessment is draft" do
      expect(policy.update?).to be true
    end
  end

  describe "when assessment is submitted" do
    let(:owner_role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
    let(:owner) { create(:user) }
    let(:policy) { described_class.new(owner, response_record) }

    before do
      create(:user_role, user: owner, space: space, role: owner_role)
      assessment.update!(status: :submitted)
    end

    it "denies update? for non-admin" do
      expect(policy.update?).to be false
    end
  end
end
