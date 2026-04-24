# frozen_string_literal: true

module AssessmentTemplateSeeds
  module_function

  def section(id:, title:, description:, transition_title: nil, transition_body: nil, summary_title: nil, summary_body: nil)
    compact_hash(
      "id" => id,
      "title" => title,
      "description" => description,
      "transition_title" => transition_title,
      "transition_body" => transition_body,
      "summary_title" => summary_title,
      "summary_body" => summary_body
    )
  end

  def select_question(
    id:,
    label:,
    dimension_key:,
    concept_key:,
    options:,
    section: nil,
    help_text: nil,
    placeholder: nil,
    step_group: nil,
    optional_detail_prompt: nil,
    short_label: nil,
    progress_label: nil,
    required: true,
    evidence_weight: 1.0,
    extraction_hint: nil
  )
    compact_hash(
      "id" => id,
      "label" => label,
      "type" => "select",
      "dimension_key" => dimension_key,
      "concept_key" => concept_key,
      "time_window" => "lately",
      "section" => section,
      "help_text" => help_text,
      "placeholder" => placeholder,
      "step_group" => step_group,
      "optional_detail_prompt" => optional_detail_prompt,
      "short_label" => short_label,
      "progress_label" => progress_label,
      "required" => required,
      "evidence_weight" => evidence_weight,
      "options" => options,
      "extraction_hint" => extraction_hint
    )
  end

  def scale_question(
    id:,
    label:,
    dimension_key:,
    concept_key:,
    section: nil,
    help_text: nil,
    placeholder: nil,
    step_group: nil,
    optional_detail_prompt: nil,
    short_label: nil,
    progress_label: nil,
    required: true,
    evidence_weight: 1.0,
    min: 1,
    max: 5,
    extraction_hint: nil
  )
    compact_hash(
      "id" => id,
      "label" => label,
      "type" => "scale",
      "dimension_key" => dimension_key,
      "concept_key" => concept_key,
      "time_window" => "lately",
      "section" => section,
      "help_text" => help_text,
      "placeholder" => placeholder,
      "step_group" => step_group,
      "optional_detail_prompt" => optional_detail_prompt,
      "short_label" => short_label,
      "progress_label" => progress_label,
      "required" => required,
      "evidence_weight" => evidence_weight,
      "min" => min,
      "max" => max,
      "extraction_hint" => extraction_hint
    )
  end

  def text_question(
    id:,
    label:,
    dimension_key:,
    concept_key:,
    section: nil,
    help_text: nil,
    placeholder: nil,
    step_group: nil,
    optional_detail_prompt: nil,
    short_label: nil,
    progress_label: nil,
    required: true,
    evidence_weight: 1.0,
    extraction_hint: nil
  )
    compact_hash(
      "id" => id,
      "label" => label,
      "type" => "text",
      "dimension_key" => dimension_key,
      "concept_key" => concept_key,
      "time_window" => "lately",
      "section" => section,
      "help_text" => help_text,
      "placeholder" => placeholder,
      "step_group" => step_group,
      "optional_detail_prompt" => optional_detail_prompt,
      "short_label" => short_label,
      "progress_label" => progress_label,
      "required" => required,
      "evidence_weight" => evidence_weight,
      "extraction_hint" => extraction_hint
    )
  end

  def textarea_question(
    id:,
    label:,
    dimension_key:,
    concept_key:,
    section: nil,
    help_text: nil,
    placeholder: nil,
    step_group: nil,
    optional_detail_prompt: nil,
    short_label: nil,
    progress_label: nil,
    required: true,
    evidence_weight: 1.0,
    extraction_hint: nil
  )
    compact_hash(
      "id" => id,
      "label" => label,
      "type" => "textarea",
      "dimension_key" => dimension_key,
      "concept_key" => concept_key,
      "time_window" => "lately",
      "section" => section,
      "help_text" => help_text,
      "placeholder" => placeholder,
      "step_group" => step_group,
      "optional_detail_prompt" => optional_detail_prompt,
      "short_label" => short_label,
      "progress_label" => progress_label,
      "required" => required,
      "evidence_weight" => evidence_weight,
      "extraction_hint" => extraction_hint
    )
  end

  def compact_hash(hash)
    hash.reject { |_key, value| value.nil? }
  end
