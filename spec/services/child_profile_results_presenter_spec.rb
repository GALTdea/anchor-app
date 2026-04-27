# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChildProfileResultsPresenter, type: :model do
  let(:child_profile) { create(:child_profile, first_name: "Maya", last_name: "Rivera") }

  describe "#page_title" do
    it "uses the child name profile wording" do
      presenter = described_class.new(child_profile)

      expect(presenter.page_title).to eq("Maya Rivera Profile")
    end
  end

  describe "#current_profile" do
    it "returns an unsaved empty profile object when none exists yet" do
      presenter = described_class.new(child_profile)

      expect(presenter.current_profile).to be_a(CurrentProfile)
      expect(presenter.current_profile).not_to be_persisted
      expect(presenter.current_profile.summary).to eq({})
      expect(presenter.current_profile.profile_version).to eq(1)
    end
  end

  describe "#strengths_dimensions" do
    it "separates strengths from other profile domains" do
      create(:current_profile, child_profile: child_profile, summary: profile_summary)

      presenter = described_class.new(child_profile)

      expect(presenter.strengths_dimensions.keys).to contain_exactly("strengths.interests")
    end
  end

  describe "#profile_domain_groups" do
    it "groups profile dimensions into parent-readable domains" do
      create(:current_profile, child_profile: child_profile, summary: profile_summary)

      groups = described_class.new(child_profile).profile_domain_groups

      expect(groups.map(&:title)).to eq([
        "Communication",
        "Sensory experience",
        "Regulation",
        "Priorities",
        "Other signals"
      ])
      expect(groups.find { |group| group.key == "communication" }.dimensions.keys).to contain_exactly("communication.expressive")
      expect(groups.find { |group| group.key == "other_signals" }.dimensions.keys).to contain_exactly("medical.medications")
    end
  end

  describe "#active_recommendations" do
    it "returns active recommendations newest first" do
      snapshot = create(:profile_snapshot, child_profile: child_profile)
      older = create(:recommendation, child_profile: child_profile, source_profile_snapshot: snapshot, generated_at: 2.days.ago)
      archived = create(:recommendation, child_profile: child_profile, source_profile_snapshot: snapshot, status: :archived)
      newer = create(:recommendation, child_profile: child_profile, source_profile_snapshot: snapshot, generated_at: 1.hour.ago)

      recommendations = described_class.new(child_profile).active_recommendations

      expect(recommendations).to eq([ newer, older ])
      expect(recommendations).not_to include(archived)
    end
  end

  describe "#profile_traits" do
    it "returns parent-readable values from current profile dimensions" do
      create(:current_profile, child_profile: child_profile, summary: profile_summary)

      traits = described_class.new(child_profile).profile_traits

      expect(traits).to include("Dinosaurs", "Uses short phrases", "Sound sensitive")
      expect(traits).not_to include("None reported")
    end

    it "uses safe fallback traits when profile dimensions are not ready" do
      traits = described_class.new(child_profile).profile_traits

      expect(traits).to include("May do best when the next step is clear.")
    end
  end

  describe "#driving_explanations" do
    it "returns up to three uncertain behavior explanations" do
      create(:current_profile, child_profile: child_profile, summary: profile_summary)

      explanations = described_class.new(child_profile).driving_explanations

      expect(explanations.length).to eq(3)
      expect(explanations.map(&:behavior_context).join).to include("Communication")
      expect(explanations.map(&:possible_meaning).join).to match(/may|might|could/)
    end
  end

  describe "#support_priorities" do
    it "returns no more than three focus areas from recommendations" do
      snapshot = create(:profile_snapshot, child_profile: child_profile)
      4.times do
        create(:recommendation, child_profile: child_profile, source_profile_snapshot: snapshot, category: "regulation")
      end

      priorities = described_class.new(child_profile).support_priorities

      expect(priorities.length).to eq(3)
      expect(priorities.map(&:title)).to all(eq("Support recovery after hard moments"))
    end
  end

  describe "#weekly_ideas" do
    it "returns no more than three ideas from recommendations" do
      snapshot = create(:profile_snapshot, child_profile: child_profile)
      4.times do |index|
        create(
          :recommendation,
          child_profile: child_profile,
          source_profile_snapshot: snapshot,
          title: "Try support #{index}",
          body: "Use support #{index}."
        )
      end

      ideas = described_class.new(child_profile).weekly_ideas

      expect(ideas.length).to eq(3)
      expect(ideas.map(&:title)).to all(include("Try support"))
      expect(ideas.map(&:estimated_time)).to all(eq("5-10 minutes"))
    end

    it "uses safe fallback ideas when recommendations are not ready" do
      ideas = described_class.new(child_profile).weekly_ideas

      expect(ideas.length).to eq(3)
      expect(ideas.first.title).to eq("Preview one tricky transition")
    end
  end

  describe "#latest_assessment_response" do
    it "returns the latest submitted response and exposes its processing status" do
      older_response = submitted_response(submitted_at: 2.days.ago, processing_status: "completed")
      latest_response = submitted_response(submitted_at: 1.hour.ago, processing_status: "queued")
      draft_assessment = create(:assessment, child_profile: child_profile)
      create(:assessment_response, assessment: draft_assessment, submitted_at: nil, processing_status: "processing")

      presenter = described_class.new(child_profile)

      expect(presenter.latest_assessment_response).to eq(latest_response)
      expect(presenter.latest_assessment_response).not_to eq(older_response)
      expect(presenter.processing_status).to eq("queued")
    end
  end

  describe "#parent_analysis_rows" do
    it "returns parent-facing rows from the latest completed analysis run" do
      rubric = create(:analysis_rubric, :published, rubric_key: "presenter_ar", version: 1, schema: { "version" => 1, "domains" => [] })
      run = create(:analysis_run, :completed, child_profile: child_profile, analysis_rubric: rubric)
      create(
        :analysis_finding,
        analysis_run: run,
        dimension_key: "communication",
        finding_key: "communication.support_signal",
        label: "Communication support",
        summary: "A working pattern from saved answers.",
        confidence: 0.75,
        evidence_refs: { "profile_evidence_ids" => [ 1, 2 ] }
      )

      rows = described_class.new(child_profile).parent_analysis_rows

      expect(rows.size).to eq(1)
      expect(rows.first.title).to eq("Communication support")
      expect(rows.first.evidence_note).to include("2 saved observations")
    end

    it "orders strengths domain findings before other domains" do
      rubric = create(:analysis_rubric, :published, rubric_key: "presenter_ar2", version: 1, schema: { "version" => 1, "domains" => [] })
      run = create(:analysis_run, :completed, child_profile: child_profile, analysis_rubric: rubric)
      create(
        :analysis_finding,
        analysis_run: run,
        dimension_key: "communication",
        finding_key: "communication.support_signal",
        label: "Other",
        summary: "B",
        confidence: 0.8,
        evidence_refs: { "profile_evidence_ids" => [ 1 ] }
      )
      create(
        :analysis_finding,
        analysis_run: run,
        dimension_key: "strengths_and_motivators",
        finding_key: "strengths_and_motivators.support_signal",
        label: "Strengths first",
        summary: "A",
        confidence: 0.8,
        evidence_refs: { "profile_evidence_ids" => [ 2 ] }
      )

      titles = described_class.new(child_profile).parent_analysis_rows.map(&:title)

      expect(titles.first).to eq("Strengths first")
    end
  end

  describe "#profile_ready?" do
    it "is true when a persisted current profile has dimensions" do
      create(:current_profile, child_profile: child_profile, summary: profile_summary)

      expect(described_class.new(child_profile)).to be_profile_ready
    end

    it "is false when the current profile has not been generated" do
      expect(described_class.new(child_profile)).not_to be_profile_ready
    end
  end

  def submitted_response(submitted_at:, processing_status:)
    assessment = create(:assessment, child_profile: child_profile)
    create(
      :assessment_response,
      assessment: assessment,
      submitted_at: submitted_at,
      processing_status: processing_status
    )
  end

  def profile_summary
    {
      "dimensions" => {
        "strengths.interests" => dimension_details("Dinosaurs"),
        "communication.expressive" => dimension_details("Uses short phrases"),
        "sensory.sensitivity" => dimension_details("Sound sensitive"),
        "regulation.recovery" => dimension_details("Needs quiet recovery"),
        "priorities.parent_goal" => dimension_details("Transitions"),
        "medical.medications" => dimension_details("None reported")
      }
    }
  end

  def dimension_details(value)
    {
      "latest_value" => value,
      "confidence" => 0.8,
      "respondent_kind" => "parent_proxy",
      "recorded_at" => Time.current.iso8601
    }
  end
end
