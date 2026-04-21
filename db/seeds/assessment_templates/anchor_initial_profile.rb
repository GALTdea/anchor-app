# frozen_string_literal: true

# V1: Original 10-question linear assessment
anchor_onboarding_v1 = AssessmentTemplate.find_or_initialize_by(
  template_key: "anchor_functional_profile_v1"
)

anchor_onboarding_v1.assign_attributes(
  "title" => "Anchor Functional Support Profile",
  "slug" => "anchor-functional-profile",
  "template_key" => "anchor_functional_profile_v1",
  "version" => 1,
  "category" => "onboarding",
  "respondent_types" => [ "parent_proxy" ],
  "status" => "published",
  "schema" => {
    "version" => 1,
    "intro_title" => "Mapping Your Child's Profile",
    "intro_body" => "Welcome to Anchor. This assessment helps move beyond clinical labels to map your child's functional needs, sensory preferences, and communication style.",
    "sections" => [
      {
        "id" => "comm_landscape",
        "title" => "The Communication Landscape",
        "description" => "Understanding the gap between what your child understands and how they express needs.",
        "transition_title" => "Next: Sensory Processing",
        "transition_body" => "Great. Now let's look at how your child's body perceives their environment.",
        "summary_title" => "Communication Overview",
        "summary_body" => "You've provided key insights into your child's expressive and receptive language styles."
      },
      {
        "id" => "sensory_os",
        "title" => "The Sensory Operating System",
        "description" => "Mapping the sensory battery that impacts your child's energy levels.",
        "transition_title" => "Next: Regulation",
        "transition_body" => "Next, we'll explore how these patterns impact daily transitions and routines.",
        "summary_title" => "Sensory Overview",
        "summary_body" => "These sensory markers help identify potential triggers for overload or seeking behaviors."
      },
      {
        "id" => "reg_transitions",
        "title" => "Regulation & Transitions",
        "description" => "Understanding safety, flexibility, and the impact of change.",
        "transition_title" => "Next: Social Connection",
        "transition_body" => "Now let's look at how your child connects with others and where their joy lives.",
        "summary_title" => "Regulation Overview",
        "summary_body" => "Predictability and transition support appear to be core factors in your child's daily flow."
      },
      {
        "id" => "social_glimmers",
        "title" => "Social Interaction & Glimmers",
        "description" => "Focusing on connection, shared joy, and deep interests.",
        "transition_title" => "Final: Daily Living",
        "transition_body" => "One last section regarding internal body cues and motor coordination.",
        "summary_title" => "Connection Overview",
        "summary_body" => "Focusing on glimmers helps us leverage your child's natural strengths for learning."
      },
      {
        "id" => "daily_autonomy",
        "title" => "Daily Living & Autonomy",
        "description" => "How your child manages their own body and internal sensations.",
        "summary_title" => "Profile Map Ready",
        "summary_body" => "Thank you. We are now generating your child's functional support map."
      }
    ],
    "questions" => [
      {
        "id" => "expression_of_needs",
        "section" => "comm_landscape",
        "label" => "How does your child primarily communicate a need they can't reach (like a favorite snack)?",
        "type" => "select",
        "dimension_key" => "communication.expressive",
        "concept_key" => "functional_communication",
        "time_window" => "current_pattern",
        "step_group" => "comm_basics",
        "required" => true,
        "evidence_weight" => 0.8,
        "options" => [
          { "label" => "Leads me to the item by the hand (using me as a tool)", "value" => "hand_leading" },
          { "label" => "Uses one-word requests or scripts from media", "value" => "scripting" },
          { "label" => "Points and uses eye contact to check in", "value" => "joint_attention_pointing" },
          { "label" => "Becomes frustrated or upset", "value" => "frustration_based" }
        ]
      },
      {
        "id" => "receptive_processing",
        "section" => "comm_landscape",
        "label" => "How do they react to a simple, two-step instruction (e.g., 'Get your shoes and go to the door')?",
        "type" => "select",
        "dimension_key" => "communication.receptive",
        "concept_key" => "processing_delay",
        "time_window" => "current_pattern",
        "step_group" => "comm_basics",
        "required" => true,
        "evidence_weight" => 0.7,
        "options" => [
          { "label" => "Follows it immediately", "value" => "immediate" },
          { "label" => "Follows the first part, but loses the second", "value" => "partial_recall" },
          { "label" => "Needs a physical gesture (pointing) to understand", "value" => "visual_prompt_dependent" },
          { "label" => "Seems to hear words but cannot translate to action yet", "value" => "processing_lag" }
        ]
      },
      {
        "id" => "auditory_load",
        "section" => "sensory_os",
        "label" => "How does your child react to unpredictable noise (vacuum, hand-dryer)?",
        "type" => "select",
        "dimension_key" => "sensory.auditory",
        "concept_key" => "sensory_reactivity",
        "time_window" => "recent_pattern",
        "step_group" => "sensory_profile",
        "required" => true,
        "evidence_weight" => 0.9,
        "options" => [
          { "label" => "Covers ears or tries to flee (Avoider)", "value" => "avoider" },
          { "label" => "Becomes louder/active to 'drown out' noise (Seeker)", "value" => "seeker" },
          { "label" => "Seems completely unfazed/doesn't notice", "value" => "hypo_reactive" },
          { "label" => "Seems fine in the moment but has a crash later", "value" => "delayed_overload" }
        ]
      },
      {
        "id" => "proprioceptive_need",
        "section" => "sensory_os",
        "label" => "Does your child seek out heavy physical input (crashing, jumping, tight hugs)?",
        "type" => "select",
        "dimension_key" => "sensory.proprioception",
        "concept_key" => "body_awareness",
        "time_window" => "typical_week",
        "step_group" => "sensory_profile",
        "required" => true,
        "evidence_weight" => 0.8,
        "options" => [
          { "label" => "Frequently/Constantly (Boundless energy)", "value" => "high_seeker" },
          { "label" => "Occasionally, usually when stressed", "value" => "intermittent_seeker" },
          { "label" => "Rarely; prefers still or gentle movement", "value" => "low_seeker" },
          { "label" => "Avoids being touched or squeezed", "value" => "tactile_avoider" }
        ]
      },
      {
        "id" => "stop_start_friction",
        "section" => "reg_transitions",
        "label" => "How do they react when it is time to stop a preferred activity?",
        "type" => "select",
        "dimension_key" => "regulation.transitions",
        "concept_key" => "set_shifting",
        "time_window" => "recent_pattern",
        "step_group" => "flexibility",
        "required" => true,
        "evidence_weight" => 0.8,
        "options" => [
          { "label" => "Immediate emotional collapse (meltdown)", "value" => "emotional_collapse" },
          { "label" => "Ignores the request entirely (stalling)", "value" => "stalling" },
          { "label" => "Only transitions with specific timers or warnings", "value" => "timer_dependent" },
          { "label" => "Transitions easily but seems lost or anxious after", "value" => "anxious_post_transition" }
        ]
      },
      {
        "id" => "routine_predictability",
        "section" => "reg_transitions",
        "label" => "How does an unexpected change in routine (like a new route home) impact their mood?",
        "type" => "select",
        "dimension_key" => "regulation.routine",
        "concept_key" => "predictability_need",
        "time_window" => "typical_week",
        "step_group" => "flexibility",
        "required" => true,
        "evidence_weight" => 0.7,
        "options" => [
          { "label" => "Significant distress; needs things just so", "value" => "high_rigidity" },
          { "label" => "Mild confusion, but can be redirected", "value" => "moderate_flexibility" },
          { "label" => "Does not seem to notice the change", "value" => "low_awareness" },
          { "label" => "Enjoys the novelty or change", "value" => "high_flexibility" }
        ]
      },
      {
        "id" => "shared_joy",
        "section" => "social_glimmers",
        "label" => "If they find something exciting, do they try to get you to look at it too?",
        "type" => "select",
        "dimension_key" => "social.engagement",
        "concept_key" => "joint_attention",
        "time_window" => "recent_pattern",
        "step_group" => "social_connection",
        "required" => true,
        "evidence_weight" => 0.8,
        "options" => [
          { "label" => "Yes, they bring it or point to it", "value" => "active_sharing" },
          { "label" => "They enjoy it intensely but keep it to themselves", "value" => "internalized_sharing" },
          { "label" => "They show me only if I ask 'What do you have?'", "value" => "responsive_only" },
          { "label" => "They prefer to play in a separate room", "value" => "solitary_preference" }
        ]
      },
      {
        "id" => "deep_interests",
        "section" => "social_glimmers",
        "label" => "Does your child have an Expert Topic or play style they focus on for hours?",
        "type" => "select",
        "dimension_key" => "social.interests",
        "concept_key" => "monotropism",
        "time_window" => "current_pattern",
        "step_group" => "social_connection",
        "required" => true,
        "evidence_weight" => 0.6,
        "options" => [
          { "label" => "Yes, and it is hard to pull them away", "value" => "intense_monotropism" },
          { "label" => "They have interests, but they shift frequently", "value" => "shifting_interests" },
          { "label" => "No deep-dive interest yet; play is scattered", "value" => "low_monotropism" },
          { "label" => "Interest is mainly physical (running/climbing)", "value" => "vestibular_focus" }
        ]
      },
      {
        "id" => "interoception_cues",
        "section" => "daily_autonomy",
        "label" => "Does your child know when they are hungry, thirsty, or need the bathroom?",
        "type" => "select",
        "dimension_key" => "daily_living.interoception",
        "concept_key" => "internal_awareness",
        "time_window" => "current_pattern",
        "step_group" => "body_management",
        "required" => true,
        "evidence_weight" => 0.7,
        "options" => [
          { "label" => "Yes, communicates these needs clearly", "value" => "high_awareness" },
          { "label" => "Only realizes when it's an emergency or meltdown", "value" => "low_awareness" },
          { "label" => "Very high pain tolerance (doesn't cry when hurt)", "value" => "hypo_sensitive_pain" },
          { "label" => "Hyper-aware of every small scratch or itch", "value" => "hyper_sensitive" }
        ]
      },
      {
        "id" => "motor_planning",
        "section" => "daily_autonomy",
        "label" => "How does your child handle complex movements (stairs, spoons, coats)?",
        "type" => "select",
        "dimension_key" => "daily_living.motor",
        "concept_key" => "coordination",
        "time_window" => "recent_pattern",
        "step_group" => "body_management",
        "required" => true,
        "evidence_weight" => 0.6,
        "options" => [
          { "label" => "Typical age-appropriate coordination", "value" => "typical" },
          { "label" => "Seems clumsy or frequently trips/falls", "value" => "clumsy" },
          { "label" => "Avoids these tasks because they seem too hard", "value" => "avoidant" },
          { "label" => "Can do them, but only with intense focus", "value" => "high_effort" }
        ]
      }
    ]
  }
)

