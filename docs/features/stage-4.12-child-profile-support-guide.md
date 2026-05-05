# Stage 4.12 — Child Profile Support Guide

> Light brief. Rebuilds the child profile show page from a profile-output
> dashboard into a parent-facing Support Guide.

---

## Goal

Make the child profile show page feel like a calm, practical support guide that
helps a parent understand the child, respond during hard moments, plan ahead,
and choose what to try next.

## Changes

Rework `app/views/spaces/child_profiles/show.html.erb` and
`app/services/child_profile_results_presenter.rb` so the page no longer renders
raw current-profile narrative text, raw dimension values, scoring language, or
mechanical recommendation labels.

This stage replaces the Stage 4.10/4.11 parent-dashboard attempt with a more
explicit Support Guide structure. Stage 4.10 and 4.11 remain historical records;
do not edit them except for future status notes if needed.

The show page should become a parent-facing guide with these sections:

1. Header
2. Child Snapshot
3. What Anchor Understands Right Now
4. When Things Get Hard
5. What to Plan Around
6. Best Support Style
7. Focus Right Now
8. Try This This Week
9. What We're Still Learning

The page should use existing data only:

- `ChildProfile`
- `CurrentProfile.summary`
- `Recommendation`
- latest submitted `AssessmentResponse`
- existing presenter fallback content

Any translation from raw profile data into parent-facing copy should happen in
presenter methods or small helper methods, not directly in the ERB.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action must call `authorize` through existing Pundit
      policies.
- [ ] Keep controllers thin; do not add profile translation logic to controller
      actions.
- [ ] Preserve the existing analysis architecture:
      `AssessmentResponse` remains the raw audit trail, `ProfileEvidence`
      remains the normalized signal layer, `CurrentProfile` remains the latest
      portrait, `ProfileSnapshot` remains the point-in-time profile record, and
      `Recommendation` remains the action layer.
- [ ] Do not introduce new models, migrations, routes, controllers, or policies
      in this stage.
- [ ] Use existing detail pages for deeper data: Full Profile/current profile,
      Recommendations, and Assessments.
- [ ] Do not display raw deterministic narrative text on the child profile show
      page.
- [ ] Do not display raw profile values such as standalone `1`, `2`, `3`, or
      internal values without parent-facing context.
- [ ] Do not display evidence counts, dimension counts, dimension keys, concept
      keys, confidence, severity, scores, rubric metadata, AI audit text, or
      provider/debug language on the main page.
- [ ] Use Tailwind CSS 4 + daisyUI 5 components.
- [ ] Use `render "shared/page_header"` where it fits the dashboard pattern.
- [ ] Avoid diagnostic language. Frame output as support-oriented guidance and
      working hypotheses, not clinical determinations.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Support Guide Structure

### 1. Header

Use:

- Title: "`[Child First Name]`'s Support Guide"
- Subtitle: "A simple guide to what Anchor understands right now, what may help,
  and what to watch next."
- Actions:
  - Recommendations
  - Assessments
  - Edit child details, only when authorized

Do not make "Full profile" a primary action on this page. If linked, it should be
quiet/supporting because the parent should not need the deep profile to get
value.

### 2. Child Snapshot

Keep compact.

Include:

- name
- age
- last updated
- profile freshness
- gentle provenance note, such as "Based on the onboarding profile completed
  recently."

Do not include evidence counts, dimension counts, profile version, or internal
status beyond parent-safe processing badges.

### 3. What Anchor Understands Right Now

Replace the current long technical narrative with 3-5 short insight cards.

Cards should be parent-readable and behavior/support oriented. Examples:

- "`[Child]` may do best when expectations are clear before a task starts."
- "Changes may feel harder when the next step is uncertain."
- "Support may work best when adults lower pressure before giving more
  instruction."
- "Interests like music can be useful entry points for connection or recovery."

Use available data from `CurrentProfile.summary["dimensions"]`, especially:

