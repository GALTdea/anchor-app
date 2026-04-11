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

  describe "admin management" do
    let(:admin) { create(:user, :admin) }

    it "allows index on the model class" do
      policy = described_class.new(admin, AssessmentTemplate)

      expect(policy.index?).to be true
    end

    it "allows updating a template record" do
      policy = described_class.new(admin, template)

      expect(policy.update?).to be true
    end

    it "scopes admin management to all templates" do
      expect(described_class::Scope.new(admin, AssessmentTemplate.all).resolve).to eq(AssessmentTemplate.all)
    end
  end

  describe "non-admin management" do
    let(:user) { create(:user) }

    it "denies index on the model class" do
      policy = described_class.new(user, AssessmentTemplate)

      expect(policy.index?).to be false
    end

    it "returns no records from scope" do
      expect(described_class::Scope.new(user, AssessmentTemplate.all).resolve).to be_empty
    end
  end
end
