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

    it "requires template_key" do
      template = build(:assessment_template, template_key: nil)
      expect(template).not_to be_valid
      expect(template.errors[:template_key]).to be_present
    end

    it "requires version to be a positive integer" do
      template = build(:assessment_template, version: 0)
      expect(template).not_to be_valid
      expect(template.errors[:version]).to be_present
    end

    it "requires template_key to be unique within a version" do
      create(:assessment_template, template_key: "child-onboarding", version: 1)
      duplicate = build(:assessment_template, template_key: "child-onboarding", version: 1)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:template_key]).to be_present
    end

    it "allows a new version for the same template_key" do
      create(:assessment_template, template_key: "child-onboarding", version: 1)
      next_version = build(:assessment_template, template_key: "child-onboarding", version: 2)

      expect(next_version).to be_valid
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

    it "requires published templates to include AI-facing semantics" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "questions" => [
            {
              "id" => "concern_level",
              "label" => "Overall level of concern",
              "type" => "scale",
              "min" => 1,
              "max" => 5,
              "required" => true
            }
          ]
        }
      )

      expect(template).not_to be_valid
      expect(template.errors[:schema]).to be_present
    end

    it "requires unique question ids for published templates" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "questions" => [
            {
              "id" => "duplicate",
              "label" => "Question one",
              "type" => "text",
              "dimension_key" => "regulation.one",
              "concept_key" => "question_one",
              "time_window" => "typical_week",
              "evidence_weight" => 0.5
            },
            {
              "id" => "duplicate",
              "label" => "Question two",
              "type" => "text",
              "dimension_key" => "regulation.two",
              "concept_key" => "question_two",
              "time_window" => "typical_week",
              "evidence_weight" => 0.5
            }
          ]
        }
      )

      expect(template).not_to be_valid
      expect(template.errors[:schema]).to be_present
    end

    it "allows optional runner metadata on published sections and questions" do
      template = build(
        :assessment_template,
        schema: {
          "version" => 1,
          "sections" => [
            {
              "id" => "regulation",
              "title" => "Regulation",
              "description" => "Core regulation questions",
              "transition_title" => "Start here",
              "transition_body" => "We will go one step at a time.",
              "summary_title" => "Quick recap",
              "summary_body" => "Here is what we captured."
            }
          ],
          "questions" => [
            {
              "id" => "concern_level",
              "label" => "Overall level of concern",
              "type" => "scale",
              "section" => "regulation",
              "step_group" => "regulation-core",
              "optional_detail_prompt" => "Add more detail if you want",
              "short_label" => "Concern",
              "progress_label" => "Concern level",
              "placeholder" => "Type here",
              "dimension_key" => "regulation.overall_concern",
              "concept_key" => "overall_concern_level",
              "time_window" => "typical_week",
              "evidence_weight" => 0.8,
              "min" => 1,
              "max" => 5,
              "required" => true
            }
          ]
        }
      )

      expect(template).to be_valid
    end

    describe "visible_if predicates" do
      let(:base_schema) do
        {
          "version" => 1,
          "sections" => [
            { "id" => "core", "title" => "Core" }
          ],
          "questions" => [
            {
              "id" => "trigger",
              "label" => "What's the primary trigger?",
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
              "label" => "How severe is it?",
              "type" => "scale",
              "section" => "core",
              "dimension_key" => "regulation.severity",
              "concept_key" => "trigger_severity",
              "time_window" => "typical_week",
              "evidence_weight" => 0.6,
              "min" => 1,
              "max" => 5
            }
          ]
        }
      end

      it "accepts a question with a valid visible_if predicate" do
        schema = base_schema.deep_dup
        schema["questions"][1]["visible_if"] = {
          "question_id" => "trigger", "equals" => "sensory"
        }

        expect(build(:assessment_template, schema: schema)).to be_valid
      end

      it "accepts a section with a valid visible_if predicate" do
        schema = base_schema.deep_dup
        schema["sections"] << {
          "id" => "sensory_detail",
          "title" => "Sensory detail",
          "visible_if" => { "question_id" => "trigger", "equals" => "sensory" }
        }

        expect(build(:assessment_template, schema: schema)).to be_valid
      end

      it "accepts forward references (visible_if referencing a later question)" do
        schema = base_schema.deep_dup
        schema["questions"][0]["visible_if"] = {
          "question_id" => "severity", "answered" => true
        }

        expect(build(:assessment_template, schema: schema)).to be_valid
      end

      it "accepts nested all/any/not predicates" do
        schema = base_schema.deep_dup
        schema["questions"][1]["visible_if"] = {
          "all" => [
            { "question_id" => "trigger", "answered" => true },
            { "not" => { "question_id" => "trigger", "equals" => "transition" } }
          ]
        }

        expect(build(:assessment_template, schema: schema)).to be_valid
      end

      it "rejects a visible_if referencing an unknown question id" do
        schema = base_schema.deep_dup
        schema["questions"][1]["visible_if"] = {
          "question_id" => "does_not_exist", "equals" => "x"
        }

        template = build(:assessment_template, schema: schema)

        expect(template).not_to be_valid
        expect(template.errors[:schema]).to include(match(/visible_if references unknown question id/))
      end

      it "rejects a malformed visible_if (missing operator)" do
        schema = base_schema.deep_dup
        schema["questions"][1]["visible_if"] = { "question_id" => "trigger" }

        template = build(:assessment_template, schema: schema)

        expect(template).not_to be_valid
        expect(template.errors[:schema]).to include(match(/question\[severity\]\.visible_if/))
      end

      it "rejects a malformed visible_if on a section" do
        schema = base_schema.deep_dup
        schema["sections"] << {
          "id" => "broken",
          "title" => "Broken",
          "visible_if" => { "all" => [] }
        }

        template = build(:assessment_template, schema: schema)

        expect(template).not_to be_valid
        expect(template.errors[:schema]).to include(match(/section\[broken\]\.visible_if\.all must be a non-empty array/))
      end

      it "rejects a visible_if that is not a hash" do
        schema = base_schema.deep_dup
        schema["questions"][1]["visible_if"] = "nope"

        template = build(:assessment_template, schema: schema)

        expect(template).not_to be_valid
        expect(template.errors[:schema]).to include(match(/visible_if must be an object/))
      end

      it "allows visible_if to be omitted entirely" do
        expect(build(:assessment_template, schema: base_schema)).to be_valid
      end

      it "allows visible_if to be explicitly nil" do
        schema = base_schema.deep_dup
        schema["questions"][1]["visible_if"] = nil

        expect(build(:assessment_template, schema: schema)).to be_valid
      end
    end

    it "treats published versions as immutable" do
      template = create(:assessment_template)

      expect(template.update(title: "Updated title")).to be(false)
      expect(template.errors[:base]).to include("published template versions are immutable; create a new version instead")
    end

    it "allows archiving a published template version" do
      template = create(:assessment_template)

      expect(template.update(status: :archived)).to be(true)
    end
  end

  describe ".published" do
    it "returns only published records" do
      published = create(:assessment_template)
      create(:assessment_template, :draft, slug: "draft-only", title: "Draft only")
      expect(described_class.published).to contain_exactly(published)
    end
  end

  describe "#apply_schema_editor_attributes!" do
    it "normalizes draft editor params into schema sections and questions" do
      template = build(:assessment_template, :draft, schema: {})

      template.apply_schema_editor_attributes!(
        schema_version: 2,
        sections_attributes: [
          {
            "id" => "communication",
            "title" => "Communication",
            "description" => "How the child communicates",
            "position" => "1",
            "questions_attributes" => {
              "0" => {
                "id" => "expresses_needs",
                "label" => "How does your child express needs?",
                "type" => "select",
                "required" => "1",
                "options_text" => "Words\nGestures\nMixed",
                "dimension_key" => "communication.expression",
                "concept_key" => "expresses_needs",
                "time_window" => "typical_two_weeks",
                "evidence_weight" => "0.8",
                "position" => "1"
              }
            }
          }
        ]
      )

      expect(template.schema).to eq(
        {
          "version" => 2,
          "sections" => [
            {
              "id" => "communication",
              "title" => "Communication",
              "description" => "How the child communicates",
              "position" => 1
            }
          ],
          "questions" => [
            {
              "id" => "expresses_needs",
              "label" => "How does your child express needs?",
              "type" => "select",
              "required" => true,
              "dimension_key" => "communication.expression",
              "concept_key" => "expresses_needs",
              "time_window" => "typical_two_weeks",
              "evidence_weight" => 0.8,
              "position" => 1,
              "options" => [ "Words", "Gestures", "Mixed" ],
              "section" => "communication"
            }
          ]
        }
      )
    end
  end

  describe "#build_next_version_draft" do
    it "clones a published template into the next draft version" do
      template = create(:assessment_template, slug: "child-onboarding", template_key: "child-onboarding", version: 1)

      next_draft = template.build_next_version_draft

      expect(next_draft).to be_draft
      expect(next_draft.version).to eq(2)
      expect(next_draft.template_key).to eq("child-onboarding")
      expect(next_draft.slug).to eq("child-onboarding-v2-draft")
      expect(next_draft.schema).to eq(template.schema)
      expect(next_draft.respondent_types).to eq(template.respondent_types)
    end
  end
end
