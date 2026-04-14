require "rails_helper"

RSpec.describe AssessmentRunner do
  describe "#steps" do
    it "builds section intro, grouped question, and summary steps from schema metadata" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "sections" => [
            {
              "id" => "regulation",
              "title" => "Regulation",
              "transition_title" => "Let’s start with regulation",
              "summary_title" => "Regulation recap"
            }
          ],
          "questions" => [
            {
              "id" => "overwhelm_frequency",
              "label" => "How often?",
              "type" => "scale",
              "section" => "regulation",
              "step_group" => "regulation-core",
              "required" => true,
              "min" => 1,
              "max" => 5,
              "position" => 1,
              "dimension_key" => "regulation.overwhelm_frequency",
              "concept_key" => "overwhelm_frequency",
              "time_window" => "current",
              "evidence_weight" => 0.8
            },
            {
              "id" => "recovery_supports",
              "label" => "What helps?",
              "type" => "textarea",
              "section" => "regulation",
              "step_group" => "regulation-core",
              "position" => 2,
              "dimension_key" => "regulation.recovery_supports",
              "concept_key" => "recovery_supports",
              "time_window" => "current",
              "evidence_weight" => 0.6
            }
          ]
        }
      )

      steps = described_class.new(
        template: template,
        answers: { "overwhelm_frequency" => 3, "recovery_supports" => "quiet time" }
      ).steps

      expect(steps.map { |step| step["kind"] }).to eq([ "section_intro", "questions", "section_summary" ])
      expect(steps.first["title"]).to eq("Let’s start with regulation")
      expect(steps.second["question_ids"]).to eq([ "overwhelm_frequency", "recovery_supports" ])
      expect(steps.second["answered"]).to be(true)
      expect(steps.third["title"]).to eq("Regulation recap")
      expect(steps.third["answered"]).to eq(2)
      expect(steps.third["total"]).to eq(2)
    end

    it "adds a fallback questions section when a question has no declared section" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "sections" => [],
          "questions" => [
            {
              "id" => "notes",
              "label" => "Anything else?",
              "type" => "text",
              "dimension_key" => "context.notes",
              "concept_key" => "notes",
              "time_window" => "current",
              "evidence_weight" => 0.2
            }
          ]
        }
      )

      runner = described_class.new(template: template)

      expect(runner.sections.map { |section| section["id"] }).to eq([ "questions" ])
      expect(runner.steps.map { |step| step["kind"] }).to eq([ "section_intro", "questions", "section_summary" ])
    end
  end
end
