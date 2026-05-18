# Stage 8 - Guided Practice Audio Reflection

> Full brief. Adds recommendation-linked audio practice sessions that let a
> caregiver record or upload a short practice interaction, receive a warm
> parent-facing AI reflection, and approve structured evidence before it enriches
> the child profile.

---

## Goal

Turn recommendations into a feedback loop: a caregiver practices a recommended
support strategy, records or uploads the interaction, receives coaching
reflection, and reviews proposed profile evidence before Anchor updates the
child profile.

## User value

A caregiver can open a recommendation, capture a real practice session, and get
help understanding what happened, how the child appeared to respond, what the
caregiver did well, and what to try next. Useful observations from the session
can improve the child profile only after caregiver review.

## V1 product decisions

- Practice sessions are started from a `Recommendation` in V1.
- Practice sessions snapshot the source recommendation so they remain usable if
  recommendations are regenerated later.
- In-app browser recording is the primary capture path.
- Uploading an existing audio file is a fallback path.
- Audio is transcribed first, then the transcript is analyzed.
- The reflection page leads with summary, timeline, coaching, and next step.
- The full transcript is available in a collapsed or secondary section.
- Raw audio is retained only for a short default window after processing, with a
  caregiver delete path.
- Caregivers approve or reject suggested profile evidence item by item.
- Approved evidence immediately enters the existing profile rebuild pipeline.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action must call `authorize` through Pundit.
- [ ] Use `policy_scope` for index queries.
- [ ] Keep controllers thin; recording/upload, transcription, AI reflection,
      evidence creation, and refresh orchestration belong in services/jobs.
- [ ] Use Active Job with Solid Queue for asynchronous audio and AI work.
- [ ] Practice sessions must be tenant-scoped through the child profile's space.
- [ ] V1 practice sessions must be created from a recommendation.
- [ ] Practice sessions must remain readable if recommendations are regenerated
      or archived later.
- [ ] AI reflection must not act as a therapist, diagnose, or claim certainty
      about internal emotional states.
- [ ] AI-suggested evidence must not update `ProfileEvidence` until the
      caregiver explicitly approves it.
- [ ] Approved evidence must preserve provenance back to the practice session,
      evidence suggestion, recommendation, transcript, and timestamp range where
      possible.
- [ ] Raw audio and transcripts are sensitive child data; provide clear consent,
      deletion, and retention behavior.
- [ ] Use Tailwind CSS 4 + daisyUI 5 for all views.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Reference implementation

- Model pattern: `app/models/assessment_response.rb`,
  `app/models/profile_evidence.rb`, `app/models/recommendation.rb`
- Evidence pipeline: `app/services/assessment_evidence_extractor.rb`,
  `app/jobs/assessment_evidence_extractor_job.rb`,
  `app/jobs/current_profile_rebuilder_job.rb`,
  `app/jobs/profile_snapshot_builder_job.rb`,
  `app/jobs/recommendation_generator_job.rb`
- AI pattern: `app/services/ai/client.rb`,
  `app/services/ai/synthesis_runner.rb`,
  `app/services/ai/structured_output_validator.rb`,
  `app/models/ai_synthesis_run.rb`
- Controller pattern: `app/controllers/child_profiles/recommendations_controller.rb`,
  `app/controllers/child_profiles/assessment_responses_controller.rb`
- View pattern: `app/views/child_profiles/recommendations/show.html.erb`,
  `app/views/child_profiles/current_profiles/show.html.erb`
- Policy pattern: `app/policies/recommendation_policy.rb`,
  `app/policies/assessment_response_policy.rb`
- Upload module note: `docs/modules/file_uploads.md`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| `PracticeSession` | `practice_sessions` | `child_profile_id`, `recommendation_id`, `author_id`, `status`, `parent_review_status`, `title`, `session_type`, `recorded_at`, `duration_seconds`, `recommendation_snapshot`, `transcript`, `transcript_metadata`, `ai_summary`, `ai_timeline`, `child_response_notes`, `parent_coaching_notes`, `suggested_next_step`, `processing_started_at`, `processing_completed_at`, `processing_error`, `audio_retention_expires_at`, `approved_profile_evidence_at` | belongs to `ChildProfile`, belongs to optional `Recommendation`, belongs to `author`, has one attached `audio_file`, has many `practice_session_evidence_suggestions`, has many `profile_evidences` as source |
| `PracticeSessionEvidenceSuggestion` | `practice_session_evidence_suggestions` | `practice_session_id`, `profile_evidence_id`, `review_status`, `dimension_key`, `concept_key`, `value`, `value_type`, `confidence`, `rationale`, `timestamp_start_seconds`, `timestamp_end_seconds`, `metadata`, `reviewed_at`, `reviewed_by_id` | belongs to `PracticeSession`, belongs to optional `ProfileEvidence`, belongs to optional `reviewed_by` |

