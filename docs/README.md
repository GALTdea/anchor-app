## docs/

Documentation for this Rails application.

---

## Start here

**[AGENTS.md](AGENTS.md)** — AI agent entry point.
Read this first in every Cursor or AI coding session.
Contains the full stack, key files, layout system,
and what NOT to do.

---

## App development docs

Reference these when building features.

| File | Contents |
|------|----------|
| [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md) | Product goal, target user, and MVP promise |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Domain model, layout system, request lifecycle, AppSettings, background jobs |
| [modules/internal_analysis_engine.md](modules/internal_analysis_engine.md) | Deterministic analysis: rubric schema, `anchor_child_profile_v1`, evaluation, jobs, UI + recommendation grounding |
| [assessment_templates.md](assessment_templates.md) | Step-by-step runbook for adding and versioning seeded assessment templates |
| [CONVENTIONS.md](CONVENTIONS.md) | Coding conventions, UI patterns, daisyUI 5 class reference, form patterns |
| [SETUP.md](SETUP.md) | First-time setup, prerequisites, credentials |

---

## AI development process

Repeatable workflow for building features with AI assistance.

| File | Contents |
|------|----------|
| [process/ai-dev-flow.md](process/ai-dev-flow.md) | Five-phase dev flow: Brief → Review → Build → Audit → Document |

## Feature briefs

Planning artifacts for each feature stage. Read the current brief
at the start of every AI coding session.

| File | Contents |
|------|----------|
| [features/_template-full.md](features/_template-full.md) | Full brief template (new models, controllers, migrations) |
| [features/_template-light.md](features/_template-light.md) | Light brief template (config, seeds, docs, UI copy) |
| [features/_constraints.md](features/_constraints.md) | Shared app invariants reference |
| [features/stage-0-foundation.md](features/stage-0-foundation.md) | Stage 0 — Foundation cleanup (roles, permissions, UI labels) |
| [features/stage-1-child-profile.md](features/stage-1-child-profile.md) | Stage 1 — Child profile + single-guardian flow |
| [features/stage-2-invite-caregiver.md](features/stage-2-invite-caregiver.md) | Stage 2 — Invite caregiver *(deferred post-MVP)* |
| [features/stage-3-observations.md](features/stage-3-observations.md) | Stage 3 — Observations *(deferred post-MVP)* |
| [features/stage-4-assessments.md](features/stage-4-assessments.md) | Stage 4 — Assessments *(MVP with Stage 1)* |
| [features/stage-4.5-adaptive-assessments.md](features/stage-4.5-adaptive-assessments.md) | Stage 4.5 — Onboarding assessment UX + second brain foundation *(draft proposal)* |
| [features/stage-4.6-first-time-parent-onboarding.md](features/stage-4.6-first-time-parent-onboarding.md) | Stage 4.6 — First-time parent onboarding funnel *(draft proposal)* |
| [features/stage-4.7-guided-assessment-runner.md](features/stage-4.7-guided-assessment-runner.md) | Stage 4.7 — Guided assessment runner *(draft proposal)* |
| [features/stage-4.9-child-profile-results-home.md](features/stage-4.9-child-profile-results-home.md) | Stage 4.9 — Child profile results home *(draft proposal)* |
| [features/stage-6-internal-analysis-engine.md](features/stage-6-internal-analysis-engine.md) | Stage 6 — Internal analysis engine (deterministic rubric) |

## Optional modules

Pre-researched patterns for common features.
Not installed by default — add per app as needed.

| File | Contents |
|------|----------|
| [modules/billing.md](modules/billing.md) | Stripe integration pattern |
| [modules/api.md](modules/api.md) | API layer pattern |
| [modules/file_uploads.md](modules/file_uploads.md) | Active Storage + S3 |
| [modules/multitenancy.md](modules/multitenancy.md) | Multi-tenant patterns |

---

## Template maintenance

Only relevant when improving the template itself.
Safe to ignore when building an app from this template.

| File | Contents |
|------|----------|
| [template/MAINTENANCE.md](template/MAINTENANCE.md) | Status checklist, phase history, planned improvements, version history |
| [template/DECISIONS.md](template/DECISIONS.md) | Architecture and technology decision log |
| [template/README.md](template/README.md) | Template folder guide |
