# db/seeds.rb
# Creates minimal seed data for development.
# Safe to run multiple times (find_or_create_by).

puts "Seeding database..."

# --- Roles (create before users/spaces that reference them) ---

all_true = Role::AVAILABLE_PERMISSIONS.index_with { "true" }

owner_role = Roles::Common.find_or_create_by!(name: "Owner") do |r|
  r.value = "owner"
  r.permissions = all_true
end

Roles::Common.find_or_create_by!(name: "Caregiver") do |r|
  r.value = "caregiver"
  r.permissions = all_true.merge(
    "create_space" => "false",
    "update_space" => "false",
    "delete_space" => "false",
    "manage_collaborators" => "false"
  )
end

Roles::Common.find_or_create_by!(name: "Collaborator") do |r|
  r.value = "collaborator"
  r.permissions = all_true.merge(
    "create_user" => "false",
    "update_user" => "false",
    "delete_user" => "false",
    "create_space" => "false",
    "update_space" => "false",
    "delete_space" => "false",
    "update_child_profile" => "false",
    "delete_child_profile" => "false",
    "manage_collaborators" => "false"
  )
end

puts "  roles: #{Roles::Common.pluck(:name).join(', ')}"

# --- Users ---

admin = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.first_name = "Admin"
  u.last_name  = "User"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.admin = true
end
puts "  admin user: #{admin.email}"

user = User.find_or_create_by!(email: "user@example.com") do |u|
  u.first_name = "Regular"
  u.last_name  = "User"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.admin = false
end
puts "  regular user: #{user.email}"

# --- Space + membership ---

space = Space.find_or_create_by!(name: "Demo Family") do |s|
  s.status = :active
end
puts "  space: #{space.name}"

UserRole.find_or_create_by!(user: admin, space: space) do |ur|
  ur.role = owner_role
end
puts "  admin assigned owner role in #{space.name}"

# --- Assessment templates (Stage 4.5 foundation) ---

# Published templates are append-only. If the assessment changes in a meaningful way,
# create a new version instead of mutating an older published version.
load Rails.root.join("db/seeds/assessment_templates/anchor_initial_profile.rb")
load Rails.root.join("db/seeds/assessment_templates/anchor_onboarding_5_8.rb")

# --- Analysis rubrics (Stage 6) ---
# Published rubrics are versioned; create new `version` rows instead of mutating.
load Rails.root.join("db/seeds/analysis_rubrics/anchor_child_profile_v1.rb")

care_intake = AssessmentTemplate.find_or_initialize_by(template_key: "care-intake", version: 2)
  care_intake.assign_attributes(
    slug: "care-intake-v2",
    title: "Care intake",
    category: "intake",
    status: :published,
    respondent_types: %w[parent_proxy therapist_report],
    schema: {
      "version" => 1,
      "sections" => [
        {
          "id" => "goals",
          "title" => "Current goals"
        }
      ],
      "questions" => [
        {
          "id" => "primary_need",
          "section" => "goals",
          "label" => "Primary area of focus",
          "type" => "select",
          "dimension_key" => "care.primary_focus",
          "concept_key" => "current_primary_focus",
          "time_window" => "current_pattern",
          "evidence_weight" => 0.8,
          "options" => [ "Development", "Behavior", "Social", "Other" ],
          "required" => true
        },
        {
          "id" => "context",
          "section" => "goals",
          "label" => "Additional context",
          "type" => "textarea",
          "dimension_key" => "care.context",
          "concept_key" => "caregiver_context",
          "time_window" => "current_pattern",
          "evidence_weight" => 0.5,
          "extraction_hint" => "Extract care priorities, constraints, and helpful context for future recommendations.",
          "required" => false
        }
      ]
    }
  )
care_intake.save!

puts "  assessment templates: #{AssessmentTemplate.published.pluck(:slug).join(', ')}"
puts "  analysis rubrics: #{AnalysisRubric.published.pluck(:rubric_key).join(', ')}"

puts ""
puts "Done! Seed data loaded."
puts ""
puts "Login credentials:"
puts "  Admin — admin@example.com / password123"
puts "  User  — user@example.com / password123"



