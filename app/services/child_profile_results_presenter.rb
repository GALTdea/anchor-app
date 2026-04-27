# frozen_string_literal: true

class ChildProfileResultsPresenter
  DomainGroup = Struct.new(:key, :title, :dimensions, keyword_init: true)
  DrivingExplanation = Struct.new(:behavior_context, :possible_meaning, :support_implication, keyword_init: true)
  SupportPriority = Struct.new(:title, :body, keyword_init: true)
  WeeklyIdea = Struct.new(:title, :why_it_may_help, :how_to_try_it, :estimated_time, keyword_init: true)
  ParentAnalysisRow = Struct.new(
    :title, :summary, :confidence_phrase, :evidence_note, :low_confidence, keyword_init: true
  )

  MVP_LIMIT = 3
  STRENGTHS_DOMAIN_KEYS = [ "strengths_and_motivators" ].freeze
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

  def profile_traits
    traits = profile_dimensions.filter_map do |dimension_key, details|
      next if dimension_key.to_s.start_with?("medical.")

      display_value(details)
    end

    (traits.presence || fallback_profile_traits).first(5)
  end

  def driving_explanations
    explanations = profile_domain_groups.first(MVP_LIMIT).filter_map do |group|
      detail = group.dimensions.values.first
      value = display_value(detail)
      next if value.blank?

      DrivingExplanation.new(
        behavior_context: "#{group.title}: #{value}",
        possible_meaning: driving_meaning_for(group),
        support_implication: driving_support_for(group)
      )
    end

    fill_to_limit(explanations, fallback_driving_explanations)
  end

  def support_priorities
    priorities = active_recommendations.first(MVP_LIMIT).map do |recommendation|
      SupportPriority.new(
        title: priority_title_for(recommendation),
        body: "Focus on one repeatable support before adding more."
      )
    end

    fill_to_limit(priorities, fallback_support_priorities)
  end

  def weekly_ideas
    ideas = active_recommendations.first(MVP_LIMIT).map do |recommendation|
      WeeklyIdea.new(
        title: recommendation.title,
        why_it_may_help: "This may help because it gives #{child_profile.first_name} a clearer support during #{recommendation.category.to_s.humanize.downcase} moments.",
        how_to_try_it: recommendation.body,
        estimated_time: "5-10 minutes"
      )
    end

    fill_to_limit(ideas, fallback_weekly_ideas)
  end

  def latest_assessment_response
    @latest_assessment_response ||= AssessmentResponse
      .joins(:assessment)
      .includes(assessment: :assessment_template)
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

  def latest_completed_analysis_run
    @latest_completed_analysis_run ||= child_profile.analysis_runs
      .completed
      .includes(:analysis_findings)
      .order(completed_at: :desc, id: :desc)
      .first
  end

  def show_analysis_insights?
    latest_completed_analysis_run.present? && latest_completed_analysis_run.analysis_findings.any?
  end

  def parent_analysis_rows
    run = latest_completed_analysis_run
    return [].freeze if run.blank? || run.analysis_findings.empty?

    ordered_findings = run.analysis_findings.sort_by { |f| [ finding_display_rank(f), f.dimension_key, f.finding_key ] }
    ordered_findings.map { |f| build_parent_analysis_row(f) }
  end

  def display_value(details)
    details.to_h["metadata"].to_h["selected_option_label"].presence || details.to_h["latest_value"]
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

  def fill_to_limit(items, fallback_items)
    (items + fallback_items).first(MVP_LIMIT)
  end

  def finding_display_rank(finding)
    return 0 if STRENGTHS_DOMAIN_KEYS.include?(finding.dimension_key.to_s)
    return 0 if finding.metadata["rubric_domain"].to_s == "strengths_and_motivators"

    1
  end

  def build_parent_analysis_row(finding)
    ids = Array(finding.evidence_refs["profile_evidence_ids"])
    n = ids.size
    evidence_note = if n.positive?
      "Drawn from #{n} saved observation#{'s' if n != 1} in your answers and profile."
    else
      "Drawn from your saved profile responses."
    end

    conf = finding.confidence
    low = conf.present? && conf < 0.4
    ParentAnalysisRow.new(
      title: finding.label,
      summary: finding.summary,
      confidence_phrase: analysis_confidence_phrase(conf),
      evidence_note:,
      low_confidence: low
    )
  end

  def analysis_confidence_phrase(confidence)
    return "Anchor is still building confidence in this read." if confidence.blank?

    pct = (confidence.to_f * 100).round
    "Anchor is about #{pct}% confident in this read — a working pattern, not a diagnosis."
  end

  def driving_meaning_for(group)
    case group.key.to_s
    when "communication"
      "This may be a way of showing that communication needs more support in the moment."
    when "sensory"
      "This could mean the environment is asking more of the body than feels manageable."
    when "regulation"
      "This might be connected to needing more time or support to recover."
    when "flexibility"
      "This may happen when a change or expectation feels hard to predict."
    else
      "This may be connected to a support need that becomes clearer across repeated moments."
    end
  end

  def driving_support_for(group)
    case group.key.to_s
    when "communication"
      "Use fewer words, add a visual cue, and give extra time to respond."
    when "sensory"
      "Adjust one part of the environment and watch whether stress decreases."
    when "regulation"
      "Build in a calm reset before the moment becomes too much."
    when "flexibility"
      "Preview the next step and practice small changes when pressure is low."
    else
      "Keep the support small, predictable, and easy to repeat."
    end
  end

  def priority_title_for(recommendation)
    case recommendation.category.to_s
    when "communication"
      "Make communication easier to use"
    when "sensory"
      "Reduce sensory friction"
    when "regulation"
      "Support recovery after hard moments"
    when "behavior"
      "Make uncertain moments more predictable"
    else
      "Build one steady support routine"
    end
  end

  def fallback_profile_traits
    [
      "May do best when the next step is clear.",
      "May need extra time to recover after hard moments.",
      "Could benefit from simple, repeatable supports."
    ]
  end

  def fallback_driving_explanations
    [
      DrivingExplanation.new(
        behavior_context: "Hard moments during transitions",
        possible_meaning: "Transitions may feel harder when the next step is unclear.",
        support_implication: "Preview what is changing and offer one simple next step."
      ),
      DrivingExplanation.new(
        behavior_context: "Big reactions after mistakes or frustration",
        possible_meaning: "A strong reaction might mean recovery support is needed before problem-solving.",
        support_implication: "Pause, lower demands, and return to the task after a brief reset."
      ),
      DrivingExplanation.new(
        behavior_context: "Resistance when expectations change",
        possible_meaning: "Flexibility could be harder when the change feels sudden or high-pressure.",
        support_implication: "Practice small changes during calm, low-pressure moments."
      )
    ]
  end

  def fallback_support_priorities
    [
      SupportPriority.new(
        title: "Make uncertain moments more predictable",
        body: "Use a short preview before transitions or new expectations."
      ),
      SupportPriority.new(
        title: "Support recovery after mistakes",
        body: "Give space to reset before explaining, correcting, or trying again."
      ),
      SupportPriority.new(
        title: "Practice flexibility in low-pressure situations",
        body: "Try tiny changes during calm moments so flexibility feels safer."
      )
    ]
  end

  def fallback_weekly_ideas
    [
      WeeklyIdea.new(
        title: "Preview one tricky transition",
        why_it_may_help: "This may help because predictability can lower stress before a change.",
        how_to_try_it: "Pick one daily transition and name what will happen now, next, and after.",
        estimated_time: "5 minutes"
      ),
      WeeklyIdea.new(
        title: "Create a short reset routine",
        why_it_may_help: "This could help recovery feel safer and more familiar.",
        how_to_try_it: "Choose one calming option, offer it early, and keep the words simple.",
        estimated_time: "5-10 minutes"
      ),
      WeeklyIdea.new(
        title: "Try one tiny change during play",
        why_it_may_help: "This might make flexibility easier to practice when the stakes are low.",
        how_to_try_it: "Change one small part of a familiar activity and praise any attempt to adjust.",
        estimated_time: "5 minutes"
      )
    ]
  end
end
