# API Module — JSON API Layer

> Status: Placeholder — not yet implemented.
> Add this module when the app needs a public API.

## When to use this module
When the app needs to expose data to mobile clients,
third-party integrations, or a separate frontend.

## Recommended approach
- Rails API controllers in app/controllers/api/v1/
- Token authentication via Devise token auth or
  a simple Bearer token on the User model
- JSON serialization via jsonapi-serializer or
  simple as_json overrides for small APIs

## Installation steps
<!-- To be documented when first implemented -->

## Key files to create/modify
<!-- To be documented when first implemented -->

## Decisions to make per app
- Public API vs internal only
- Authentication method (token, OAuth, API key)
- Versioning strategy (v1, v2, etc.)
- Serialization library vs plain as_json

