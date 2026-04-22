# frozen_string_literal: true

# Minimal template using real question ids from `anchor_functional_profile` v2:
# `stop_start_friction` → conditional `transition_recovery_time` (visible when
# answer is `emotional_collapse`). Used by Stage 4.8 Step 9 full-stack specs.
FRICTION_TRANSITION_E2E_SCHEMA = {
  "version" => 1,
  "sections" => [
    { "id" => "reg_transitions", "title" => "Regulation" }
  ],
  "questions" => [
    {
      "id" => "stop_start_friction",
      "label" => "How do they react when it is time to stop a preferred activity?",
      "type" => "select",
      "section" => "reg_transitions",
      "dimension_key" => "regulation.transitions",
      "concept_key" => "set_shifting",
      "time_window" => "recent_pattern",
      "evidence_weight" => 0.8,
      "required" => true,
      "options" => [
        { "label" => "Immediate emotional collapse (meltdown)", "value" => "emotional_collapse" },
        { "label" => "Ignores the request entirely (stalling)", "value" => "stalling" }
      ]
    },
    {
      "id" => "transition_recovery_time",
      "label" => "When a meltdown happens during a transition, how long does it typically take for them to recover?",
      "type" => "select",
      "section" => "reg_transitions",
      "dimension_key" => "regulation.recovery",
      "concept_key" => "emotional_recovery_duration",
      "time_window" => "typical_week",
      "evidence_weight" => 0.7,
      "required" => false,
      "visible_if" => { "question_id" => "stop_start_friction", "equals" => "emotional_collapse" },
      "options" => [
        { "label" => "Under 5 minutes with comfort", "value" => "quick_recovery" },
        { "label" => "10-20 minutes; needs quiet space", "value" => "moderate_recovery" }
      ]
    },
    {
      "id" => "friction_closing",
      "label" => "Anything else about transitions?",
      "type" => "textarea",
      "section" => "reg_transitions",
      "dimension_key" => "regulation.notes",
      "concept_key" => "transition_notes",
      "time_window" => "recent_pattern",
      "evidence_weight" => 0.5,
      "required" => false
    }
  ]
}.freeze
