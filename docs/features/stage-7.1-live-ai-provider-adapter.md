# Stage 7.1 - Live AI Provider Adapter

> Light brief. Adds the first live provider adapter behind the existing Stage 7
> AI synthesis boundary. This stage keeps `stub` mode as the default, preserves
> deterministic fallback behavior, and limits live API risk to `Ai::Client`.

---

## Goal

Implement a live OpenAI provider adapter for `Ai::Client` so Stage 7 synthesis
can use real model responses when explicitly enabled by environment
configuration.

## Changes

This stage changes only the AI provider integration layer. It should not add new
database tables, routes, controllers, policies, or parent-facing workflows.

Existing Stage 7 flow:

```text
AnalysisRun completed
-> AiSynthesisJob
-> Ai::SynthesisRunner
-> Ai::PromptRenderer
-> Ai::Client
-> Ai::StructuredOutputValidator
-> AiSynthesisRun
```

Current implementation status:

- `Ai::Client` supports `provider: stub`.
- Non-stub providers currently raise `Ai::UnsupportedProviderError`.
- `config/ai.yml` defaults every environment to `enabled: false` and
  `provider: stub` except test behavior controlled through specs.
- `Ai::SynthesisRunner` already validates output and records completed/failed
  `AiSynthesisRun` rows.

Proposed changes:

- Add an OpenAI adapter path inside or under `Ai::Client`.
- Use the Responses API as the first live endpoint.
- Send the existing rendered prompt as text input.
- Request JSON-compatible output that is still validated by
  `Ai::StructuredOutputValidator`.
- Treat provider JSON as untrusted text until Anchor validates it. The provider
  may be asked for JSON, but only `Ai::StructuredOutputValidator` decides
  whether the output is usable.
- Keep `ANCHOR_AI_ENABLED=false` and `provider: stub` as safe defaults.
- Configure live mode only through environment variables:
  - `ANCHOR_AI_ENABLED=true`
  - `ANCHOR_AI_PROVIDER=openai`
  - `ANCHOR_AI_DEFAULT_MODEL=<model id>`
  - `ANCHOR_AI_API_KEY=<secret>`
  - optional `ANCHOR_AI_API_BASE_URL=<override>`
  - optional `ANCHOR_AI_TIMEOUT_SECONDS=<seconds>`
- Do not store API keys in code, YAML, database records, logs, request payloads,
  response payloads, or `AiSynthesisRun`.
- Store safe provider metadata in `AiSynthesisRun#response_payload`, such as
  upstream response id, status, model, usage, latency, retry classification, and
  finish/output metadata when available.
- Preserve the existing stub provider for deterministic specs and local
  no-network development.

### Provider adapter contract

Every provider adapter must normalize its response into the same stable
`Ai::Client#complete` contract:

```ruby
{
  text: String,
  provider: String,
  model: String,
  response_payload: Hash
}
```

Contract rules:

- `text` is the only provider field passed to `Ai::StructuredOutputValidator`.
- `response_payload` is observational metadata only.
- `response_payload` must never decide synthesis correctness.
- Provider-native structured fields may inform `text` extraction, but they are
  not trusted as validated Anchor output.
- Provider-specific metadata must be normalized and safe to persist.
- Future providers must use this same contract rather than bypassing validation.

### Failure classification

Provider failures should be classified even if full retry/backoff tuning remains
out of scope for this stage.

Retryable failures:

- HTTP 429
- HTTP 408
- request timeout
- connection reset or transient network failure
- HTTP 5xx

Non-retryable failures:

- HTTP 400
- HTTP 401
- HTTP 403
- malformed provider response
- empty output
- invalid schema output after `Ai::StructuredOutputValidator`

The adapter or runner should record the classification in safe metadata when
available so future job retry behavior can use it.

### Logging and redaction rules

Never log or persist:

- authorization headers
- API keys or bearer tokens
- raw request bodies
- full raw response bodies in production logs
- prompts containing child-specific content at info/error level

Allowed operational metadata:

- provider
- model
- upstream request/response id
- HTTP status
- latency or duration in milliseconds
- token usage when available
- retry classification
- truncated error class/message

### Model compatibility

The configured model must support the OpenAI Responses API and the
JSON-compatible output constraints expected by this adapter. Model selection
stays in environment configuration; business logic should not hard-code a model
id.

Reference docs used for planning:

- OpenAI Responses API create endpoint:
  `https://developers.openai.com/api/docs/api-reference/responses/create`
- OpenAI Structured Outputs guide:
  `https://developers.openai.com/api/docs/guides/structured-outputs`
- OpenAI model docs:
  `https://developers.openai.com/api/docs/models`

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Keep controllers thin; no controller should call an AI provider directly.
- [ ] Use Active Job with Solid Queue; live provider calls continue to happen
      through `AiSynthesisJob`.
- [ ] AI synthesis can only run from a completed deterministic `AnalysisRun`.
- [ ] AI failure must not block profile availability; deterministic Stage 6/7
      fallback remains usable.
- [ ] AI must not create rubric scores, findings, clinical claims, or
      safety-sensitive conclusions.
