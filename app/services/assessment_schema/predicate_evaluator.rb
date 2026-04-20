# frozen_string_literal: true

module AssessmentSchema
  # Evaluates an AssessmentTemplate schema +visible_if+ predicate against a
  # given answers hash.
  #
  # Predicates are a small declarative DSL serialized into the schema jsonb:
  #
  #   { "question_id" => "x", "equals" => "value" }
  #   { "question_id" => "x", "in" => ["a", "b"] }
  #   { "question_id" => "x", "answered" => true }
  #   { "all" => [<predicate>, ...] }
  #   { "any" => [<predicate>, ...] }
  #   { "not" => <predicate> }
  #
  # Pure function of +answers+: no database access, no state.
  #
  # At runtime, predicates reaching the evaluator are assumed to be well-formed;
  # AssessmentTemplate validation rejects invalid shapes at publish time.
  # Malformed predicates here raise +InvalidPredicate+ so bugs surface loudly
  # rather than silently hiding or showing the wrong questions.
  class PredicateEvaluator
    class InvalidPredicate < StandardError; end

    def initialize(answers)
      @answers = (answers || {}).deep_stringify_keys
    end

    def match?(predicate)
      return true if predicate.nil?
      raise InvalidPredicate, "predicate must be a hash, got #{predicate.class}" unless predicate.is_a?(Hash)

      normalized = predicate.deep_stringify_keys

      if normalized.key?("all")
        evaluate_all(normalized["all"])
      elsif normalized.key?("any")
        evaluate_any(normalized["any"])
      elsif normalized.key?("not")
        !match?(normalized["not"])
      elsif normalized.key?("question_id")
        evaluate_leaf(normalized)
      else
        raise InvalidPredicate, "unknown predicate shape: #{normalized.keys.inspect}"
      end
    end

    private

    def evaluate_all(predicates)
      unless predicates.is_a?(Array) && predicates.any?
        raise InvalidPredicate, "`all` must be a non-empty array"
      end

      predicates.all? { |predicate| match?(predicate) }
    end

    def evaluate_any(predicates)
      unless predicates.is_a?(Array) && predicates.any?
        raise InvalidPredicate, "`any` must be a non-empty array"
      end

      predicates.any? { |predicate| match?(predicate) }
    end

    def evaluate_leaf(predicate)
      question_id = predicate["question_id"].to_s
      raise InvalidPredicate, "leaf predicate must include `question_id`" if question_id.blank?

      answer = @answers[question_id]

      if predicate.key?("equals")
        !answer_blank?(answer) && answer.to_s == predicate["equals"].to_s
      elsif predicate.key?("in")
        values = Array(predicate["in"]).map(&:to_s)
        !answer_blank?(answer) && values.include?(answer.to_s)
      elsif predicate.key?("answered")
        expected = ActiveModel::Type::Boolean.new.cast(predicate["answered"])
        answer_blank?(answer) ? !expected : expected
      else
        raise InvalidPredicate, "leaf predicate must include one of: equals, in, answered"
      end
    end

    def answer_blank?(answer)
      answer.nil? || answer == "" || (answer.respond_to?(:empty?) && answer.empty?)
    end
  end
end
