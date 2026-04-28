# Internal analysis engine (deterministic rubric)

Anchor runs a **local, deterministic** analysis over profile data: no external LLM calls. A **published `AnalysisRubric`** defines domains, how evidence maps into those domains, and parent-facing constraints. Each evaluation produces an **`AnalysisRun`** and one **`AnalysisFinding` per domain that had matching evidence**.

This document complements **`docs/features/stage-6-internal-analysis-engine.md`** (product brief and step checklist) with **developer-oriented** detail: how the rubric is stored, how inputs are built, how scores are computed, and how findings surface in the UI and in **`Recommendation`** rationale.

---

## Why this exists

- **Testable:** Same evidence + same rubric version → same digest and idempotent completed run.
- **Traceable:** Findings carry `evidence_refs` (for example `profile_evidence_ids`) and metadata (`rubric_key`, `rubric_version`, `rubric_domain`).
- **Aligned with the second brain:** `ProfileEvidence` stays the normalized signal layer; analysis reads it via a canonical payload, not by mutating assessments.

---

## Data model

| Model | Role |
|--------|------|
| **`AnalysisRubric`** | Versioned definition: `rubric_key`, `version`, `status` (`draft` / `published`), `schema` (JSONB), `published_at`. Only **published** rubrics are evaluated in jobs. |
| **`AnalysisRun`** | One execution for a child + rubric (+ optional **`ProfileSnapshot`**). Holds `status`, `input_digest`, `engine_version`, timestamps. Completed runs satisfy validations (`input_digest`, `engine_version`, `completed_at`). |
| **`AnalysisFinding`** | Child of a run: `dimension_key` (rubric **domain** key, e.g. `regulation`), `finding_key`, `score`, `confidence`, `severity`, `label`, `summary`, `evidence_refs`, `metadata`. |

Associations:

- `ChildProfile` **has_many** `analysis_runs`
- `AnalysisRun` **belongs_to** `child_profile`, `analysis_rubric`, optional `profile_snapshot`
- `AnalysisFinding` **belongs_to** `analysis_run`

Idempotency: a **partial unique index** enforces at most one **completed** run per `(child_profile_id, analysis_rubric_id, input_digest)` when digest is present. See migration `db/migrate/20260427120000_create_analysis_rubrics_runs_and_findings.rb`.

---

## End-to-end pipeline

After the profile is rebuilt, **`ProfileSnapshotBuilderJob`** ensures there is a snapshot matching the current profile, then enqueues:

1. **`AnalysisRunJob`** — for **each published** `AnalysisRubric`, runs **`Analysis::RunCreator`**
2. **`RecommendationGeneratorJob`** — rebuilds recommendations from `CurrentProfile` dimensions

Both use the **same** `profile_snapshot_id`. **`RecommendationGeneratorJob`** loads a **completed** `AnalysisRun` for that child and snapshot (if any) and passes it to **`RecommendationBuilder`** so `rationale` can include `analysis_run_id`, `analysis_finding_id`, etc. If analysis has not finished yet, recommendations are still generated; grounding keys are simply omitted until a later run with a completed analysis.

High-level flow:

```text
ProfileEvidence + CurrentProfile
    → CurrentProfileBuilder / evidence jobs
    → ProfileSnapshotBuilderJob
        → ProfileSnapshot (if new or changed)
        → AnalysisRunJob (per published rubric)
              → Analysis::RunCreator
        → RecommendationGeneratorJob
              → RecommendationBuilder (+ optional analysis_run)
```

---

## Services (evaluation stack)

### `Analysis::InputBuilder`

Builds a single **hash payload** used for evaluation and for **digesting**:

- **`child_profile`** — stable identity fields
- **`evidence`** — all `ProfileEvidence` rows for the child, ordered by `id`, each serialized (`dimension_key`, `concept_key`, `value`, `value_type`, `confidence`, etc.)
- **`current_profile`** — version, `generated_at`, sorted `summary`
- **`profile_snapshot`** — when present: id, `generated_at`, sorted `summary`

**`InputBuilder.digest`:** recursively **sorts object keys**, `JSON.generate`, then **`Digest::SHA256`** hex digest. Any change to ordered evidence or profile content changes the digest and allows a **new** completed run.

### `Analysis::RubricEvaluator`

Purely deterministic. For each **domain** in `rubric.schema["domains"]`:

1. **Match evidence** — keep rows whose `dimension_key` matches any `dimension_key_prefixes` entry (prefix rules support trailing `.` for segment boundaries).
2. If no rows, **no finding** for that domain.
3. Otherwise:
   - **Score:** For integer-like values, maps 1–5 → 0–1 (`concern_norm`), then applies `higher_is_more_support` (inverted when false). Non-integer types currently score `0.5`.
   - **Weights:** `confidence` × optional `metadata.evidence_weight` (default multiplier 0.5 if missing/invalid), clamped.
   - **Aggregate:** weighted mean of scores → `mean_score` (clamped 0–1).
   - **Confidence:** mean row confidence × penalty if below `evidence_minimums.min_rows`, capped by `confidence.base_cap`.
   - **Severity:** `low` if confidence below rubric threshold; else bands from `mean_score` (`low` / `medium` / `high`).

Emits a hash suitable for `AnalysisFinding` create: `finding_key` is `"#{domain_key}.support_signal"`, `summary` is non-diagnostic copy, `evidence_refs.profile_evidence_ids` lists matched rows, `metadata` includes `rubric_domain`, counts, schema version.

