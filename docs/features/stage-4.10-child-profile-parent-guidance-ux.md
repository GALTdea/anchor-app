# Stage 4.10 — Child Profile Parent Guidance UX

> Light brief. Redesigns the child profile show page from an internal profile
> output surface into a parent-readable guidance page.

---

## Goal

Make the child profile page feel like a practical parent companion: "Here is
what we currently understand about your child, why it may be happening, and
what to do next."

## Changes

Rework `app/views/spaces/child_profiles/show.html.erb` and any small presenter
helpers needed so the page no longer feels like a medical chart, raw assessment
report, or internal data dashboard. This stage is scoped to the child profile
show page only.

The data needed to populate the MVP profile should come from the current data
structure: `ChildProfile`, `CurrentProfile`, existing current profile summary
data, `Recommendation`, and existing assessment provenance. If a UX element
cannot be supported by the current structured data yet, use safe dummy/static
fallback content for the MVP rather than changing the data model.

The redesigned page should answer the parent's underlying questions through a
clear MVP page structure:

1. Your Child at a Glance
2. What May Be Driving This
3. What to Focus on Right Now
4. Try This This Week
5. What We're Still Learning

Remove or hide parent-facing sections that expose internal profile mechanics
without helping the caregiver understand their child, especially:

- "Profile signals"
- confidence scores
- evidence counts
- raw dimension keys
- "Based on" rationale snippets when they read like system provenance
- profile version badges
- internal "Profile detail" and "Recommendations" module links as primary calls
  to action

Rethink "Recommended next steps." The page should not present a large generic
task list. Instead, it should frame guidance as a small number of supportive,
behavior-linked ideas, such as "Ideas to try for transitions" or "Ways to make
communication easier this week."

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action must call `authorize` through existing Pundit
      policies.
- [ ] Keep controllers thin; page assembly belongs in presenters/helpers, not
      controller actions.
- [ ] Preserve the existing Stage 4.5 second-brain architecture:
      `AssessmentResponse` remains the raw audit trail, `ProfileEvidence`
      remains the normalized signal layer, `CurrentProfile` remains the latest
      portrait, and `Recommendation` remains the action layer.
- [ ] Do not introduce new models, migrations, routes, controllers, or policies
      in this stage.
- [ ] Do not modify the current data structure. Use current records where
      available and safe dummy/static fallback content where the current
      structure cannot yet support the desired UX.
- [ ] Scope implementation to the child profile show page. Do not redesign
      onboarding, assessment history, current profile detail, recommendation
      detail/history, or submitted-answer pages in this stage.
- [ ] Use Tailwind CSS 4 + daisyUI 5 components.
- [ ] Use the shared `page_header` partial where it fits the authenticated
      dashboard pattern.
- [ ] Avoid diagnostic language. The page should frame output as support
      guidance and working hypotheses, not clinical determinations.
- [ ] Do not require parents to understand workspaces, assessments, evidence,
      snapshots, recommendations, confidence, or internal profile concepts
      before receiving value.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## MVP Page Structure

### Header / Framing

Keep the title as "`[Child's name] Profile`", but change the subtitle and
opening copy so the page leads with support and understanding rather than
assessment mechanics.

Preferred framing:

> Here is what we currently understand about [child], why it may be happening,
> and what may help next.

Keep any "not a diagnosis" language small and calm. It should reassure without
making the page feel clinical.

### Your Child at a Glance

Lead with a warm, plain-language summary that helps the parent orient quickly.
Use `CurrentProfile.narrative` when available, surrounded by copy that explains
it as an early working support picture.

Include 3-5 parent-readable profile traits when enough profile information is
available from the existing current profile summary. Traits should read like
everyday observations, not system output. If profile traits cannot be derived
cleanly from current structured data yet, use safe dummy/static fallback traits
for this MVP page.

Include a short early-profile note, such as:

> This is an early profile based on what has been shared so far. It should get
> more useful as Anchor learns more about what helps [child].

Do not show confidence scores, raw dimensions, evidence counts, or profile
version data.

### What May Be Driving This

Translate behavior patterns into parent-readable explanations. For MVP, show
2-3 cards using current profile data when possible. If the current structured
data cannot yet support robust behavior explanations, use safe dummy/static
fallback cards. Each card should include:

- behavior/context
- possible meaning
- support implication

Use uncertain language such as "may", "might", or "could." The goal is to help
parents make sense of behavior without implying diagnostic certainty.

Good examples:

- "Transitions may feel harder when the next step is unclear."
- "Pulling away could be a way of saying the situation is too much."
- "Big reactions might happen more often when recovery time is too short."

Avoid framing that implies certainty:

- "This proves..."
- "The profile detected..."
- "The confidence score is..."

### What to Focus on Right Now

Show the top 2-3 support priorities. Phrase them as focus areas, not tasks or
assignments. This section should help the parent decide where to put attention
right now without feeling overwhelmed. Use existing `CurrentProfile` summary
data and `Recommendation` records where possible; otherwise use safe
dummy/static fallback focus areas.

Examples:

- Make uncertain moments more predictable
- Support recovery after mistakes
- Practice flexibility in low-pressure situations

### Try This This Week

Show 2-3 practical activities or support ideas. Use `Recommendation` records
when available. If recommendations are not ready yet, fall back to safe generic
defaults that are low-risk, parent-friendly, and clearly optional.

Each item should include:

- title
- why it may help
- how to try it
- estimated time, preferably 5-10 minutes

