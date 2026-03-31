# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssessmentTemplatePolicy, type: :policy do
  let(:space) { create(:space) }
  let(:template) { create(:assessment_template) }
  let(:context) { described_class::Context.new(template, space) }

  describe "user with read_assessment in space" do
    let(:role) { create(:role, :common, permissions: Role::AVAILABLE_PERMISSIONS.index_with { "true" }) }
    let(:user) { create(:user) }
    let(:policy) { described_class.new(user, context) }

    before do
      create(:user_role, user: user, space: space, role: role)
    end

    it "grants show?" do
      expect(policy.show?).to be true
    end
  end

  describe "user without role in space" do
    let(:outsider) { create(:user) }
    let(:policy) { described_class.new(outsider, context) }

    it "denies show?" do
      expect(policy.show?).to be false
    end
  end
end