anchor_onboarding_v1.save! unless anchor_onboarding_v1.persisted?

# V2: Same 10 questions + 3 adaptive follow-ups with visible_if
anchor_onboarding_v2 = AssessmentTemplate.find_or_initialize_by(
  template_key: "anchor_functional_profile_v2"
)

v2_questions = anchor_onboarding_v1.schema["questions"].deep_dup

# Add conditional follow-up questions
v2_questions << {
  "id" => "transition_recovery_time",
  "section" => "reg_transitions",
  "label" => "When a meltdown happens during a transition, how long does it typically take for them to recover?",
  "type" => "select",
  "dimension_key" => "regulation.recovery",
  "concept_key" => "emotional_recovery_duration",
  "time_window" => "typical_week",
  "step_group" => "flexibility",
  "required" => false,
  "evidence_weight" => 0.7,
  "visible_if" => { "question_id" => "stop_start_friction", "equals" => "emotional_collapse" },
  "options" => [
    { "label" => "Under 5 minutes with comfort", "value" => "quick_recovery" },
    { "label" => "10-20 minutes; needs quiet space", "value" => "moderate_recovery" },
    { "label" => "30+ minutes; hard to console", "value" => "slow_recovery" },
    { "label" => "Rest of the day is impacted", "value" => "extended_dysregulation" }
  ]
}

