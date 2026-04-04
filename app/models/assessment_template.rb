# frozen_string_literal: true

require "set"

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
class AssessmentTemplate < ApplicationRecord
  include AssessmentRespondentKinds

  IMMUTABLE_FIELDS = %w[
    title
    slug
    category
    schema
    respondent_types
    template_key
    version
  ].freeze
  REQUIRED_QUESTION_FIELDS = %w[id label type dimension_key concept_key time_window].freeze
  OPTIONAL_STRING_QUESTION_FIELDS = %w[section help_text extraction_hint units polarity].freeze
  SUPPORTED_QUESTION_TYPES = %w[scale textarea text select].freeze

  enum :status, { draft: 0, published: 1, archived: 2 }, default: :draft

  validates :title, :slug, :template_key, presence: true
  validates :slug, uniqueness: true
  validates :template_key, uniqueness: { scope: :version }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validate :published_templates_have_valid_respondent_types, if: :published?
  validate :published_templates_have_valid_schema_contract, if: :published?
  validate :published_templates_are_immutable, on: :update

  scope :published, -> { where(status: :published) }

  def question_ids
    Array(schema&.dig("questions")).filter_map { |q| q["id"].presence }.map(&:to_s)
  end

  private

  def published_templates_have_valid_respondent_types
    types = respondent_types
    unless types.is_a?(Array) && types.present?
      errors.add(:respondent_types, "must be a non-empty array for published templates")
      return
    end

    invalid = types.reject { |k| CANONICAL.include?(k.to_s) }
    return if invalid.empty?

    errors.add(:respondent_types, "contains invalid values: #{invalid.join(', ')}")
  end

  def published_templates_have_valid_schema_contract
    unless schema.is_a?(Hash)
      errors.add(:schema, "must be an object")
      return
    end

    schema_hash = schema.deep_stringify_keys

    schema_version = Integer(schema_hash["version"], exception: false)
    if schema_version.nil? || schema_version <= 0
      errors.add(:schema, "must include a positive integer version")
    end

    questions = schema_hash["questions"]
    unless questions.is_a?(Array) && questions.present?
      errors.add(:schema, "must include a non-empty questions array for published templates")
      return
    end

    section_ids = validate_sections(schema_hash["sections"])
    seen_ids = Set.new

    questions.each_with_index do |question, index|
      validate_question(question, index, section_ids, seen_ids)
    end
  end

  def validate_sections(sections)
    return Set.new unless sections.present?

    unless sections.is_a?(Array)
      errors.add(:schema, "sections must be an array when present")
      return Set.new
    end

    seen_ids = Set.new

    sections.each_with_index do |section, index|
      unless section.is_a?(Hash)
        errors.add(:schema, "section #{index + 1} must be an object")
        next
      end

      section = section.deep_stringify_keys
      section_id = section["id"].to_s
      title = section["title"].to_s

      errors.add(:schema, "section #{index + 1} must include an id") if section_id.blank?
      errors.add(:schema, "section #{section_id.presence || index + 1} must include a title") if title.blank?

      next if section_id.blank?

      if seen_ids.include?(section_id)
        errors.add(:schema, "section ids must be unique (duplicate #{section_id})")
      else
        seen_ids << section_id
      end
    end

    seen_ids
  end

  def validate_question(question, index, section_ids, seen_ids)
    unless question.is_a?(Hash)
      errors.add(:schema, "question #{index + 1} must be an object")
      return
    end

    question = question.deep_stringify_keys
    question_id = question["id"].to_s

    REQUIRED_QUESTION_FIELDS.each do |field|
      errors.add(:schema, "question #{index + 1} must include #{field}") if question[field].to_s.blank?
    end

    if question_id.present?
      if seen_ids.include?(question_id)
        errors.add(:schema, "question ids must be unique (duplicate #{question_id})")
      else
        seen_ids << question_id
      end
    end

    type = question["type"].to_s
    unless SUPPORTED_QUESTION_TYPES.include?(type)
      errors.add(:schema, "question #{question_id.presence || index + 1} has unsupported type #{type.inspect}")
      return
    end

    OPTIONAL_STRING_QUESTION_FIELDS.each do |field|
      next unless question.key?(field)
      next if question[field].is_a?(String)

      errors.add(:schema, "question #{question_id.presence || index + 1} #{field} must be a string")
    end

    if section_ids.present? && question["section"].present? && !section_ids.include?(question["section"].to_s)
      errors.add(:schema, "question #{question_id.presence || index + 1} references unknown section #{question['section']}")
    end

    validate_question_evidence_weight(question, question_id, index)
    validate_question_type_config(question, question_id, index)
  end

  def validate_question_evidence_weight(question, question_id, index)
    weight = Float(question["evidence_weight"], exception: false)
    if weight.nil? || weight <= 0 || weight > 1
      errors.add(:schema, "question #{question_id.presence || index + 1} evidence_weight must be a number between 0 and 1")
    end
  end

  def validate_question_type_config(question, question_id, index)
    case question["type"].to_s
    when "scale"
      min = Integer(question["min"], exception: false)
      max = Integer(question["max"], exception: false)

      if min.nil? || max.nil?
        errors.add(:schema, "question #{question_id.presence || index + 1} scale questions must define integer min and max")
      elsif min >= max
        errors.add(:schema, "question #{question_id.presence || index + 1} scale min must be less than max")
      end
    when "select"
      options = Array(question["options"]).map(&:to_s).reject(&:blank?)
      errors.add(:schema, "question #{question_id.presence || index + 1} select questions must define options") if options.blank?
    end
  end

  def published_templates_are_immutable
    return unless immutable_version_record?

    changed_fields = IMMUTABLE_FIELDS.select { |field| will_save_change_to_attribute?(field) }
    return if changed_fields.empty?

    errors.add(:base, "published template versions are immutable; create a new version instead")
  end

  def immutable_version_record?
    persisted? && %w[published archived].include?(attribute_in_database("status"))
  end
end
