# Internal analysis engine (deterministic rubric)

Anchor runs a **local, deterministic** analysis over profile data: no external LLM calls. A **published `AnalysisRubric`** defines domains, how evidence maps into those domains, and parent-facing constraints. Each evaluation produces an **`AnalysisRun`** and one **`AnalysisFinding` per domain that had matching evidence**.

### How the analysis is made (plain language)

Caregivers’ answers and other saved signals are first turned into small, structured rows called **profile evidence**—each row says what topic it belongs to (for example regulation or communication), what was answered, and how confident the system is in that fact. **Analysis does not invent new facts**; it only reads those rows and the latest profile snapshot the run is tied to.

The **rubric** is a fixed recipe: for each topic area (a “domain”), the engine finds every evidence row that belongs to that area, combines them with simple math into a **score** and **confidence**, picks a **severity** band, and writes a short **summary** in careful, support-focused wording. It also **remembers which evidence rows** were used so the result can be traced. The same evidence and the same published rubric always produce the same fingerprint, so the app can **store one completed run per fingerprint** and avoid duplicate work.

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

---

## Updating the rubric (adjust internal analysis)

### Rule: published rows are immutable

**`AnalysisRubric`** forbids changing `schema`, `rubric_key`, `version`, `status`, `description`, `name`, or `published_at` on a row that is already **`published`** or **`archived`**. That is intentional: existing **`AnalysisRun`** rows point at a specific rubric id/version; silently rewriting the schema would make old runs misleading.

So to change scoring, domains, wording, or thresholds you **create a new version** (or a new `rubric_key`), then **publish** that row when ready.

### Typical workflow

1. **Add a new DB row** — Same `rubric_key`, **increment `version`** (unique index is `(rubric_key, version)`), or introduce a new `rubric_key` if you treat it as a separate line of rubrics.
2. **Author `schema`** — Usually by copying `db/seeds/analysis_rubrics/anchor_child_profile_v1.rb` into a new file (e.g. `anchor_child_profile_v2.rb`), bumping the frozen schema constant, and registering it from `db/seeds.rb` with `find_or_initialize_by(rubric_key: ..., version: N)`.
3. **Iterate in draft** — Create/update the record with `status: :draft` via seeds or Rails console until the JSON shape is valid; fix `Analysis::RubricEvaluator` only if you add new **machine-readable** knobs it does not already read (today it uses domains, prefixes, scoring flags, confidence caps, evidence minimums, etc.).
4. **Publish** — Set `status: :published` and **`published_at`** (required by validations). After publish, the row can no longer be edited; ship another version for the next change.

### What happens after you publish

- **`AnalysisRunJob`** runs **`AnalysisRubric.published.find_each`**, so **every published** rubric gets a run for each snapshot. A new version is a **separate** rubric row → **new** `AnalysisRun` records (old runs for old rubric versions remain for history).
- **Idempotency** is per `(child_profile, analysis_rubric, input_digest)` digest comes from **evidence + profile + snapshot**, not from rubric text. Changing only the rubric does **not** change the digest; you get **new** runs because `analysis_rubric_id` differs.
- **Rolling out v2 in production:** Aim for **one** rubric row in **`published`** status for a given product line, so `AnalysisRunJob` and `RecommendationGeneratorJob` behavior stay predictable. **`RecommendationGeneratorJob`** today loads **one** completed `AnalysisRun` per snapshot and does **not** choose a specific `rubric_key`; multiple published rubrics mean multiple runs per snapshot and **undefined** which run grounds recommendations.

**Retiring an older published version:** `AnalysisRubric` blocks **any** `save` that changes core fields on a published row, **including** changing `status` to `archived`. To stop evaluating an old row you currently need a **migration** / **`update_all`** (skips validations), e.g. set `status` to `archived`, or add a future model change that explicitly allows `published → archived` only.

### If you add or rename domains

- **`Analysis::RubricEvaluator`** emits one finding per `schema["domains"][]` that has matching evidence; new `key` values appear as new `AnalysisFinding.dimension_key` values.
- **`RecommendationBuilder`** maps profile `dimension_key`s to **rubric domain keys** via `RUBRIC_DOMAIN_BY_PROFILE_PREFIX` and `rubric_domain_key_for_profile_dimension`. If you add a domain or rename `key`, update that mapping so recommendations can attach **`analysis_finding_*`** fields to the right rows.
- **Parent UI** (`ChildProfileResultsPresenter` / `_analysis_insights`) orders findings from the **latest** completed run globally for the child; confirm that matches your intent when multiple rubric versions have runs.

### Tests and `ENGINE_VERSION`

- Extend or add **`spec/services/analysis/rubric_evaluator_spec.rb`** (and seed specs) when behavior changes.
- Bump **`Analysis::RunCreator::ENGINE_VERSION`** only when **run lifecycle** or payload logic changes in a way you need to distinguish from old runs—not for every rubric JSON tweak.

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