v2_questions << {
  "id" => "auditory_coping",
  "section" => "sensory_os",
  "label" => "What helps your child cope when they encounter overwhelming noise?",
  "type" => "select",
  "dimension_key" => "sensory.coping_strategies",
  "concept_key" => "sensory_regulation_tools",
  "time_window" => "recent_pattern",
  "step_group" => "sensory_profile",
  "required" => false,
  "evidence_weight" => 0.6,
  "visible_if" => {
    "any" => [
      { "question_id" => "auditory_load", "equals" => "avoider" },
      { "question_id" => "auditory_load", "equals" => "delayed_overload" }
    ]
  },
  "options" => [
    { "label" => "Headphones or ear defenders", "value" => "noise_canceling" },
    { "label" => "Moving to a quiet space", "value" => "escape_to_quiet" },
    { "label" => "Physical pressure (tight hug, weighted item)", "value" => "proprioceptive_input" },
    { "label" => "Nothing helps; must wait it out", "value" => "no_effective_strategy" }
  ]
}

v2_questions << {
  "id" => "frustration_deescalation",
  "section" => "comm_landscape",
  "label" => "When frustration builds because they can't express what they need, what helps most?",
  "type" => "select",
  "dimension_key" => "communication.regulation",
  "concept_key" => "deescalation_strategies",
  "time_window" => "recent_pattern",
  "step_group" => "comm_basics",
  "required" => false,
  "evidence_weight" => 0.7,
  "visible_if" => { "question_id" => "expression_of_needs", "equals" => "frustration_based" },
  "options" => [
    { "label" => "Visual supports (pictures, choice boards)", "value" => "visual_supports" },
    { "label" => "Physical comfort and waiting", "value" => "coregulation" },
    { "label" => "Offering specific options verbally", "value" => "structured_choices" },
    { "label" => "Distraction or change of environment", "value" => "environmental_shift" }
  ]
}

anchor_onboarding_v2.assign_attributes(
  "title" => "Anchor Functional Support Profile",
  "slug" => "anchor-functional-profile-v2",
  "template_key" => "anchor_functional_profile_v2",
  "version" => 2,
  "category" => "onboarding",
  "respondent_types" => [ "parent_proxy" ],
  "status" => "published",
  "schema" => anchor_onboarding_v1.schema.deep_dup.merge(
    "questions" => v2_questions
  )
)

anchor_onboarding_v2.save! unless anchor_onboarding_v2.persisted?

# Point AppSettings to v2
AppSettings.write_setting!("onboarding_assessment_template_id", anchor_onboarding_v2.id.to_s)
