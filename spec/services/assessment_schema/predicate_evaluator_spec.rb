# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssessmentSchema::PredicateEvaluator do
  subject(:evaluator) { described_class.new(answers) }

  let(:answers) do
    {
      "expression_of_needs" => "frustration_based",
      "routine_predictability" => "high_rigidity",
      "blank_answer" => "",
      "nil_answer" => nil,
      "empty_array" => []
    }
  end

  describe "#match?" do
    context "when predicate is nil" do
      it "returns true (no restriction)" do
        expect(evaluator.match?(nil)).to be true
      end
    end

    context "when predicate is not a hash" do
      it "raises InvalidPredicate" do
        expect { evaluator.match?("not a hash") }.to raise_error(described_class::InvalidPredicate)
      end
    end

    context "with an unknown top-level shape" do
      it "raises InvalidPredicate" do
        expect { evaluator.match?({ "what" => "is this" }) }.to raise_error(described_class::InvalidPredicate, /unknown predicate shape/)
      end
    end

    describe "equals operator" do
      it "matches when the answer equals the expected value" do
        predicate = { "question_id" => "expression_of_needs", "equals" => "frustration_based" }
        expect(evaluator.match?(predicate)).to be true
      end

      it "does not match when the answer differs" do
        predicate = { "question_id" => "expression_of_needs", "equals" => "scripting" }
        expect(evaluator.match?(predicate)).to be false
      end

      it "does not match when the answer is blank" do
        predicate = { "question_id" => "blank_answer", "equals" => "" }
        expect(evaluator.match?(predicate)).to be false
      end

      it "does not match when the answer is nil" do
        predicate = { "question_id" => "nil_answer", "equals" => "anything" }
        expect(evaluator.match?(predicate)).to be false
      end

      it "does not match when the referenced question has no recorded answer" do
        predicate = { "question_id" => "missing_question", "equals" => "anything" }
        expect(evaluator.match?(predicate)).to be false
      end

      it "compares as strings (supports numeric answers from scale questions)" do
        answers["rating"] = 4
        predicate = { "question_id" => "rating", "equals" => "4" }
        expect(evaluator.match?(predicate)).to be true
      end
    end

    describe "in operator" do
      it "matches when the answer is in the allowed list" do
        predicate = { "question_id" => "expression_of_needs", "in" => %w[frustration_based hand_leading] }
        expect(evaluator.match?(predicate)).to be true
      end

      it "does not match when the answer is not in the list" do
        predicate = { "question_id" => "expression_of_needs", "in" => %w[scripting joint_attention_pointing] }
        expect(evaluator.match?(predicate)).to be false
      end

      it "does not match when the answer is blank" do
        predicate = { "question_id" => "blank_answer", "in" => [ "", "something" ] }
        expect(evaluator.match?(predicate)).to be false
      end

      it "does not match when the answer is nil" do
        predicate = { "question_id" => "nil_answer", "in" => %w[a b] }
        expect(evaluator.match?(predicate)).to be false
      end
    end

    describe "answered operator" do
      it "matches when the question has a non-blank answer and answered: true" do
        predicate = { "question_id" => "expression_of_needs", "answered" => true }
        expect(evaluator.match?(predicate)).to be true
      end

      it "does not match when the question is unanswered and answered: true" do
        predicate = { "question_id" => "nil_answer", "answered" => true }
        expect(evaluator.match?(predicate)).to be false
      end

      it "matches when the question has a blank string answer and answered: false" do
        predicate = { "question_id" => "blank_answer", "answered" => false }
        expect(evaluator.match?(predicate)).to be true
      end

      it "matches when the question has an empty array answer and answered: false" do
        predicate = { "question_id" => "empty_array", "answered" => false }
        expect(evaluator.match?(predicate)).to be true
      end

      it "does not match when the question has a non-blank answer and answered: false" do
        predicate = { "question_id" => "expression_of_needs", "answered" => false }
        expect(evaluator.match?(predicate)).to be false
      end
    end

    describe "all operator" do
      it "matches when every sub-predicate matches" do
        predicate = {
          "all" => [
            { "question_id" => "expression_of_needs", "equals" => "frustration_based" },
            { "question_id" => "routine_predictability", "equals" => "high_rigidity" }
          ]
        }
        expect(evaluator.match?(predicate)).to be true
      end

      it "does not match when any sub-predicate fails" do
        predicate = {
          "all" => [
            { "question_id" => "expression_of_needs", "equals" => "frustration_based" },
            { "question_id" => "routine_predictability", "equals" => "low_awareness" }
          ]
        }
        expect(evaluator.match?(predicate)).to be false
      end

      it "raises on an empty array" do
        expect { evaluator.match?({ "all" => [] }) }.to raise_error(described_class::InvalidPredicate)
      end

      it "raises when not an array" do
        expect { evaluator.match?({ "all" => "not an array" }) }.to raise_error(described_class::InvalidPredicate)
      end
    end

    describe "any operator" do
      it "matches when any sub-predicate matches" do
        predicate = {
          "any" => [
            { "question_id" => "expression_of_needs", "equals" => "scripting" },
            { "question_id" => "routine_predictability", "equals" => "high_rigidity" }
          ]
        }
        expect(evaluator.match?(predicate)).to be true
      end

      it "does not match when all sub-predicates fail" do
        predicate = {
          "any" => [
            { "question_id" => "expression_of_needs", "equals" => "scripting" },
            { "question_id" => "routine_predictability", "equals" => "low_awareness" }
          ]
        }
        expect(evaluator.match?(predicate)).to be false
      end

      it "raises on an empty array" do
        expect { evaluator.match?({ "any" => [] }) }.to raise_error(described_class::InvalidPredicate)
      end
    end

    describe "not operator" do
      it "inverts a matching predicate" do
        predicate = { "not" => { "question_id" => "expression_of_needs", "equals" => "frustration_based" } }
        expect(evaluator.match?(predicate)).to be false
      end

      it "inverts a non-matching predicate" do
        predicate = { "not" => { "question_id" => "expression_of_needs", "equals" => "scripting" } }
        expect(evaluator.match?(predicate)).to be true
      end
    end

    describe "composition" do
      it "evaluates nested all/any/not correctly" do
        predicate = {
          "all" => [
            { "question_id" => "expression_of_needs", "answered" => true },
            {
              "any" => [
                { "question_id" => "routine_predictability", "equals" => "high_rigidity" },
                { "question_id" => "routine_predictability", "equals" => "low_awareness" }
              ]
            },
            { "not" => { "question_id" => "expression_of_needs", "equals" => "scripting" } }
          ]
        }
        expect(evaluator.match?(predicate)).to be true
      end

      it "short-circuits a failing nested branch" do
        predicate = {
          "all" => [
            { "question_id" => "expression_of_needs", "equals" => "scripting" },
            { "any" => [ { "question_id" => "routine_predictability", "equals" => "high_rigidity" } ] }
          ]
        }
        expect(evaluator.match?(predicate)).to be false
      end
    end

    describe "leaf validation" do
      it "raises when question_id is blank" do
        expect { evaluator.match?({ "question_id" => "", "equals" => "x" }) }.to raise_error(described_class::InvalidPredicate)
      end

      it "raises when no operator is present" do
        expect { evaluator.match?({ "question_id" => "expression_of_needs" }) }.to raise_error(described_class::InvalidPredicate, /one of: equals, in, answered/)
      end
    end

    describe "key normalization" do
      it "accepts symbol keys at the top level" do
        predicate = { question_id: "expression_of_needs", equals: "frustration_based" }
        expect(evaluator.match?(predicate)).to be true
      end

      it "accepts symbol keys in nested predicates" do
        predicate = {
          all: [
            { question_id: "expression_of_needs", equals: "frustration_based" }
          ]
        }
        expect(evaluator.match?(predicate)).to be true
      end
    end

    describe "answer key normalization" do
      it "accepts symbol-keyed answers" do
        symbol_evaluator = described_class.new(expression_of_needs: "frustration_based")
        predicate = { "question_id" => "expression_of_needs", "equals" => "frustration_based" }
        expect(symbol_evaluator.match?(predicate)).to be true
      end

      it "treats nil answers as empty" do
        nil_evaluator = described_class.new(nil)
        predicate = { "question_id" => "expression_of_needs", "answered" => false }
        expect(nil_evaluator.match?(predicate)).to be true
      end
    end
  end
end
