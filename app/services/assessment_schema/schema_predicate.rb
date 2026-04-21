# frozen_string_literal: true

module AssessmentSchema
  # Static validation of a +visible_if+ predicate tree.
  #
  # Walks the predicate without requiring answers, accumulating two pieces
  # of information:
  #
  # * +errors+ — a list of human-readable messages, each already prefixed
  #   with a path like +"section[transitions].visible_if.all[0]"+ so callers
  #   can surface them with context.
  # * +referenced_question_ids+ — the set of question ids appearing in any
  #   leaf node, so callers can cross-check them against the template.
  #
  # Use +AssessmentSchema::PredicateEvaluator+ when evaluating predicates at
  # runtime; use this class when validating shape at publish time.
  class SchemaPredicate
    VALID_LEAF_OPERATORS = %w[equals in answered].freeze

    attr_reader :errors, :referenced_question_ids

    def initialize(predicate, path: "visible_if")
      @predicate = predicate
      @path = path
      @errors = []
      @referenced_question_ids = Set.new
      @validated = false
    end

    def valid?
      validate! unless @validated
      @errors.empty?
    end

    def validate!
      return if @validated

      @validated = true
      walk(@predicate, path: @path)
    end

    private

    def walk(predicate, path:)
      return if predicate.nil?

      unless predicate.is_a?(Hash)
        @errors << "#{path} must be an object"
        return
      end

      normalized = predicate.deep_stringify_keys

      if normalized.key?("all")
        walk_group(normalized["all"], operator: "all", path: path)
      elsif normalized.key?("any")
        walk_group(normalized["any"], operator: "any", path: path)
      elsif normalized.key?("not")
        walk(normalized["not"], path: "#{path}.not")
      elsif normalized.key?("question_id")
        walk_leaf(normalized, path: path)
      else
        @errors << "#{path} has an unknown shape (keys: #{normalized.keys.inspect}); must include one of: question_id, all, any, not"
      end
    end

    def walk_group(items, operator:, path:)
      unless items.is_a?(Array) && items.any?
        @errors << "#{path}.#{operator} must be a non-empty array"
        return
      end

      items.each_with_index do |item, index|
        walk(item, path: "#{path}.#{operator}[#{index}]")
      end
    end

    def walk_leaf(predicate, path:)
      question_id = predicate["question_id"].to_s
      if question_id.blank?
        @errors << "#{path} must include a non-blank question_id"
      else
        @referenced_question_ids << question_id
      end

      present_ops = VALID_LEAF_OPERATORS & predicate.keys

      if present_ops.empty?
        @errors << "#{path} must include one of: #{VALID_LEAF_OPERATORS.join(', ')}"
        return
      elsif present_ops.size > 1
        @errors << "#{path} can only include one of: #{VALID_LEAF_OPERATORS.join(', ')} (got: #{present_ops.join(', ')})"
        return
      end

      case present_ops.first
      when "in"
        values = predicate["in"]
        unless values.is_a?(Array) && values.any?
          @errors << "#{path}.in must be a non-empty array"
        end
      when "answered"
        value = predicate["answered"]
        unless [ true, false ].include?(value)
          @errors << "#{path}.answered must be a boolean"
        end
      end
    end
  end
end
