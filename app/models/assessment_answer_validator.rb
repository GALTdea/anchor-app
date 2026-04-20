# frozen_string_literal: true

# Validates +answers+ hash against an AssessmentTemplate +schema+ (version 1 contract).
class AssessmentAnswerValidator
  attr_reader :error_messages

  def initialize(schema:, answers:)
    @schema = (schema || {}).deep_stringify_keys
    @answers = (answers || {}).stringify_keys
    @error_messages = []
  end

  def valid?
    @error_messages = []
    questions = @schema["questions"]
    if questions.blank?
      @error_messages << "schema must define questions"
      return false
    end

    questions.each { |q| validate_question(q.deep_stringify_keys) }
    @error_messages.empty?
  end

  private

  def validate_question(q)
    id = q["id"].to_s
    return if id.blank?

    required = ActiveModel::Type::Boolean.new.cast(q["required"])
    value = @answers[id]
    type = q["type"].to_s

    if required && (value.nil? || value == "")
      @error_messages << "#{id} is required"
      return
    end

    return if value.nil? || value == ""

    case type
    when "scale"
      validate_scale(q, id, value)
    when "textarea", "text"
      @error_messages << "#{id} must be a string" unless value.is_a?(String)
    when "select"
      validate_select(q, id, value)
    else
      @error_messages << "#{id} has unsupported type #{type.inspect}"
    end
  end

  def validate_scale(q, id, value)
    num = Integer(value, exception: false)
    if num.nil?
      @error_messages << "#{id} must be a number"
      return
    end

    min = q["min"]&.to_i
    max = q["max"]&.to_i
    if min && max && (num < min || num > max)
      @error_messages << "#{id} must be between #{min} and #{max}"
    end
  end

  def validate_select(q, id, value)
    allowed = select_allowed_values(q)
    if allowed.blank?
      @error_messages << "#{id} must define options for select"
      return
    end

    @error_messages << "#{id} must be one of the allowed options" unless allowed.include?(value.to_s)
  end

  # Matches AssessmentResponsesHelper#assessment_question_options: options may be
  # plain strings or { "label" => "...", "value" => "..." } hashes.
  def select_allowed_values(q)
    Array(q["options"]).filter_map do |option|
      if option.respond_to?(:stringify_keys)
        normalized = option.stringify_keys
        normalized["value"].presence&.to_s
      elsif option.nil?
        nil
      else
        option.to_s
      end
    end
  end
end
