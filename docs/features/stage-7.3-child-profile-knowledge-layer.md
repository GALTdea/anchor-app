# Stage 7.3 - Child Profile Knowledge Layer

> Light brief. Post-MVP proposal for turning Anchor's structured child profile
> data into task-specific knowledge bundles. This stage should improve AI
> grounding and product explainability without making vector search the primary
> memory layer.

---

## Goal

Formalize Anchor's child profile memory as structured, task-specific knowledge
bundles that can be used by AI synthesis, recommendations, profile change
summaries, and future caregiver/practitioner workflows.

## Product thesis

Anchor should avoid treating child profile memory as generic RAG over text
chunks. The core product memory is already structured: child details,
assessment answers, profile evidence, deterministic findings, recommendations,
profile snapshots, confidence, freshness, and provenance.

Parents do not need Anchor to retrieve random "relevant chunks." They need
Anchor to understand the current support picture, explain where that picture
came from, and recommend what to try next.

## MVP boundary

This is not part of MVP.

MVP should continue using deterministic analysis findings and tightly scoped AI
synthesis. No vector database, broad semantic search, or generic memory
retrieval is required for launch.

## Current foundation

Anchor already has the raw ingredients for a knowledge layer:

- `ProfileEvidence` stores normalized observations with dimensions, concepts,
  confidence, respondent kind, source, timestamp, and metadata.
- `CurrentProfile` stores the current structured profile summary and narrative.
- `ProfileSnapshot` preserves point-in-time profile state.
- `AnalysisRun` and `AnalysisFinding` store deterministic rubric output.
- `Recommendation` stores generated guidance with rationale and source
  snapshot references.
- `AssessmentTemplate` schemas preserve question structure, sections,
  branching, and versioned meaning.
- `AiSynthesisRun` stores provider/model/prompt metadata, request payloads,
  validated output, and failure state.

## Proposed direction

Introduce a `ChildProfileKnowledgeBundleBuilder` or equivalent service layer
that assembles compact, structured context packets for specific jobs.

Example bundle types:

- parent support guide bundle
- recommendation generation bundle
- "what changed since last time?" bundle
- next assessment question bundle
- caregiver handoff bundle
- practitioner review bundle
- profile evidence audit bundle

Each bundle should be intentionally shaped for its task instead of dumping full
profile history into model context.

Example bundle shape:

```json
{
  "bundle_schema_version": "child_profile_knowledge_bundle_v1",
  "bundle_type": "parent_support_guide",
  "child": {},
  "profile_state": {},
  "current_profile_summary": {},
  "top_analysis_findings": [],
  "evidence_by_finding": {},
  "recommendations": [],
  "confidence_and_freshness": {},
  "missing_or_low_confidence_areas": [],
  "provenance": {}
}
```

## Data shapes

### Document trees

Assessment templates, sections, questions, branching rules, answer provenance,
and versioned question meaning.

Use this shape when Anchor needs to explain where an answer came from or why a
question was asked.

### Tabular data

Profile evidence, findings, recommendations, snapshots, confidence scores,
timestamps, respondent kinds, and statuses.

Use this shape for deterministic filtering, scoring, freshness checks, and
bundle assembly. SQL and domain keys should come before semantic retrieval for
core profile data.

### Knowledge graph

Relationships between child profiles, assessment responses, evidence rows,
analysis findings, recommendations, source questions, respondents, and
snapshots.

Use this shape to answer provenance questions such as:

- "Why does Anchor think this?"
- "Which answers contributed to this recommendation?"
- "What changed between the last profile and this one?"
- "Which areas are strong signals versus weak signals?"

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] AI must not replace deterministic analysis as the source of truth.
- [ ] Bundles must be task-specific and compact.
- [ ] Bundle schemas must be versioned.
- [ ] Bundle output must preserve provenance to source evidence, findings, and
      snapshots.
- [ ] Low confidence, stale evidence, and missing data should be explicit in the
      bundle instead of hidden.
- [ ] AI prompts should consume bundles, not raw database records directly.
- [ ] Parent-facing copy must remain non-diagnostic and uncertainty-aware.
- [ ] Vector search, if introduced later, must be an auxiliary retrieval signal,
      not the primary memory model for child profile facts.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Out of scope

- No MVP implementation.
- No vector database.
- No generic chat memory.
- No broad semantic search over child records.
- No replacement of `Analysis::RubricEvaluator`.
- No model-generated clinical scores, diagnoses, or deterministic findings.
- No parent-facing provenance UI in the first bundle-only iteration unless a
  later brief explicitly adds it.

## Decisions

- Treat Anchor's structured child profile data as the primary memory layer.
- Prefer SQL/domain-key retrieval for core child profile facts.
- Build task-specific bundles before considering vector search.
- Preserve provenance from AI-facing context back to source records.
- Make freshness, confidence, and missing data first-class bundle metadata.
- Use vector search later only for suitable fuzzy retrieval domains, such as
  long-form notes, uploaded documents, or external resource matching.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- Which bundle should be implemented first?
- Should bundles be generated on demand, persisted, or both?
- What bundle metadata should be visible to parents versus admin/internal users?
- How should stale evidence decay over time?
- How should conflicting evidence from multiple caregivers be represented?
- What permissions apply when multiple caregivers contribute evidence?

## Future phases

### Phase 1 - Define bundle schemas

Document one or two bundle schemas in code or docs before implementation.
Likely candidates:

- `parent_support_guide`
- `recommendation_generation`
- `profile_change_summary`

**Verify:** bundle schemas can be reviewed without running AI.
**Revert:** remove the draft schema document or constants.

### Phase 2 - Add bundle builder service

Add `ChildProfileKnowledgeBundleBuilder` or a namespaced equivalent. The service
should accept a `child_profile`, `bundle_type`, and optional source snapshot or
analysis run.

**Verify:** unit specs cover bundle shape, provenance, freshness metadata, and
low-confidence indicators.
**Revert:** remove the service and specs.

### Phase 3 - Use bundles in AI synthesis prompts

Update AI prompt rendering so future synthesis can consume a bundle as its
structured source of truth.

**Verify:** prompt-rendering specs assert that AI receives the compact bundle,
not broad child records.
**Revert:** restore the previous prompt payload path.

### Phase 4 - Add provenance surfaces

Expose simple "why Anchor thinks this" information in parent or internal views,
grounded in bundle provenance.

**Verify:** UI shows source-safe explanations without exposing sensitive raw
payloads unnecessarily.
**Revert:** remove provenance UI and presenter methods.

### Phase 5 - Evaluate vector search only where it fits

Consider vector search for fuzzy domains only after bundles are working:

- long-form parent notes
- uploaded school/provider documents
- external resources
- historical observation text

**Verify:** vector retrieval is supplemental and cannot override structured
profile facts.
**Revert:** disable vector-backed retrieval without breaking bundle-based
features.

## Success criteria

- [ ] AI outputs are more grounded and less generic.
- [ ] Recommendations can explain their source evidence.
- [ ] Anchor can answer "what changed?" without rereading everything.
- [ ] Context size stays small because each task receives only the right bundle.
- [ ] Bundle payloads make confidence, freshness, gaps, and provenance visible.
- [ ] Vector search remains optional and secondary to structured profile memory.

---

## Status

- [ ] Post-MVP proposal documented
- [ ] Bundle schemas defined
- [ ] Bundle builder implemented
- [ ] AI synthesis consumes bundles
- [ ] Provenance surfaces designed

**Last updated:** 2026-05-13
**Handoff note:** This is a future direction brief only. Keep it out of MVP
scope until Stage 7 synthesis is stable and there is a concrete product surface
that needs richer structured context.
