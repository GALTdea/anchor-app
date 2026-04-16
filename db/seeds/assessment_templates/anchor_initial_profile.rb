# frozen_string_literal: true

anchor_onboarding = AssessmentTemplate.find_or_initialize_by(
  template_key: "child-onboarding",
  version: 2
)

anchor_onboarding.assign_attributes(
  slug: "anchor-initial-profile-v2",
  title: "Anchor Initial Profile Assessment",
  category: "onboarding",
  status: :published,
  respondent_types: [ "parent_proxy" ],
  schema: {
    "version" => 1,
    "intro_title" => "Building Your Child's Functional Map",
    "intro_body" => "Beyond a diagnosis, every child has a unique internal operating system. This 10-minute assessment helps us identify your child's specific sensory needs, communication style, and strengths so we can surface useful support strategies right away.",
    "sections" => [
      {
        "id" => "comm",
        "title" => "Communication & Understanding",
        "description" => "How your child shares their world and processes yours.",
        "transition_title" => "Moving to Sensory Needs",
        "transition_body" => "Communication is only half the story. Now let's look at how your child's body perceives the environment.",
        "summary_title" => "Communication Summary",
        "summary_body" => "You've identified how your child bridges the gap between their thoughts and their environment."
      },
      {
        "id" => "sensory",
        "title" => "The Sensory System",
        "description" => "Mapping what drains and charges your child's battery.",
        "transition_title" => "Regulation and Change",
        "transition_body" => "Next, we'll look at how sensory input impacts daily transitions and routines.",
        "summary_title" => "Sensory Profile Complete",
        "summary_body" => "Understanding these hidden inputs is the first step in reducing daily overwhelm."
      },
      {
        "id" => "reg",
        "title" => "Regulation & Joy",
        "description" => "Understanding your child's flexibility and what brings them the most engagement.",
        "summary_title" => "Profile Map Generated",
        "summary_body" => "We have enough to build your child's initial support profile."
      }
    ],
    "questions" => [
      {
        "id" => "needs_communication",
        "section" => "comm",
        "label" => "How does your child primarily let you know they want something out of reach?",
        "help_text" => "Think about a favorite snack or toy.",
        "type" => "select",
        "dimension_key" => "communication.expressive",
        "concept_key" => "functional_communication",
        "time_window" => "current_pattern",
        "step_group" => "comm_flow",
        "required" => true,
        "evidence_weight" => 0.8,
        "options" => [
          { "label" => "Leads me to it by the hand (using me as a tool)", "value" => "hand_leading" },
          { "label" => "Uses one-word requests or scripts from shows", "value" => "scripting" },
          { "label" => "Points and makes eye contact to ensure I see", "value" => "joint_attention" },
          { "label" => "Becomes frustrated or upset", "value" => "frustration_based" }
        ]
      },
      {
        "id" => "receptive_processing",
        "section" => "comm",
        "label" => "When you give a two-step instruction, what happens?",
        "help_text" => "Example: Get your shoes and wait by the door.",
        "type" => "select",
        "dimension_key" => "communication.receptive",
        "concept_key" => "processing_speed",
        "time_window" => "current_pattern",
        "step_group" => "comm_flow",
        "required" => true,
        "evidence_weight" => 0.7,
        "options" => [
          { "label" => "Follows both steps immediately", "value" => "typical" },
          { "label" => "Follows the first part, but loses the second", "value" => "limited_working_memory" },
          { "label" => "Needs a physical gesture to understand", "value" => "visual_dependent" },
          { "label" => "Seems to hear me but cannot translate it to action", "value" => "processing_lag" }
        ]
      },
      {
        "id" => "auditory_load",
        "section" => "sensory",
        "label" => "How does your child react to unpredictable noise?",
        "help_text" => "Examples: vacuum, hand dryers, or blenders.",
        "type" => "select",
        "dimension_key" => "sensory.auditory",
        "concept_key" => "sensory_reactivity",
        "time_window" => "recent_pattern",
        "step_group" => "sensory_profile",
        "required" => true,
        "evidence_weight" => 0.9,
        "options" => [
          { "label" => "Covers ears or tries to flee", "value" => "hyper_reactive" },
          { "label" => "Becomes louder or more active to drown it out", "value" => "sensory_seeking" },
          { "label" => "Seems completely unfazed or does not notice", "value" => "hypo_reactive" },
          { "label" => "Seems fine in the moment but crashes later", "value" => "delayed_overload" }
        ]
      },
      {
        "id" => "proprioceptive_seeking",
        "section" => "sensory",
        "label" => "Does your child seek out heavy physical input?",
        "type" => "scale",
        "min" => 1,
        "max" => 5,
        "dimension_key" => "sensory.proprioception",
        "concept_key" => "body_awareness",
        "time_window" => "typical_week",
        "step_group" => "sensory_profile",
        "required" => true,
        "evidence_weight" => 0.8,
        "help_text" => "1 = Never, 5 = Constant seeking",
        "progress_label" => "Body Awareness"
      },
      {
        "id" => "interoception_cues",
        "section" => "sensory",
        "label" => "Does your child seem to know when they are hungry, thirsty, or hurt?",
        "type" => "select",
        "dimension_key" => "sensory.interoception",
        "concept_key" => "internal_cues",
        "time_window" => "current_pattern",
        "required" => false,
        "evidence_weight" => 0.6,
        "options" => [
          { "label" => "Yes, communicates needs clearly", "value" => "aware" },
          { "label" => "Only realizes when it becomes urgent or overwhelming", "value" => "low_awareness" },
          { "label" => "High pain tolerance or limited pain response", "value" => "hyposensitive_pain" }
        ]
      },
      {
        "id" => "transition_friction",
        "section" => "reg",
        "label" => "What is the hardest transition of the day?",
        "type" => "select",
        "dimension_key" => "regulation.transitions",
        "concept_key" => "flexibility",
        "time_window" => "typical_week",
        "step_group" => "reg_flow",
        "required" => true,
        "evidence_weight" => 0.8,
        "options" => [
          { "label" => "Waking up or starting the day", "value" => "morning" },
          { "label" => "Leaving the house", "value" => "departures" },
          { "label" => "Stopping a favorite activity", "value" => "disengagement" },
          { "label" => "Bedtime routine", "value" => "evening" }
        ]
      },
      {
        "id" => "routine_rigidity",
        "section" => "reg",
        "label" => "If a small part of a routine changes unexpectedly, how does it impact them?",
        "type" => "scale",
        "min" => 1,
        "max" => 5,
        "dimension_key" => "regulation.predictability",
        "concept_key" => "adaptive_loading",
        "time_window" => "recent_pattern",
        "step_group" => "reg_flow",
        "required" => true,
        "evidence_weight" => 0.7,
        "help_text" => "1 = No reaction, 5 = Extreme distress",
        "progress_label" => "Flexibility"
      },
      {
        "id" => "monotropic_interests",
        "section" => "reg",
        "label" => "Does your child have a deep-dive interest they could focus on for hours?",
        "placeholder" => "Example: trains, ceiling fans, space, or certain movie scenes",
        "type" => "textarea",
        "dimension_key" => "interests.monotropism",
        "concept_key" => "specialized_focus",
        "time_window" => "current_pattern",
        "required" => true,
        "evidence_weight" => 0.5,
        "extraction_hint" => "Extract the primary subject of interest and whether it is a physical object, topic, or repetitive action."
      },
      {
        "id" => "joint_attention_joy",
        "section" => "reg",
        "label" => "If your child finds something exciting, do they try to get you to look at it too?",
        "type" => "select",
        "dimension_key" => "social.engagement",
        "concept_key" => "joint_attention",
        "time_window" => "recent_pattern",
        "required" => true,
        "evidence_weight" => 0.8,
        "options" => [
          { "label" => "Yes, they bring it to me or point", "value" => "active_sharing" },
          { "label" => "They enjoy it intensely but keep it to themselves", "value" => "internalized_joy" },
          { "label" => "They only show me if I ask", "value" => "responsive_only" }
        ]
      }
    ]
  }
)

anchor_onboarding.save!
AppSettings.write_setting!("onboarding_assessment_template_id", anchor_onboarding.id.to_s)
