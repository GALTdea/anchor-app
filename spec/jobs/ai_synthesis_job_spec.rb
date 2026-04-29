# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiSynthesisJob, type: :job do
  it "delegates to the synthesis runner" do
    child = create(:child_profile)
    rubric = create(:analysis_rubric, :published, rubric_key: "job_syn", version: 1)
    run = create(:analysis_run, :completed, child_profile: child, analysis_rubric: rubric)
    create(:analysis_finding, analysis_run: run, dimension_key: "communication.z", finding_key: "communication.z.sig")

    expect do
      described_class.perform_now(run.id)
    end.to change(AiSynthesisRun, :count).by(1)

    synthesis = AiSynthesisRun.order(:id).last
    expect(synthesis.analysis_run_id).to eq(run.id)
    expect(synthesis).to be_completed
  end
end