end

preflight_questions = [
  AssessmentTemplateSeeds.select_question(
    id: "school_setting",
    label: "What best describes your child's current school situation?",
    section: "getting_started",
    dimension_key: "context.school",
    concept_key: "school_setting",
    help_text: "Choose the option that feels most true right now.",
    short_label: "School setting",
    progress_label: "Getting started",
    step_group: "setup",
    options: [
      "General education most of the day",
      "Mix of general and special education",
      "Special education most of the day",
      "Homeschooled or alternative setting",
      "Not currently in school"
    ],
    extraction_hint: "Use as context for school-related interpretation."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "communication_starting_point",
    label: "How does your child usually communicate best right now?",
    section: "getting_started",
    dimension_key: "communication.expressive",
    concept_key: "communication_starting_point",
    help_text: "Pick the option that best matches your child's everyday communication.",
    short_label: "Communication style",
    progress_label: "Getting started",
    step_group: "setup",
    options: [
      "Mostly full sentences",
      "Short phrases",
      "Single words",
      "A mix of words, gestures, and pointing",
      "Mostly gestures, AAC, or other supports",
      "Hard to say"
    ],
    extraction_hint: "Use as communication baseline and later branching context."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "support_services",
    label: "Is your child currently receiving any supports or therapies?",
    section: "getting_started",
    dimension_key: "context.supports",
    concept_key: "current_supports_snapshot",
    help_text: "Choose the option that best fits right now.",
    short_label: "Current supports",
    progress_label: "Getting started",
    step_group: "setup",
    options: [
      "Yes, one or more supports are in place",
      "No supports right now",
      "Not sure"
    ],
    extraction_hint: "Use as current-support context, not severity."
  )
]

communication_questions = [
  AssessmentTemplateSeeds.scale_question(
    id: "expressing_needs_clarity",
    label: "When your child wants something, how clearly do they usually let you know?",
    section: "communication",
    dimension_key: "communication.expressive",
    concept_key: "expressing_needs_clarity",
    help_text: "Think about what happens on most days.",
    short_label: "Expressing needs",
    progress_label: "Communication",
    step_group: "communication_core",
    extraction_hint: "Higher values indicate clearer day-to-day expressive communication."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "understanding_directions",
    label: "How easily does your child understand everyday directions or explanations?",
    section: "communication",
    dimension_key: "communication.receptive",
    concept_key: "understanding_directions",
    help_text: "For example: simple routines, explanations, or reminders.",
    short_label: "Understanding language",
    progress_label: "Communication",
    step_group: "communication_core",
    extraction_hint: "Higher values indicate stronger receptive language in daily life."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "asking_for_help",
    label: "When something is hard, how likely is your child to ask for help in a clear way?",
    section: "communication",
    dimension_key: "communication.self_advocacy",
    concept_key: "asking_for_help",
    help_text: "Think about schoolwork, routines, or confusing moments.",
    short_label: "Asking for help",
    progress_label: "Communication",
    step_group: "communication_core",
    extraction_hint: "Higher values indicate stronger help-seeking and self-advocacy."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "back_and_forth_conversation",
    label: "How easy is it for your child to have a back-and-forth conversation with a familiar adult?",
    section: "communication",
    dimension_key: "communication.pragmatic",
    concept_key: "back_and_forth_conversation",
    help_text: "Think about whether the conversation flows, not just whether your child talks.",
    short_label: "Conversation flow",
    progress_label: "Communication",
    step_group: "communication_core",
    extraction_hint: "Higher values indicate stronger reciprocal conversation with familiar adults."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "explaining_thoughts_or_upset",
    label: "How well can your child explain what happened, what they were thinking, or why they were upset?",
    section: "communication",
    dimension_key: "communication.narrative",
    concept_key: "explaining_thoughts_or_upset",
    help_text: "This can be hard even for bright kids when emotions are involved.",
    short_label: "Explaining experiences",
    progress_label: "Communication",
    step_group: "communication_core",
    extraction_hint: "Higher values indicate stronger narrative and reflective communication."
  )
]

