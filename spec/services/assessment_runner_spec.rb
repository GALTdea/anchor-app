require "rails_helper"

RSpec.describe AssessmentRunner do
  describe "#steps" do
    it "builds one step per question and ignores step_group" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "sections" => [
            {
              "id" => "regulation",
              "title" => "Regulation",
              "transition_title" => "Let's start with regulation",
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

      expect(steps.map { |step| step["kind"] }).to eq([ "questions", "questions" ])
      expect(steps.map { |step| step["id"] }).to eq([ "q-overwhelm_frequency", "q-recovery_supports" ])
      expect(steps.map { |step| step["question_ids"] }).to eq([
        [ "overwhelm_frequency" ],
        [ "recovery_supports" ]
      ])
      expect(steps.map { |step| step["answered"] }).to eq([ true, true ])
      expect(steps.first["section_title"]).to eq("Regulation")
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
      expect(runner.steps.map { |step| step["kind"] }).to eq([ "questions" ])
      expect(runner.steps.map { |step| step["id"] }).to eq([ "q-notes" ])
    end
  end

  describe "visible_if filtering" do
    let(:base_schema) do
      {
        "version" => 1,
        "sections" => [
          { "id" => "core", "title" => "Core" },
          {
            "id" => "sensory_detail",
            "title" => "Sensory detail",
            "visible_if" => { "question_id" => "trigger", "equals" => "sensory" }
          }
        ],
        "questions" => [
          {
            "id" => "trigger",
            "label" => "Primary trigger?",
            "type" => "select",
            "section" => "core",
            "dimension_key" => "regulation.trigger",
            "concept_key" => "primary_trigger",
            "time_window" => "typical_week",
            "evidence_weight" => 0.7,
            "options" => [ "sensory", "social", "transition" ]
          },
          {
            "id" => "severity",
            "label" => "Severity?",
            "type" => "scale",
            "section" => "core",
            "dimension_key" => "regulation.severity",
            "concept_key" => "trigger_severity",
            "time_window" => "typical_week",
            "evidence_weight" => 0.6,
            "min" => 1,
            "max" => 5,
            "visible_if" => { "question_id" => "trigger", "answered" => true }
          },
          {
            "id" => "sensory_specifics",
            "label" => "Sensory specifics?",
            "type" => "textarea",
            "section" => "sensory_detail",
            "dimension_key" => "regulation.sensory_specifics",
            "concept_key" => "sensory_specifics",
            "time_window" => "typical_week",
            "evidence_weight" => 0.5
          }
        ]
      }
    end

    it "includes questions without visible_if" do
      template = build(:assessment_template, schema: base_schema)
      runner = described_class.new(template: template, answers: {})

      expect(runner.active_question_ids).to include("trigger")
    end

    it "includes questions whose visible_if predicate matches" do
      template = build(:assessment_template, schema: base_schema)
      runner = described_class.new(template: template, answers: { "trigger" => "sensory" })

      expect(runner.active_question_ids).to include("trigger", "severity")
    end

    it "excludes questions whose visible_if predicate does not match" do
      template = build(:assessment_template, schema: base_schema)
      runner = described_class.new(template: template, answers: {})

      expect(runner.active_question_ids).not_to include("severity")
    end

    it "excludes sections whose visible_if predicate does not match" do
      template = build(:assessment_template, schema: base_schema)
      runner = described_class.new(template: template, answers: { "trigger" => "social" })

      expect(runner.sections.map { |s| s["id"] }).not_to include("sensory_detail")
    end

    it "includes sections whose visible_if predicate matches" do
      template = build(:assessment_template, schema: base_schema)
      runner = described_class.new(template: template, answers: { "trigger" => "sensory" })

      expect(runner.sections.map { |s| s["id"] }).to include("sensory_detail")
      expect(runner.active_question_ids).to include("sensory_specifics")
    end

    it "generates steps only for visible questions" do
      template = build(:assessment_template, schema: base_schema)
      runner = described_class.new(template: template, answers: {})

      expect(runner.steps.map { |s| s["id"] }).to eq([ "q-trigger" ])
    end

    it "updates steps when answers change to reveal new questions" do
      template = build(:assessment_template, schema: base_schema)
      runner_before = described_class.new(template: template, answers: {})
      runner_after = described_class.new(template: template, answers: { "trigger" => "sensory" })

      expect(runner_before.steps.map { |s| s["id"] }).to eq([ "q-trigger" ])
      expect(runner_after.steps.map { |s| s["id"] }).to eq([ "q-trigger", "q-severity", "q-sensory_specifics" ])
    end

    it "generates one step per visible question, ignoring step_group" do
      schema = base_schema.deep_dup
      schema["questions"][1]["step_group"] = "grouped"
      schema["questions"] << {
        "id" => "extra",
        "label" => "Extra?",
        "type" => "text",
        "section" => "core",
        "step_group" => "grouped",
        "dimension_key" => "regulation.extra",
        "concept_key" => "extra",
        "time_window" => "typical_week",
        "evidence_weight" => 0.3,
        "visible_if" => { "question_id" => "trigger", "answered" => true }
      }

      template = build(:assessment_template, schema: schema)
      runner = described_class.new(template: template, answers: { "trigger" => "sensory" })

      severity_step = runner.steps.find { |s| s["question_ids"] == [ "severity" ] }
      extra_step = runner.steps.find { |s| s["question_ids"] == [ "extra" ] }

      expect(severity_step["id"]).to eq("q-severity")
      expect(extra_step["id"]).to eq("q-extra")
      expect(runner.steps.map { |s| s["question_ids"].size }).to all(eq(1))
    end
  end

  describe "#active_question_ids" do
    it "returns all visible question ids" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "questions" => [
            {
              "id" => "a",
              "label" => "A",
              "type" => "text",
              "dimension_key" => "d.a",
              "concept_key" => "a",
              "time_window" => "current",
              "evidence_weight" => 0.5
            },
            {
              "id" => "b",
              "label" => "B",
              "type" => "text",
              "dimension_key" => "d.b",
              "concept_key" => "b",
              "time_window" => "current",
              "evidence_weight" => 0.5,
              "visible_if" => { "question_id" => "a", "answered" => true }
            }
          ]
        }
      )

      runner_without = described_class.new(template: template, answers: {})
      runner_with = described_class.new(template: template, answers: { "a" => "yes" })

      expect(runner_without.active_question_ids).to eq([ "a" ])
      expect(runner_with.active_question_ids).to eq([ "a", "b" ])
    end
  end

  describe "#section_progress_for" do
    let(:template) do
      build(
        :assessment_template,
        schema: {
          "version" => 1,
          "sections" => [
            { "id" => "communication", "title" => "Communication" },
            { "id" => "regulation", "title" => "Regulation" }
          ],
          "questions" => [
            {
              "id" => "comm_one",
              "label" => "C1",
              "type" => "text",
              "section" => "communication",
              "dimension_key" => "d.c1",
              "concept_key" => "c1",
              "time_window" => "current",
              "evidence_weight" => 0.5
            },
            {
              "id" => "comm_two",
              "label" => "C2",
              "type" => "text",
              "section" => "communication",
              "dimension_key" => "d.c2",
              "concept_key" => "c2",
              "time_window" => "current",
              "evidence_weight" => 0.5
            },
            {
              "id" => "reg_one",
              "label" => "R1",
              "type" => "text",
              "section" => "regulation",
              "dimension_key" => "d.r1",
              "concept_key" => "r1",
              "time_window" => "current",
              "evidence_weight" => 0.5
            }
          ]
        }
      )
    end

    it "returns 1-based index and total within the step's section" do
      runner = described_class.new(template: template, answers: {})

      expect(runner.section_progress_for("q-comm_one")).to eq(index: 1, total: 2)
      expect(runner.section_progress_for("q-comm_two")).to eq(index: 2, total: 2)
      expect(runner.section_progress_for("q-reg_one")).to eq(index: 1, total: 1)
    end

    it "accepts a step hash as well as a step id" do
      runner = described_class.new(template: template, answers: {})
      step = runner.current_step("q-comm_two")

      expect(runner.section_progress_for(step)).to eq(index: 2, total: 2)
    end

    it "reflects branching-hidden questions in the section total" do
      branching_template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "sections" => [ { "id" => "core", "title" => "Core" } ],
          "questions" => [
            {
              "id" => "first",
              "label" => "First",
              "type" => "select",
              "section" => "core",
              "options" => [ "yes", "no" ],
              "dimension_key" => "d.first",
              "concept_key" => "first",
              "time_window" => "current",
              "evidence_weight" => 0.5
            },
            {
              "id" => "follow_up",
              "label" => "Follow up",
              "type" => "text",
              "section" => "core",
              "dimension_key" => "d.follow",
              "concept_key" => "follow",
              "time_window" => "current",
              "evidence_weight" => 0.5,
              "visible_if" => { "question_id" => "first", "equals" => "yes" }
            }
          ]
        }
      )

      without_follow = described_class.new(template: branching_template, answers: { "first" => "no" })
      with_follow = described_class.new(template: branching_template, answers: { "first" => "yes" })

      expect(without_follow.section_progress_for("q-first")).to eq(index: 1, total: 1)
      expect(with_follow.section_progress_for("q-first")).to eq(index: 1, total: 2)
      expect(with_follow.section_progress_for("q-follow_up")).to eq(index: 2, total: 2)
    end

    it "returns nil for an unknown step id" do
      runner = described_class.new(template: template, answers: {})

      expect(runner.section_progress_for("q-nonexistent")).to be_nil
      expect(runner.section_progress_for(nil)).to be_nil
    end
  end

  describe "#current_step" do
    let(:template) do
      build(
        :assessment_template,
        schema: {
          "version" => 1,
          "questions" => [
            {
              "id" => "first",
              "label" => "First",
              "type" => "text",
              "dimension_key" => "d.first",
              "concept_key" => "first",
              "time_window" => "current",
              "evidence_weight" => 0.5
            },
            {
              "id" => "second",
              "label" => "Second",
              "type" => "text",
              "dimension_key" => "d.second",
              "concept_key" => "second",
              "time_window" => "current",
              "evidence_weight" => 0.5
            }
          ]
        }
      )
    end

    it "returns the requested step when the id is valid" do
      runner = described_class.new(template: template, answers: {})
      step = runner.current_step("q-second")

      expect(step["id"]).to eq("q-second")
    end

    it "returns the default step when the id is unknown" do
      runner = described_class.new(template: template, answers: {})
      step = runner.current_step("q-nonexistent")

      expect(step["id"]).to eq("q-first")
    end

    it "returns the default step when the id is nil" do
      runner = described_class.new(template: template, answers: {})
      step = runner.current_step(nil)

      expect(step["id"]).to eq("q-first")
    end

    it "tolerates legacy positional step ids by falling back to default" do
      runner = described_class.new(template: template, answers: {})
      step = runner.current_step("section-questions-step-1")

      expect(step["id"]).to eq("q-first")
    end
  end
end
