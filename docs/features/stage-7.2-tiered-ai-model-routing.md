# Stage 7.2 - Tiered AI Model Routing

> Light brief. Adds model-selection logic on top of the Stage 7.1 live provider
> adapter. The default path uses a lower-cost/lower-latency model for routine
> parent-facing synthesis, and escalates to a stronger model only when the
> synthesis packet indicates complexity or the first attempt fails validation.

---

## Goal

Route AI synthesis attempts to an appropriate configured model based on
complexity, confidence, free-text load, and validation outcomes while preserving
the compact synthesis-packet safety boundary.

## Changes

This stage changes model selection only. It should not add new database tables,
routes, controllers, policies, or parent-facing workflows.

Existing Stage 7.1 live-provider flow:

```text
AnalysisRun completed
-> compact AI synthesis packet rendered
-> Ai::Client calls configured live provider
-> Ai::StructuredOutputValidator validates text output
-> AiSynthesisRun records provider/model/prompt/output metadata
```

Proposed changes:

- Add an `Ai::ModelRouter` or equivalent service that selects a model before
  `Ai::Client#complete`.
- Use a default lower-cost/lower-latency model for routine synthesis.
- Escalate to a stronger configured model only when the synthesis packet or prior
  attempt indicates more complexity.
- Record the selected model and routing reason in safe metadata.
- Keep all model ids environment-configured; do not hard-code product logic to a
  specific OpenAI model id.
- Keep `Ai::StructuredOutputValidator` as the output correctness boundary.
- Keep the compact synthesis packet as the input boundary. Model escalation must
  not expand the provider payload by default.

### Model tiers

Initial environment configuration:

- `ANCHOR_AI_DEFAULT_MODEL` - lower-cost/lower-latency default model for routine
  synthesis.
- `ANCHOR_AI_ESCALATION_MODEL` - stronger model for more complex synthesis.

Optional future configuration:

- `ANCHOR_AI_VALIDATION_RETRY_MODEL` - model used when the first attempt returns
  invalid output. If unset, use `ANCHOR_AI_ESCALATION_MODEL`.
- `ANCHOR_AI_ESCALATION_ENABLED` - feature flag for model escalation. Default can
  be false until tested locally.

### Escalation criteria

Escalate only when at least one clear signal is present:

- conflicting findings or evidence conflict markers in the synthesis packet
- low average confidence or one or more important low-confidence findings
- high free-text load, based on packet metadata such as excerpt count/length
- first synthesis attempt failed `Ai::StructuredOutputValidator`
- severity mix suggests the explanation needs more careful wording
- packet metadata explicitly marks the case as complex

The first version can use conservative deterministic thresholds. Avoid asking AI
which model to use.

### Safety and privacy boundary

The model router must choose from metadata already present in the compact
synthesis packet, the `AnalysisRun`, and previous `AiSynthesisRun` attempt
metadata.

The router must not:

- query full child records to decide model tier
- send the whole child record to a stronger model
- include extra raw assessment answers during escalation
- relax validation requirements for stronger models

Escalation changes the model, not the data boundary.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Keep controllers thin; no controller should choose AI models directly.
- [ ] Use Active Job with Solid Queue; model routing continues to happen inside
      the synthesis job/service path.
- [ ] AI synthesis can only run from a completed deterministic `AnalysisRun`.
- [ ] The compact AI synthesis packet remains the maximum provider payload.
- [ ] AI must not create rubric scores, findings, clinical claims, or
      safety-sensitive conclusions.
- [ ] AI output must still pass `Ai::StructuredOutputValidator` before display.
- [ ] Model escalation must not bypass validation or send additional raw child
      data.
- [ ] Model ids and tier configuration must come from environment/configuration,
      not hard-coded product logic.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Out of scope

- No new models, migrations, controllers, policies, or routes.
- No provider comparison dashboard.
- No automated cost budgeting UI.
- No multi-vendor routing.
- No prompt management UI.
- No conversational AI chat.
- No changes to Stage 6 deterministic analysis logic.
- No changes to the analysis rubric.
- No production enablement by default.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Decisions

- Default synthesis should use a lower-cost/lower-latency configured model.
- Escalation should be deterministic and based on packet/analysis metadata.
- Escalation changes only the selected model, not the amount of child data sent.
- Validation-failure retry may use the escalation model once, then fail closed.
- Store routing reason as safe operational metadata.
- Keep exact model ids in environment configuration.

## Steps

### Step 1 - Add tier configuration

Extend `Ai::Configuration` to expose default and escalation model settings,
including safe defaults for disabled/stub mode.

Expected environment variables:

- `ANCHOR_AI_DEFAULT_MODEL`
- `ANCHOR_AI_ESCALATION_MODEL`
- optional `ANCHOR_AI_VALIDATION_RETRY_MODEL`
- optional `ANCHOR_AI_ESCALATION_ENABLED`

**Verify:** `bundle exec rspec spec/services/ai/configuration_spec.rb spec/services/ai/client_spec.rb`
**Revert:** Remove the new configuration accessors and specs.