social_questions = [
  AssessmentTemplateSeeds.scale_question(
    id: "shares_enjoyment_with_others",
    label: "When your child is excited about something, how often do they try to share it with you or another person?",
    section: "social_connection",
    dimension_key: "social.reciprocity",
    concept_key: "shares_enjoyment_with_others",
    help_text: "For example: showing, telling, calling you over, or checking your reaction.",
    short_label: "Sharing enjoyment",
    progress_label: "Social connection",
    step_group: "social_core",
    extraction_hint: "Higher values indicate stronger social sharing and reciprocity."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "responds_to_social_bids",
    label: "How often does your child notice and respond when someone talks to them, greets them, or tries to join them?",
    section: "social_connection",
    dimension_key: "social.attunement",
    concept_key: "responds_to_social_bids",
    help_text: "Think about everyday interactions at home or school.",
    short_label: "Responding to others",
    progress_label: "Social connection",
    step_group: "social_core",
    extraction_hint: "Higher values indicate stronger social attention and response."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "peer_play_participation",
    label: "How easy is it for your child to join in, keep up with, or enjoy play with other children?",
    section: "social_connection",
    dimension_key: "social.peer_interaction",
    concept_key: "peer_play_participation",
    help_text: "Think about recess, playdates, group games, or free play.",
    short_label: "Peer play",
    progress_label: "Social connection",
    step_group: "social_core",
    extraction_hint: "Higher values indicate stronger practical peer participation."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "social_understanding",
    label: "How often does your child misunderstand what other people mean, feel, or expect socially?",
    section: "social_connection",
    dimension_key: "social.social_cognition",
    concept_key: "social_understanding",
    help_text: "For example: missing cues, taking things literally, or misreading intent.",
    short_label: "Social understanding",
    progress_label: "Social connection",
    step_group: "social_core",
    extraction_hint: "Lower values may indicate greater difficulty with social interpretation."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "free_time_social_preference",
    label: "In free time, what does your child usually prefer?",
    section: "social_connection",
    dimension_key: "social.participation_style",
    concept_key: "free_time_social_preference",
    help_text: "There is no right answer here.",
    short_label: "Free-time preference",
    progress_label: "Social connection",
    step_group: "social_core",
    options: [
      "Mostly being with others",
      "A mix of both",
      "Mostly being alone",
      "Depends a lot on the situation",
      "Hard to say"
    ],
    extraction_hint: "Use as preference/style context rather than deficit signal."
  )
]