- strengths/interests
- strengths/profile
- strengths/support_fit
- strengths/support_history
- communication dimensions
- behavior/flexibility dimensions
- regulation dimensions
- sensory dimensions
- adaptive/daily-life dimensions
- context/supports and context/school only when they can be expressed usefully

Do not render `CurrentProfile.narrative` on the show page.

### 4. When Things Get Hard

Show 3 cards:

- Possible triggers
- Early signs to watch for
- What may help

Use uncertain language and only infer from available profile dimensions. For
example:

- Trigger-like areas may come from transitions, uncertainty, nonpreferred
  expectations, sensory impact, school demand, open-ended demands, or changes in
  plans.
- Early signs may come from `regulation.stress_pattern` or fallback copy.
- What may help may come from `strengths.support_fit`,
  `strengths.support_history`, interests, or fallback support strategies.

If exact trigger data is not available, use "What may make things harder" rather
than implying Anchor knows definite triggers.

### 5. What to Plan Around

Show compact planning cards or chips. These are prevention-oriented areas a
parent can keep in mind.

Potential areas:

- transitions
- unclear expectations
- sensory-heavy settings
- multi-step tasks
- school fatigue or school demand
- mistakes/uncertainty
- changes in plans
- nonpreferred expectations
- recovery after upset

Only show areas supported by available data where possible. Use safe fallback
planning areas when the profile is early.

### 6. Best Support Style

Use strengths and parent-provided context if available:

- interests
- best qualities
- helpful support style
- existing strategies that work
- parent top priority
- parent goal in their own words

This section should help the page feel strengths-based and personal before
moving into priorities. It should avoid sounding like a deficit inventory.

### 7. Focus Right Now

Show 1-3 priorities.

Each priority should include:

- what to focus on
- why it matters
- what to try first

Use recommendations and high-signal profile dimensions as source material, but
rewrite the output into parent-friendly copy. Do not show mechanical titles like
"Support adaptive compliance flexibility with predictable recovery space."

### 8. Try This This Week

Show 1-3 small experiments from active `Recommendation` records when available.

Each experiment should include:

- parent-friendly title
- why it may help
- how to try it
- optional time estimate

The page may use recommendation records as source material, but must rewrite or
present them in language that makes sense to a parent. Avoid direct display of
dimension names, concept names, evidence values, or mechanical recommendation
titles.

### 9. What We're Still Learning

Keep this practical and short.

Use questions such as:

- What usually happens right before a hard moment?
- What helps the child recover?
- Are hard moments more common when tired, hungry, rushed, or overstimulated?
- Which supports make the moment shorter or easier?

Frame this as gentle noticing, not homework or data collection pressure.

## Copy and Data Rules

- Prefer "may", "seems", "often", "right now", and "based on what has been
  shared so far."
- Prefer short cards over long paragraphs.
- Use values only after translating them into parent-facing meaning.
- Never show raw numeric scale values directly on the show page.
- Never show deterministic/stub/audit copy on the show page.
- Never show `CurrentProfile.narrative` directly on the show page.
- If source data is missing, show a graceful early-profile state that explains
  what the section will become.

## Acceptance Criteria

- [ ] The page title is "`[Child First Name]`'s Support Guide."
- [ ] The page subtitle is "A simple guide to what Anchor understands right now,
      what may help, and what to watch next."
- [ ] Header actions include Recommendations, Assessments, and Edit child
      details when authorized.
- [ ] The child snapshot remains compact and includes name, age, last updated,
      freshness, and a parent-safe onboarding provenance note when available.
- [ ] The page renders the sections: Child Snapshot, What Anchor Understands
      Right Now, When Things Get Hard, What to Plan Around, Best Support Style,
      Focus Right Now, Try This This Week, and What We're Still Learning.
- [ ] "What Anchor Understands Right Now" shows 3-5 parent-readable insight
      cards.
- [ ] "When Things Get Hard" shows exactly 3 cards: Possible triggers or what
      may make things harder, early signs to watch for, and what may help.
