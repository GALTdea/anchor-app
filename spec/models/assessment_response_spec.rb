# frozen_string_literal: true

# == Schema Information
#
# Table name: assessment_responses
# Database name: primary
#
#  id              :bigint           not null, primary key
#  answers         :jsonb            not null
#  respondent_kind :string           not null
#  submitted_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  actor_id        :integer          not null
#  assessment_id   :bigint           not null
#
# Indexes
#
#  index_assessment_responses_on_assessment_id  (assessment_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (assessment_id => assessments.id)
#
require "rails_helper"

RSpec.describe AssessmentResponse, type: :model do
  let(:template) { create(:assessment_template) }
  let(:assessment) { create(:assessment, assessment_template: template) }
  let(:actor) { create(:user) }

  describe "validations" do
    it "is valid with factory defaults" do
      response = build(:assessment_response, assessment: assessment, actor: actor)
      expect(response).to be_valid
      expect(response.template_slug_snapshot).to eq(template.slug)
      expect(response.template_version_snapshot).to eq(template.version)
      expect(response.template_schema_snapshot).to eq(template.schema)
    end

    it "rejects invalid respondent_kind" do
      response = build(:assessment_response, assessment: assessment, actor: actor, respondent_kind: "nope")
      expect(response).not_to be_valid
    end

    it "rejects respondent_kind not allowed by template" do
      response = build(
        :assessment_response,
        assessment: assessment,
        actor: actor,
        respondent_kind: "therapist_report"
      )
      expect(response).not_to be_valid
    end

    it "validates answers on submit" do
      response = build(
        :assessment_response,
        assessment: assessment,
        actor: actor,
        answers: {},
        respondent_kind: "parent_proxy"
      )
      response.submitting = true
      expect(response).not_to be_valid
      expect(response.errors[:answers]).to be_present
    end

    it "accepts complete answers on submit" do
      response = build(
        :assessment_response,
        assessment: assessment,
        actor: actor,
        answers: { "concern_level" => 3, "notes" => "ok" },
        respondent_kind: "parent_proxy"
      )
      response.submitting = true
      expect(response).to be_valid
    end

    it "rejects invalid processing_status" do
      response = build(:assessment_response, assessment: assessment, actor: actor, processing_status: "nope")
      expect(response).not_to be_valid
      expect(response.errors[:processing_status]).to include("is not included in the list")
    end

    it "keeps template snapshots immutable after creation" do
      response = create(:assessment_response, assessment: assessment, actor: actor)

      response.template_slug_snapshot = "changed"

      expect(response).not_to be_valid
      expect(response.errors[:base]).to include("template snapshot cannot change once the response is created")
    end
  end
end