flexibility_questions = [
  AssessmentTemplateSeeds.scale_question(
    id: "transition_difficulty",
    label: "How hard is it for your child to stop one activity and move to another?",
    section: "flexibility",
    dimension_key: "behavior.flexibility",
    concept_key: "transition_difficulty",
    help_text: "Think about daily routines, screen time, schoolwork, or leaving preferred activities.",
    short_label: "Transitions",
    progress_label: "Flexibility",
    step_group: "flexibility_core",
    extraction_hint: "Lower values indicate greater transition difficulty."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "change_in_plans_reaction",
    label: "How strongly does your child react when plans change unexpectedly?",
    section: "flexibility",
    dimension_key: "behavior.flexibility",
    concept_key: "change_in_plans_reaction",
    help_text: "For example: changes in routine, schedule, rules, or order.",
    short_label: "Change in plans",
    progress_label: "Flexibility",
    step_group: "flexibility_core",
    extraction_hint: "Lower values indicate greater distress with change."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "need_for_sameness",
    label: "How much does your child rely on things being done in a certain order or a certain way?",
    section: "flexibility",
    dimension_key: "behavior.rigidity",
    concept_key: "need_for_sameness",
    help_text: "Think about routines, preferences, or specific ways of doing things.",
    short_label: "Need for sameness",
    progress_label: "Flexibility",
    step_group: "flexibility_core",
    extraction_hint: "Lower values indicate stronger rigidity or sameness needs."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "repetitive_patterns_presence",
    label: "Does your child have repeated movements, sounds, routines, or habits they return to often?",
    section: "flexibility",
    dimension_key: "behavior.repetitive_patterns",
    concept_key: "repetitive_patterns_presence",
    help_text: "This can include repeated phrases, routines, movements, or very focused interests.",
    short_label: "Repeated patterns",
    progress_label: "Flexibility",
    step_group: "flexibility_core",
    options: [
      "Not really",
      "A little",
      "Yes, definitely",
      "Hard to say"
    ],
    extraction_hint: "Use as broad marker for repetitive or pattern-based behavior."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "uncertainty_and_mistakes_tolerance",
    label: "How hard is it for your child when they are unsure what to do or think they got something wrong?",
    section: "flexibility",
    dimension_key: "behavior.cognitive_flexibility",
    concept_key: "uncertainty_and_mistakes_tolerance",
    help_text: "Think about schoolwork, games, routines, or open-ended tasks.",
    short_label: "Handling uncertainty",
    progress_label: "Flexibility",
    step_group: "flexibility_core",
    extraction_hint: "Lower values indicate more difficulty with uncertainty, ambiguity, or mistakes."
  )
]

sensory_questions = [
  AssessmentTemplateSeeds.scale_question(
    id: "sensory_sensitivity_frequency",
    label: "How often do sounds, textures, lights, smells, clothing, or busy environments seem to bother your child more than expected?",
    section: "sensory",
    dimension_key: "sensory.sensitivity",
    concept_key: "sensory_sensitivity_frequency",
    help_text: "Think about the kinds of sensory experiences that show up in daily life.",
    short_label: "Sensory sensitivity",
    progress_label: "Sensory",
    step_group: "sensory_core",
    extraction_hint: "Lower values indicate more frequent sensory sensitivity."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "sensory_seeking_frequency",
    label: "How often does your child seek out movement, pressure, spinning, crashing, touching, or other strong sensory input?",
    section: "sensory",
    dimension_key: "sensory.seeking",
    concept_key: "sensory_seeking_frequency",
    help_text: "Think about what your child seems to crave or repeat physically.",
    short_label: "Sensory seeking",
    progress_label: "Sensory",
    step_group: "sensory_core",
    extraction_hint: "Lower values indicate more frequent sensory-seeking behavior."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "sensory_impact_on_daily_life",
    label: "When sensory things bother your child, how much do they affect daily life?",
    section: "sensory",
    dimension_key: "sensory.impact",
    concept_key: "sensory_impact_on_daily_life",
    help_text: "Think about whether sensory challenges change routines, behavior, or participation.",
    short_label: "Sensory impact",
    progress_label: "Sensory",
    step_group: "sensory_core",
    extraction_hint: "Lower values indicate greater sensory-related impact on daily life."
  )
]