### PracticeSession schema notes

Recommended columns:

- `child_profile_id` - required foreign key.
- `recommendation_id` - optional foreign key with `on_delete: :nullify`. V1
  should validate that a recommendation is present on create, but sessions must
  survive later recommendation regeneration.
- `author_id` - required foreign key to `users`.
- `recommendation_snapshot` - jsonb copy of source recommendation title, body,
  category, rationale, generated_at, source profile snapshot id, and id at the
  time the session was created.
- `status` - enum: `draft`, `submitted`, `processing`, `completed`, `failed`,
  `archived`.
- `parent_review_status` - enum: `not_ready`, `pending_review`, `approved`,
  `partially_approved`, `rejected`.
- `title` - optional caregiver-facing title. Default can derive from the
  recommendation title and recorded date.
- `session_type` - enum/string for `recommendation_practice` in V1; leaves room
  for future freeform practice.
- `recorded_at` - when the practice happened.
- `duration_seconds` - captured from browser recording, upload metadata, or
  transcription metadata when available.
- `transcript` - text transcript used for analysis.
- `transcript_metadata` - jsonb with provider, model, segments, confidence,
  language, and file metadata.
- `ai_summary` - parent-facing text summary.
- `ai_timeline` - jsonb array of timestamped key moments.
- `child_response_notes` - jsonb or text. Prefer jsonb for structured sections.
- `parent_coaching_notes` - jsonb or text. Prefer jsonb for "what went well" and
  suggestions.
- `suggested_next_step` - jsonb or text. Prefer jsonb with title/body/action.
- `processing_started_at`, `processing_completed_at`, `processing_error` -
  async processing audit fields.
- `audio_retention_expires_at` - supports privacy-first raw audio retention.
- `approved_profile_evidence_at` - set once at least one evidence suggestion is
  approved.

Use `has_one_attached :audio_file` after Active Storage is installed.

### PracticeSessionEvidenceSuggestion schema notes

Store each AI-proposed evidence item separately so caregivers can approve or
reject individual suggestions.

Recommended columns:

- `practice_session_id` - required foreign key.
- `profile_evidence_id` - optional foreign key set after approval creates a
  `ProfileEvidence`.
- `review_status` - enum: `pending`, `approved`, `rejected`.
- `dimension_key`, `concept_key`, `value`, `value_type`, `confidence` - mirrors
  the eventual `ProfileEvidence` shape.
- `rationale` - short parent-readable explanation of why this suggestion may
  matter.
- `timestamp_start_seconds`, `timestamp_end_seconds` - optional transcript/audio
  range that supports provenance.
- `metadata` - jsonb with transcript excerpt, recommendation id,
  recommendation snapshot, prompt version, and safety/uncertainty notes.
- `reviewed_at`, `reviewed_by_id` - audit trail for caregiver review.

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `ChildProfile` | Add `has_many :practice_sessions, dependent: :destroy` | A child has many recommendation practice attempts. |
| `Recommendation` | Add `has_many :practice_sessions, dependent: :nullify` or use database-level nullify behavior | Current recommendation generation deletes and recreates recommendations, so practice sessions must not be destroyed when recommendations refresh. |
| `User` | Add `has_many :authored_practice_sessions, class_name: "PracticeSession", foreign_key: :author_id` | A caregiver authors sessions. |
| `ProfileEvidence` | No schema change expected. Use `source: practice_session` for approved evidence. | Keeps approved practice evidence in the existing profile pipeline. |

### Active Storage

Active Storage is configured but its database tables are not present in the
current schema. This stage should install Active Storage before implementing
audio attachments.

Development can use local disk. Production storage backend should be decided
before launch, with S3-compatible storage preferred for deployment flexibility.

### Seed data

No required seed data.

Optional demo seed:

- one completed practice session attached to a demo recommendation
- two pending evidence suggestions
- one approved evidence suggestion showing provenance into `ProfileEvidence`

## Routes and controllers

```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resources :recommendations, only: %i[index show],
      controller: "child_profiles/recommendations" do
      resources :practice_sessions,
        only: %i[new create show index],
        controller: "child_profiles/practice_sessions"
    end

    resources :practice_sessions,
      only: %i[index show destroy],
      controller: "child_profiles/practice_sessions" do
      member do
        post :process_audio
        delete :audio
      end

      resources :evidence_suggestions,
        only: %i[update],
        controller: "child_profiles/practice_session_evidence_suggestions"
    end
  end
end
```

