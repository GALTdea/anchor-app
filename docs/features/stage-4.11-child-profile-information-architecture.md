# Stage 4.11 — Child Profile Information Architecture

> Light brief. Refines what belongs on the parent-facing child profile show page
> versus existing deeper views, before the next visual UX pass.

---

## Goal

Turn the child profile show page into a compact parent dashboard that answers
what Anchor understands, what matters most right now, what to do this week, and
what to pay attention to next.

## Changes

Rework the content hierarchy for `app/views/spaces/child_profiles/show.html.erb`
and the supporting presenter/helper code so the show page keeps only the
highest-value parent dashboard content.

The page should no longer try to be the full synthesized profile, the full
recommendation library, assessment history, observation timeline, or internal
evidence audit surface. Those experiences should live on existing deeper pages
where possible:

- Full Profile: use the existing
  `space_child_profile_current_profile_path(@space, @child_profile)` surface.
- Recommendations: use the existing
  `space_child_profile_recommendations_path(@space, @child_profile)` surface.
- Assessments: use the existing
  `space_child_profile_assessments_path(@space, @child_profile)` surface.
- Observations: reserve for the Stage 3 observations surface when implemented.
- Explainability: defer a future "Why Anchor thinks this" surface.

The show page should keep only these parent-homepage blocks:

1. Child Snapshot
2. Plain-language Summary
3. What Anchor Is Noticing
4. What to Focus on Right Now
5. Try This This Week
6. What We're Still Learning

The implementation should also update labels and links so parents can reach
deeper pages without those deeper concepts dominating the main child profile
experience.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action must call `authorize` through existing Pundit
      policies.
- [ ] Keep controllers thin; page assembly belongs in presenters/helpers, not
      controller actions.
- [ ] Preserve the existing analysis architecture:
      `AssessmentResponse` remains the raw audit trail, `ProfileEvidence`
      remains the normalized signal layer, `CurrentProfile` remains the latest
      portrait, and `Recommendation` remains the action layer.
- [ ] Do not introduce new models, migrations, or policies in this stage.
- [ ] Prefer existing routes for deeper surfaces before adding any new route.
- [ ] Scope the main-page IA work to the child profile show page and the
      existing current profile, recommendations, and assessments pages only as
      needed for labels/navigation.
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

## Child Profile Show Page IA

### 1. Child Snapshot

Keep this compact at the top of the page.

Include:

- child name
- age
- last updated
- profile freshness, such as "updated today" or "updated 3 days ago"
- optional parent-friendly confidence state, such as "early profile", "growing
  confidence", or "well-established"

Do not show raw profile version, evidence counts, score counts, or internal
freshness logic.

### 2. Plain-language Summary

Keep one concise paragraph near the top of the page.

The summary should explain, in plain language, how the child tends to respond,
learn, struggle, or receive support. It should avoid:

- jargon
- scoring language
- domain names
- repeated "Anchor has detected" framing
- diagnostic claims

This is the emotional anchor of the page and should read like "explain my child
to me", not like a report.

### 3. What Anchor Is Noticing

Keep 3-5 concise observations.

Each observation should be behavior-based and skimmable. Good examples:

- "Your child does best when tasks feel predictable."
- "Unexpected changes seem to raise stress quickly."
- "Support works best when it lowers pressure before giving instruction."

Avoid repetitive lead-ins, model mechanics, score language, and diagnostic
claims.

### 4. What to Focus on Right Now

Keep 2-3 current priorities.

Each priority should include:

- simple label
- one-sentence explanation
- why it matters now

This section should help a parent decide where to put attention this week
without feeling like they have been assigned a large care plan.

### 5. Try This This Week

Keep exactly the top 3 practical actions when enough data exists; show fewer
when fewer useful recommendations exist.

Each action should be short, concrete, and feasible in real life. One action
equals one card. Prefer recommendations from active `Recommendation` records,
but do not expose the full recommendation library here.

### 6. What We're Still Learning

Keep 2-4 uncertainty areas.

Frame these as working hypotheses or useful patterns to notice, not deficits.
This section should build trust by making the profile feel iterative and honest
without turning the parent into a data-entry worker.

## Move to Existing Deeper Views

### Full Profile

Use the existing current profile detail page as the Full Profile surface.

This is where deeper synthesized content belongs:

- deeper narrative
- domain breakdown
- learning patterns
- communication profile
- regulation profile
- flexibility profile
- sensory patterns
- strengths profile
- support needs

The child profile show page should only surface the short summary, key
observations, current focus, and next actions.

### Recommendations

Use the existing recommendations index/detail pages as the recommendation
library.

This is where the full set of active recommendations belongs:

- all active recommendations
- categories
- why each was suggested
- linked evidence, where available and parent-appropriate
- status, when supported by the current model
- feedback loop, when implemented later

The child profile show page should show only the top 3 actions.

### Assessments

Use the existing assessments page for assessment history and submissions.

This is where historical assessment artifacts belong:

- completed assessments
- in-progress assessments
- submissions
- retakes
- changes over time, when supported

The child profile show page may reference this only as quiet provenance, such as
"Profile updated from onboarding assessment 2 days ago."

### Observations

Do not add observations in this stage unless Stage 3 has already been
implemented.

When observations exist, the child profile show page may show only a recent
activity preview, such as the last 3 observations. The full observation stream
belongs on its own timeline page.

### Why Anchor Thinks This

Defer this surface.