regulation_questions = [
  AssessmentTemplateSeeds.scale_question(
    id: "frustration_reaction_intensity",
    label: "When something is hard or does not go as expected, how strongly does your child usually react?",
    section: "regulation",
    dimension_key: "regulation.frustration_response",
    concept_key: "frustration_reaction_intensity",
    help_text: "Think about everyday moments, not just the hardest ones.",
    short_label: "Frustration response",
    progress_label: "Regulation",
    step_group: "regulation_core",
    extraction_hint: "Lower values indicate stronger day-to-day frustration reactions."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "overwhelm_first_sign",
    label: "When your child gets overwhelmed, what usually happens first?",
    section: "regulation",
    dimension_key: "regulation.stress_pattern",
    concept_key: "overwhelm_first_sign",
    help_text: "Choose the option that feels most typical.",
    short_label: "First sign of overwhelm",
    progress_label: "Regulation",
    step_group: "regulation_core",
    options: [
      "Says no or protests",
      "Covers ears or avoids",
      "Cries",
      "Yells",
      "Gets angry",
      "Shuts down or withdraws",
      "Runs away or leaves",
      "Hard to tell"
    ],
    extraction_hint: "Use as initial stress-pattern indicator."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "recovery_after_upset",
    label: "Once upset, how easily does your child usually calm and recover?",
    section: "regulation",
    dimension_key: "regulation.recovery",
    concept_key: "recovery_after_upset",
    help_text: "Think about how hard it is to get back to a steady state.",
    short_label: "Recovery",
    progress_label: "Regulation",
    step_group: "regulation_core",
    extraction_hint: "Higher values indicate easier recovery after upset."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "hard_moments_trigger_clarity",
    label: "Do your child's hard moments usually seem linked to clear triggers?",
    section: "regulation",
    dimension_key: "regulation.trigger_pattern",
    concept_key: "hard_moments_trigger_clarity",
    help_text: "This can include things like transitions, demands, sensory overload, or being told no.",
    short_label: "Clear triggers",
    progress_label: "Regulation",
    step_group: "regulation_core",
    options: [
      "Yes, usually",
      "Sometimes",
      "Not really",
      "Hard to say"
    ],
    extraction_hint: "Use to estimate how predictable hard moments are."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "open_ended_or_unclear_demands_difficulty",
    label: "How hard is it for your child when work feels confusing, open-ended, or not black and white?",
    section: "regulation",
    dimension_key: "regulation.demand_tolerance",
    concept_key: "open_ended_or_unclear_demands_difficulty",
    help_text: "Think about schoolwork, chores, games, or social situations with no obvious answer.",
    short_label: "Open-ended demands",
    progress_label: "Regulation",
    step_group: "regulation_core",
    extraction_hint: "Lower values indicate more difficulty tolerating ambiguity and open-ended demands."
  )
]

daily_function_questions = [
  AssessmentTemplateSeeds.scale_question(
    id: "daily_routine_support_needed",
    label: "How much help does your child usually need with everyday routines like getting dressed, getting ready, or staying on task?",
    section: "daily_function",
    dimension_key: "adaptive.daily_routines",
    concept_key: "daily_routine_support_needed",
    help_text: "Think about the amount of adult support usually needed.",
    short_label: "Daily routines",
    progress_label: "Daily life",
    step_group: "daily_function_core",
    extraction_hint: "Lower values indicate greater day-to-day support needs."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "multi_step_direction_following",
    label: "How easily can your child follow a few steps in a row without getting lost or upset?",
    section: "daily_function",
    dimension_key: "adaptive.executive_function",
    concept_key: "multi_step_direction_following",
    help_text: "For example: clean up, get shoes, and come to the table.",
    short_label: "Following steps",
    progress_label: "Daily life",
    step_group: "daily_function_core",
    extraction_hint: "Higher values indicate stronger everyday multi-step follow-through."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "handling_nonpreferred_expectations",
    label: "How well does your child handle everyday expectations that are not their preferred way?",
    section: "daily_function",
    dimension_key: "adaptive.compliance_flexibility",
    concept_key: "handling_nonpreferred_expectations",
    help_text: "Think about chores, routines, transitions, and adult requests.",
    short_label: "Handling expectations",
    progress_label: "Daily life",
    step_group: "daily_function_core",
    extraction_hint: "Higher values indicate better tolerance of everyday nonpreferred expectations."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "independence_relative_to_age",
    label: "Compared with other children their age, how independent does your child seem in daily life?",
    section: "daily_function",
    dimension_key: "adaptive.independence",
    concept_key: "independence_relative_to_age",
    help_text: "Choose the option that feels closest overall.",
    short_label: "Independence",
    progress_label: "Daily life",
    step_group: "daily_function_core",
    options: [
      "More independent than expected",
      "About what I would expect",
      "A little less independent",
      "Much less independent",
      "Hard to say"
    ],
    extraction_hint: "Use as broad relative independence anchor."
  )
]