Implementation can simplify routes if nested recommendation paths are enough for
V1. The key requirements are:

- create a session from a recommendation
- view processing/reflection state
- review individual evidence suggestions
- delete/archive a session
- delete raw audio independently when retained

| Controller | Actions | Notes |
|-----------|---------|-------|
| `ChildProfiles::PracticeSessionsController` | `index`, `new`, `create`, `show`, `destroy`, `process_audio`, `audio` | Nested under child profile. `new/create` may also be nested under recommendation for a clear entry point. |
| `ChildProfiles::PracticeSessionEvidenceSuggestionsController` | `update` | Approves or rejects one suggestion at a time. Approval creates `ProfileEvidence` and triggers profile rebuild. |

Controller setup should follow existing nested child profile controllers:

```ruby
before_action :set_space
before_action :set_child_profile
before_action :set_recommendation, only: %i[new create]
before_action :set_practice_session, only: %i[show destroy process_audio audio]
```

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `PracticeSessionPolicy` | `index?`, `show?` | User can read practice sessions if they can read the child profile. |
| `PracticeSessionPolicy` | `create?`, `new?` | User can create practice sessions if they can update the child profile or create observations/evidence for the child. |
| `PracticeSessionPolicy` | `destroy?`, `audio?` | User can archive/delete sessions or raw audio if they authored the session, can update the child profile, or is admin. |
| `PracticeSessionPolicy` | `process_audio?` | User can request processing for sessions they can update. Job remains idempotent. |
| `PracticeSessionEvidenceSuggestionPolicy` | `update?` | User can approve/reject suggestions if they can update the child profile, the suggestion is still pending, and the parent session is completed. |

Policy initialization should derive role from `record.child_profile.space`, the
same way `RecommendationPolicy` and `AssessmentResponsePolicy` do.

## UI

- **Layout:** dashboard.
- **Turbo:** recommended for processing state refresh and individual evidence
  review updates. Full-page fallback is acceptable.
- **New views:**
  - `app/views/child_profiles/practice_sessions/index.html.erb`
  - `app/views/child_profiles/practice_sessions/new.html.erb`
  - `app/views/child_profiles/practice_sessions/show.html.erb`
  - partials for recorder/upload, processing state, reflection sections,
    transcript, and evidence suggestion cards
- **Changed views:**
  - `app/views/child_profiles/recommendations/show.html.erb`
  - optionally `app/views/child_profiles/recommendations/index.html.erb`
  - optionally `app/views/spaces/child_profiles/show.html.erb`

### Recommendation entry point

Add a prominent action to the recommendation detail page:

```text
Record practice session
```

Supporting copy should be brief and consent-oriented:

```text
Record a short practice attempt so Anchor can reflect on what happened. You can
review anything suggested for the profile before it is saved.
```

### Capture screen

The capture screen should support:

- browser recording as the primary action
- upload existing audio as a secondary action
- title/date fields
- visible guidance that 5-15 minutes is ideal
- consent/privacy language before recording or upload
- accepted file type and maximum size guidance

Do not over-explain AI or internal processing. Keep the caregiver focused on
capturing the practice session.

### Reflection screen

After processing, show these sections:

1. Session Summary
2. Timeline
3. What Anchor Noticed About the Child
4. What You Did Well
5. Coaching Suggestion
6. Suggested Profile Evidence
7. Next Recommended Step

The full transcript should be available in a collapsed "Transcript" section.

### Evidence review UI

Each evidence suggestion should be shown as an individual review item with:

- proposed profile area
- cautious observation text
- confidence or strength indicator
- source timestamp range when available
- rationale
- approve/reject controls

Approval should create a `ProfileEvidence` record and mark the suggestion
approved. Rejection should preserve the suggestion record for audit but should
not update the child profile.

## AI and processing layer

### Processing contract

```text
PracticeSession submitted with audio
-> audio stored temporarily
-> PracticeSessionProcessingJob starts
-> audio transcribed
-> transcript and transcript metadata saved
-> transcript analyzed with a versioned prompt
-> reflection fields and evidence suggestions saved
-> session marked completed and pending review
-> caregiver reviews evidence suggestions
-> approved suggestions create ProfileEvidence rows
-> CurrentProfileRebuilderJob runs
-> ProfileSnapshotBuilderJob runs
-> AnalysisRunJob and RecommendationGeneratorJob run from latest snapshot
```

### Recommended services/jobs

- `PracticeSessionProcessingJob` - idempotent orchestration job.
- `PracticeSessions::AudioTranscriber` - provider abstraction for transcription.
- `PracticeSessions::ReflectionPromptRenderer` - renders versioned prompt from
  recommendation context, child-safe context, and transcript.
