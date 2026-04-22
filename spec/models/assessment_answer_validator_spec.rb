# frozen_string_literal: true

require "ostruct"
require "rails_helper"
require Rails.root.join("spec/support/friction_transition_schema")

RSpec.describe AssessmentAnswerValidator do
  let(:schema) do
    {
      "version" => 1,
      "sections" => [ { "id" => "s1", "title" => "Section" } ],
      "questions" => [
        {
          "id" => "hash_select",
          "type" => "select",
          "section" => "s1",
          "required" => true,
          "options" => [
            { "label" => "One", "value" => "one" },
            { "label" => "Two", "value" => "two" }
          ]
        },
        {
          "id" => "string_select",
          "type" => "select",
          "section" => "s1",
          "required" => true,
          "options" => %w[alpha beta]
        },
        {
          "id" => "optional_hash_select",
          "type" => "select",
          "section" => "s1",
          "required" => false,
          "options" => [ { "label" => "X", "value" => "x" } ]
        }
      ]
    }
  end

  it "accepts select values that match hash option value keys" do
    validator = described_class.new(
      schema: schema,
      answers: { "hash_select" => "one", "string_select" => "alpha" }
    )
    expect(validator).to be_valid
  end

  it "rejects select values not in hash option values" do
    validator = described_class.new(
      schema: schema,
      answers: { "hash_select" => "nope", "string_select" => "alpha" }
    )
    expect(validator).not_to be_valid
    expect(validator.error_messages).to include("hash_select must be one of the allowed options")
  end

  it "accepts plain-string select options" do
    validator = described_class.new(
      schema: schema,
      answers: { "hash_select" => "one", "string_select" => "beta" }
    )
    expect(validator).to be_valid
  end

  it "treats blank optional select as valid" do
    validator = described_class.new(
      schema: schema,
      answers: { "hash_select" => "one", "string_select" => "alpha", "optional_hash_select" => "" }
    )
    expect(validator).to be_valid
  end

  it "reports missing required answers" do
    validator = described_class.new(schema: schema, answers: {})
    expect(validator).not_to be_valid
    expect(validator.error_messages).to include("hash_select is required")
    expect(validator.error_messages).to include("string_select is required")
  end

  describe "active_question_ids" do
    it "validates every question when active_question_ids is nil (default)" do
      validator = described_class.new(schema: schema, answers: {})
      expect(validator).not_to be_valid
      expect(validator.error_messages).to include("hash_select is required", "string_select is required")
    end

    it "skips required-field checks for inactive questions" do
      validator = described_class.new(
        schema: schema,
        answers: { "hash_select" => "one" },
        active_question_ids: [ "hash_select" ]
      )

      expect(validator).to be_valid
    end

    it "still reports required-field errors for active questions" do
      validator = described_class.new(
        schema: schema,
        answers: {},
        active_question_ids: [ "hash_select" ]
      )

      expect(validator).not_to be_valid
      expect(validator.error_messages).to contain_exactly("hash_select is required")
    end

    it "skips type/value checks for inactive questions" do
      validator = described_class.new(
        schema: schema,
        answers: { "hash_select" => "one", "string_select" => "not_in_options" },
        active_question_ids: [ "hash_select" ]
      )

      expect(validator).to be_valid
    end

    it "accepts a Set of ids" do
      validator = described_class.new(
        schema: schema,
        answers: { "hash_select" => "one" },
        active_question_ids: Set.new([ "hash_select" ])
      )

      expect(validator).to be_valid
    end

    it "normalizes ids to strings" do
      validator = described_class.new(
        schema: schema,
        answers: { "hash_select" => "one" },
        active_question_ids: [ :hash_select ]
      )

      expect(validator).to be_valid
    end

    it "treats an empty active set as 'validate nothing'" do
      validator = described_class.new(
        schema: schema,
        answers: {},
        active_question_ids: []
      )

      expect(validator).to be_valid
    end
  end

  describe "seed-shaped stop_start_friction / transition_recovery (Stage 4.8 Step 9)" do
    it "does not require transition_recovery_time when the branch is hidden" do
      answers = {
        "stop_start_friction" => "stalling",
        "friction_closing" => ""
      }
      runner = AssessmentRunner.new(
        template: OpenStruct.new(schema: FRICTION_TRANSITION_E2E_SCHEMA),
        answers: answers
      )

      validator = described_class.new(
        schema: FRICTION_TRANSITION_E2E_SCHEMA,
        answers: answers,
        active_question_ids: runner.active_question_ids
      )

      expect(validator).to be_valid
    end
  end
end