cooccurring_questions = [
  AssessmentTemplateSeeds.scale_question(
    id: "attention_or_impulsivity_interference",
    label: "How often does trouble staying focused, sitting still, or slowing down get in your child's way?",
    section: "cooccurring",
    dimension_key: "cooccurring.attention",
    concept_key: "attention_or_impulsivity_interference",
    help_text: "Think about whether this affects learning, routines, or behavior.",
    short_label: "Attention and impulsivity",
    progress_label: "Other important factors",
    step_group: "cooccurring_core",
    extraction_hint: "Lower values indicate more frequent attention or impulsivity interference."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "anxiety_or_worry_interference",
    label: "How often does worry, fear, or getting stuck on something upsetting seem to affect your child?",
    section: "cooccurring",
    dimension_key: "cooccurring.anxiety",
    concept_key: "anxiety_or_worry_interference",
    help_text: "Think about everyday moments, not just unusual ones.",
    short_label: "Worry and fear",
    progress_label: "Other important factors",
    step_group: "cooccurring_core",
    extraction_hint: "Lower values indicate more frequent anxiety-related interference."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "sleep_problem_impact",
    label: "How much do sleep problems affect your child or family right now?",
    section: "cooccurring",
    dimension_key: "cooccurring.sleep",
    concept_key: "sleep_problem_impact",
    help_text: "This includes trouble falling asleep, staying asleep, or sleep affecting daytime life.",
    short_label: "Sleep impact",
    progress_label: "Other important factors",
    step_group: "cooccurring_core",
    extraction_hint: "Lower values indicate greater sleep-related impact."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "feeding_selectivity_impact",
    label: "How much do picky eating, limited foods, or food texture issues affect daily life right now?",
    section: "cooccurring",
    dimension_key: "cooccurring.feeding",
    concept_key: "feeding_selectivity_impact",
    help_text: "Think about meals, stress, nutrition worries, or family routines.",
    short_label: "Feeding impact",
    progress_label: "Other important factors",
    step_group: "cooccurring_core",
    extraction_hint: "Lower values indicate greater feeding or selectivity impact."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "safety_concern_presence",
    label: "Are there any behaviors right now that make safety a serious concern?",
    section: "cooccurring",
    dimension_key: "cooccurring.safety",
    concept_key: "safety_concern_presence",
    help_text: "Choose the option that feels most true right now.",
    short_label: "Safety concerns",
    progress_label: "Other important factors",
    step_group: "cooccurring_core",
    options: [
      "No serious safety concerns right now",
      "Some safety concerns are present",
      "Safety feels like a major concern",
      "Prefer not to answer"
    ],
    extraction_hint: "Use to detect urgency and possible safety-focused follow-up."
  ),
  AssessmentTemplateSeeds.scale_question(
    id: "school_demand_overwhelm",
    label: "How much do schoolwork, classroom expectations, or learning demands seem to overwhelm your child right now?",
    section: "cooccurring",
    dimension_key: "cooccurring.school_friction",
    concept_key: "school_demand_overwhelm",
    help_text: "Think about daily school demands rather than isolated bad days.",
    short_label: "School overwhelm",
    progress_label: "Other important factors",
    step_group: "cooccurring_core",
    extraction_hint: "Lower values indicate greater school-related overwhelm."
  )
]