- `PracticeSessions::ReflectionOutputValidator` - validates model response shape
  and basic safety constraints before persistence.
- `PracticeSessions::ReflectionRunner` - calls AI client, validates output, and
  persists reflection/evidence suggestions.
- `PracticeSessions::EvidenceApprovalService` - converts one approved suggestion
  into `ProfileEvidence` and enqueues the existing profile rebuild pipeline.

### AI prompt boundaries

The model must:

- use cautious language
- avoid diagnosis and clinical certainty
- distinguish observed audio cues from hypotheses
- avoid claiming to know internal emotional states
- avoid blaming or shaming the caregiver
- produce practical next-step coaching
- propose evidence as suggestions requiring caregiver approval

Prefer:

- "The audio suggests possible frustration around this moment."
- "There were signs that the change may have felt difficult."
- "She appeared to re-engage after a choice was offered."
- "This may indicate that preview plus choice is a helpful support strategy."

Avoid:

- "She was anxious."
- "She was angry."
- "This proves rigidity."
- "You handled this incorrectly."

### Expected AI output shape

The validated output should be structured, for example:

```json
{
  "session_summary": "",
  "timeline": [
    {
      "start_seconds": 0,
      "end_seconds": 45,
      "summary": "",
      "notable_cues": []
    }
  ],
  "child_response_notes": [
    {
      "observation": "",
      "supportive_language": "",
      "timestamp_range": [0, 45]
    }
  ],
  "parent_strengths": [],
  "coaching_suggestions": [],
  "suggested_profile_evidence": [
    {
      "dimension_key": "",
      "concept_key": "",
      "value": "",
      "value_type": "text",
      "confidence": 0.6,
      "rationale": "",
      "timestamp_range": [0, 45],
      "transcript_excerpt": ""
    }
  ],
  "next_recommended_step": {
    "title": "",
    "body": ""
  },
  "safety_notes": []
}
```

## Privacy and retention

V1 should be privacy-forward because recordings may include a child's voice,
caregiver voice, home context, and sensitive family information.

Recommended V1 behavior:

- require caregiver confirmation before recording or upload
- explain that audio is used to generate a transcript and reflection
- store raw audio only while needed for processing plus a short retention window
- default retention window: 30 days after successful processing
- allow caregiver to delete raw audio sooner
- keep transcript/reflection/evidence suggestions unless the session is archived
  or deleted according to future data retention policy
- never create profile evidence without explicit caregiver approval

Future policy work should decide whether transcript deletion should also remove
the reflection or only prevent future reprocessing.

## Acceptance criteria

- [ ] A caregiver can start a practice session from a recommendation.
- [ ] A caregiver can record audio in the browser.
- [ ] A caregiver can upload an existing audio file as a fallback.
- [ ] The app stores the session under the correct child profile,
      recommendation, author, and space tenant.
- [ ] Practice session processing runs asynchronously and records status,
      timestamps, and errors.
- [ ] Audio is transcribed before reflection analysis.
- [ ] The reflection includes summary, timeline, child response notes, caregiver
      strengths, coaching suggestions, suggested evidence, and next step.
- [ ] The full transcript is available but secondary to the parent-facing
      reflection.
- [ ] AI output is validated before it is shown as completed.
- [ ] Parent-facing AI copy avoids diagnosis, certainty about internal states,
      and blame.
- [ ] Evidence suggestions are reviewed individually.
- [ ] Rejected suggestions do not update `ProfileEvidence`.
- [ ] Approved suggestions create `ProfileEvidence` with `source:
      practice_session`, `inferred: true`, confidence, metadata, and provenance.
- [ ] Approving evidence triggers the existing current profile, snapshot,
      analysis, and recommendation refresh flow.
- [ ] Raw audio can be deleted independently from the reflection record.
- [ ] Authorization prevents access across spaces.
- [ ] Specs cover models, policies, requests, processing jobs, AI output
      validation, evidence approval, and profile refresh enqueueing.

## Out of scope

- No freeform practice sessions not tied to recommendations in V1.
- No therapist/provider workflow.
- No clinical diagnosis or therapy-plan generation.
- No AI-only child profile updates.
- No automatic evidence approval.
- No live real-time coaching during a session.
- No video upload or analysis.
- No speaker diarization requirement for V1, though transcript metadata may
  support it later.
- No permanent raw audio retention by default.
- No prompt management UI.
- No admin audio review interface.

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None for V1.

## Future options

