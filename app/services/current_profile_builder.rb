# frozen_string_literal: true

class CurrentProfileBuilder
  def initialize(child_profile)
    @child_profile = child_profile
  end

  def call
    evidence = child_profile.profile_evidences.order(:recorded_at, :id).to_a

    {
      summary: build_summary(evidence),
      narrative: build_narrative(evidence)
    }
  end

  private

  attr_reader :child_profile

  def build_summary(evidence)
    grouped = evidence.group_by(&:dimension_key)

    {
      "stats" => {
        "evidence_count" => evidence.count,
        "dimension_count" => grouped.keys.count,
        "last_recorded_at" => evidence.last&.recorded_at&.iso8601
      }.compact,
      "dimensions" => grouped.transform_values do |items|
        latest = items.max_by { |item| [ item.recorded_at, item.id ] }

        {
          "concept_key" => latest.concept_key,
          "latest_value" => latest.value,
          "value_type" => latest.value_type,
          "confidence" => latest.confidence,
          "respondent_kind" => latest.respondent_kind,
          "recorded_at" => latest.recorded_at.iso8601,
          "evidence_count" => items.count,
          "latest_source_type" => latest.source_type,
          "metadata" => latest.metadata
        }
      end
    }
  end

  def build_narrative(evidence)
    return "Not enough evidence yet to build a child profile." if evidence.empty?

    grouped = evidence.group_by(&:dimension_key)
    opening = "#{child_profile.name}'s current profile is built from #{evidence.count} evidence point#{'s' unless evidence.one?} across #{grouped.keys.count} tracked dimension#{'s' unless grouped.keys.one?}."
    dimension_sentences = grouped.sort.map do |dimension_key, items|
      latest = items.max_by { |item| [ item.recorded_at, item.id ] }
      "#{humanize_dimension(dimension_key)} currently points to #{humanize_value(latest)} based on #{latest.respondent_kind.to_s.humanize.downcase} input."
    end

    ([ opening ] + dimension_sentences).join(" ")
  end

  def humanize_dimension(dimension_key)
    dimension_key.to_s.tr(".", " ").humanize
  end

  def humanize_value(evidence)
    label = evidence.metadata.to_h["selected_option_label"].presence
    label || evidence.value.to_s
  end
end
