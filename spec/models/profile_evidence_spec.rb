# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfileEvidence, type: :model do
  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:profile_evidence)).to be_valid
    end

    it "requires a supported value_type" do
      evidence = build(:profile_evidence, value_type: "numberish")

      expect(evidence).not_to be_valid
      expect(evidence.errors[:value_type]).to include("is not included in the list")
    end

    it "requires confidence between 0 and 1" do
      evidence = build(:profile_evidence, confidence: 1.5)

      expect(evidence).not_to be_valid
      expect(evidence.errors[:confidence]).to be_present
    end
  end
end
