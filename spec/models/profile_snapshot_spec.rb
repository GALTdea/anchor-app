# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfileSnapshot, type: :model do
  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:profile_snapshot)).to be_valid
    end

    it "allows a snapshot without a trigger source" do
      snapshot = build(:profile_snapshot, trigger_source: nil)

      expect(snapshot).to be_valid
    end
  end
end