The section should feel like a small experiment for the week, not homework or a
care plan.

### What We're Still Learning

End with honest uncertainty. Help the parent notice useful patterns without
making it feel like data collection or homework.

Examples:

- what usually happens before the behavior
- what helps the child recover
- whether patterns change with fatigue, transitions, sensory input, or task
  difficulty
- whether a support seems to make the moment easier, shorter, or less intense

## UX Principles

- Parent-first, not system-first.
- Plain language over internal terminology.
- Small next action over long task list.
- Behavior context over raw scores.
- Warm and practical, not clinical.
- Honest uncertainty: use "may", "might", and "could" where appropriate.
- Strengths and motivators should appear before friction-heavy content when
  available.

## Acceptance Criteria

- [ ] The page renders the five MVP section labels: "Your Child at a Glance",
      "What May Be Driving This", "What to Focus on Right Now", "Try This This
      Week", and "What We're Still Learning."
- [ ] Implementation is scoped to
      `app/views/spaces/child_profiles/show.html.erb` plus small presenter/helper
      support if needed.
- [ ] The page uses the current data structure for available profile data and
      safe dummy/static fallback content where the current structure cannot yet
      support a UX element.
- [ ] The child profile page no longer shows a parent-facing "Profile signals"
      section.
- [ ] The main page does not use the phrases "Profile signals", "confidence
      score", "evidence count", "dimension key", or "profile version."
- [ ] The main page does not expose confidence scores, evidence counts, raw
      dimension keys, or profile version data.
- [ ] The page shows no more than 3 support priorities.
- [ ] The page shows no more than 3 try-this-week ideas.
- [ ] Behavior explanations use uncertain language such as "may", "might", or
      "could."
- [ ] Parent-facing copy avoids medical-chart language and diagnostic claims.
- [ ] Empty/processing states still explain what is happening in plain language.
- [ ] Assessment provenance remains available in a quieter supporting area, but
      it does not dominate the page.
- [ ] Existing detail/history routes for current profile, recommendations,
      assessments, and submitted answers remain available.
- [ ] Request specs cover the revised parent-facing copy and verify hidden
      internal data is not shown on the main profile page.

## Out of Scope

- No new clinical scoring, diagnosis, or diagnostic interpretation.
- No new data model, migration, route, controller, or policy.
- No modification to the current data structure.
- No AI-generated rewrite pipeline.
- No recommendation feedback or outcomes tracking.
- No redesign of onboarding assessment questions.
- No redesign of any page other than the child profile show page.
- No removal of existing detail/history pages.
- No cohort comparison language such as "children with similar profiles tend
  to..." as a standalone section in MVP.
- No full strengths section in MVP unless strengths are already available from
  the current profile narrative.
- No recent signals/timeline section until observations are implemented.
- No adaptive follow-up questions on the child profile page.

## Open Questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Steps

### Step 1 — Review Current Page Against MVP Structure

Audit `app/views/spaces/child_profiles/show.html.erb`,
`app/services/child_profile_results_presenter.rb`, and the related request specs
to identify every parent-facing internal concept that should be hidden,
renamed, or moved into a supporting area. Also identify which MVP elements can
be populated from the current data structure and which need safe dummy/static
fallback content for now.

**Verify:** List the UI elements to remove, keep, rename, reframe, populate
from current data, or fill with dummy/static fallback content before editing
code.
**Revert:** Documentation-only; restore this brief if direction changes.

### Step 2 — Reframe Page Structure

Update the child profile show page so the main content follows the five MVP
sections. Keep the existing dashboard layout, shared page header, and
authorization behavior. Do not change routes, controllers, policies, models, or
database structure.

**Verify:** Request spec confirms the page renders the five MVP section labels
and no longer renders "Profile signals" or "Recommended next steps."
**Revert:** Revert the show view and any small presenter helper changes.

### Step 3 — Hide Internal Profile Mechanics

Remove parent-facing confidence, evidence count, raw dimension key, profile
version, and internal rationale display from the main profile page. Keep raw
records accessible through existing detail/history routes where appropriate.

**Verify:** Request spec confirms confidence/evidence/profile-version language
is absent from the main child profile page.
**Revert:** Revert the show view and any test changes from this step.

### Step 4 — Limit and Reframe Recommendations

Show 2-3 practical ideas in "Try This This Week" and make the section feel
supportive rather than task-oriented. Keep full recommendation history on the
existing recommendations route. Use `Recommendation` records when available and
safe generic fallback content when they are not ready.

**Verify:** Request spec confirms only the intended number of recommendations
appears on the main profile page, while the recommendations index remains
available.
**Revert:** Revert presenter/view changes that limit or relabel main-page
recommendations.

### Step 5 — Polish Empty and Processing States

Rewrite empty, queued, processing, and failed states so they explain the parent
benefit in plain language and avoid internal processing jargon where possible.

**Verify:** Existing queued/failed request specs are updated and pass.
**Revert:** Revert copy-only changes in the view/specs.

---

## Status

- [x] Step 1
- [x] Step 2
- [x] Step 3
- [x] Step 4
- [x] Step 5

**Last updated:** 2026-04-27
**Handoff note:** Stage implemented for the child profile show page only. The
page now renders the five MVP sections, uses current profile/recommendation data
with safe fallback content, hides internal profile mechanics on the main page,
and keeps existing detail/history routes available. Verification: `bundle exec
rspec` and `bundle exec rubocop` both pass.
