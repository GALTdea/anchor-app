# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("spec/support/friction_transition_schema")

RSpec.describe AssessmentEvidenceExtractor, type: :model do
  let(:user) { create(:user) }
  let(:space) { create(:space) }
  let(:child_profile) { create(:child_profile, space: space) }
  let(:template) do
    create(
      :assessment_template,
      title: "Friction e2e",
      slug: "friction-e2e-#{SecureRandom.hex(4)}",
      template_key: "friction_e2e_#{SecureRandom.hex(4)}",
      schema: FRICTION_TRANSITION_E2E_SCHEMA
    )
  end
  let(:assessment) { create(:assessment, child_profile: child_profile, assessment_template: template) }

  def extract_for!(answers)
    response = build(
      :assessment_response,
      assessment: assessment,
      actor: user,
      answers: answers,
      submitted_at: Time.current
    )
    response.save!
    described_class.new(response).call
    response.reload
  end

  it "omits evidence for transition_recovery_time when the branch is hidden" do
    # Stale key should not create evidence if the question is not in the active set
    extract_for!(
      "stop_start_friction" => "stalling",
      "transition_recovery_time" => "quick_recovery",
      "friction_closing" => "ok"
    )

    expect(ProfileEvidence.where(child_profile: child_profile, concept_key: "emotional_recovery_duration")).to be_empty
    expect(ProfileEvidence.where(child_profile: child_profile, concept_key: "set_shifting")).to be_present
  end

  it "creates evidence for transition_recovery_time when emotional_collapse and answered" do
    extract_for!(
      "stop_start_friction" => "emotional_collapse",
      "transition_recovery_time" => "quick_recovery",
      "friction_closing" => ""
    )

    ev = ProfileEvidence.find_by(child_profile: child_profile, concept_key: "emotional_recovery_duration")
    expect(ev).to be_present
    expect(ev.value).to eq("quick_recovery")
  end
end
