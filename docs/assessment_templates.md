# Assessment Template Seeds

Use this runbook when adding or versioning an `AssessmentTemplate` through seeds.
Templates are global catalog records, and published or archived versions are
treated as immutable by the model. If a template has already been published and
the questions, options, branching, respondent types, or schema meaning need to
change, add a new version instead of mutating the existing record.

## Seed Location

Create one file per template family under:

```text
db/seeds/assessment_templates/
```

Then load that file from `db/seeds.rb` in the assessment template section:

```ruby
load Rails.root.join("db/seeds/assessment_templates/example_template.rb")
```

Keep template bodies out of `db/seeds.rb` unless they are tiny legacy examples.
Dedicated files keep the main seed entrypoint readable and make template changes
easier to review.

## Step By Step

1. Choose a stable template family name.

   Use a `template_key` that identifies the template family, and a positive
   integer `version` for the specific published shape. The pair
   `[template_key, version]` must be unique.

2. Create a seed file.

   Example:

   ```text
   db/seeds/assessment_templates/example_template.rb
   ```

3. Find or initialize the exact version.

   ```ruby
   # frozen_string_literal: true

   template = AssessmentTemplate.find_or_initialize_by(
     template_key: "example_template",
     version: 1
   )
   ```

4. Assign all required template attributes.

   Published templates require:

   - `title`
   - `slug`
   - `template_key`
   - `version`
   - `category`
   - non-empty `respondent_types`
   - `status: :published`
   - a valid `schema`

   Valid respondent types are:

   - `parent_proxy`
   - `self_report`
   - `therapist_report`
   - `teacher_report`

5. Build the schema.

   A published schema must include a positive integer `version`, at least one
   question, and every question must include:

   - `id`
   - `label`
   - `type`
   - `dimension_key`
   - `concept_key`
   - `time_window`
   - `evidence_weight`

   Supported question types are `scale`, `textarea`, `text`, and `select`.
   `select` questions need `options`. `scale` questions need integer `min` and
   `max` values where `min` is less than `max`. `evidence_weight` must be a
   number greater than `0` and less than or equal to `1`.

6. Save new versions without rewriting existing published records.

   Use `save!` so invalid schemas fail loudly during seeding.

   ```ruby
   template.assign_attributes(
     title: "Example Template",
     slug: "example-template-v1",
     category: "intake",
     respondent_types: [ "parent_proxy" ],
     status: :published,
     schema: {
       "version" => 1,
       "sections" => [
         {
           "id" => "context",
           "title" => "Context"
         }
       ],
       "questions" => [
         {
           "id" => "primary_goal",
           "section" => "context",
           "label" => "What is the primary goal right now?",
           "type" => "textarea",
           "dimension_key" => "care.goals",
           "concept_key" => "primary_goal",
           "time_window" => "current_pattern",
           "evidence_weight" => 0.7,
           "required" => true
         }
       ]
     }
   )

   template.save!
   ```

7. Inject the file in `db/seeds.rb`.

   Add the load call near the existing assessment template seed files:

   ```ruby
   # --- Assessment templates (Stage 4.5 foundation) ---

   load Rails.root.join("db/seeds/assessment_templates/anchor_initial_profile.rb")
   load Rails.root.join("db/seeds/assessment_templates/example_template.rb")
   ```

8. Run seeds locally.

   ```bash
   bin/rails db:seed
   ```

9. Verify the record.

   ```bash
   bin/rails runner 'template = AssessmentTemplate.find_by!(template_key: "example_template", version: 1); puts({ slug: template.slug, status: template.status, questions: template.question_count }.inspect)'
   ```

## Versioning Existing Templates

When changing a published template:

1. Add a new `version`.
2. Use a new `slug`, usually ending in `-v2`, `-v3`, and so on.
3. Copy the previous schema and make the intended changes.
4. Save the new record as `published`.
5. Archive older versions only if they should disappear from new-template
   pickers.
6. Update any related `AppSettings` pointer if the app should use the new
   version by default.

Example:

```ruby
previous = AssessmentTemplate.find_by!(template_key: "example_template", version: 1)

next_template = AssessmentTemplate.find_or_initialize_by(
  template_key: "example_template",
  version: 2
)

next_schema = previous.schema.deep_dup
next_schema["questions"] << {
  "id" => "follow_up",
  "section" => "context",
  "label" => "What support would help most?",
  "type" => "text",
  "dimension_key" => "care.support",
  "concept_key" => "requested_support",
  "time_window" => "current_pattern",
  "evidence_weight" => 0.5,
  "required" => false
}

next_template.assign_attributes(
  title: previous.title,
  slug: "example-template-v2",
  category: previous.category,
  respondent_types: previous.respondent_types,
  status: :published,
  schema: next_schema
)

next_template.save!
previous.update!(status: :archived) if previous.published?
```

## Branching With `visible_if`

Questions and sections may include a `visible_if` predicate. Every referenced
`question_id` must exist in the same template schema.

```ruby
{
  "id" => "auditory_coping",
  "section" => "sensory",
  "label" => "What helps with overwhelming noise?",
  "type" => "select",
  "dimension_key" => "sensory.coping",
  "concept_key" => "noise_coping_tools",
  "time_window" => "recent_pattern",
  "evidence_weight" => 0.6,
  "required" => false,
  "visible_if" => {
    "question_id" => "auditory_load",
    "equals" => "overwhelming"
  },
  "options" => [
    { "label" => "Headphones", "value" => "headphones" },
    { "label" => "Quiet room", "value" => "quiet_room" }
  ]
}
```

For more complex branching examples, see
`db/seeds/assessment_templates/anchor_initial_profile.rb`.

## Checklist

- [ ] Seed file lives under `db/seeds/assessment_templates/`.
- [ ] `db/seeds.rb` loads the seed file.
- [ ] Published records use a unique `slug`.
- [ ] `[template_key, version]` is unique.
- [ ] Existing published or archived records are not mutated except for status
      transitions such as publishing a draft or archiving an old version.
- [ ] Every published question has the required schema fields.
- [ ] `select` and `scale` questions include their required type config.
- [ ] Any `visible_if` references point to question ids in the same schema.
- [ ] `bin/rails db:seed` completes successfully.
