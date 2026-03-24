# Multitenancy Module

> Status: Placeholder — not yet implemented.
> The Space/UserRole model already supports
> multitenancy. This module documents how to
> enforce it at the query level.

## When to use this module
When building a true multi-tenant SaaS where users
belong to organizations (Spaces) and all data must
be scoped to the current space.

## What is already in place
- Space model (tenant/workspace)
- UserRole join (user + space + role)
- multi_tenant_mode? helper in SettingsHelper
- AppSettings.multi_tenant_mode flag

## What needs to be added per app
- Current space detection (subdomain or path-based)
- ApplicationController#current_space
- Scoping all queries to current_space
- acts_as_tenant gem (optional, enforces scoping)

## Recommended approach
- acts_as_tenant gem for automatic query scoping
- Subdomain-based tenant detection for SaaS
- Path-based (/spaces/:id/) for simpler apps

## Installation steps
<!-- To be documented when first implemented -->

## Decisions to make per app
- Subdomain vs path-based tenant detection
- acts_as_tenant vs manual scoping
- Cross-tenant admin access pattern
- Data isolation level (row-level vs schema-level)

