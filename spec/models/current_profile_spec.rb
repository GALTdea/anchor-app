# frozen_string_literal: true

require "rails_helper"

RSpec.describe CurrentProfile, type: :model do
  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:current_profile)).to be_valid
    end

    it "requires a positive profile_version" do
      profile = build(:current_profile, profile_version: 0)

      expect(profile).not_to be_valid
      expect(profile.errors[:profile_version]).to be_present
    end
  end
end
