# frozen_string_literal: true

require "set"
require "json"

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
  OPTIONAL_STRING_QUESTION_FIELDS = %w[
    section
    help_text
    extraction_hint
    units
    polarity
    placeholder
    step_group
    optional_detail_prompt
    short_label
    progress_label
  ].freeze
  OPTIONAL_SECTION_STRING_FIELDS = %w[
    description
    transition_title
    transition_body
    summary_title
    summary_body
  ].freeze
  EDITOR_SECTION_FIELDS = %w[id title description].freeze
  EDITOR_QUESTION_STRING_FIELDS = %w[
    id
    label
    type
    help_text
    placeholder
    dimension_key
    concept_key
    time_window
    extraction_hint
    units
    polarity
  ].freeze
  SUPPORTED_QUESTION_TYPES = %w[scale textarea text select].freeze

  enum :status, { draft: 0, published: 1, archived: 2 }, default: :draft

  validates :title, :slug, :template_key, presence: true
  validates :slug, uniqueness: true
  validates :template_key, uniqueness: { scope: :version }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validate :published_templates_have_valid_respondent_types, if: :published?
  validate :published_templates_have_valid_schema_contract, if: :published?
  validate :published_templates_are_immutable, on: :update
  validate :schema_editor_visible_if_must_parse

  scope :published, -> { where(status: :published) }

  def self.default_schema
    {
      "version" => 1,
      "sections" => [],
      "questions" => []
    }
  end

  def draft_editable?
    draft?
  end

  def schema_version
    schema.to_h.deep_stringify_keys["version"] || 1
  end

  def question_count
    Array(schema.to_h.deep_stringify_keys["questions"]).size
  end

  def section_count
    Array(schema.to_h.deep_stringify_keys["sections"]).size
  end

  def editor_sections
    schema_hash = schema.to_h.deep_stringify_keys
    sections = Array(schema_hash["sections"]).map.with_index do |section, index|
      normalized = section.deep_stringify_keys.slice(*EDITOR_SECTION_FIELDS)
      normalized["position"] = index + 1
      normalized["questions"] = []
      normalized
    end

    indexed_sections = sections.index_by { |section| section["id"].to_s }

    Array(schema_hash["questions"]).each_with_index do |question, index|
      normalized = normalize_editor_question(question, index + 1)
      section_id = normalized["section"].to_s

      target_section = if section_id.present? && indexed_sections.key?(section_id)
        indexed_sections[section_id]
      else
        sections.find { |section| section["id"].blank? } || begin
          extra = {
            "id" => "",
            "title" => "",
            "description" => "",
            "position" => sections.size + 1,
            "questions" => []
          }
          sections << extra
          extra
        end
      end

      target_section["questions"] << normalized
    end

    sections = [ default_editor_section ] if sections.empty?

    sections.each { |section| section["questions"] = [ default_editor_question(section["id"]) ] if section["questions"].empty? }
    sections
  end

  def apply_schema_editor_attributes!(sections_attributes:, schema_version: nil)
    @schema_editor_errors = []
    schema_hash = schema.to_h.deep_stringify_keys
    existing_section_visible_if_by_id = Array(schema_hash["sections"]).each_with_object({}) do |section, memo|
      section = section.deep_stringify_keys
      section_id = section["id"].to_s
      memo[section_id] = section["visible_if"] if section_id.present? && section.key?("visible_if")
    end
    existing_question_visible_if_by_id = Array(schema_hash["questions"]).each_with_object({}) do |question, memo|
      question = question.deep_stringify_keys
      question_id = question["id"].to_s
      memo[question_id] = question["visible_if"] if question_id.present? && question.key?("visible_if")
    end

    normalized_sections = Array(sections_attributes).filter_map.with_index do |section_attributes, index|
      normalize_editor_section(
        section_attributes,
        index,
        existing_section_visible_if_by_id: existing_section_visible_if_by_id,
        existing_question_visible_if_by_id: existing_question_visible_if_by_id
      )
    end

    questions = normalized_sections.flat_map do |section|
      Array(section.delete("questions")).map do |question|
        question["section"] = section["id"].to_s
        question
      end
    end

    self.schema = {
      "version" => normalize_schema_version(schema_version),
      "sections" => normalized_sections,
      "questions" => questions
    }
  end

  def build_next_version_draft
    next_version = self.class.where(template_key: template_key).maximum(:version).to_i + 1

    self.class.new(
      title: title,
      slug: next_version_slug(next_version),
      template_key: template_key,
      version: next_version,
      category: category,
      respondent_types: respondent_types.deep_dup,
      schema: schema.deep_dup,
      status: :draft
    )
  end

  def question_ids
    Array(schema&.dig("questions")).filter_map { |q| q["id"].presence }.map(&:to_s)
  end

  private

  def next_version_slug(next_version)
    base_slug = template_key.to_s.parameterize.presence || slug.to_s.parameterize.presence || title.to_s.parameterize
    candidate = "#{base_slug}-v#{next_version}-draft"
    suffix = 2

    while self.class.exists?(slug: candidate)
      candidate = "#{base_slug}-v#{next_version}-draft-#{suffix}"
      suffix += 1
    end

    candidate
  end

  def default_editor_section
    {
      "id" => "",
      "title" => "",
      "description" => "",
      "position" => 1,
      "questions" => [ default_editor_question("") ]
    }
  end

  def default_editor_question(section_id = "")
    {
      "id" => "",
      "label" => "",
      "type" => "text",
      "section" => section_id.to_s,
      "help_text" => "",
      "placeholder" => "",
      "dimension_key" => "",
      "concept_key" => "",
      "time_window" => "",
      "evidence_weight" => "",
      "extraction_hint" => "",
      "units" => "",
      "polarity" => "",
      "min" => "",
      "max" => "",
      "required" => false,
      "options_text" => "",
      "position" => 1
    }
  end

  def normalize_schema_version(value)
    version_value = Integer(value.presence || schema_version, exception: false)
    version_value.present? && version_value.positive? ? version_value : 1
  end

  def normalize_editor_section(
    section_attributes,
    index,
    existing_section_visible_if_by_id: {},
    existing_question_visible_if_by_id: {}
  )
    section = section_attributes.to_h.deep_stringify_keys
    return if ActiveModel::Type::Boolean.new.cast(section["_destroy"])

    normalized = section.slice(*EDITOR_SECTION_FIELDS)
    normalized.transform_values! { |value| value.is_a?(String) ? value.strip : value }
    normalized["position"] = normalize_position(section["position"], index)
    normalized["questions"] = Array(section["questions_attributes"]&.to_h&.values).filter_map.with_index do |question_attributes, question_index|
      normalize_editor_question(
        question_attributes,
        question_index + 1,
        existing_question_visible_if_by_id: existing_question_visible_if_by_id
      )
    end
    visible_if = normalize_visible_if_editor_value(
      section["visible_if"],
      owner_label: "section #{section['id'].presence || index + 1}",
      fallback_visible_if: existing_section_visible_if_by_id[normalized["id"].to_s]
    )
    normalized["visible_if"] = visible_if if visible_if.present?
    normalized
  end

  def normalize_editor_question(question_attributes, index, existing_question_visible_if_by_id: {})
    question = question_attributes.to_h.deep_stringify_keys
    return if ActiveModel::Type::Boolean.new.cast(question["_destroy"])

    normalized = question.slice(*EDITOR_QUESTION_STRING_FIELDS)
    normalized.transform_values! { |value| value.is_a?(String) ? value.strip : value }
    normalized["required"] = ActiveModel::Type::Boolean.new.cast(question["required"])
    normalized["position"] = normalize_position(question["position"], index)
    normalized["options_text"] = Array(question["options"]).join("\n") if question["options"].present?

    type = normalized["type"].to_s
    normalized["min"] = Integer(question["min"], exception: false) if type == "scale" && question["min"].present?
    normalized["max"] = Integer(question["max"], exception: false) if type == "scale" && question["max"].present?
    normalized["evidence_weight"] = normalize_decimal(question["evidence_weight"])
    normalized["options"] = question_options_from_editor(question)
    visible_if = normalize_visible_if_editor_value(
      question["visible_if"],
      owner_label: "question #{question['id'].presence || index}",
      fallback_visible_if: existing_question_visible_if_by_id[normalized["id"].to_s]
    )
    normalized["visible_if"] = visible_if if visible_if.present?

    normalized.compact_blank
  end

  def normalize_visible_if_editor_value(value, owner_label:, fallback_visible_if: nil)
    return fallback_visible_if.deep_stringify_keys if value.nil? && fallback_visible_if.present?
    return nil if value.nil?

    if value.is_a?(String)
      stripped = value.strip
      return nil if stripped.blank?

      parsed = JSON.parse(stripped)
      return parsed.deep_stringify_keys if parsed.is_a?(Hash)

      add_schema_editor_error("#{owner_label} visible_if must be a JSON object")
      return nil
    end

    return value.deep_stringify_keys if value.is_a?(Hash)

    add_schema_editor_error("#{owner_label} visible_if must be a JSON object")
    nil
  rescue JSON::ParserError => error
    add_schema_editor_error("#{owner_label} visible_if is not valid JSON: #{error.message}")
    nil
  end

  def add_schema_editor_error(message)
    @schema_editor_errors ||= []
    @schema_editor_errors << message
  end

  def question_options_from_editor(question)
    options_text = question["options_text"].to_s
    options = options_text.split("\n").map(&:strip).reject(&:blank?)
    return options if options.present?

    Array(question["options"]).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def normalize_position(value, fallback)
    position = Integer(value, exception: false)
    position.present? && position.positive? ? position : fallback
  end

  def normalize_decimal(value)
    decimal = Float(value, exception: false)
    decimal.nil? ? nil : decimal
  end

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

    referenced_visible_if_ids = Set.new
    section_ids = validate_sections(schema_hash["sections"], referenced_visible_if_ids)
    seen_ids = Set.new

    questions.each_with_index do |question, index|
      validate_question(question, index, section_ids, seen_ids, referenced_visible_if_ids)
    end

    validate_visible_if_references(referenced_visible_if_ids, seen_ids)
  end

  def validate_sections(sections, referenced_visible_if_ids)
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
      label = section_id.presence || (index + 1).to_s

      errors.add(:schema, "section #{index + 1} must include an id") if section_id.blank?
      errors.add(:schema, "section #{label} must include a title") if title.blank?

      OPTIONAL_SECTION_STRING_FIELDS.each do |field|
        next unless section.key?(field)
        next if section[field].is_a?(String)

        errors.add(:schema, "section #{label} #{field} must be a string")
      end

      if section.key?("visible_if")
        validate_visible_if(
          section["visible_if"],
          owner_path: "section[#{label}]",
          referenced_ids: referenced_visible_if_ids
        )
      end

      next if section_id.blank?

      if seen_ids.include?(section_id)
        errors.add(:schema, "section ids must be unique (duplicate #{section_id})")
      else
        seen_ids << section_id
      end
    end

    seen_ids
  end

  def validate_question(question, index, section_ids, seen_ids, referenced_visible_if_ids)
    unless question.is_a?(Hash)
      errors.add(:schema, "question #{index + 1} must be an object")
      return
    end

    question = question.deep_stringify_keys
    question_id = question["id"].to_s
    label = question_id.presence || (index + 1).to_s

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
      errors.add(:schema, "question #{label} has unsupported type #{type.inspect}")
      return
    end

    OPTIONAL_STRING_QUESTION_FIELDS.each do |field|
      next unless question.key?(field)
      next if question[field].is_a?(String)

      errors.add(:schema, "question #{label} #{field} must be a string")
    end

    if section_ids.present? && question["section"].present? && !section_ids.include?(question["section"].to_s)
      errors.add(:schema, "question #{label} references unknown section #{question['section']}")
    end

    if question.key?("visible_if")
      validate_visible_if(
        question["visible_if"],
        owner_path: "question[#{label}]",
        referenced_ids: referenced_visible_if_ids
      )
    end

    validate_question_evidence_weight(question, question_id, index)
    validate_question_type_config(question, question_id, index)
  end

  def validate_visible_if(predicate, owner_path:, referenced_ids:)
    validator = AssessmentSchema::SchemaPredicate.new(predicate, path: "#{owner_path}.visible_if")
    validator.validate!

    validator.errors.each { |message| errors.add(:schema, message) }
    referenced_ids.merge(validator.referenced_question_ids)
  end

  def validate_visible_if_references(referenced_ids, question_ids)
    unknown = referenced_ids - question_ids
    unknown.each do |id|
      errors.add(:schema, "visible_if references unknown question id #{id.inspect}")
    end
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

  def schema_editor_visible_if_must_parse
    return if @schema_editor_errors.blank?

    @schema_editor_errors.each { |message| errors.add(:schema, message) }
  end
end