### `Analysis::RunCreator`

- Requires **`analysis_rubric.published?`**.
- Under **`child_profile.with_lock`** (avoids duplicate runs under concurrency):
  - Builds payload + digest
  - If a **completed** run exists for same child, rubric, digest → **returns it**
  - Else creates run `running`, persists findings from **`RubricEvaluator`**, marks **`completed`**
- **`ENGINE_VERSION`** is `"1.0.0"` (bump when run semantics change).

---

## Current published rubric: `anchor_child_profile_v1`

**Seed file:** `db/seeds/analysis_rubrics/anchor_child_profile_v1.rb`  
**Loaded from:** `db/seeds.rb` (`load ... anchor_child_profile_v1.rb`)

**Identity:** `rubric_key: "anchor_child_profile_v1"`, `version: 1`, **published** if new or not already published.

**Schema top level** (`ANCHOR_CHILD_PROFILE_V1_RUBRIC_SCHEMA`):

- `version`, `engine` (`deterministic_v1`)
- **`wording`** — `use_terms`, `avoid_terms`, `stance` (used for product consistency; evaluator summary follows non-diagnostic phrasing)
- **`domains`** — array of domain objects (below)

### Domains (v1)

Each domain has at least: `key`, `title`, `dimension_key_prefixes`, `accepted_concept_keys`, `scoring`, `confidence`, `evidence_minimums`, `parent_labels.anchor`, `support_categories`, `safety`.

| Domain `key` | Evidence prefixes (summary) |
|----------------|-----------------------------|
| `communication` | `communication.` |
| `social_connection` | `social.` |
| `flexibility` | `behavior.`, `regulation.routine`, `regulation.transitions` |
| `sensory_experience` | `sensory.` |
| `regulation` | `regulation.` (routine/transitions overlaps flexibility by prefix design) |
| `daily_life` | `daily_living.`, `adaptive.` |
| `strengths_and_motivators` | `strengths.` — `higher_is_more_support: false` |
| `family_priorities` | `priorities.`, `context.` |

**Changing v1 after publish:** Treat the seeded rubric as **append-only** for behavior: ship a **new row** (`rubric_key` and/or higher `version`) and publish that, rather than editing a rubric customers already ran against (keeps history and digests meaningful).

---

## UI and recommendations

### Parent-visible insights

**`ChildProfileResultsPresenter`** exposes the latest **completed** analysis run (with findings) for display. Shared partial **`app/views/child_profiles/shared/_analysis_insights.html.erb`** is included from space child profile show and current profile show. Copy stays support-oriented and aligned with rubric `wording.avoid_terms`.

### Recommendation grounding

**`RecommendationBuilder`** maps each profile **dimension** (e.g. `regulation.overall_concern`) to a **rubric domain key** (e.g. `regulation`) so it can attach the matching **`AnalysisFinding`** to `rationale`:

- String keys: `analysis_run_id`, `analysis_rubric_key`, `analysis_rubric_version`, `analysis_finding_id`, `analysis_finding_key`
- Mapping handles prefixes that differ between profile dimensions and rubric keys (e.g. `sensory.*` → `sensory_experience`, `behavior.*` / certain `regulation.*` → `flexibility`). See `RecommendationBuilder::RUBRIC_DOMAIN_BY_PROFILE_PREFIX` and `rubric_domain_key_for_profile_dimension`.

If there is no completed analysis for that snapshot, **`rationale` omits** those keys; titles and bodies are unchanged.

---

## Jobs reference

| Job | Responsibility |
|-----|----------------|
| **`AnalysisRunJob`** | `AnalysisRubric.published.find_each` → `Analysis::RunCreator` for the snapshot |
| **`RecommendationGeneratorJob`** | Resolves completed `AnalysisRun` for snapshot → `RecommendationBuilder` → replaces active recommendations |

---

## Tests and verification

- Models: `spec/models/analysis_*_spec.rb`
- Services: `spec/services/analysis/*_spec.rb`, `spec/services/recommendation_builder_spec.rb`
- Jobs: `spec/jobs/analysis_run_job_spec.rb`, `spec/jobs/profile_snapshot_builder_job_spec.rb`, `spec/jobs/recommendation_generator_job_spec.rb`
- Seed: `spec/db/anchor_child_profile_rubric_seed_spec.rb`

---

## Related files (quick index)

| Area | Path |
|------|------|
| Rubric seed | `db/seeds/analysis_rubrics/anchor_child_profile_v1.rb` |
| Input + digest | `app/services/analysis/input_builder.rb` |
| Evaluator | `app/services/analysis/rubric_evaluator.rb` |
| Run persistence | `app/services/analysis/run_creator.rb` |
| Jobs | `app/jobs/analysis_run_job.rb`, `app/jobs/profile_snapshot_builder_job.rb`, `app/jobs/recommendation_generator_job.rb` |
| Recommendations | `app/services/recommendation_builder.rb` |
| Presenter + views | `app/services/child_profile_results_presenter.rb`, `app/views/child_profiles/shared/_analysis_insights.html.erb` |
| Product brief | `docs/features/stage-6-internal-analysis-engine.md` |
| Architecture overview | `docs/ARCHITECTURE.md` (Section 6 + second-brain pipeline) |
