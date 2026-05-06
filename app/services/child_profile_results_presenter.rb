# frozen_string_literal: true

class ChildProfileResultsPresenter
  DomainGroup = Struct.new(:key, :title, :dimensions, keyword_init: true)
  DrivingExplanation = Struct.new(:behavior_context, :possible_meaning, :support_implication, keyword_init: true)
  FocusPriority = Struct.new(:focus, :why_it_matters, :what_to_try_first, keyword_init: true)
  WeeklyIdea = Struct.new(:title, :why_it_may_help, :how_to_try_it, :estimated_time, keyword_init: true)
  LearningArea = Struct.new(:body, keyword_init: true)
  SupportGuideInsight = Struct.new(:body, keyword_init: true)
  HardMomentGuideCard = Struct.new(:title, :body, keyword_init: true)
  PlanningFocus = Struct.new(:label, keyword_init: true)
  BestSupportLine = Struct.new(:label, :detail, keyword_init: true)
  ParentAnalysisRow = Struct.new(
    :title, :summary, :confidence_phrase, :evidence_note, :low_confidence, keyword_init: true
  )
  AiGuidancePanel = Struct.new(:summary_plain, :confidence_note, :what_to_watch, keyword_init: true)

  MVP_LIMIT = 3
  INSIGHT_MIN = 3
  INSIGHT_MAX = 5
  AI_SYNTHESIS_PURPOSE_PARENT = "parent_guidance_v1".freeze
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
    "#{child_profile.first_name}'s Support Guide"
  end

  def page_subtitle
    "A simple guide to what Anchor understands right now, what may help, and what to watch next."
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

      parent_safe_display(details)
    end

    (traits.presence || fallback_profile_traits).first(5)
  end

  # Context note above insight cards on the Support Guide (processing states + early profile).
  def support_guide_context_note
    case processing_status
    when "failed"
      "We saved the assessment, but the profile update needs attention before these results can be refreshed."
    when "queued", "processing"
      "We saved what has been shared so far and are building this profile. Gentle starting points below may help while Anchor catches up."
    else
      default_support_guide_intro unless profile_ready?
    end
  end

  def plain_language_summary
    support_guide_context_note || default_support_guide_intro
  end

  def default_support_guide_intro
    "This guide turns what has been shared so far into practical ideas. It should feel more personal as Anchor learns what helps #{child_profile.first_name}."
  end

  def child_snapshot_updated_at
    [
      persisted_current_profile&.generated_at,
      latest_assessment_response&.submitted_at,
      child_profile.updated_at
    ].compact.max || Time.current
  end

  def profile_state_label
    return "Early profile" unless profile_ready?

    dimension_count = profile_dimensions.size
    if dimension_count >= 8 && latest_assessment_response.present?
      "Well-established"
    elsif dimension_count >= 3
      "Growing confidence"
    else
      "Early profile"
    end
  end

  def anchor_observations
    profile_traits.first(5)
  end

  def support_guide_insights
    bodies = collect_support_insight_sentences.uniq
    merged = (bodies + fallback_support_insight_bodies).uniq
    cards = merged.first(INSIGHT_MAX).map { |body| SupportGuideInsight.new(body:) }
    pad_insight_cards(cards)
  end

  def hard_moment_guide_cards
    [
      HardMomentGuideCard.new(title: hard_moment_triggers_title, body: build_hard_moment_triggers_body),
      HardMomentGuideCard.new(title: "Early signs to watch for", body: build_hard_moment_early_signs_body),
      HardMomentGuideCard.new(title: "What may help", body: build_hard_moment_help_body)
    ]
  end

  def planning_focus_areas
    labels = []
    labels << "Transitions and shifting plans" if dimension_signal?(/\Abehavior\.(flexibility|rigidity|cognitive_flexibility)/)
    labels << "Open-ended or unclear expectations" if dimension_signal?(/\Abehavior\.cognitive_flexibility/)
    labels << "Sensory-heavy settings" if dimension_signal?(/\Asensory\./)
    labels << "Recovery after big feelings" if dimension_signal?(/\Aregulation\.(recovery|stress_pattern)/)
    labels << "School-day demand or fatigue" if parent_safe_display(profile_dimensions["context.school"]).present?
    labels << "Multi-step daily tasks" if dimension_signal?(/\Aadaptive\./)
    labels << "Moments after mistakes or uncertainty" if dimension_signal?(/\Aregulation\.stress_pattern/)
    labels << "Changes to the usual routine" if dimension_signal?(/\Abehavior\.(rigidity|flexibility)/)

    merged = (labels.presence || default_planning_focus_labels).uniq.first(6)
    merged.map { |label| PlanningFocus.new(label:) }
  end

  def best_support_style_lines
    fn = child_profile.first_name
    lines = []
    if (v = parent_safe_display(profile_dimensions["strengths.interests"]))
      lines << BestSupportLine.new(label: "Interests", detail: "Interests like #{v} may be useful entry points for connection or recovery.")
    end
    if (v = parent_safe_display(profile_dimensions["strengths.profile"]))
      lines << BestSupportLine.new(label: "Best qualities", detail: v.to_s)
    end
    if (v = parent_safe_display(profile_dimensions["strengths.support_fit"]))
      lines << BestSupportLine.new(label: "Helpful support style", detail: v.to_s)
    end
    if (v = parent_safe_display(profile_dimensions["strengths.support_history"]))
      lines << BestSupportLine.new(label: "What already works", detail: v.to_s)
    end
    if (v = parent_safe_display(profile_dimensions["priorities.parent_goal"]))
      lines << BestSupportLine.new(label: "Your priority in your own words", detail: v.to_s)
    end

    return fallback_best_support_lines(fn) if lines.empty?

    lines.first(6)
  end

  def snapshot_provenance_phrase
    response = latest_assessment_response
    return nil unless response&.submitted_at.present?

    template_title = response.assessment&.assessment_template&.title.to_s.strip
    ago = helpers.time_ago_in_words(response.submitted_at)
    if template_title.present?
      "Based on #{template_title}, completed #{ago} ago."
    else
      "Based on the profile questionnaire completed #{ago} ago."
    end
  end

  def driving_explanations
    explanations = profile_domain_groups.first(MVP_LIMIT).filter_map do |group|
      detail = group.dimensions.values.first
      value = parent_safe_display(detail) || display_value(detail)
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
      FocusPriority.new(
        focus: focus_heading_for(recommendation),
        why_it_matters: focus_why_it_matters_for(recommendation),
        what_to_try_first: truncate_for_focus(recommendation.body.to_s.strip)
      )
    end

    fill_focus_priorities(priorities)
  end

  def weekly_ideas
    ideas = active_recommendations.first(MVP_LIMIT).map do |recommendation|
      WeeklyIdea.new(
        title: weekly_title_for(recommendation),
        why_it_may_help: weekly_why_it_may_help_for(recommendation),
        how_to_try_it: recommendation.body.to_s.strip,
        estimated_time: "5-10 minutes"
      )
    end

    fill_to_limit(ideas, fallback_weekly_ideas)
  end

  def learning_areas
    fn = child_profile.first_name
    [
      "What usually happens right before a hard moment?",
      "What helps #{fn} recover?",
      "Are hard moments more common when tired, hungry, rushed, or overstimulated?",
      "Which supports make the moment shorter or easier?"
    ].map { |body| LearningArea.new(body:) }
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
      .includes(:ai_synthesis_runs)
      .order(completed_at: :desc, id: :desc)
      .first
  end

  # Uses the latest successful parent-guidance Ai synthesis for this profile's freshest completed run only.
  def ai_guidance_panel
    return @ai_guidance_panel if instance_variable_defined?(:@ai_guidance_panel)

    run = latest_completed_analysis_run
    synthesis = run && latest_parent_ai_synthesis_for(run)
    @ai_guidance_panel = synthesis&.completed? ? build_ai_guidance_panel(synthesis) : nil
  end

  def show_ai_guidance?
    ai_guidance_panel.present?
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

  def parent_safe_display(details)
    raw = display_value(details)
    return nil if raw.blank?

    str = raw.to_s.strip
    return nil if str.match?(/\A\d+\z/)

    str
  end

  def display_value(details)
    details.to_h["metadata"].to_h["selected_option_label"].presence || details.to_h["latest_value"]
  end

  private

  def helpers
    ApplicationController.helpers
  end

  def persisted_current_profile
    current_profile.persisted? ? current_profile : nil
  end

  def latest_parent_ai_synthesis_for(analysis_run)
    Array(analysis_run.ai_synthesis_runs)
      .select { |syn| syn.purpose.to_s == AI_SYNTHESIS_PURPOSE_PARENT && syn.completed? }
      .max_by(&:id)
  end

  def build_ai_guidance_panel(synthesis)
    out = synthesis.output.to_h
    summary_plain = out["summary_plain"].to_s.strip
    return nil if summary_plain.blank?

    watch = Array(out["what_to_watch"]).filter_map do |item|
      s = item.to_s.strip
      next if s.blank?

      s
    end

    AiGuidancePanel.new(
      summary_plain:,
      confidence_note: out["confidence_note"].presence,
      what_to_watch: watch
    )
  end

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

  def fill_focus_priorities(priorities)
    return priorities if priorities.size >= MVP_LIMIT

    (priorities + fallback_focus_priorities).first(MVP_LIMIT)
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

  def focus_heading_for(recommendation)
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

  def focus_why_it_matters_for(recommendation)
    case recommendation.category.to_s
    when "communication"
      "Clearer communication reduces guesswork when #{child_profile.first_name} is already working hard to keep up."
    when "sensory"
      "Lowering sensory load can prevent overwhelm before behavior escalates."
    when "regulation"
      "Recovery support often works better before adding more instruction or correction."
    when "behavior"
      "Predictability can shrink uncertainty when flexibility feels hardest."
    else
      "One repeatable support is easier to notice and adjust than many scattered attempts."
    end
  end

  def truncate_for_focus(text, limit: 240)
    return text if text.length <= limit

    "#{text[0, limit].strip}…"
  end

  def weekly_title_for(recommendation)
    title = recommendation.title.to_s.strip
    return title if title.present? && !mechanical_recommendation_title?(title)

    friendly_weekly_title_for_category(recommendation.category)
  end

  def mechanical_recommendation_title?(title)
    down = title.downcase
    return true if title.include?("_")
    return true if down.include?("support adaptive") || down.include?("predictable recovery space")
    return true if title.length > 72

    false
  end

  def friendly_weekly_title_for_category(category)
    case category.to_s
    when "communication"
      "Try a simpler communication cue"
    when "sensory"
      "Soften one sensory hotspot"
    when "regulation"
      "Practice a short recovery rhythm"
    when "behavior"
      "Preview one change before it happens"
    else
      "Try one small support tweak"
    end
  end

  def weekly_why_it_may_help_for(recommendation)
    case recommendation.category.to_s
    when "communication"
      "Small communication tweaks can lower friction before frustration builds."
    when "sensory"
      "Lowering sensory load may keep the nervous system steadier through the day."
    when "regulation"
      "Rhythm around recovery can shorten hard moments over time."
    when "behavior"
      "Previewing change gives #{child_profile.first_name} time to adjust before pressure rises."
    else
      "Tiny experiments make it easier to see what actually helps."
    end
  end

  def fallback_profile_traits
    [
      "May do best when the next step is clear.",
      "May need extra time to recover after hard moments.",
      "Could benefit from simple, repeatable supports."
    ]
  end

  def collect_support_insight_sentences
    fn = child_profile.first_name
    sentences = []
    dims = profile_dimensions
    add = ->(s) { sentences << s if s.present? }

    if (v = parent_safe_display(dims["strengths.interests"]))
      add.call("#{fn} may connect more easily when interests like #{v} are welcomed into everyday moments.")
    end
    if (v = parent_safe_display(dims["strengths.profile"]))
      add.call("You shared qualities that may shine when #{v}.")
    end
    if (v = parent_safe_display(dims["strengths.support_fit"]))
      add.call("Support may land better when adults #{v}.")
    end
    if (v = parent_safe_display(dims["strengths.support_history"]))
      add.call("What already helps often includes #{v}.")
    end

    add_first_matching_dimension_sentence(
      sentences,
      /\Acommunication\./,
      ->(v) { "#{fn} may do best when communication stays patient, concrete, and matched to how #{fn} connects (#{v})." }
    )
    add_first_matching_dimension_sentence(
      sentences,
      /\Abehavior\.(flexibility|rigidity|cognitive_flexibility)/,
      ->(v) { "Changes may feel harder for #{fn} when expectations shift suddenly (#{v})." }
    )
    add_first_matching_dimension_sentence(
      sentences,
      /\Asensory\./,
      ->(v) { "Sensory load may shape how full the day feels (#{v})." }
    )
    add_first_matching_dimension_sentence(
      sentences,
      /\Aregulation\./,
      ->(v) { "Regulation may depend on pacing and recovery (#{v})." }
    )
    add_first_matching_dimension_sentence(
      sentences,
      /\Aadaptive\./,
      ->(v) { "Daily life flows more smoothly when demands fit what #{fn} can manage (#{v})." }
    )

    if (v = parent_safe_display(dims["context.supports"]))
      add.call("Existing supports such as #{v} may be anchors to lean on.")
    end
    if (v = parent_safe_display(dims["context.school"]))
      add.call("School context (#{v}) may be worth planning around on heavier days.")
    end

    sentences
  end

  def add_first_matching_dimension_sentence(sentences, key_pattern, builder)
    profile_dimensions.each do |key, details|
      next unless key.to_s.match?(key_pattern)

      v = parent_safe_display(details)
      next unless v

      sentences << builder.call(v)
      break
    end
  end

  def fallback_support_insight_bodies
    fn = child_profile.first_name
    [
      "#{fn} may do best when expectations are clear before a task starts.",
      "Changes may feel harder when the next step is uncertain.",
      "Support may work best when adults lower pressure before giving more instruction.",
      "Small previews before transitions can make shifts feel safer.",
      "Recovery time after a hard moment may matter as much as the moment itself."
    ]
  end

  def pad_insight_cards(cards)
    fallback_bodies = fallback_support_insight_bodies
    idx = 0
    while cards.size < INSIGHT_MIN
      body = fallback_bodies[idx % fallback_bodies.size]
      idx += 1
      next if cards.any? { |c| c.body == body }

      cards << SupportGuideInsight.new(body:)
    end
    cards.first(INSIGHT_MAX)
  end

  def hard_moment_triggers_title
    trigger_signals_present? ? "Possible triggers" : "What may make things harder"
  end

  def trigger_signals_present?
    keys = profile_dimensions.keys.map(&:to_s)
    keys.any? { |k| k.start_with?("sensory.") } ||
      keys.any? { |k| k.match?(/\Abehavior\.(flexibility|rigidity)/) } ||
      parent_safe_display(profile_dimensions["context.school"]).present?
  end

  def build_hard_moment_triggers_body
    fn = child_profile.first_name
    bits = []
    if (v = first_dimension_display_for_key_pattern(/\Abehavior\.(flexibility|rigidity)/))
      bits << "Changes in plans or unclear next steps may feel harder (#{v})."
    end
    if (v = first_dimension_display_for_key_pattern(/\Asensory\./))
      bits << "Busy or intense sensory environments may add strain (#{v})."
    end
    if (v = parent_safe_display(profile_dimensions["context.school"]))
      bits << "School-related demand (#{v}) may stack with tiredness or transitions."
    end

    bits.first(2).join(" ").presence ||
      "Moments may feel harder when transitions sneak up, expectations shift suddenly, or the day already feels full. This is a gentle guess based on what has been shared so far."
  end

  def build_hard_moment_early_signs_body
    if (v = parent_safe_display(profile_dimensions["regulation.stress_pattern"]))
      return "You shared patterns around stress that may include #{v}. Tiny shifts in pace, tone, or sensory load can be early cues to slow down."
    end

    "Small shifts in pace, tone, or sensory load may show up before a bigger reaction. Noticing what tends to come first can help you experiment earlier."
  end

  def build_hard_moment_help_body
    fn = child_profile.first_name
    bits = []
    if (v = parent_safe_display(profile_dimensions["strengths.support_fit"]))
      bits << "Support framed as #{v} may land more softly."
    end
    if (v = parent_safe_display(profile_dimensions["strengths.support_history"]))
      bits << "Strategies that already help (#{v}) can be the first lever."
    end
    if (v = parent_safe_display(profile_dimensions["strengths.interests"]))
      bits << "Weaving in interests like #{v} may make recovery or connection easier for #{fn}."
    end

    bits.first(2).join(" ").presence ||
      "Lower pressure first, keep words simple, preview what comes next, and offer one clear choice when possible."
  end

  def first_dimension_display_for_key_pattern(key_pattern)
    profile_dimensions.each do |key, details|
      next unless key.to_s.match?(key_pattern)

      v = parent_safe_display(details)
      return v if v
    end
    nil
  end

  def dimension_signal?(key_pattern)
    profile_dimensions.any? { |k, d| k.to_s.match?(key_pattern) && parent_safe_display(d).present? }
  end

  def default_planning_focus_labels
    [
      "Transitions between activities",
      "Moments when expectations are unclear",
      "Recovery after upset",
      "Changes to the usual routine"
    ]
  end

  def fallback_best_support_lines(fn)
    [
      BestSupportLine.new(
        label: "Starting posture",
        detail: "Lead with warmth and curiosity—#{fn} is doing their best with the skills they have right now."
      ),
      BestSupportLine.new(
        label: "Strengths-first framing",
        detail: "Name what went well, even in small ways, before layering new expectations."
      )
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

  def fallback_focus_priorities
    [
      FocusPriority.new(
        focus: "Make uncertain moments more predictable",
        why_it_matters: "Predictability can lower pressure before stress has time to build.",
        what_to_try_first: "Use a short preview before transitions or new expectations."
      ),
      FocusPriority.new(
        focus: "Support recovery after mistakes",
        why_it_matters: "Recovery support often works best before more instruction is added.",
        what_to_try_first: "Give space to reset before explaining, correcting, or trying again."
      ),
      FocusPriority.new(
        focus: "Practice flexibility in low-pressure situations",
        why_it_matters: "Small practice can make change feel less sudden when real life shifts.",
        what_to_try_first: "Try tiny changes during calm moments so flexibility feels safer."
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