strengths_questions = [
  AssessmentTemplateSeeds.text_question(
    id: "child_joys_and_interests",
    label: "What does your child most enjoy or naturally light up around?",
    section: "strengths",
    dimension_key: "strengths.interests",
    concept_key: "child_joys_and_interests",
    help_text: "A few words is enough.",
    placeholder: "Favorite activities, topics, toys, people, or routines",
    short_label: "Interests",
    progress_label: "Strengths and priorities",
    step_group: "strengths_core",
    extraction_hint: "Use as strengths and motivation anchor for recommendations."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "most_helpful_support_style",
    label: "What is most likely to help your child engage, try, or recover after a hard moment?",
    section: "strengths",
    dimension_key: "strengths.support_fit",
    concept_key: "most_helpful_support_style",
    help_text: "Choose the option that feels most helpful most often.",
    short_label: "What helps",
    progress_label: "Strengths and priorities",
    step_group: "strengths_core",
    options: [
      "Praise or encouragement",
      "Predictable routine",
      "Favorite interests",
      "Breaks or quiet time",
      "Movement",
      "Visual supports",
      "One-on-one help",
      "Hard to say"
    ],
    extraction_hint: "Use as recommendation anchor for support fit."
  ),
  AssessmentTemplateSeeds.text_question(
    id: "best_qualities",
    label: "What are a few of your child's best qualities?",
    section: "strengths",
    dimension_key: "strengths.profile",
    concept_key: "best_qualities",
    help_text: "Think about personality, temperament, or what others appreciate about your child.",
    placeholder: "For example: curious, funny, kind, determined, creative",
    short_label: "Best qualities",
    progress_label: "Strengths and priorities",
    step_group: "strengths_core",
    extraction_hint: "Use to humanize profile and shape supportive tone."
  ),
  AssessmentTemplateSeeds.text_question(
    id: "existing_strategies_that_work",
    label: "What already works better than average for your child?",
    section: "strengths",
    dimension_key: "strengths.support_history",
    concept_key: "existing_strategies_that_work",
    help_text: "Think about routines, tools, supports, or ways adults respond.",
    placeholder: "Anything that helps your child participate, calm, or succeed",
    short_label: "What already works",
    progress_label: "Strengths and priorities",
    step_group: "strengths_core",
    extraction_hint: "Use as existing-support anchor for recommendations."
  ),
  AssessmentTemplateSeeds.select_question(
    id: "parent_top_priority",
    label: "If Anchor could help with one thing first, what would matter most right now?",
    section: "strengths",
    dimension_key: "priorities.parent_goal",
    concept_key: "parent_top_priority",
    help_text: "Choose the area that feels most important to you today.",
    short_label: "Top priority",
    progress_label: "Strengths and priorities",
    step_group: "strengths_core",
    options: [
      "Communication",
      "Social connection",
      "Transitions or flexibility",
      "Sensory struggles",
      "Meltdowns or overwhelm",
      "School challenges",
      "Independence or daily routines",
      "Behavior or safety",
      "Sleep or eating",
      "I am not sure yet"
    ],
    extraction_hint: "Use as first-priority anchor for recommendations and next goals."
  ),
  AssessmentTemplateSeeds.text_question(
    id: "parent_goal_in_own_words",
    label: "In your own words, what do you most want your child to be able to do more easily?",
    section: "strengths",
    dimension_key: "priorities.parent_goal",
    concept_key: "parent_goal_in_own_words",
    help_text: "A sentence or two is enough.",
    placeholder: "For example: handle changes better, ask for help, join peers more easily",
    short_label: "Parent goal",
    progress_label: "Strengths and priorities",
    step_group: "strengths_core",
    extraction_hint: "Use as custom goal and recommendation anchor."
  )
]

all_questions = preflight_questions +
  communication_questions +
  social_questions +
  flexibility_questions +
  sensory_questions +
  regulation_questions +
  daily_function_questions +
  cooccurring_questions +
  strengths_questions

anchor_onboarding_5_8 = AssessmentTemplate.find_or_initialize_by(
  template_key: "anchor_onboarding_5_8",
  version: 1
)

