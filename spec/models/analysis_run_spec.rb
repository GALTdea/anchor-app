# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalysisRun, type: :model do
  describe "associations" do
    it "wires to child profile, rubric, optional snapshot, and findings" do
      expect(described_class.reflect_on_association(:child_profile).macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:analysis_rubric).macro).to eq(:belongs_to)
      snapshot = described_class.reflect_on_association(:profile_snapshot)
      expect(snapshot.macro).to eq(:belongs_to)
      expect(snapshot.options[:optional]).to be true
      findings = described_class.reflect_on_association(:analysis_findings)
      expect(findings.macro).to eq(:has_many)
      expect(findings.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "is valid when completed with terminal fields" do
      run = build(:analysis_run, :completed)
      expect(run).to be_valid
    end

    it "rejects completed without input_digest" do
      run = build(:analysis_run, :completed, input_digest: nil)
      expect(run).not_to be_valid
      expect(run.errors[:input_digest]).to be_present
    end

    it "rejects completed without engine_version" do
      run = build(:analysis_run, :completed, engine_version: nil)
      expect(run).not_to be_valid
      expect(run.errors[:engine_version]).to be_present
    end

    it "rejects completed without completed_at" do
      run = build(:analysis_run, :completed, completed_at: nil)
      expect(run).not_to be_valid
      expect(run.errors[:completed_at]).to be_present
    end

    it "rejects completed_at before started_at" do
      run = build(
        :analysis_run,
        :completed,
        started_at: Time.current,
        completed_at: 1.hour.ago
      )
      expect(run).not_to be_valid
      expect(run.errors[:completed_at]).to be_present
    end

    it "rejects a second completed run for the same child, rubric, and input digest at the database" do
      profile = create(:child_profile)
      rubric = create(:analysis_rubric, :published, rubric_key: "idem", version: 1)
      digest = "sha256:abc"
      create(:analysis_run, :completed, child_profile: profile, analysis_rubric: rubric, input_digest: digest)
      duplicate = build(
        :analysis_run,
        :completed,
        child_profile: profile,
        analysis_rubric: rubric,
        input_digest: digest
      )
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "dependent destroy" do
    it "destroys findings with the run" do
      run = create(:analysis_run, :completed)
      finding = create(:analysis_finding, analysis_run: run)
      expect { run.destroy! }.to change(AnalysisFinding, :count).by(-1)
      expect(AnalysisFinding.find_by(id: finding.id)).to be_nil
    end
  end
end
