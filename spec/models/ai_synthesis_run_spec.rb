# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiSynthesisRun, type: :model do
  describe "associations" do
    it "belongs to analysis_run" do
      expect(described_class.reflect_on_association(:analysis_run).macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "is valid for a minimal pending run" do
      run = build(:ai_synthesis_run)
      expect(run).to be_valid
    end

    it "requires purpose" do
      run = build(:ai_synthesis_run, purpose: " ")
      expect(run).not_to be_valid
      expect(run.errors[:purpose]).to be_present
    end

    it "accepts completed with terminal synthesis fields and non-empty output" do
      run = build(:ai_synthesis_run, :completed)
      expect(run).to be_valid
    end

    it "rejects completed without provider, model, prompt_version, completed_at, or non-empty output" do
      expect(build(:ai_synthesis_run, :completed, provider: nil)).not_to be_valid
      expect(build(:ai_synthesis_run, :completed, model: nil)).not_to be_valid
      expect(build(:ai_synthesis_run, :completed, prompt_version: nil)).not_to be_valid
      expect(build(:ai_synthesis_run, :completed, completed_at: nil)).not_to be_valid

      empty_output = build(:ai_synthesis_run, :completed, output: {})
      expect(empty_output).not_to be_valid
      expect(empty_output.errors[:output]).to be_present
    end

    it "rejects failed without error_message" do
      run = build(:ai_synthesis_run, :failed, error_message: nil)
      expect(run).not_to be_valid
      expect(run.errors[:error_message]).to be_present
    end

    it "rejects completed_at before started_at" do
      run = build(
        :ai_synthesis_run,
        :completed,
        started_at: Time.current,
        completed_at: 1.hour.ago
      )
      expect(run).not_to be_valid
      expect(run.errors[:completed_at]).to be_present
    end
  end

  describe "dependent destroy" do
    it "destroying analysis_run removes synthesis attempts" do
      synthesis = create(:ai_synthesis_run)
      analysis = synthesis.analysis_run

      expect { analysis.destroy! }.to change(described_class, :count).by(-1)
    end
  end
end