Evidence provenance, system reasoning, source weighting, and traceability should
not be shown by default on the parent dashboard. Later, these may belong in a
separate explainability view or a quiet expandable "Why am I seeing this?"
detail.

## Hide from Parent Default View

Remove or hide these from the default child profile show page:

- raw evidence matrix
- domain scores
- confidence per domain
- evidence counts
- parent proxy scoring tables
- matrix values such as "2 / 3 / 1"
- extraction confidence blocks
- repeated domain-by-domain interpretation blocks
- internal confidence percentages
- phrases like "based on 5 scored observations"
- provenance chains
- dimension keys
- concept keys
- source weighting
- model mechanics

Parent-friendly confidence is acceptable only when it changes interpretation,
for example:

- "This is an early hypothesis."
- "Anchor is still learning this pattern."
- "This profile should get more useful as more is shared."

## Acceptance Criteria

- [ ] The child profile show page renders only the six parent-dashboard blocks:
      Child Snapshot, Plain-language Summary, What Anchor Is Noticing, What to
      Focus on Right Now, Try This This Week, and What We're Still Learning.
- [ ] The show page answers the four parent questions: what Anchor understands,
      what matters now, what to do this week, and what to pay attention to next.
- [ ] The show page displays no more than 5 observations, 3 focus priorities,
      3 weekly actions, and 4 learning areas.
- [ ] The show page includes child name, age, last updated/freshness, and a
      parent-friendly profile state when available.
- [ ] The show page does not expose raw evidence, domain scores, evidence
      counts, confidence percentages, dimension keys, concept keys, provenance
      chains, profile version, or extraction confidence.
- [ ] The show page does not contain parent-facing labels that make internal
      systems primary, such as "Profile signals", "Evidence matrix",
      "Confidence score", or "Scored dimensions."
- [ ] The full profile/current profile detail surface remains reachable.
- [ ] The recommendations index remains reachable as the full recommendation
      library.
- [ ] The assessments index remains reachable as assessment history.
- [ ] Observations are not introduced on the show page unless an observations
      route/model already exists.
- [ ] Empty, loading, and early-profile states use plain parent-facing language.
- [ ] Request specs verify both visible dashboard content and hidden internal
      language.

## Out of scope

- No visual redesign beyond the structure needed to support the new IA.
- No new AI synthesis pipeline.
- No new recommendation scoring or ranking algorithm.
- No recommendation feedback/outcomes tracking.
- No clinical diagnosis, scoring, or medical interpretation.
- No new observation model or observation CRUD implementation.
- No new admin or clinician mode.
- No full explainability/audit view in this stage.
- No removal of existing current profile, recommendation, assessment, or
  assessment response records.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Steps

### Step 1 — Audit Current Child Profile Content

Review `app/views/spaces/child_profiles/show.html.erb`,
`app/services/child_profile_results_presenter.rb`, existing child profile
request specs, and the existing current profile/recommendations/assessments
views. Classify each current item as keep on dashboard, move to deeper view,
hide from parent default view, or defer.

**Verify:** Produce a short keep/move/hide/defer list before editing code.
**Revert:** Documentation-only; restore this brief if direction changes.

### Step 2 — Update Presenter Shape for Dashboard Limits

Add or adjust presenter/helper methods so the dashboard can ask for bounded
sets: summary, 3-5 observations, 2-3 focus areas, up to 3 weekly actions, and
2-4 learning areas. Keep fallback content parent-friendly and low-risk.

**Verify:** Targeted specs cover limits and fallback behavior.
**Revert:** Revert presenter/helper and spec changes from this step.

### Step 3 — Rebuild the Show Page Around Six Blocks

Update the child profile show view so the main page contains only the six
parent-dashboard blocks. Add quiet links to Full Profile, Recommendations, and
Assessments where useful, but do not let them become the main page content.

**Verify:** Request spec confirms all six sections render and old internal
primary sections do not render.
**Revert:** Revert the show view and related spec changes.

### Step 4 — Move or Reframe Deep Content

Ensure deeper profile narrative, full recommendation lists, and assessment
history are reachable from existing deeper pages. Update labels/copy on those
pages only as needed so the IA feels intentional.

**Verify:** Request specs confirm current profile, recommendations, and
assessments routes still render for authorized users.
**Revert:** Revert copy/navigation changes on deeper views.

### Step 5 — Hide Internal System Language by Default

Remove raw evidence, score, confidence, provenance, dimension, and extraction
language from the parent default show page. Keep internal records available
through existing technical/detail surfaces where they already exist.

**Verify:** Request spec asserts the hidden phrases do not appear on the child
profile show page.
**Revert:** Revert show view, presenter/helper, and spec changes from this step.

### Step 6 — Final Verification

Run the targeted request specs, then the full suite and RuboCop at the stage
boundary.

**Verify:** `bundle exec rspec` and `bundle exec rubocop`
**Revert:** Revert the stage changes if the final verification cannot be made
green within the session.

---

## Status

- [x] Step 1
- [x] Step 2
- [x] Step 3
- [x] Step 4
- [x] Step 5
- [x] Step 6

**Last updated:** 2026-04-30
**Handoff note:** Stage implemented. The child profile show page now renders the
six parent-dashboard blocks, uses a compact snapshot with freshness/profile
state, routes deeper profile/recommendation/assessment content to existing
surfaces, hides analysis/evidence mechanics from the default parent dashboard,
and keeps top-level guidance bounded to parent-actionable content. Verification:
`bundle exec rspec` and `bundle exec rubocop` pass.