### Step 2 - Add deterministic model router

Implement `Ai::ModelRouter` to choose:

- selected model
- tier key, such as `default` or `escalated`
- routing reason
- signals used for routing

The router should use only compact synthesis packet metadata, completed
`AnalysisRun` data, and previous synthesis attempt metadata.

**Verify:** `bundle exec rspec spec/services/ai/model_router_spec.rb`
**Revert:** Remove the router and specs.

### Step 3 - Route initial synthesis attempts

Update `Ai::SynthesisRunner` so it asks the router for the model before calling
`Ai::Client#complete`. Persist the routing reason in safe request or response
metadata.

**Verify:** `bundle exec rspec spec/services/ai/synthesis_runner_spec.rb spec/jobs/ai_synthesis_job_spec.rb`
**Revert:** Remove router integration from the runner.

### Step 4 - Add validation-failure escalation retry

When the default model returns output that fails `Ai::StructuredOutputValidator`,
optionally retry once with the escalation/validation-retry model if escalation is
enabled and the first attempt did not already use that model.

The failed first attempt should remain auditable or be represented in metadata;
the successful retry, if any, should still persist a normal completed
`AiSynthesisRun`.

**Verify:** `bundle exec rspec spec/services/ai/synthesis_runner_spec.rb`
**Revert:** Remove retry-on-validation-failure behavior.

### Step 5 - Add packet complexity signals

If the current `Ai::PromptRenderer` packet does not expose enough metadata, add
small explicit fields such as:

- average confidence
- low-confidence finding count
- severity counts
- finding count
- free-text excerpt count
- free-text excerpt character count
- conflict marker count

Do not include raw records or unbounded free text.

**Verify:** `bundle exec rspec spec/services/ai/prompt_renderer_spec.rb spec/services/ai/model_router_spec.rb`
**Revert:** Remove packet metadata additions.

### Step 6 - Document manual testing

Update this brief's status handoff or add a short docs note showing how to test:

- default routing
- escalation routing
- validation-failure retry
- stub mode still working

Example console check:

```ruby
run = AnalysisRun.completed.order(created_at: :desc).first
AiSynthesisJob.perform_now(run.id, force: true)
synthesis = run.ai_synthesis_runs.order(created_at: :desc).first
synthesis.slice(:status, :provider, :model, :prompt_version, :error_message)
synthesis.request_payload.dig("model_routing")
```

**Verify:** Manual smoke test in development with stub mode. If a live key is
available, repeat with live OpenAI mode.
**Revert:** Remove the docs note or status addition.

### Step 7 - Run stage verification

Run targeted specs for routing and synthesis, then the normal stage boundary
checks.

**Verify:**

```text
bundle exec rspec spec/services/ai/model_router_spec.rb spec/services/ai/synthesis_runner_spec.rb spec/jobs/ai_synthesis_job_spec.rb
bundle exec rubocop
```

If time permits before commit:

```text
bundle exec rspec
```

**Revert:** Revert this stage's service/spec/doc changes.

---

### Local routing smoke checks (development)

- **Default routing:** leave `ANCHOR_AI_ESCALATION_ENABLED` unset or `false`; run `AiSynthesisJob.perform_now` and inspect `request_payload["model_routing"]["tier"]` (expect `default`).
- **Escalation:** set `ANCHOR_AI_ESCALATION_ENABLED=true`, set `ANCHOR_AI_ESCALATION_MODEL` to a real model id, and use a completed run whose findings produce packet signals (e.g. mark a finding `metadata: { "anchor_routing_complex" => true }` in console for a one-off test), then check `tier` / `requested_model`.
- **Validation retry:** enable escalation; force a first completion that returns invalid JSON (only in a test or stub client); second attempt should use `ANCHOR_AI_VALIDATION_RETRY_MODEL` or the escalation model.
- **Stub:** default `config/ai.yml` remains `provider: stub`; routing metadata is still persisted on `request_payload`.

```ruby
run = AnalysisRun.completed.order(created_at: :desc).first
AiSynthesisJob.perform_now(run.id, force: true)
synthesis = run.ai_synthesis_runs.order(created_at: :desc).first
synthesis.slice(:status, :provider, :model, :prompt_version, :error_message)
synthesis.request_payload["model_routing"]
```

---

## Status

- [x] Step 1
- [x] Step 2
- [x] Step 3
- [x] Step 4
- [x] Step 5
- [x] Step 6
- [x] Step 7

**Last updated:** 2026-04-29
**Handoff note:** `Ai::Configuration` exposes escalation env/YAML keys. `Ai::ModelRouter` selects `default`, `escalated`, or `validation_retry` from `packet_meta` only. `Ai::PromptRenderer` adds `packet_meta` aggregates (counts, confidence, conflict signals, etc.). `Ai::SynthesisRunner` passes the routed model to `Client#complete`, stores `request_payload["model_routing"]`, and on validation failure retries once with the escalation/retry model when enabled. Specs: `configuration_spec`, `model_router_spec`, extended renderer/synthesis_runner specs.
