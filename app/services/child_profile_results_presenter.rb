# frozen_string_literal: true

class ChildProfileResultsPresenter
  DomainGroup = Struct.new(:key, :title, :dimensions, keyword_init: true)

  STRENGTH_PREFIXES = [ "strengths." ].freeze
  DOMAIN_GROUPS = [
    {
      key: "communication",
      title: "Communication",
      prefixes: [ "communication." ]
    },
    {
      key: "social_connection",
      title: "Social connection",
      prefixes: [ "social." ]
    },
    {
      key: "flexibility",
      title: "Flexibility",
      prefixes: [
        "behavior.flexibility",
        "behavior.rigidity",
        "behavior.repetitive_patterns",
        "behavior.cognitive_flexibility"
      ]
    },
    {
      key: "sensory",
      title: "Sensory experience",
      prefixes: [ "sensory." ]
    },
    {
      key: "regulation",
      title: "Regulation",
      prefixes: [ "regulation." ]
    },
    {
      key: "daily_life",
      title: "Daily life",
      prefixes: [ "adaptive." ]
    },
    {
      key: "other_important_factors",
      title: "Other important factors",
      prefixes: [ "cooccurring.", "context." ]
    },
    {
      key: "priorities",
      title: "Priorities",
      prefixes: [ "priorities." ]
    }
  ].freeze

  def initialize(child_profile)
    @child_profile = child_profile
  end

  attr_reader :child_profile

  def page_title
    "#{child_profile.name} Profile"
  end

  def current_profile
    @current_profile ||= child_profile.current_profile || child_profile.build_current_profile(
      summary: {},
      generated_at: Time.current,
      profile_version: 1
    )
  end

  def profile_dimensions
    current_profile.summary.to_h.fetch("dimensions", {})
  end

  def strengths_dimensions
    select_dimensions_by_prefix(STRENGTH_PREFIXES)
  end

  def profile_domain_groups
    groups = DOMAIN_GROUPS.filter_map do |group|
      dimensions = select_dimensions_by_prefix(group.fetch(:prefixes))
      next if dimensions.blank?

      DomainGroup.new(
        key: group.fetch(:key),
        title: group.fetch(:title),
        dimensions: dimensions
      )
    end

    other_dimensions = ungrouped_dimensions
    if other_dimensions.present?
      groups << DomainGroup.new(
        key: "other_signals",
        title: "Other signals",
        dimensions: other_dimensions
      )
    end

    groups
  end

  def active_recommendations
    @active_recommendations ||= child_profile.recommendations.active.order(generated_at: :desc, id: :desc)
  end

  def latest_assessment_response
    @latest_assessment_response ||= AssessmentResponse
      .joins(:assessment)
      .includes(:actor, assessment: :assessment_template)
      .where(assessments: { child_profile_id: child_profile.id })
      .where.not(submitted_at: nil)
      .order(submitted_at: :desc, id: :desc)
      .first
  end

  def processing_status
    latest_assessment_response&.processing_status
  end

  def profile_ready?
    current_profile.persisted? && profile_dimensions.present?
  end

  private

  def select_dimensions_by_prefix(prefixes)
    profile_dimensions.select do |dimension_key, _details|
      starts_with_any_prefix?(dimension_key, prefixes)
    end
  end

  def ungrouped_dimensions
    grouped_keys = (STRENGTH_PREFIXES + DOMAIN_GROUPS.flat_map { |group| group.fetch(:prefixes) })

    profile_dimensions.reject do |dimension_key, _details|
      starts_with_any_prefix?(dimension_key, grouped_keys)
    end
  end

  def starts_with_any_prefix?(dimension_key, prefixes)
    prefixes.any? { |prefix| dimension_key.to_s.start_with?(prefix) }
  end
end
