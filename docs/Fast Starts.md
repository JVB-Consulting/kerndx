---
navOrder: 5
title: "Fast Starts"
---

# Fast Starts

**Copy-paste-ready guides that get one KernDX capability working in ~30 minutes — no prior framework knowledge needed.** Each one is a self-contained walkthrough: the smallest example that runs, then the few options you'll actually reach for. New to KernDX? Start at the top and work down.

## Start here — the daily drivers

These five are the spine of almost every KernDX project. Learn them first.

- [**Trigger Actions**](./Fast%20Start%20-%20Trigger%20Actions.md) — metadata-driven trigger handlers with an audited bypass and a 4-level kill switch, no trigger code to write.
- [**Selectors**](./Fast%20Start%20-%20Selectors.md) — one FLS-safe, mockable query class per object, with inherited methods and compile-time field safety.
- [**DML**](./Fast%20Start%20-%20DML.md) — `USER_MODE`-by-default writes with transactional batching, async DML, and dependency ordering.
- [**Security**](./Fast%20Start%20-%20Security.md) — FLS/CRUD enforced by default, with bypasses that are audit-logged with the reason the caller gave.
- [**Logging**](./Fast%20Start%20-%20Logging.md) — structured, correlated logging with flood control, the replacement for `System.debug`.

## Build features

Reach for these as you build out UI, integrations, and background work.

- [**LWC**](./Fast%20Start%20-%20LWC.md) — components built on `ComponentBuilder` and shared patterns instead of raw `LightningElement`.
- [**Outbound APIs**](./Fast%20Start%20-%20Outbound%20APIs.md) — resilient callouts with retry, circuit breaker, correlation-ID idempotency, and a dead-letter queue.
- [**Inbound APIs**](./Fast%20Start%20-%20Inbound%20APIs.md) — a two-class REST routing pattern with DTO marshalling and replay-safe `409`s.
- [**Async Processing**](./Fast%20Start%20-%20Async%20Processing.md) — chained queueables and batches with correlation IDs threaded through the whole run.
- [**Feature Flags**](./Fast%20Start%20-%20Feature%20Flags.md) — metadata-driven flags that gate behaviour per org or user, no deploy to flip.

## Harden

Add governance and safety once the feature works.

- [**Custom Validations**](./Fast%20Start%20-%20Custom%20Validations.md) — declarative, Flow-invocable validation rules that return structured errors.
- [**Resilience**](./Fast%20Start%20-%20Resilience.md) — circuit breakers and retry policies for fragile downstream dependencies.
- [**Data Masking**](./Fast%20Start%20-%20Data%20Masking.md) — field-level masking for logs and exports, PII and secrets redacted by rule.
- [**Test Data**](./Fast%20Start%20-%20Test%20Data.md) — builder-based test factories, no inline DML, and robust across namespaces.

## CI & quality

Drop the framework's guardrails into your pipeline.

- [**Code Scanning**](./Fast%20Start%20-%20Code%20Scanning.md) — PMD rulesets, an ESLint plugin, and secret scanning that run in your pipeline.
- [**E2E Testing**](./Fast%20Start%20-%20E2E%20Testing.md) — Playwright-first end-to-end tests that run against the deployed org.
