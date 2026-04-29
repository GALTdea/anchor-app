# Stage 7 - AI Synthesis Layer

> Full brief. Adds external AI as a constrained synthesis layer on top of the
> deterministic analysis engine from Stage 6. AI consumes structured analysis
> output and produces parent-readable explanations; it does not own scores,
> findings, clinical claims, or safety-sensitive conclusions.

---

## Goal

Use AI to turn completed `AnalysisRun` results into warmer, clearer,
parent-readable guidance while preserving the deterministic analysis engine as
the source of truth.

## User value

Parents receive analysis explanations that are easier to understand and act on.
The AI layer can summarize patterns, soften language, connect findings into a
coherent narrative, and suggest what to observe next without replacing Anchor's
rubric-based reasoning.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action must call `authorize` through Pundit.
- [ ] Keep controllers thin; AI provider calls, prompt rendering, validation, and
      persistence belong in services/jobs.
- [ ] Use Active Job with Solid Queue for asynchronous AI work.
- [ ] AI synthesis can only run from a completed deterministic `AnalysisRun`.
- [ ] AI must consume structured analysis output, not raw database records
      directly.
- [ ] AI must not be the sole source of rubric scores, eligibility decisions,
      clinical claims, or safety-sensitive conclusions.
- [ ] AI failure must not block profile availability; deterministic analysis
      remains the fallback.
- [ ] AI outputs must be stored with provider/model metadata, prompt version,
      source analysis id, status, and error state for auditability.
- [ ] Avoid diagnostic language. Outputs are support guidance and working
      hypotheses, not clinical determinations.
- [ ] Use Tailwind CSS 4 + daisyUI 5 for any changed profile or audit views.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Reference implementation

- Model pattern: `app/models/current_profile.rb`,
  `app/models/profile_snapshot.rb`, `app/models/recommendation.rb`
- Service pattern: `app/services/current_profile_builder.rb`,
  `app/services/recommendation_builder.rb`,
  `app/services/child_profile_results_presenter.rb`
- Job pattern: `app/jobs/current_profile_rebuilder_job.rb`,
  `app/jobs/profile_snapshot_builder_job.rb`,
  `app/jobs/recommendation_generator_job.rb`
- Expected Stage 6 pattern: `AnalysisRubric`, `AnalysisRun`,
  `AnalysisFinding`, `Analysis::InputBuilder`, `Analysis::RubricEvaluator`,
  `AnalysisRunJob`
- Controller pattern: `app/controllers/spaces/child_profiles_controller.rb`,
  `app/controllers/child_profiles/current_profiles_controller.rb`
- View pattern: `app/views/spaces/child_profiles/show.html.erb`,
  `app/views/child_profiles/current_profiles/show.html.erb`
- Policy pattern: `app/policies/current_profile_policy.rb`,
  `app/policies/child_profile_policy.rb`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| `AiSynthesisRun` | `ai_synthesis_runs` | `analysis_run_id`, `status`, `purpose`, `provider`, `model`, `prompt_version`, `request_payload` (jsonb), `response_payload` (jsonb), `output` (jsonb), `started_at`, `completed_at`, `error_message` | belongs to `AnalysisRun` |

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `AnalysisRun` | Add `has_many :ai_synthesis_runs` | A completed deterministic analysis can have one or more synthesis attempts. |
| `CurrentProfile` | May display latest successful AI synthesis copy when present, with deterministic fallback | Keeps profile useful when AI is disabled or unavailable. |
| `Recommendation` | May use AI wording only when grounded in existing `AnalysisFinding` refs | Keeps recommendations tied to deterministic analysis. |

### Seed data

No required seed data.

Prompt templates should be versioned in code or configuration. If stored in the
database later, that should be a separate brief.

## Routes and controllers

No parent-facing route sprawl is expected. AI synthesis should be surfaced inside
existing child profile/current profile pages.

Optional read-only routes can be added if useful for internal audit:

