# frozen_string_literal: true

class RecommendationBuilder
  # Maps profile `dimension_key` first segments to the published rubric domain keys
  # in `db/seeds/analysis_rubrics/anchor_child_profile_v1.rb` (e.g. sensory -> sensory_experience).
  RUBRIC_DOMAIN_BY_PROFILE_PREFIX = {
    "sensory" => "sensory_experience",
    "social" => "social_connection",
    "adaptive" => "daily_life",
    "daily_living" => "daily_life",
    "strengths" => "strengths_and_motivators",
    "priorities" => "family_priorities",
    "context" => "family_priorities"
  }.freeze

  def initialize(current_profile:, source_profile_snapshot:, analysis_run: nil)
    @current_profile = current_profile
    @source_profile_snapshot = source_profile_snapshot
    @analysis_run = analysis_run
  end

  def call
    dimensions.map do |dimension_key, details|
      build_recommendation(dimension_key, details)
    end
  end

  private

  attr_reader :current_profile, :source_profile_snapshot, :analysis_run

  def build_recommendation(dimension_key, details)
    category = dimension_key.to_s.split(".").first.to_s.presence || "support"
    latest_value = details["metadata"].to_h["selected_option_label"].presence || details["latest_value"].to_s
    title = recommendation_title(category, dimension_key)
    base_rationale = {
      "dimension_key" => dimension_key,
      "concept_key" => details["concept_key"],
      "latest_value" => details["latest_value"],
      "display_value" => latest_value,
      "confidence" => details["confidence"],
      "respondent_kind" => details["respondent_kind"],
      "recorded_at" => details["recorded_at"]
    }
    base_rationale.merge!(analysis_grounding_for(dimension_key))

    {
      category: category,
      title: title,
      body: recommendation_body(category, latest_value, details),
      rationale: base_rationale,
      generated_at: Time.current,
      source_profile_snapshot: source_profile_snapshot
    }
  end

  def analysis_grounding_for(dimension_key)
    return {} if analysis_run.blank? || !analysis_run.completed?

    out = { "analysis_run_id" => analysis_run.id }
    if analysis_run.analysis_rubric
      out["analysis_rubric_key"] = analysis_run.analysis_rubric.rubric_key
      out["analysis_rubric_version"] = analysis_run.analysis_rubric.version
    end
    finding = match_analysis_finding(dimension_key, analysis_run.analysis_findings)
    if finding
      out["analysis_finding_id"] = finding.id
      out["analysis_finding_key"] = finding.finding_key
    end
    out
  end

  def match_analysis_finding(dimension_key, findings)
    list = Array(findings)
    return nil if list.empty?

    target = rubric_domain_key_for_profile_dimension(dimension_key)
    list.find { |f| f.dimension_key == target } ||
      list.find { |f| f.metadata.is_a?(Hash) && f.metadata["rubric_domain"].to_s == target }
  end

  def rubric_domain_key_for_profile_dimension(dimension_key)
    dk = dimension_key.to_s
    segs = dk.split(".")

    if segs[0] == "behavior" || (segs[0] == "regulation" && %w[routine transitions].include?(segs[1]))
      "flexibility"
    elsif (mapped = RUBRIC_DOMAIN_BY_PROFILE_PREFIX[segs[0]]).present?
      mapped
    else
      segs[0].to_s
    end
  end

  def recommendation_title(category, dimension_key)
    case category
    when "regulation"
      "Support #{humanized_dimension(dimension_key)} with predictable recovery space"
    when "sensory"
      "Reduce friction around #{humanized_dimension(dimension_key)}"
    when "communication"
      "Use clear supports around #{humanized_dimension(dimension_key)}"
    else
      "Try a small support plan for #{humanized_dimension(dimension_key)}"
    end
  end

  def recommendation_body(category, latest_value, details)
    case category
    when "regulation"
      "Based on the latest profile signal, #{current_profile.child_profile.name} may benefit from a calm recovery routine that reflects #{latest_value.downcase}. Start with one repeatable support after challenging moments and track whether recovery becomes easier."
    when "sensory"
      "Recent evidence suggests #{humanized_dimension(details['concept_key'])} may be a meaningful part of daily friction. Try one environmental adjustment linked to #{latest_value.downcase} and watch for whether stress decreases."
    when "communication"
      "The current profile suggests communication support around #{latest_value.downcase}. Keep language simple, reduce pressure, and note which prompts make things easier."
    else
      "The current profile highlights #{latest_value.downcase} in #{humanized_dimension(details['concept_key'])}. Choose one gentle support strategy, keep it consistent for a few days, and observe what changes."
    end
  end

  def dimensions
    current_profile.summary.fetch("dimensions", {})
  end

  def humanized_dimension(value)
    value.to_s.tr("._", "  ").squeeze(" ").humanize.downcase
  end
end
