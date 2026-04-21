# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssessmentSchema::SchemaPredicate do
  def validate(predicate, path: "visible_if")
    validator = described_class.new(predicate, path: path)
    validator.validate!
    validator
  end

  describe "#valid?" do
    it "treats a nil predicate as valid" do
      expect(validate(nil)).to be_valid
    end

    it "accepts a simple equals leaf" do
      predicate = { "question_id" => "stop_start_friction", "equals" => "emotional_collapse" }

      expect(validate(predicate)).to be_valid
    end

    it "accepts an in leaf with a non-empty list" do
      predicate = { "question_id" => "stop_start_friction", "in" => [ "mild", "severe" ] }

      expect(validate(predicate)).to be_valid
    end

    it "accepts an answered leaf with a boolean" do
      predicate = { "question_id" => "stop_start_friction", "answered" => true }

      expect(validate(predicate)).to be_valid
    end

    it "accepts nested all/any/not" do
      predicate = {
        "all" => [
          { "question_id" => "a", "answered" => true },
          {
            "any" => [
              { "question_id" => "b", "equals" => "x" },
              { "not" => { "question_id" => "c", "equals" => "y" } }
            ]
          }
        ]
      }

      expect(validate(predicate)).to be_valid
    end

    it "rejects a non-hash predicate" do
      validator = validate("not a hash")

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/must be an object/))
    end

    it "rejects a leaf without question_id" do
      validator = validate({ "equals" => "x" })

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/unknown shape/))
    end

    it "rejects a leaf with blank question_id" do
      validator = validate({ "question_id" => "", "equals" => "x" })

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/non-blank question_id/))
    end

    it "rejects a leaf without an operator" do
      validator = validate({ "question_id" => "a" })

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/equals, in, answered/))
    end

    it "rejects a leaf with multiple operators" do
      validator = validate({ "question_id" => "a", "equals" => "x", "in" => [ "x" ] })

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/can only include one of/))
    end

    it "rejects an in leaf with an empty array" do
      validator = validate({ "question_id" => "a", "in" => [] })

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/\.in must be a non-empty array/))
    end

    it "rejects an answered leaf with a non-boolean" do
      validator = validate({ "question_id" => "a", "answered" => "yes" })

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/answered must be a boolean/))
    end

    it "rejects an empty all group" do
      validator = validate({ "all" => [] })

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/all must be a non-empty array/))
    end

    it "rejects a non-array any group" do
      validator = validate({ "any" => "nope" })

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/any must be a non-empty array/))
    end

    it "annotates errors with the full path" do
      validator = validate({
        "all" => [
          { "question_id" => "a", "equals" => "x" },
          { "question_id" => "", "equals" => "y" }
        ]
      }, path: "question[foo].visible_if")

      expect(validator).not_to be_valid
      expect(validator.errors).to include(match(/question\[foo\]\.visible_if\.all\[1\]/))
    end
  end

  describe "#referenced_question_ids" do
    it "collects ids from all leaves" do
      predicate = {
        "all" => [
          { "question_id" => "a", "answered" => true },
          { "any" => [
            { "question_id" => "b", "equals" => "x" },
            { "not" => { "question_id" => "c", "equals" => "y" } }
          ] }
        ]
      }

      validator = validate(predicate)

      expect(validator.referenced_question_ids.to_a).to contain_exactly("a", "b", "c")
    end

    it "is empty for a nil predicate" do
      expect(validate(nil).referenced_question_ids).to be_empty
    end

    it "skips blank question_ids" do
      validator = validate({ "question_id" => "", "equals" => "x" })

      expect(validator.referenced_question_ids).to be_empty
    end
  end
end
