---
navOrder: 5
title: "Fast Starts"
---

# Fast Starts

**Copy-paste-ready guides that get one KernDX capability working in about 30 minutes, with no prior framework knowledge needed.** Each one is a self-contained walkthrough: the smallest example that runs, then the few options you'll actually reach for. New to KernDX? Start at the top and work down.

## Start here — the daily drivers

These five are the spine of almost every KernDX project. Learn them first.

- [**Trigger Actions**](./Fast%20Start%20-%20Trigger%20Actions.md): add behaviour to a trigger by creating a configuration record, with no trigger code to write. Each behaviour can be switched off without a deployment (a 4-level kill switch, the master off-switch you flip in an incident), and every bypass is audit-logged.
- [**Selectors**](./Fast%20Start%20-%20Selectors.md): one query class per object that respects the running user's field-level security (FLS = field-level security), is easy to swap out in tests, and catches mistyped field names at compile time.
- [**DML**](./Fast%20Start%20-%20DML.md): writes that enforce the current user's permissions and record sharing by default (USER_MODE), batched into one all-or-nothing transaction, with async saves and automatic parent-before-child ordering.
- [**Security**](./Fast%20Start%20-%20Security.md): field-level security and object permissions (FLS/CRUD: object create, read, update, delete) enforced by default. When a check is bypassed, the framework records the reason the caller gave.
- [**Logging**](./Fast%20Start%20-%20Logging.md): structured logs you can search and keep, with one tracking ID that follows a single user action across triggers, queries, callouts, and jobs (a correlation ID), plus flood control. This is the replacement for `System.debug`.

## Build features

Reach for these as you build out UI, integrations, and background work.

- [**LWC**](./Fast%20Start%20-%20LWC.md): build Lightning components on `ComponentBuilder` (a base class with the common wiring already built in) and shared patterns, instead of starting from raw `LightningElement`.
- [**Outbound APIs**](./Fast%20Start%20-%20Outbound%20APIs.md): callouts that survive flaky external systems. They retry on failure; after repeated failures they stop calling the failing system for a cool-off, then resume (a circuit breaker); a repeated request returns the first result instead of running twice (an idempotency key); and messages that fail every retry are set aside for inspection rather than lost (a dead-letter queue).
- [**Inbound APIs**](./Fast%20Start%20-%20Inbound%20APIs.md): a two-class pattern for receiving REST calls. A small class carries exactly the fields to move in or out and converts itself to and from JSON (a DTO), and a duplicate request is recognised and answered safely with a `409` instead of running again.
- [**Async Processing**](./Fast%20Start%20-%20Async%20Processing.md): chained queueables and batches, with one tracking ID (a correlation ID) threaded through the whole run so you can follow it end to end.
- [**Feature Flags**](./Fast%20Start%20-%20Feature%20Flags.md): switches that turn behaviour on or off per org or user from configuration, with no deployment needed to flip them.

## Harden

Add governance and safety once the feature works.

- [**Custom Validations**](./Fast%20Start%20-%20Custom%20Validations.md): validation rules you define as configuration, that Flows can call and that return structured errors.
- [**Resilience**](./Fast%20Start%20-%20Resilience.md): circuit breakers (stop calling a failing system for a cool-off, then resume) and retry policies for downstream systems that fail under load.
- [**Data Masking**](./Fast%20Start%20-%20Data%20Masking.md): field-level masking for logs and exports, so personal data and secrets are redacted by rule before they leave.
- [**Test Data**](./Fast%20Start%20-%20Test%20Data.md): builder-based test factories that avoid inline DML and keep working across namespaces.

## CI & quality

Drop the framework's guardrails into your pipeline.

- [**Code Scanning**](./Fast%20Start%20-%20Code%20Scanning.md): PMD rulesets, an ESLint plugin, and secret scanning that run in your pipeline to catch problems before they merge.
- [**E2E Testing**](./Fast%20Start%20-%20E2E%20Testing.md): Playwright-first end-to-end tests that run against the deployed org, so you exercise the real UI.
