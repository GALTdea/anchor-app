require "rails_helper"

RSpec.describe AssessmentResponsesHelper, type: :helper do
  describe "#assessment_sections" do
    it "groups questions into declared sections" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "sections" => [
            { "id" => "regulation", "title" => "Regulation" },
            { "id" => "sensory", "title" => "Sensory" }
          ],
          "questions" => [
            {
              "id" => "recovery",
              "label" => "Recovery",
              "type" => "scale",
              "section" => "regulation",
              "required" => true,
              "min" => 1,
              "max" => 5,
              "dimension_key" => "regulation.recovery",
              "concept_key" => "recovery_time",
              "time_window" => "current",
              "evidence_weight" => 0.6
            },
            {
              "id" => "noise",
              "label" => "Noise",
              "type" => "text",
              "section" => "sensory",
              "required" => false,
              "dimension_key" => "sensory.auditory",
              "concept_key" => "noise_response",
              "time_window" => "current",
              "evidence_weight" => 0.5
            }
          ]
        }
      )

      sections = helper.assessment_sections(template)

      expect(sections.map { |section| section["title"] }).to eq([ "Regulation", "Sensory" ])
      expect(sections.first["questions"].map { |question| question["id"] }).to eq([ "recovery" ])
      expect(sections.second["questions"].map { |question| question["id"] }).to eq([ "noise" ])
    end
  end

  describe "#assessment_progress" do
    it "counts answered questions and calculates percentage" do
      template = create(:assessment_template)
      answers = { "concern_level" => 3, "notes" => "" }

      progress = helper.assessment_progress(template, answers)

      expect(progress).to eq(answered: 1, total: 2, percentage: 50)
    end
  end

  describe "#assessment_runner_steps" do
    it "delegates to the assessment runner and returns ordered steps" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "sections" => [
            { "id" => "regulation", "title" => "Regulation" }
          ],
          "questions" => [
            {
              "id" => "recovery",
              "label" => "Recovery",
              "type" => "scale",
              "section" => "regulation",
              "required" => true,
              "min" => 1,
              "max" => 5,
              "dimension_key" => "regulation.recovery",
              "concept_key" => "recovery_time",
              "time_window" => "current",
              "evidence_weight" => 0.6
            }
          ]
        }
      )

      steps = helper.assessment_runner_steps(template, answers: { "recovery" => 4 })

      expect(steps.map { |step| step["kind"] }).to eq([ "section_intro", "questions", "section_summary" ])
      expect(steps.second["question_ids"]).to eq([ "recovery" ])
      expect(steps.second["answered"]).to be(true)
    end
  end

  describe "#assessment_answer_display" do
    it "renders the label for select answers stored by value" do
      question = {
        "id" => "support_style",
        "label" => "Support style",
        "type" => "select",
        "options" => [
          { "value" => "quiet_space", "label" => "Quiet space" }
        ]
      }

      expect(helper.assessment_answer_display(question, "quiet_space")).to eq("Quiet space")
    end
  end
end