- [ ] "Focus Right Now" shows no more than 3 priorities.
- [ ] "Try This This Week" shows no more than 3 small experiments.
- [ ] No raw current-profile narrative dump appears on the page.
- [ ] The page does not expose standalone raw numeric values like "2" as
      guidance cards.
- [ ] The page does not expose evidence counts, dimension counts, dimension
      keys, concept keys, confidence, scores, severity, rubric metadata, profile
      version, AI audit copy, or debug/provider language.
- [ ] Recommendation copy shown on the main page is parent-friendly and does not
      include mechanical dimension names.
- [ ] Empty/early-profile states are calm, short, and parent-facing.
- [ ] Existing current profile, recommendations, and assessments routes remain
      reachable.
- [ ] Request specs cover the new section labels and verify hidden internal/raw
      language.

## Out of scope

- No new clinical scoring, diagnosis, or diagnostic interpretation.
- No new data model, migration, route, controller, or policy.
- No changes to onboarding assessment questions or seed data.
- No changes to the AI provider pipeline.
- No new recommendation-generation algorithm.
- No recommendation feedback/outcomes tracking.
- No observation model or observation timeline work.
- No redesign of Full Profile, Recommendations, or Assessments pages beyond
  preserving links from the Support Guide.
- No admin/clinician explainability view.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Steps

### Step 1 — Audit Current Show Page and Presenter Data

Review `app/views/spaces/child_profiles/show.html.erb`,
`app/services/child_profile_results_presenter.rb`, related request specs, and
the current onboarding profile dimensions. Classify existing displayed content
as keep, translate, hide, or move to a deeper surface.

**Verify:** Produce a short keep/translate/hide/move list before code edits.
**Revert:** Documentation-only; restore this brief if direction changes.

### Step 2 — Add Support Guide Presenter Objects

Add presenter methods for the guide sections, such as support insights,
hard-moment guidance, planning areas, best support style, focus priorities, and
weekly experiments. Keep the data translation in Ruby, not ERB.

**Verify:** Presenter specs cover fallback behavior, limits, and no raw numeric
or mechanical dimension-only output.
**Revert:** Revert presenter and presenter spec changes.

### Step 3 — Rebuild the Show Page Structure

Update `app/views/spaces/child_profiles/show.html.erb` to render the Support
Guide sections with short, responsive cards and daisyUI 5/Tailwind classes.

**Verify:** Request spec confirms the new title, subtitle, actions, and section
labels render.
**Revert:** Revert the show view and related request spec changes.

### Step 4 — Hide Raw/Internal Data on the Main Page

Remove direct rendering of `CurrentProfile.narrative`, raw profile values,
technical recommendation titles, evidence/dimension counts, confidence/scoring,
rubric metadata, and AI audit/debug copy from the child profile show page.

**Verify:** Request spec asserts forbidden raw/internal phrases and values are
absent from the show page.
**Revert:** Revert presenter/view/spec changes from this step.

### Step 5 — Preserve Empty and Early States

Ensure children with no current profile, no recommendations, queued processing,
or failed processing still see calm parent-facing copy and clear next actions.

**Verify:** Existing empty/queued/failed request specs pass and include the new
Support Guide copy.
**Revert:** Revert fallback copy and related spec changes.

### Step 6 — Final Verification

Run targeted specs during the stage, then full RSpec and RuboCop at the stage
boundary.

**Verify:** `bundle exec rspec` and `bundle exec rubocop`
**Revert:** Revert stage changes if final verification cannot be made green in
the session.

---

## Status

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3
- [ ] Step 4
- [ ] Step 5
- [ ] Step 6

**Last updated:** 2026-05-04
**Handoff note:** Brief created. Next session should start with Phase 2 design
review against `docs/ARCHITECTURE.md`, `docs/CONVENTIONS.md`, and existing
child profile/current profile/recommendation/assessment code before building.