anchor_onboarding_5_8.assign_attributes(
  "title" => "Anchor Onboarding Profile (Ages 5-8)",
  "slug" => "anchor-onboarding-5-8-v1",
  "template_key" => "anchor_onboarding_5_8",
  "version" => 1,
  "category" => "onboarding",
  "respondent_types" => [ "parent_proxy" ],
  "status" => "published",
  "schema" => {
    "version" => 1,
    "intro_title" => "Let's build your child's first support profile",
    "intro_body" => "You'll answer a short set of questions about how your child communicates, handles daily life, and experiences the world. There are no perfect answers--just choose what feels most true lately.",
    "sections" => [
      AssessmentTemplateSeeds.section(
        id: "getting_started",
        title: "Getting started",
        description: "A few quick questions so we can tailor the rest of the assessment.",
        transition_title: "First, a little context",
        transition_body: "These quick questions help Anchor make the next steps feel more relevant.",
        summary_title: "Helpful starting context",
        summary_body: "This gives us a basic picture of your child's current situation before we look at daily patterns."
      ),
      AssessmentTemplateSeeds.section(
        id: "communication",
        title: "Communication",
        description: "How your child understands language and lets others know what they need.",
        transition_title: "Now let's talk about communication",
        transition_body: "We'll focus on how your child understands, expresses, and explains things in everyday life.",
        summary_title: "Communication gives us a strong starting signal",
        summary_body: "How a child understands and expresses themselves often shapes frustration, learning, and support needs."
      ),
      AssessmentTemplateSeeds.section(
        id: "social_connection",
        title: "Social connection",
        description: "How your child connects, responds, and engages with other people.",
        transition_title: "Next, social connection",
        transition_body: "This section looks at how your child shares, responds, and joins with others.",
        summary_title: "Social patterns matter in daily life",
        summary_body: "These answers help us understand how your child connects with adults and peers in real settings."
      ),
      AssessmentTemplateSeeds.section(
        id: "flexibility",
        title: "Flexibility",
        description: "How your child handles change, routines, uncertainty, and repeated patterns.",
        transition_title: "Now let's look at flexibility",
        transition_body: "We'll ask about transitions, routines, and how your child handles change or uncertainty.",
        summary_title: "Flexibility shapes many hard moments",
        summary_body: "Transitions, routine changes, and uncertainty can have a big impact on stress and participation."
      ),
      AssessmentTemplateSeeds.section(
        id: "sensory",
        title: "Sensory experience",
        description: "How sounds, textures, movement, and other sensory input affect your child.",
        transition_title: "Let's look at sensory experience",
        transition_body: "This section helps us understand whether sensory experiences are helping, bothering, or driving behavior.",
        summary_title: "Sensory patterns can explain a lot",
        summary_body: "Sensory differences often change how a child feels, behaves, and copes in daily environments."
      ),
      AssessmentTemplateSeeds.section(
        id: "regulation",
        title: "Regulation",
        description: "How your child responds to stress, frustration, and overwhelm.",
        transition_title: "Now let's talk about regulation",
        transition_body: "We'll focus on what happens when things feel hard, confusing, or too much.",
        summary_title: "Regulation patterns help guide support",
        summary_body: "Understanding triggers, stress signs, and recovery helps Anchor suggest what may help most."
      ),
      AssessmentTemplateSeeds.section(
        id: "daily_function",
        title: "Daily life",
        description: "How your child manages routines, directions, and everyday expectations.",
        transition_title: "Next, daily life",
        transition_body: "This section looks at practical day-to-day functioning at home and beyond.",
        summary_title: "Daily life matters just as much as traits",
        summary_body: "These questions help us understand how much support your child needs in real routines."
      ),
      AssessmentTemplateSeeds.section(
        id: "cooccurring",
        title: "Other important factors",
        description: "A few quick questions about attention, anxiety, sleep, feeding, safety, and school strain.",
        transition_title: "A few other important factors",
        transition_body: "These questions stay brief, but they can make a big difference in daily life and recommendations.",
        summary_title: "These factors often change the picture",
        summary_body: "Attention, sleep, feeding, safety, and school stress can strongly shape what support will help most."
      ),
      AssessmentTemplateSeeds.section(
        id: "strengths",
        title: "Strengths and priorities",
        description: "What your child enjoys, what already helps, and what matters most to you right now.",
        transition_title: "We'll finish with strengths and priorities",
        transition_body: "This helps Anchor see your child as a whole person and focus on what matters most to your family.",
        summary_title: "This is where the profile becomes personal",
        summary_body: "Your child's strengths, motivators, and your goals help Anchor turn insight into useful next steps."
      )
    ],
    "questions" => all_questions
  }
)

anchor_onboarding_5_8.save!