- [ ] AI output must still pass `Ai::StructuredOutputValidator` before display.
- [ ] API keys and bearer tokens must never be persisted or logged.
- [ ] Provider response JSON is untrusted until Anchor validates it.
- [ ] Safe metadata can be persisted, but it must never determine synthesis
      correctness.
- [ ] Provider failures should be classified as retryable or non-retryable.
- [ ] Logs must not include child-specific prompts or raw provider payloads.
- [ ] Keep `stub` as the default provider for tests and local development.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Out of scope

- No new models, migrations, controllers, policies, or routes.
- No prompt management UI.
- No multi-provider UI or admin settings screen.
- No provider failover/routing across multiple vendors.
- No streaming UI.
- No conversational AI chat.
- No changes to Stage 6 deterministic analysis logic.
- No AI-generated rubric scores or findings.
- No production enablement by default.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Decisions

- The first live provider is OpenAI.
- The adapter should use OpenAI's Responses API.
- The adapter should live behind the existing `Ai::Client` boundary.
- `stub` remains the default provider in `config/ai.yml`.
- Live provider mode is enabled only with environment variables.
- The implementation should prefer a small HTTP adapter using Ruby stdlib
  `Net::HTTP` unless the codebase later adopts a shared HTTP client gem.
- The default model should be configured through `ANCHOR_AI_DEFAULT_MODEL`
  instead of hard-coded into business logic. Development examples may use a
  currently supported lower-cost OpenAI model.
- Provider output always flows through text extraction, Anchor validation, and
  structured parse before display.
- Record request latency as safe operational metadata.

## Steps

### Step 1 - Add OpenAI request builder and client branch

Extend `Ai::Client#complete` so `provider: openai` calls an OpenAI adapter.
Build a request to the Responses API with:

- configured model
- rendered prompt as text input
- JSON-oriented response instructions compatible with the existing validator
- request timeout
- authorization header from `ANCHOR_AI_API_KEY`

Keep unsupported providers raising `Ai::UnsupportedProviderError`.
The adapter must return the stable provider contract documented above.

**Verify:** `bundle exec rspec spec/services/ai/client_spec.rb`
**Revert:** Remove the OpenAI branch/adapter and restore the previous
unsupported-provider behavior.

### Step 2 - Parse OpenAI responses into the existing client contract

Map the OpenAI response into the hash expected by `Ai::SynthesisRunner`:

```ruby
{
  text: "...",
  provider: "openai",
  model: "...",
  response_payload: { ...safe metadata... }
}
```

Handle missing output text, malformed JSON, non-2xx responses, rate limits,
timeouts, and transport errors by raising or returning errors that
`Ai::SynthesisRunner` records as failed synthesis attempts. Classify failures as
retryable or non-retryable according to this brief and include the classification
in safe metadata when possible.

**Verify:** `bundle exec rspec spec/services/ai/client_spec.rb spec/services/ai/synthesis_runner_spec.rb`
**Revert:** Remove response parsing/error handling changes.

### Step 3 - Add focused provider specs without live network calls

Add WebMock-style or stubbed `Net::HTTP` specs for:

- live mode disabled
- missing API key
- successful OpenAI response
- non-2xx response
- timeout/transport error
- response body with no usable output text
- no API key leakage into persisted payloads
- provider JSON is still passed through Anchor validation
- response payload metadata does not determine synthesis correctness
- retryable vs non-retryable failure classification
- latency metadata is captured

If the project does not already use an HTTP stubbing gem, keep specs at the
adapter boundary with injected fake HTTP behavior rather than adding a new gem
unless truly needed.

**Verify:** `bundle exec rspec spec/services/ai/client_spec.rb`
**Revert:** Remove the new specs and any test-only adapter seams.

### Step 4 - Document local live-mode smoke test

Add a short docs note, or update this brief's status handoff, with the manual
commands for trying one live synthesis run from Rails console:

```ruby
run = AnalysisRun.completed.order(created_at: :desc).first
AiSynthesisJob.perform_now(run.id, force: true)
run.ai_synthesis_runs.order(created_at: :desc).first.slice(
  :status, :provider, :model, :prompt_version, :error_message
)
```

The note should also show the required environment variables without including
real secrets.
It should mention that the configured model must support the Responses API and
JSON-compatible output expected by the adapter.

**Verify:** Manual smoke test in development with a real key, if available.
If no key is available, verify stub mode still works with
`AiSynthesisJob.perform_now`.
**Revert:** Remove the docs note or status addition.

### Step 5 - Run stage verification

Run targeted specs for the adapter and synthesis path, then the normal stage
boundary checks.

**Verify:**

```text
bundle exec rspec spec/services/ai/client_spec.rb spec/services/ai/synthesis_runner_spec.rb spec/jobs/ai_synthesis_job_spec.rb
bundle exec rubocop
```

If time permits before commit:

```text
bundle exec rspec
```

**Revert:** Revert this stage's service/spec/doc changes.

---

## Status

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3
- [ ] Step 4
- [ ] Step 5

**Last updated:** 2026-04-29
**Handoff note:** Brief created from Stage 7 completion follow-up. Stage 7 has
the synthesis pipeline and stub provider; this stage adds the first live OpenAI
adapter while preserving stub mode and deterministic fallback.
