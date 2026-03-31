# frozen_string_literal: true

# == Schema Information
#
# Table name: assessments
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  status                 :integer          default("draft"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  assessment_template_id :bigint           not null
#  assigned_to_user_id    :integer
#  child_profile_id       :bigint           not null
#
# Indexes
#
#  index_assessments_on_assessment_template_id  (assessment_template_id)
#  index_assessments_on_child_profile_id        (child_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (assessment_template_id => assessment_templates.id)
#  fk_rails_...  (assigned_to_user_id => users.id)
#  fk_rails_...  (child_profile_id => child_profiles.id)
#
require "rails_helper"

RSpec.describe Assessment, type: :model do
  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:assessment)).to be_valid
    end

    it "requires a published template on create" do
      draft_template = create(:assessment_template, :draft, slug: "draft-tpl", title: "Draft tpl")
      assessment = build(:assessment, assessment_template: draft_template)
      expect(assessment).not_to be_valid
      expect(assessment.errors[:assessment_template]).to be_present
    end
  end

  describe "associations" do
    it "destroys responses with the assessment" do
      response = create(:assessment_response)
      assessment = response.assessment
      expect { assessment.destroy }.to change(AssessmentResponse, :count).by(-1)
    end
  end
end
