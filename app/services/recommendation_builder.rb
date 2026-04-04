# frozen_string_literal: true

class RecommendationBuilder
  def initialize(current_profile:, source_profile_snapshot:)
    @current_profile = current_profile
    @source_profile_snapshot = source_profile_snapshot
  end

  def call
    dimensions.map do |dimension_key, details|
      build_recommendation(dimension_key, details)
    end
  end

  private

  attr_reader :current_profile, :source_profile_snapshot

  def build_recommendation(dimension_key, details)
    category = dimension_key.to_s.split(".").first.to_s.presence || "support"
    latest_value = details["metadata"].to_h["selected_option_label"].presence || details["latest_value"].to_s
    title = recommendation_title(category, dimension_key)

    {
      category: category,
      title: title,
      body: recommendation_body(category, latest_value, details),
      rationale: {
        "dimension_key" => dimension_key,
        "concept_key" => details["concept_key"],
        "latest_value" => details["latest_value"],
        "display_value" => latest_value,
        "confidence" => details["confidence"],
        "respondent_kind" => details["respondent_kind"],
        "recorded_at" => details["recorded_at"]
      },
      generated_at: Time.current,
      source_profile_snapshot: source_profile_snapshot
    }
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
