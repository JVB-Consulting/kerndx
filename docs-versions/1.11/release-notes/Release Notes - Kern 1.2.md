# Kern 1.2 Release Notes

**Builds on:** [Kern 1.1 Release Notes](./Release%20Notes%20-%20Kern%201.1.md) and the [Kern 1.0 Feature Reference](./Release%20Notes%20-%20Kern%201.0.md), which together remain the full reference for everything 1.2 carries forward.
**Platform:** Salesforce API 67.0 (Summer '26), unchanged from 1.1 · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** the 1.2 feature set is complete, the build is validated, and end-to-end testing has passed. The package version id and release tag below are published with the release.

> **What's new since 1.1**, grouped by capability and ordered by impact. Each entry leads with the value, says **who it's for**, contrasts **before and now** where it helps, and links to a guide for the detail, so you can scan it in a minute and click through only where it's useful to you.
>
> **Safe to upgrade:** 1.2 is a **backward-compatible feature release**. It only adds new surface (a few Apex methods, one value class, a Flow input, and some query functions); no existing API, metadata, or configuration changes, and every new capability is opt-in. The platform baseline is unchanged from 1.1 (Summer '26, API 67), so there is nothing to adjust in your own code. For the per-build log, see the CHANGELOG.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [At a glance](#at-a-glance)
2. [Async chains: safe re-runs, typed status, and a first-step delay](#async-chains-safe-re-runs-typed-status-and-a-first-step-delay)
3. [Deterministic trigger-action ordering](#deterministic-trigger-action-ordering)
4. [Logging from Flow: link a log to its record](#logging-from-flow-link-a-log-to-its-record)
5. [Query builder: geolocation distance](#query-builder-geolocation-distance)
6. [Upgrading & compatibility](#upgrading--compatibility)

</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Async chains: safe re-runs, typed status, first-step delay](#async-chains-safe-re-runs-typed-status-and-a-first-step-delay)** | Developers · Architects | Make a chain step safe to re-run, read its status as a typed object, and delay the start by up to ten minutes |
| 2 | **[Deterministic trigger-action ordering](#deterministic-trigger-action-ordering)** | Developers · Architects | Two actions sharing an order value now run in a stable, predictable sequence |
| 3 | **[Logging from Flow: link a log to its record](#logging-from-flow-link-a-log-to-its-record)** | Admins · Flow builders · Developers | The Flow logging action takes a record id, so the log ties back to the record |
| 4 | **[Query builder: geolocation distance](#query-builder-geolocation-distance)** | Developers | Filter and sort by proximity without hand-writing SOQL |

---

## Async chains: safe re-runs, typed status, and a first-step delay

**Who it's for:** Developers (build resilient background chains) · Architects (design the integration and recovery patterns).

A KernDX async chain runs a sequence of steps in the background, each step a separate job. Kern 1.2 makes a chain safer to re-run, easier to inspect, and able to wait a few minutes before it starts. Three additions, all opt-in.

- **Per-step idempotency keys, so re-running a step doesn't act twice.** A chain step often calls an external system: charge a card, create an order, send a webhook. If that step runs again, you don't want a second charge. `context.idempotencyKey()` gives you a stable token for the step you're in that stays the same every time the step runs. Attach it to your outbound call's idempotency key and the other system treats a repeat as the same request rather than a new one. (Idempotency means: if the same request arrives twice, the second is recognised as a repeat and not run again.) Two more overloads handle a step that fans out over many records or units: `idempotencyKey(recordId)` and `idempotencyKey(grain)` add a per-record or per-unit grain so each row gets its own stable key.
- **A typed status accessor: `getChainStatus()`.** It returns a `ChainStatus` object with the chain name, the current status and step, progress (completed of total steps), the start and finish times with a readable duration, the tracking id that follows the run, and any error message, plus `isRunning()`, `isTerminal()`, and `isFailed()` so a status check reads as plain code.
  - *Previously:* the only status accessor returned an untyped map you read by string keys.
  - *Now:* you get a typed object with named fields and helper methods. The original untyped accessor is unchanged, so existing code keeps working.
- **A first-step delay: `withDelayMinutes(n)`.** Defer the chain's first step by up to ten minutes, for example to let the triggering transaction commit before the work starts, or to space out a burst of chains. Only the first step is delayed; every later step runs as normal.

**Why it matters:** a step that touches an external system can be made safe to re-run, you can read a chain's progress and outcome without parsing an untyped map, and you can hold a chain's start for a few minutes when timing matters.

**Good to know:** an idempotency key is a building block you attach to your own outbound calls; on its own it doesn't change how the chain runs. The first-step delay is best-effort and capped at ten minutes (a null or zero delay does nothing).

**Learn more:** [Async Processing - Guide](../docs/Async%20Processing%20-%20Guide.md) · [Web Services - Guide](../docs/Web%20Services%20-%20Guide.md)

---

## Deterministic trigger-action ordering

**Who it's for:** Developers (build the actions) · Architects (design predictable, repeatable automation).

In the metadata-driven trigger framework you give each trigger action an order value, and the framework runs them low to high. When two actions shared the same order value, the sequence between them was not guaranteed: a deploy or a metadata reshuffle could quietly flip which ran first.

- **Tied actions now run in a stable, predictable order.** Actions that share an order value are sequenced by that value first, then alphabetically by developer name, so the order is the same on every run and in every org.

**Why it matters:** automation behaves the same way every time. You no longer get a subtle change in behaviour just because another action was added at the same order value.

**Good to know:** this only affects actions that share an order value. If you want a specific sequence, give them distinct order values, exactly as before. The change is a compatible tightening of the field's documented "no guaranteed sequence" behaviour, observable only for actions that were already tied.

**Learn more:** [Triggers - Guide](../docs/Triggers%20-%20Guide.md)

---

## Logging from Flow: link a log to its record

**Who it's for:** Admins and Flow builders (log from a Flow) · Developers (consistent logs across Apex and Flow).

The framework's **Log Flow Event** action lets a Flow write a log entry. Kern 1.2 adds a record-id input to that action.

- **Tie a Flow's log entry to the record it's about.** Pass a record id into the action and the resulting log is associated with that record, the same way a log written from Apex can be.

**Why it matters:** logs raised from Flows are now traceable back to the specific record, so a log trail is just as useful whether it came from Apex or from a Flow.

**Learn more:** [Fast Start - Logging](../docs/Fast%20Start%20-%20Logging.md) · [Logging - Guide](../docs/Logging%20-%20Guide.md)

---

## Query builder: geolocation distance

**Who it's for:** Developers (and Architects designing location-aware queries).

The query builder gains geolocation distance functions, so you can filter and sort records by how close they are to a point without hand-writing the SOQL `DISTANCE` expression (Salesforce's built-in geolocation distance function).

- **Build proximity queries fluently.** `QRY_Function.distanceInMiles(field, latitude, longitude)`, the kilometre variant, and overloads that take a `System.Location` produce a distance expression you can drop into a where clause or an order-by. For example, select the accounts within ten miles of a point, nearest first, in one typed query.

**Why it matters:** location queries (nearest stores, accounts within a radius) become a typed, refactor-safe builder call instead of error-prone inline SOQL.

**Good to know:** the field you measure from must be a geolocation field or a compound address field (such as `BillingAddress`), and the values follow Salesforce's own `DISTANCE` rules.

**Learn more:** [Selectors - Guide](../docs/Selectors%20-%20Guide.md)

---

## Upgrading & compatibility

1.2 is a **backward-compatible feature release**. It only adds surface; no existing API, metadata, or configuration changes, so upgrading from 1.1 is the standard package upgrade with no migration steps. Every new capability is opt-in: you call the new methods or add the new Flow input where you want them, and nothing changes until you do. The platform baseline is unchanged from 1.1 (Summer '26, API 67).

The one behavioural note is the trigger-action ordering: actions that share an order value now run in a stable order (by order value, then developer name) where the sequence between them was previously not guaranteed. If you relied on the incidental order of two same-order actions, give them distinct order values to lock the sequence in.
