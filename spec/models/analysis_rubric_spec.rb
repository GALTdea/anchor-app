# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalysisRubric, type: :model do
  describe "associations" do
    it "has many analysis_runs" do
      expect(described_class.reflect_on_association(:analysis_runs).macro).to eq(:has_many)
      expect(described_class.reflect_on_association(:analysis_runs).options[:dependent]).to eq(
        :restrict_with_error
      )
    end
  end

  describe "validations" do
    it "is valid with default factory" do
      expect(build(:analysis_rubric)).to be_valid
    end

    it "requires name" do
      rubric = build(:analysis_rubric, name: "")
      expect(rubric).not_to be_valid
      expect(rubric.errors[:name]).to be_present
    end

    it "requires a hash schema" do
      rubric = build(:analysis_rubric, schema: "not")
      expect(rubric).not_to be_valid
      expect(rubric.errors[:schema]).to be_present
    end

    it "allows an empty hash schema for drafts" do
      expect(build(:analysis_rubric, schema: {})).to be_valid
    end

    it "enforces unique rubric_key scoped to version" do
      create(:analysis_rubric, rubric_key: "k", version: 1)
      duplicate = build(:analysis_rubric, rubric_key: "k", version: 1)
      expect(duplicate).not_to be_valid
    end
  end

  describe "published invariants" do
    it "requires published_at when published" do
      rubric = build(:analysis_rubric, :published, published_at: nil, rubric_key: "pk", version: 1)
      expect(rubric).not_to be_valid
      expect(rubric.errors[:published_at]).to be_present
    end
  end

  describe "immutability" do
    it "blocks changing core fields on published records" do
      rubric = create(:analysis_rubric, :published, rubric_key: "immut", version: 1)
      rubric.name = "Changed"
      expect(rubric).not_to be_valid
      expect(rubric.errors[:base].join).to include("immutable")
    end
  end

  describe "destroy restriction" do
    it "prevents destroy when analysis runs exist" do
      rubric = create(:analysis_rubric, :published, rubric_key: "r1", version: 1)
      create(:analysis_run, analysis_rubric: rubric, child_profile: create(:child_profile))
      expect { rubric.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end
end