# AssessmentTemplate.find_or_initialize_by(template_key: "anchor_initial_profile_v1").assign_attributes(
#   "title" => "Anchor Initial Profile Assessment",
#   "slug" => "anchor-initial-profile",
#   "template_key" => "anchor_initial_profile_v1",
#   "version" => 1,
#   "category" => "onboarding",
#   "respondent_types" => [ "parent_proxy" ],
#   "status" => "published",
#   "schema" => {
#     "version" => 1,
#     "intro_title" => "Mapping Your Child's Profile",
#     "intro_body" => "This assessment helps move beyond clinical labels to understand your child's unique internal operating system, focusing on how they process the world and communicate their needs.",
#     "sections" => [
#       {
#         "id" => "comm_landscape",
#         "title" => "Communication Landscape",
#         "description" => "Understanding the gap between comprehension and expression.",
#         "transition_title" => "Next: Sensory Processing",
#         "transition_body" => "Now let's look at how your child's body perceives and reacts to their environment.",
#         "summary_title" => "Communication Profile",
#         "summary_body" => "You've provided key insights into your child's expressive and receptive language styles."
#       },
#       {
#         "id" => "sensory_system",
#         "title" => "Sensory Operating System",
#         "description" => "Mapping what drains and charges your child's 'sensory battery'.",
#         "transition_title" => "Next: Regulation & Change",
#         "transition_body" => "We'll now explore how these sensory inputs impact daily routines and transitions.",
#         "summary_title" => "Sensory Profile",
#         "summary_body" => "Your answers help identify specific sensory seek/avoid patterns."
#       },
#       {
#         "id" => "reg_transitions",
#         "title" => "Regulation & Transitions",
#         "description" => "Understanding your child's safety map and flexibility.",
#         "transition_title" => "Next: Social Joy",
#         "transition_body" => "Let's move on to how your child connects with others and their deep interests.",
#         "summary_title" => "Regulation Profile",
#         "summary_body" => "These patterns illustrate your child's need for predictability and transition support."
#       },
#       {
#         "id" => "social_glimmers",
#         "title" => "Social Interaction & Glimmers",
#         "description" => "Identifying connection points and 'monotropic' strengths.",
#         "transition_title" => "Final: Daily Living",
#         "transition_body" => "One last section regarding internal body cues and motor skills.",
#         "summary_title" => "Social & Interests Profile",
#         "summary_body" => "You've highlighted your child's unique ways of sharing joy and deep focus."
#       },
#       {
#         "id" => "daily_autonomy",
#         "title" => "Daily Living & Autonomy",
#         "description" => "How your child manages their own physical body.",
#         "summary_title" => "Assessment Complete",
#         "summary_body" => "Thank you. We are now generating your child's functional support map."
#       }
#     ],
#     "questions" => [
#       {
#         "id" => "expression_of_needs",
#         "section" => "comm_landscape",
#         "label" => "When your child wants something they cannot reach, how do they primarily communicate?",
#         "type" => "select",
#         "dimension_key" => "communication.expressive",
#         "concept_key" => "functional_communication",
#         "time_window" => "current_pattern",
#         "step_group" => "communication_basics",
#         "required" => true,
#         "evidence_weight" => 0.8,
#         "options" => [
#           { "label" => "Leads me by the hand (using me as a tool)", "value" => "hand_leading" },
#           { "label" => "Uses one-word requests or 'scripts' from shows/movies", "value" => "scripting" },
#           { "label" => "Points and uses eye contact to check in", "value" => "joint_attention_pointing" },
#           { "label" => "Becomes frustrated or upset", "value" => "frustrated_nonverbal" }
#         ]
#       },
#       {
#         "id" => "receptive_processing",
#         "section" => "comm_landscape",
#         "label" => "How does your child react to a simple, two-step instruction (e.g., 'Get your shoes and go to the door')?",
#         "type" => "select",
#         "dimension_key" => "communication.receptive",
#         "concept_key" => "processing_delay",
#         "time_window" => "current_pattern",
#         "step_group" => "communication_basics",
#         "required" => true,
#         "evidence_weight" => 0.7,
#         "options" => [
#           { "label" => "Follows it immediately", "value" => "immediate" },
#           { "label" => "Follows the first part, but loses the second", "value" => "partial_recall" },
#           { "label" => "Needs a physical gesture/pointing to understand", "value" => "visual_prompt_dependent" },
#           { "label" => "Seems to hear words but cannot translate to action yet", "value" => "processing_lag" }
#         ]
#       },
#       {
#         "id" => "auditory_load",
#         "section" => "sensory_system",
#         "label" => "How does your child react to unpredictable noise (vacuum, hand-dryer, loud parties)?",
#         "type" => "select",
#         "dimension_key" => "sensory.auditory",
#         "concept_key" => "environmental_reactivity",
#         "time_window" => "recent_pattern",
#         "step_group" => "sensory_reactivity",
#         "required" => true,
#         "evidence_weight" => 0.9,
#         "options" => [
#           { "label" => "Covers ears or tries to flee (Avoider)", "value" => "hyper_reactive_avoider" },
#           { "label" => "Becomes louder/active to 'drown out' noise (Seeker)", "value" => "sensory_seeker" },
#           { "label" => "Seems completely unfazed/doesn't hear it", "value" => "hypo_reactive" },
#           { "label" => "Seems fine in the moment but 'crashes' later", "value" => "delayed_overload" }
#         ]
#       },
#       {
#         "id" => "proprioceptive_need",
#         "section" => "sensory_system",
#         "label" => "Does your child seek out 'heavy' physical input (crashing, jumping, tight hugs)?",
#         "type" => "select",
#         "dimension_key" => "sensory.proprioception",
#         "concept_key" => "body_awareness",
#         "time_window" => "typical_week",
#         "step_group" => "sensory_reactivity",
#         "required" => true,
#         "evidence_weight" => 0.8,
#         "options" => [
#           { "label" => "Frequently/Constantly (Boundless energy)", "value" => "high_seeker" },
#           { "label" => "Occasionally, usually when stressed", "value" => "occasional_seeker" },
#           { "label" => "Rarely; prefers staying still or gentle movement", "value" => "low_seeker" },
#           { "label" => "Avoids being touched or squeezed", "value" => "tactile_avoider" }
#         ]
#       },
#       {
#         "id" => "stop_start_friction",
#         "section" => "reg_transitions",
#         "label" => "How does your child react when stopping a preferred activity (tablet, blocks)?",
#         "type" => "select",
#         "dimension_key" => "regulation.transitions",
#         "concept_key" => "activity_switching",
#         "time_window" => "recent_pattern",
#         "step_group" => "routine_flexibility",
#         "required" => true,
#         "evidence_weight" => 0.8,
#         "options" => [
#           { "label" => "Immediate emotional collapse (meltdown)", "value" => "emotional_collapse" },
#           { "label" => "Ignores the request entirely (stalling)", "value" => "stalling" },
#           { "label" => "Can transition only with specific timers/warnings", "value" => "timer_dependent" },
#           { "label" => "Transitions easily but seems 'lost' or anxious after", "value" => "anxious_transition" }
#         ]
#       },
#       {
#         "id" => "routine_predictability",
#         "section" => "reg_transitions",
#         "label" => "If a small part of the routine changes unexpectedly, how is their mood impacted?",
#         "type" => "scale",
#         "min" => 1,
#         "max" => 5,
#         "dimension_key" => "regulation.routine",
#         "concept_key" => "flexibility",
#         "time_window" => "recent_pattern",
#         "step_group" => "routine_flexibility",
#         "help_text" => "1: No impact/Enjoys novelty, 5: Significant distress",
#         "required" => true,
#         "evidence_weight" => 0.7
#       },
#       {
#         "id" => "shared_joy",
#         "section" => "social_glimmers",
#         "label" => "If your child finds something exciting, do they try to get you to look at it too?",
#         "type" => "select",
#         "dimension_key" => "social.engagement",
#         "concept_key" => "joint_attention",
#         "time_window" => "recent_pattern",
#         "step_group" => "connection_styles",
#         "required" => true,
#         "evidence_weight" => 0.8,
#         "options" => [
#           { "label" => "Yes, they bring it to me or point to it", "value" => "active_sharing" },
#           { "label" => "They enjoy it intensely but keep it to themselves", "value" => "internalized_joy" },
#           { "label" => "They show me only if I ask 'What do you have?'", "value" => "responsive_only" },
#           { "label" => "They prefer to play in a separate room from others", "value" => "solitary_preference" }
#         ]
#       },
#       {
#         "id" => "deep_interests",
#         "section" => "social_glimmers",
#         "label" => "Does your child have an 'Expert Topic' or play style they focus on for hours?",
#         "type" => "textarea",
#         "placeholder" => "e.g., Lining up cars, space, ceiling fans, specific movie scenes...",
#         "dimension_key" => "social.interests",
#         "concept_key" => "monotropism",
#         "time_window" => "current_pattern",
#         "step_group" => "connection_styles",
#         "required" => true,
#         "evidence_weight" => 0.6,
#         "extraction_hint" => "Identify if the interest is object-oriented, topic-oriented, or repetitive movement-oriented."
#       },
#       {
#         "id" => "interoception_cues",
#         "section" => "daily_autonomy",
#         "label" => "Does your child seem to know when they are hungry, thirsty, or need the bathroom?",
#         "type" => "select",
#         "dimension_key" => "daily_living.interoception",
#         "concept_key" => "internal_awareness",
#         "time_window" => "current_pattern",
#         "step_group" => "body_management",
#         "required" => true,
#         "evidence_weight" => 0.7,
#         "options" => [
#           { "label" => "Yes, communicates these needs clearly", "value" => "aware" },
#           { "label" => "Only realizes when it's an 'emergency' or meltdown", "value" => "low_awareness" },
#           { "label" => "Very high pain tolerance (doesn't cry when hurt)", "value" => "hypo_sensitive_pain" },
#           { "label" => "Hyper-aware of every small scratch or itch", "value" => "hyper_sensitive_tactile" }
#         ]
#       },
#       {
#         "id" => "motor_planning",
#         "section" => "daily_autonomy",
#         "label" => "How does your child handle complex movements (climbing stairs, using spoons, coats)?",
#         "type" => "select",
#         "dimension_key" => "daily_living.motor",
#         "concept_key" => "coordination",
#         "time_window" => "recent_pattern",
#         "step_group" => "body_management",
#         "required" => true,
#         "evidence_weight" => 0.6,
#         "options" => [
#           { "label" => "Accomplishes typical age-appropriate coordination", "value" => "typical" },
#           { "label" => "Seems 'clumsy' or frequently trips/falls", "value" => "clumsy" },
#           { "label" => "Avoids these tasks because they seem 'too hard'", "value" => "avoidant" },
#           { "label" => "Can do them, but only with intense focus and effort", "value" => "high_effort" }
#         ]
#       }
#     ]
#   }
# )
