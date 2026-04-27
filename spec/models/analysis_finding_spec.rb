# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalysisFinding, type: :model do
  describe "associations" do
    it "belongs to analysis_run" do
      expect(described_class.reflect_on_association(:analysis_run).macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "is valid with default factory" do
      expect(build(:analysis_finding)).to be_valid
    end

    it "requires dimension_key and finding_key" do
      f = build(:analysis_finding, dimension_key: "", finding_key: "")
      expect(f).not_to be_valid
    end

    it "rejects non-hash evidence_refs" do
      f = build(:analysis_finding, evidence_refs: "x")
      expect(f).not_to be_valid
      expect(f.errors[:evidence_refs]).to be_present
    end

    it "rejects non-hash metadata" do
      f = build(:analysis_finding, metadata: [])
      expect(f).not_to be_valid
      expect(f.errors[:metadata]).to be_present
    end

    it "allows confidence in 0..1" do
      expect(build(:analysis_finding, confidence: 0.0)).to be_valid
      expect(build(:analysis_finding, confidence: 1.0)).to be_valid
    end

    it "rejects confidence out of range" do
      f = build(:analysis_finding, confidence: 1.1)
      expect(f).not_to be_valid
    end

    it "rejects a second row with the same finding_key in the same run at the database" do
      run = create(:analysis_run, :completed)
      create(:analysis_finding, analysis_run: run, finding_key: "only")
      dup = build(:analysis_finding, analysis_run: run, finding_key: "only")
      expect { dup.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
