# frozen_string_literal: true

require "rails_helper"

RSpec.describe OnboardingResultsPresenter, type: :model do
  let(:assessment_template) { create(:assessment_template) }
  let(:space) { create(:space) }
  let(:child_profile) { create(:child_profile, space: space, first_name: "Maya", last_name: "Rivera") }
  let(:user) { create(:user) }
  let(:onboarding_session) do
    create(
      :onboarding_session,
      assessment_template: assessment_template,
      user: user,
      space: space,
      child_profile: child_profile,
      status: :completed
    )
  end

  describe "#child_profile" do
    it "returns the session child profile" do
      expect(described_class.new(onboarding_session).child_profile).to eq(child_profile)
    end
  end

  describe "#space" do
    it "returns the session space" do
      expect(described_class.new(onboarding_session).space).to eq(space)
    end
  end

  describe "#current_profile" do
    it "returns the persisted current profile when present" do
      current = create(:current_profile, child_profile: child_profile)

      expect(described_class.new(onboarding_session).current_profile).to eq(current)
    end

    it "builds an empty profile when none exists" do
      presenter = described_class.new(onboarding_session)

      expect(presenter.current_profile).to be_a(CurrentProfile)
      expect(presenter.current_profile).not_to be_persisted
      expect(presenter.current_profile.summary).to eq({})
    end
  end

  describe "#recommendations" do
    it "returns active recommendations newest first" do
      snapshot = create(:profile_snapshot, child_profile: child_profile)
      older = create(:recommendation, child_profile: child_profile, source_profile_snapshot: snapshot, generated_at: 2.days.ago)
      create(:recommendation, child_profile: child_profile, source_profile_snapshot: snapshot, status: :archived)
      newer = create(:recommendation, child_profile: child_profile, source_profile_snapshot: snapshot, generated_at: 1.hour.ago)

      recs = described_class.new(onboarding_session).recommendations

      expect(recs).to eq([ newer, older ])
    end
  end
end