- Allow freeform practice sessions tied only to a child profile.
- Allow sessions tied to assessments, care goals, or custom exercises.
- Add caregiver-controlled long-term audio retention.
- Add speaker labels when transcription confidence is sufficient.
- Add comparison across multiple attempts at the same recommendation.
- Generate updated or follow-up recommendations that explicitly reference the
  latest practice session.
- Add richer consent controls for multi-caregiver spaces.

## Steps

### Step 1 - Install and document Active Storage for audio uploads

Install Active Storage tables, configure local development storage, and update
the file uploads module with audio-specific decisions.

**Verify:** `bundle exec rails db:migrate && bundle exec rspec`
**Revert:** Roll back Active Storage migrations and remove documentation changes.

### Step 2 - Add practice session models

Add `PracticeSession` and `PracticeSessionEvidenceSuggestion` with associations,
enums, validations, factories, and model specs.

**Verify:** `bundle exec rspec spec/models/practice_session_spec.rb spec/models/practice_session_evidence_suggestion_spec.rb`
**Revert:** Roll back migrations and remove models, specs, and factories.

### Step 3 - Add policies and routes

Add Pundit policies, nested routes, and request specs for tenant-safe access.

**Verify:** `bundle exec rspec spec/policies/practice_session_policy_spec.rb spec/policies/practice_session_evidence_suggestion_policy_spec.rb spec/requests/child_profiles/practice_sessions_spec.rb`
**Revert:** Remove policies, routes, controllers, and related specs.

### Step 4 - Add recommendation entry and capture UI

Add "Record practice session" to recommendation detail pages. Build the new
session page with browser recording, upload fallback, consent copy, and file
constraints.

**Verify:** `bundle exec rspec spec/requests/child_profiles/recommendations_spec.rb spec/requests/child_profiles/practice_sessions_spec.rb`
**Revert:** Remove changed views, helpers, and capture controller paths.

### Step 5 - Add processing job and transcription service

Add idempotent audio processing orchestration and a transcription service with a
stubbed test/development path.

**Verify:** `bundle exec rspec spec/jobs/practice_session_processing_job_spec.rb spec/services/practice_sessions/audio_transcriber_spec.rb`
**Revert:** Remove job, service, and specs.

### Step 6 - Add AI reflection runner and validator

Render a versioned prompt from the recommendation context and transcript, call
the AI client, validate the structured output, and persist reflection fields and
evidence suggestions.

**Verify:** `bundle exec rspec spec/services/practice_sessions/reflection_runner_spec.rb spec/services/practice_sessions/reflection_output_validator_spec.rb`
**Revert:** Remove reflection services, prompt template, validator, and specs.

### Step 7 - Build reflection and evidence review UI

Show completed reflections with the required sections, transcript disclosure,
processing states, failure states, and individual suggestion approval/rejection.

**Verify:** `bundle exec rspec spec/requests/child_profiles/practice_sessions_spec.rb spec/requests/child_profiles/practice_session_evidence_suggestions_spec.rb`
**Revert:** Remove views, presenter methods, and evidence review controller
changes.

### Step 8 - Approve evidence into the profile pipeline

Add approval service that creates `ProfileEvidence` from one suggestion and
enqueues `CurrentProfileRebuilderJob` with practice-session provenance.

**Verify:** `bundle exec rspec spec/services/practice_sessions/evidence_approval_service_spec.rb spec/jobs/current_profile_rebuilder_job_spec.rb spec/jobs/recommendation_generator_job_spec.rb`
**Revert:** Remove approval service and restore suggestion update behavior.

### Step 9 - Add audio retention and deletion behavior

Set default raw audio expiration, add delete-audio action, and ensure deleted
audio does not remove transcript/reflection unless the whole session is archived.

**Verify:** `bundle exec rspec spec/requests/child_profiles/practice_sessions_spec.rb spec/models/practice_session_spec.rb`
**Revert:** Remove retention fields/actions and related specs.

---

## Status

- [ ] Step 1 - Install and document Active Storage for audio uploads
- [ ] Step 2 - Add practice session models
- [ ] Step 3 - Add policies and routes
- [ ] Step 4 - Add recommendation entry and capture UI
- [ ] Step 5 - Add processing job and transcription service
- [ ] Step 6 - Add AI reflection runner and validator
- [ ] Step 7 - Build reflection and evidence review UI
- [ ] Step 8 - Approve evidence into the profile pipeline
- [ ] Step 9 - Add audio retention and deletion behavior

**Last updated:** 2026-05-16
**Handoff note:** V1 is recommendation-linked only. Use in-app recording as the
primary capture path, upload as fallback, transcribe before analysis, retain raw
audio temporarily by default, and require item-by-item caregiver approval before
creating profile evidence.
