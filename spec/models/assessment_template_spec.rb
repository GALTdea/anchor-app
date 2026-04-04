# frozen_string_literal: true

# == Schema Information
#
# Table name: assessment_templates
# Database name: primary
#
#  id               :bigint           not null, primary key
#  category         :string
#  respondent_types :jsonb            not null
#  schema           :jsonb            not null
#  slug             :string           not null
#  status           :integer          default("draft"), not null
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_assessment_templates_on_slug  (slug) UNIQUE
#
require "rails_helper"

RSpec.describe AssessmentTemplate, type: :model do
  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:assessment_template)).to be_valid
    end

    it "requires template_key" do
      template = build(:assessment_template, template_key: nil)
      expect(template).not_to be_valid
      expect(template.errors[:template_key]).to be_present
    end

    it "requires version to be a positive integer" do
      template = build(:assessment_template, version: 0)
      expect(template).not_to be_valid
      expect(template.errors[:version]).to be_present
    end

    it "requires template_key to be unique within a version" do
      create(:assessment_template, template_key: "child-onboarding", version: 1)
      duplicate = build(:assessment_template, template_key: "child-onboarding", version: 1)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:template_key]).to be_present
    end

    it "allows a new version for the same template_key" do
      create(:assessment_template, template_key: "child-onboarding", version: 1)
      next_version = build(:assessment_template, template_key: "child-onboarding", version: 2)

      expect(next_version).to be_valid
    end

    it "requires respondent_types subset for published templates" do
      template = build(:assessment_template, respondent_types: [ "invalid_kind" ])
      expect(template).not_to be_valid
      expect(template.errors[:respondent_types]).to be_present
    end

    it "requires non-empty respondent_types for published templates" do
      template = build(:assessment_template, respondent_types: [])
      expect(template).not_to be_valid
    end

    it "allows draft templates without published constraints" do
      template = build(:assessment_template, :draft, respondent_types: [], schema: {})
      expect(template).to be_valid
    end

    it "requires published templates to include AI-facing semantics" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "questions" => [
            {
              "id" => "concern_level",
              "label" => "Overall level of concern",
              "type" => "scale",
              "min" => 1,
              "max" => 5,
              "required" => true
            }
          ]
        }
      )

      expect(template).not_to be_valid
      expect(template.errors[:schema]).to be_present
    end

    it "requires unique question ids for published templates" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "questions" => [
            {
              "id" => "duplicate",
              "label" => "Question one",
              "type" => "text",
              "dimension_key" => "regulation.one",
              "concept_key" => "question_one",
              "time_window" => "typical_week",
              "evidence_weight" => 0.5
            },
            {
              "id" => "duplicate",
              "label" => "Question two",
              "type" => "text",
              "dimension_key" => "regulation.two",
              "concept_key" => "question_two",
              "time_window" => "typical_week",
              "evidence_weight" => 0.5
            }
          ]
        }
      )

      expect(template).not_to be_valid
      expect(template.errors[:schema]).to be_present
    end

    it "treats published versions as immutable" do
      template = create(:assessment_template)

      expect(template.update(title: "Updated title")).to be(false)
      expect(template.errors[:base]).to include("published template versions are immutable; create a new version instead")
    end

    it "allows archiving a published template version" do
      template = create(:assessment_template)

      expect(template.update(status: :archived)).to be(true)
    end
  end

  describe ".published" do
    it "returns only published records" do
      published = create(:assessment_template)
      create(:assessment_template, :draft, slug: "draft-only", title: "Draft only")
      expect(described_class.published).to contain_exactly(published)
    end
  end
end
