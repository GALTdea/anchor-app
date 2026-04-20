# frozen_string_literal: true

require "rails_helper"

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
end
