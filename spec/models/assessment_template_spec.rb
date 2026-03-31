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
  end

  describe ".published" do
    it "returns only published records" do
      published = create(:assessment_template)
      create(:assessment_template, :draft, slug: "draft-only", title: "Draft only")
      expect(described_class.published).to contain_exactly(published)
    end
  end
end
