# frozen_string_literal: true

require "rails_helper"

RSpec.describe "db/seeds/analysis_rubrics/anchor_child_profile_v1" do
  it "is idempotent and creates a published v1 rubric" do
    2.times { load Rails.root.join("db/seeds/analysis_rubrics/anchor_child_profile_v1.rb") }

    r = AnalysisRubric.find_by!(rubric_key: "anchor_child_profile_v1", version: 1)
    expect(r).to be_published
    expect(r.published_at).to be_present
    expect(AnalysisRubric.where(rubric_key: "anchor_child_profile_v1", version: 1).count).to eq(1)
    expect(r.schema["version"]).to eq(1)
    expect(r.schema["domains"].map { |d| d["key"] }).to include(
      "communication",
      "family_priorities"
    )
  end
end
