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
child_onboarding = AssessmentTemplate.find_or_initialize_by(template_key: "child-onboarding", version: 1)
child_onboarding.assign_attributes(
  slug: "child-onboarding-v1",
  title: "Child onboarding",
  category: "onboarding",
  status: :published,
  respondent_types: [ "parent_proxy" ],
  schema: {
    "version" => 1,
    "intro_title" => "Let's build your child's starting profile",
    "intro_body" => "This onboarding helps Anchor learn how your child experiences the world right now so it can surface better recommendations over time.",
    "sections" => [
      {
        "id" => "regulation",
        "title" => "Regulation and recovery"
      },
      {
        "id" => "sensory",
        "title" => "Sensory experiences"
      },
      {
        "id" => "communication",
        "title" => "Communication and connection"
      }
    ],
    "questions" => [
      {
        "id" => "overwhelm_frequency",
        "section" => "regulation",
        "label" => "How often does your child become overwhelmed during a typical week?",
        "help_text" => "Think about shutdowns, meltdowns, or moments where they struggle to recover.",
        "type" => "scale",
        "dimension_key" => "regulation.overwhelm_frequency",
        "concept_key" => "weekly_overwhelm_frequency",
        "time_window" => "typical_week",
        "evidence_weight" => 0.9,
        "min" => 1,
        "max" => 5,
        "required" => true
      },
      {
        "id" => "recovery_supports",
        "section" => "regulation",
        "label" => "What usually helps your child recover after a hard moment?",
        "help_text" => "Share anything that reliably helps, even if it seems small.",
        "type" => "textarea",
        "dimension_key" => "regulation.recovery_supports",
        "concept_key" => "effective_recovery_supports",
        "time_window" => "recent_pattern",
        "evidence_weight" => 0.7,
        "extraction_hint" => "Extract concrete supports, tools, routines, or sensory inputs that appear to help the child regulate.",
        "required" => false
      },
      {
        "id" => "sound_sensitivity",
        "section" => "sensory",
        "label" => "How sensitive is your child to sound in busy environments?",
        "help_text" => "Examples: cafeterias, playgrounds, birthday parties, stores.",
        "type" => "scale",
        "dimension_key" => "sensory.sound_sensitivity",
        "concept_key" => "busy_environment_sound_sensitivity",
        "time_window" => "typical_week",
        "evidence_weight" => 0.8,
        "min" => 1,
        "max" => 5,
        "required" => true
      },
      {
        "id" => "sensory_triggers",
        "section" => "sensory",
        "label" => "Which situations are most likely to overload your child right now?",
        "help_text" => "Choose the closest fit for what you are seeing most often lately.",
        "type" => "select",
        "dimension_key" => "sensory.common_triggers",
        "concept_key" => "primary_overload_trigger_context",
        "time_window" => "recent_pattern",
        "evidence_weight" => 0.75,
        "options" => [ "Noise", "Transitions", "Crowds", "Unexpected changes", "Not sure yet" ],
        "required" => true
      },
      {
        "id" => "connection_style",
        "section" => "communication",
        "label" => "When your child wants something important, how do they usually communicate it?",
        "help_text" => "Pick the option that is most typical right now.",
        "type" => "select",
        "dimension_key" => "communication.primary_expression_style",
        "concept_key" => "primary_need_communication_style",
        "time_window" => "current_pattern",
        "evidence_weight" => 0.8,
        "options" => [ "Words or phrases", "Gestures", "Bringing or showing", "Behavior or distress", "Mixed / depends" ],
        "required" => true
      },
      {
        "id" => "child_strengths",
        "section" => "communication",
        "label" => "What feels especially strong, joyful, or easy for your child right now?",
        "help_text" => "This could be interests, routines, relationships, skills, or moments that light them up.",
        "type" => "textarea",
        "dimension_key" => "strengths.current_strengths",
        "concept_key" => "caregiver_reported_strengths",
        "time_window" => "current_pattern",
        "evidence_weight" => 0.6,
        "extraction_hint" => "Extract strengths, motivators, and positive supports the caregiver identifies as meaningful.",
        "required" => false
      }
    ]
  }
)
child_onboarding.save!

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

puts ""
puts "Done! Seed data loaded."
puts ""
puts "Login credentials:"
puts "  Admin — admin@example.com / password123"
puts "  User  — user@example.com / password123"