```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resources :analysis_runs, only: %i[show],
      controller: "child_profiles/analysis_runs" do
      resources :ai_synthesis_runs, only: %i[show],
        controller: "child_profiles/ai_synthesis_runs"
    end
  end
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `ChildProfiles::AiSynthesisRunsController` | `show` | Optional read-only audit surface. Raw request payload visibility may be admin-only if it includes sensitive context. |
| `Spaces::ChildProfilesController` | `show` | May display latest successful AI synthesis through presenter methods. |
| `ChildProfiles::CurrentProfilesController` | `show` | May display deterministic findings plus AI-enhanced explanation. |

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `AiSynthesisRunPolicy` | `show?` | User can read synthesized child-level analysis if they can read the child profile in the child's space, or admin. Raw request/response payloads may require admin-only handling. |
| `AnalysisRunPolicy` | `show?` | Existing Stage 6 analysis access governs source analysis visibility. |
| `ChildProfilePolicy` | `show?` | Existing child profile read access continues to govern embedded synthesis display. |
| `CurrentProfilePolicy` | `show?` | Existing current profile read access continues to govern profile detail display. |

## UI

- **Layout:** dashboard for child/profile synthesis surfaces.
- **Turbo:** optional. Full-page rendering is acceptable.
- **New views:**
  - Optional `app/views/child_profiles/ai_synthesis_runs/show.html.erb`
- **Changed views:**
  - `app/views/spaces/child_profiles/show.html.erb`
  - `app/views/child_profiles/current_profiles/show.html.erb`
  - Optional recommendation partials to show AI-enhanced wording

### Parent-facing presentation

AI-generated copy should improve clarity without implying that AI is the
authority.

Prefer:

- "Anchor noticed"
- "based on the profile signals"
- "this may mean"
- "what may help"
- "what to keep watching"
- "confidence"

Avoid:

- "the AI decided"
- "diagnosis"
- "severity score"
- "autism score"
- "deficit"
- "clinically indicates"

### AI output boundaries

AI-generated copy should:

- cite or summarize deterministic findings rather than invent new findings
- preserve non-diagnostic framing
- include uncertainty when confidence is low
- avoid adding facts not present in the structured analysis payload
- never recommend medication, diagnosis, or emergency action beyond directing
  users to appropriate professional or emergency support when the deterministic
  system flags a safety concern
- be replaceable by deterministic fallback copy

## Service / job layer

- `Ai::Client` - provider abstraction for external model calls. No controller
  should call an AI provider directly.
- `Ai::PromptRenderer` - renders versioned prompts from structured
  `AnalysisRun` output.
- `Ai::StructuredOutputValidator` - validates model responses before persistence
  or display.
- `Ai::SynthesisRunner` - sends analysis output to AI for parent-readable
  synthesis, stores request/response metadata, validates output shape, and fails
  closed when output is missing or malformed.
- `AiSynthesisJob` - runs only after a successful deterministic `AnalysisRun`.

### Processing contract

```text
AnalysisRun completed
-> structured analysis payload built
-> prompt rendered from versioned template
-> external AI provider called asynchronously
-> response validated against expected output shape
-> AiSynthesisRun records status, metadata, and structured output
-> profile views use AI copy when successful, deterministic fallback otherwise
```

Processing rules:

- The deterministic `AnalysisRun` remains the reasoning source of truth.
- AI synthesis is optional enrichment and must not block profile availability.
- Malformed AI output is rejected and recorded as failed.
- Provider errors are recorded and can be retried.
- Prompts and output schemas should be stable enough for regression specs.
- The app should support AI-disabled environments without broken profile pages.

## Acceptance criteria

- [ ] `AiSynthesisRun` records provider, model, prompt version, request metadata,
      response metadata, output, status, and error state.
- [ ] AI synthesis can only be started from a completed deterministic
      `AnalysisRun`.
- [ ] AI receives structured analysis output, not raw database records directly.
- [ ] AI returns validated structured copy; malformed output is rejected and
      recorded as failed.
- [ ] If AI synthesis fails, the profile page still displays deterministic
      analysis output from Stage 6.
- [ ] Parent-facing AI copy avoids diagnostic claims and makes uncertainty
      visible where confidence is low.
- [ ] AI-generated recommendations or profile copy are grounded in existing
      `AnalysisFinding` refs.
- [ ] Specs cover prompt rendering, output validation, provider failure fallback,
      idempotent jobs, and parent-facing presentation.

## Out of scope

- No AI-led diagnosis or clinical classification.
- No AI-generated rubric scores or findings.
- No autonomous AI changes to rubrics.
- No conversational AI chat.
- No prompt management UI.
- No admin rubric management UI.
- No provider/therapist portal.
- No medication, treatment-plan, or crisis-management engine.
- No automatic external sharing of analysis results.
- No replacement of Stage 6 deterministic analysis.

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Decisions

- AI is an explanation and synthesis layer, not the source of truth.
- The first AI integration consumes structured `AnalysisRun` output rather than
  raw app state.
- Deterministic analysis must remain useful when AI is unavailable.
- AI output must be validated before display.
- Parent-facing language must remain support-oriented and non-diagnostic.
- Prompt management UI is deferred.

## Steps

### Step 1 - Model AI synthesis attempts

Add `AiSynthesisRun` with validations, statuses, metadata fields, associations,
factories, and model specs.

**Verify:** `bundle exec rspec spec/models/ai_synthesis_run_spec.rb`
**Revert:** Roll back the migration and remove the model/spec/factory.

### Step 2 - Add provider configuration and client abstraction

Add provider configuration and `Ai::Client` so external model calls are isolated
behind a service boundary. Keep test mode fully stubbed.

**Verify:** `bundle exec rspec spec/services/ai/client_spec.rb`
**Revert:** Remove provider config and client service.

### Step 3 - Add prompt rendering from structured analysis

Implement `Ai::PromptRenderer` so prompts are versioned and rendered from a
completed `AnalysisRun` payload.

**Verify:** `bundle exec rspec spec/services/ai/prompt_renderer_spec.rb`
**Revert:** Remove prompt renderer and specs.

### Step 4 - Validate structured AI output

Implement `Ai::StructuredOutputValidator` to accept only the expected synthesis
shape and reject malformed, unsupported, or unsafe output.

**Verify:** `bundle exec rspec spec/services/ai/structured_output_validator_spec.rb`
**Revert:** Remove validator and specs.

### Step 5 - Add synthesis runner and job

Implement `Ai::SynthesisRunner` and `AiSynthesisJob`. The job should run only for
completed analysis, record failures, and avoid duplicate successful runs for the
same analysis/purpose/prompt version unless explicitly requested.

**Verify:** `bundle exec rspec spec/services/ai/synthesis_runner_spec.rb spec/jobs/ai_synthesis_job_spec.rb`
**Revert:** Remove runner/job and specs.

### Step 6 - Surface AI synthesis with deterministic fallback

Update presenters and views so the child profile/current profile can show latest
successful AI synthesis copy when present and deterministic Stage 6 copy when AI
is unavailable or failed.

**Verify:** `bundle exec rspec spec/services/child_profile_results_presenter_spec.rb spec/requests/spaces/child_profiles_spec.rb`
**Revert:** Remove presenter/view changes.

---

## Status

- [x] Step 1
- [x] Step 2
- [x] Step 3
- [x] Step 4
- [x] Step 5
- [x] Step 6

**Last updated:** 2026-04-28
**Handoff note:** Brief split from the original AI-assisted analysis proposal.
This stage adds only the external AI synthesis layer on top of the deterministic
analysis engine from Stage 6.
