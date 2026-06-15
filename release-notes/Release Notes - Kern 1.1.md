# Kern 1.1 Release Notes

**Builds on:** [Kern 1.0 — Feature Reference](./Release%20Notes%20-%20Kern%201.0.md) — the comprehensive reference for everything 1.1 carries forward.
**Platform:** Salesforce API 67.0 (Summer '26) · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** the 1.1 feature set is complete; a validated build and full end-to-end testing are in progress. The subscriber package version id and release tag are published with the release.

> **What's new since 1.0**, grouped by capability and **ordered by impact**. Each entry leads with the value, says **who it's for**, contrasts **before → now** where it helps, and links to a guide for the detail — so you can scan it in a minute and click through only where it's useful to you.
>
> **Safe to upgrade:** 1.1 is a **backward-compatible feature release** — it only adds new capability; no existing API or configuration changes, and almost every new feature is opt-in. The one default-on improvement is stronger payment-card masking on the framework's own objects — see [Upgrading & compatibility](#upgrading--compatibility). (It does raise the platform baseline to Summer '26 — see [Summer '26 platform support](#summer-26-platform-support-api-67).) For the per-build log, see the [CHANGELOG](../CHANGELOG.md).

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [At a glance](#at-a-glance)
2. [Data Masking Advisor](#data-masking-advisor)
3. [Triggers — Change Data Capture & Post-Trigger Actions](#triggers--change-data-capture--post-trigger-actions)
4. [Logging & observability](#logging--observability)
5. [Streaming Event Monitor](#streaming-event-monitor)
6. [Security & audit](#security--audit)
7. [Query builder — typed date functions](#query-builder--typed-date-functions)
8. [Summer '26 platform support (API 67)](#summer-26-platform-support-api-67)
9. [Documentation — hosted site & expanded guides](#documentation--hosted-site--expanded-guides)
10. [Upgrading & compatibility](#upgrading--compatibility)

</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Data Masking Advisor](#data-masking-advisor)** | Admins · Architects · BAs · Developers | Find sensitive data on your own objects and redact it — point-and-click, no code |
| 2 | **[Triggers on Change Data Capture + Post-Trigger Actions](#triggers--change-data-capture--post-trigger-actions)** | Developers · Architects | React to committed changes, and run logic once after the trigger work finishes |
| 3 | **[Logging & observability](#logging--observability)** | Developers · Admins · Architects | Stop log floods, see what a failed background job was processing, and watch every async chain in the org |
| 4 | **[Streaming Event Monitor](#streaming-event-monitor)** | Admins · Developers · Architects | See platform-event and Change Data Capture volume at the granularity you need |
| 5 | **[Security & audit](#security--audit)** | Architects · Admins · Developers | A clearer security-bypass trail, and a CI gate that catches hardcoded secrets |
| 6 | **[Query builder — typed date functions](#query-builder--typed-date-functions)** | Developers | Bucket and report records by calendar/fiscal date parts without raw SOQL |
| 7 | **[Summer '26 platform support](#summer-26-platform-support-api-67)** | Architects · Admins | The framework keeps pace with the platform (API 67) — a safe, behaviour-preserving uplift |
| 8 | **[Documentation — hosted site & expanded guides](#documentation--hosted-site--expanded-guides)** | Everyone | All documentation is now a searchable website — plus eight new guides and fast starts |

---

## Data Masking Advisor

**Who it's for:** Admins & Architects (own data protection) · Business Analysts (identify and sign off on sensitive fields) · Developers (deploy and extend).

A new point-and-click console — **Data Masking Advisor** (open it from the App Launcher) — finds likely-sensitive fields, previews how they'll be redacted, and produces a ready-to-deploy masking configuration.

**Previously:** masking covered the four framework objects out of the box, and protecting a field on your *own* object meant hand-authoring custom metadata and deploying it by XML.
**Now:** you point-and-click through find → preview → assign → review, and the Advisor generates the metadata (with the exact deploy command) for you to deploy. It never changes your org itself.

- **Review coverage on your own objects** — scan your custom objects on demand for likely-sensitive fields that aren't masked yet, and surface masking that's wired up but inactive.
- **Export a sensitive-field inventory** (CSV / JSON) of the fields the Advisor flags as likely-sensitive and whether each is masked today — for review or sign-off.
- **Two new Health Check cards** flag unmasked custom objects and dead masking configuration alongside the other org-health checks.
- **A larger rule library — now 18 rules** (added address, free-text, and international-phone templates, plus the new payment-card rule below), each labelled by category.
- **Object-wide masking targets** can now be saved from the Setup UI (leave the field blank to mask every text field on an object) — previously only possible by hand-authored metadata.
- **Stronger card detection** — a new built-in rule, **Mask Payment Card Numbers**, redacts any 13–19 digit number that passes the Luhn checksum (spaces or hyphens allowed), closing a pattern gap that let 16-digit Mastercard 2-series numbers through. It takes over from the original credit-card rule on the framework objects; the original rule still ships, keeps running if you've customised it, and the Advisor labels it as replaced so new configurations bind to the newer rule.
- **Hardened against duplicate rule names** — masking now tolerates a rule in your org that shares its developer name with a packaged rule: record saves keep working, masking continues, and a warning in the log entries names the duplicate so you can rename or remove it.

**Why it matters:** extending data protection to your own objects becomes a five-minute review-and-deploy task instead of a coding exercise.
**Good to know:** the Advisor is a configuration aid, not a compliance system, and its sensitivity flag is a guided starting point (it surfaces any field carrying a Salesforce data classification), not a definitive PII scan. Your custom objects are not masked until you deploy a configuration.

**Learn more:** [Data Masking - Guide](../docs/Data%20Masking%20-%20Guide.md) · [Fast Start - Data Masking](../docs/Fast%20Start%20-%20Data%20Masking.md)

---

## Triggers — Change Data Capture & Post-Trigger Actions

**Who it's for:** Developers (build the logic) · Architects (design the integration and transaction patterns).

The metadata-driven trigger framework reaches two new execution contexts.

- **Run trigger actions on Change Data Capture.** Register your actions against a Change Event so the same pattern you use for object triggers reacts to *committed* changes — including those from other systems, async jobs, and bulk loads.
- **Drive a Flow from a change event.** A change-event Flow receives the full change context (what changed, who committed it, the affected records) with no bridging code. Because a committed change can't be rolled back, *Block DML* is rejected for change-event actions — caught in CI and safely downgraded at run time.
- **Post-Trigger Actions — a single place for end-of-save work.** Register Apex that runs after the trigger actions for a save complete — ideal for a rollup, an audit entry, or kicking off async work, instead of scattering it across handlers. The framework keeps these compute-and-enqueue only: if one tries to write data, it stops the save and names the offending action.

**Why it matters:** you can react to committed and bulk changes with the framework you already use, and consolidate once-per-save work in one ordered, guarded place.
**Good to know:** a post-trigger action runs once per trigger pass (not necessarily once per record), so write it to be idempotent. Configure ordering, feature-flag gating, object scope, and failure handling on the action's metadata — no Apex changes needed.

**Learn more:** [Triggers - Guide](../docs/Triggers%20-%20Guide.md) · [DTOs - Guide](../docs/DTOs%20-%20Guide.md)

---

## Logging & observability

**Who it's for:** Developers (tag noisy logs, diagnose failures) · Admins & Architects (keep logs usable, monitor async work org-wide).

Three changes make the framework's logging and async monitoring more useful under load.

- **Flood control for noisy logs.** Tag a recurring entry and the first occurrence is kept in full while repeats collapse into a per-day count — so a retry storm doesn't bury the error that matters. New *Fingerprint* and *Occurrence Count* fields appear on the Log Entry record page and list view.
  - *Previously:* a chatty loop wrote thousands of near-identical Log Entry rows. *Now:* it leaves one detailed sample plus a daily counter.
  - *Good to know:* this trims the log **records** you store; each occurrence still publishes its platform event, so event allocations are unchanged.
- **Logging from Change Data Capture and platform-event triggers is now safe.** *Previously:* a log raised inside such a trigger could trigger redelivery and multiply into thousands of rows. *Now:* those logs are written directly, with no redelivery loop.
- **Failed background jobs are easier to diagnose.** A Queueable job that fails now records the records it was processing on its log entry, alongside the exception and job id — everything you need in one place.
- **The Chain Monitor shows the whole org.** *Previously:* the console showed only the async chains you launched. *Now:* an admin sees every chain across the org and can drill into a failed one — while programmatic status checks still respect sharing.

**Why it matters:** logs stay readable under load, event-driven logging can't run away, and you can troubleshoot failed jobs and async chains across the org from one place.

**Learn more:** [Logging - Guide](../docs/Logging%20-%20Guide.md) · [Async Processing - Guide](../docs/Async%20Processing%20-%20Guide.md)

---

## Streaming Event Monitor

**Who it's for:** Admins (capacity-plan event usage) · Developers & Architects (debug event-driven integrations).

The Event Usage view is rebuilt, and reliability fixes land across the monitor.

- **A rebuilt usage view** with daily, hourly, or 15-minute granularity, date-range presets, and chart or table views. (Hourly and 15-minute detail needs Enhanced Usage Metrics enabled — the monitor detects this and explains it when it's off.)
- **A cleaner Change Data Capture channel picker** that lists only genuine change-event channels by their real names.
- **The Publish screen now offers only event types you can actually publish**, removing a confusing dead end.
- **Steadier, clearer behaviour** — validated custom date ranges with plain-English errors, correct time zones and locales, no stale charts after rapid filter changes, and translatable error messages.

**Why it matters:** platform events and Change Data Capture have real usage limits — when something misbehaves you can see *when* and *how much* at the right granularity.
**Example:** an integration starts burning event allocations → switch to 15-minute granularity to pinpoint the spike window.

**Learn more:** [LWC - Guide](../docs/LWC%20-%20Guide.md)

---

## Security & audit

**Who it's for:** Architects (security posture) · Admins (review the audit trail) · Developers (the CI secret-scanning gate).

KernDX is secure by default — queries and writes enforce the running user's permissions and sharing — but lets code deliberately step around that when it has to. The **bypass-audit trail** (introduced in 1.0) records every such override for review. 1.1 makes that trail far more useful, and adds a secret-scanning gate to the delivery pipeline.

- **The audit trail names the real caller.** *Previously:* every entry pointed at the framework's own helper, so you couldn't tell which code performed the bypass. *Now:* each entry names the actual class and method.
- **Repeated bypasses no longer flood the trail.** *Previously:* a bypass inside a loop wrote an entry every time. *Now:* identical bypasses roll up into one entry plus a count, while each new bypass still stands out. (Routine framework housekeeping is also no longer logged at all.)
- **Query and data-change entries name the operation that ran under the bypass.** *Previously:* these entries recorded only that a query or data change stepped around security somewhere. *Now:* each entry names the object — and for data changes, the operation and the number of rows submitted — with a separate consolidated entry per object, so activity on one object can't hide behind another. After upgrading, consolidated entries start fresh under this more specific grouping; pre-upgrade entries remain but stop accruing.
- **Cleared bypasses tie back to the bypass they end**, so the trail reads as matched pairs instead of ambiguous, noisy entries.
- **A secret-scanning gate in the delivery pipeline** scans changed files for hardcoded credentials (auth URLs, tokens, private keys, cloud keys) and fails the CI build, with a local pre-push check too. A new informational scanner rule also surfaces every new security-bypass call site for review. Both complement — they don't replace — your Git host's native secret scanning.

**Why it matters:** an audit trail you can actually read makes security review fast, and a leaked credential is far cheaper to catch in CI than in production.

**Learn more:** [Security - Guide](../docs/Security%20-%20Guide.md) · [Code Scanning - Guide](../docs/Code%20Scanning%20-%20Guide.md)

---

## Query builder — typed date functions

**Who it's for:** Developers (and Architects designing reporting queries).

The query builder gains a typed set of **date-bucket functions** (calendar and fiscal month/quarter/year, day-of-week, week-of-year, and more) so you can group, project, and order an aggregate query by a date part without hand-writing raw SOQL — and without repeating the same expression across clauses.

**Why it matters:** date-based roll-ups (records per month, per fiscal quarter, …) become a typed, refactor-safe builder call instead of error-prone inline SOQL.
**Example:** count opportunities per calendar month of close date, grouped and ordered by that month, in one fluent query.

**Learn more:** [Selectors - Guide](../docs/Selectors%20-%20Guide.md)

---

## Summer '26 platform support (API 67)

**Who it's for:** Architects & Admins (platform currency and upgrade planning).

Kern 1.1 moves to **Salesforce API 67.0 (Summer '26)**. This is a **compatibility uplift** — no new API and no change to how your code uses the framework — but it took real work under the hood to keep the framework correct on the new platform. For transparency, that work included:

- **SOQL security syntax.** Summer '26 retires the `WITH SECURITY_ENFORCED` clause, so the framework was updated to the supported user-mode syntax. Secure-by-default enforcement (the running user's field- and object-level security) is unchanged.
- **Platform-event publishing.** Summer '26 changes the default publish access mode, so the framework now publishes its events (logging, audit, monitoring) with an explicit access level — keeping log, audit, and event delivery working as before.
- **Background-job error reporting.** Summer '26 no longer allows manually raising the batch-error event the framework previously used for a failed Queueable job, so the framework now records those failures — including the records the job was processing — in the log rather than via that platform event (see [Logging & observability](#logging--observability)).

These are internal changes — there is nothing to adjust in your own code.

**Why it matters:** the framework stays current and supported on the platform release your org is running, with nothing to change in your own code.
**Good to know:** because the package targets Summer '26, 1.1 installs on Summer '26 orgs and later. Salesforce upgrades every org to Summer '26 within its standard release window.

---

## Documentation — hosted site & expanded guides

**Who it's for:** Everyone — each new guide and fast start is a self-contained front door for onboarding or going deep on one area.

**The documentation is now a website.** Every guide, fast start, the full Apex reference, and these release notes are published at **[docs.jvb-consulting.io](https://docs.jvb-consulting.io)** — full-text searchable, readable on a phone, and rebuilt automatically as the documentation evolves. The distribution bundles still include the same documentation as Markdown; the website is simply the fastest way in.

| New document | What it covers |
|--------------|----------------|
| [Data Masking - Guide](../docs/Data%20Masking%20-%20Guide.md) + [Fast Start](../docs/Fast%20Start%20-%20Data%20Masking.md) | Field redaction on your own records, what ships masked, and the Advisor — by configuration, not code |
| [Resilience - Guide](../docs/Resilience%20-%20Guide.md) + [Fast Start](../docs/Fast%20Start%20-%20Resilience.md) | Retry-with-backoff and the circuit breaker for survivable callouts |
| [Feature Flags - Guide](../docs/Feature%20Flags%20-%20Guide.md) | Metadata-driven flags and targeting from Apex, Flow, and LWC |
| [Test Data - Guide](../docs/Test%20Data%20-%20Guide.md) | The builder, mock, and factory surface for fast, reliable test data |
| [Fast Start - Security](../docs/Fast%20Start%20-%20Security.md) · [Fast Start - LWC](../docs/Fast%20Start%20-%20LWC.md) | Automatic CRUD/FLS on every query and write; your first KernDX component |
| [Strategic Guide - Choosing a Framework](../docs/Strategic%20Guide%20-%20Choosing%20a%20Framework.md) | An honest, source-checkable comparison of KernDX against the established Apex frameworks |

The [documentation hub](../docs/README.md) and reference catalogue are rewired so the new guides, fast starts, and 1.1 API reference pages are all discoverable.

---

## Upgrading & compatibility

1.1 is a **backward-compatible feature release** — it only adds surface; no existing API or metadata changes, so upgrading is the standard package upgrade with no migration steps. Almost every new capability is **opt-in**; the one default-on improvement is the stronger payment-card masking described below. The one baseline change is the platform: 1.1 targets Summer '26 (API 67) and installs on Summer '26 orgs and later.

### Card masking after the upgrade

The new **Mask Payment Card Numbers** rule arrives active, with its own targets on the four framework objects, so the stronger card detection (13–19 digit Luhn-checked numbers, spaces or hyphens allowed — including the 16-digit Mastercard 2-series numbers the original pattern missed) applies to framework logs and API records as soon as you upgrade. No steps needed.

- **If you never touched the original credit-card rule:** the new rule takes over the work on the framework objects. The original rule stays installed and active for compatibility.
- **If you customised the original rule** (pattern, replacement, failure action, …): your customisation is respected — the original rule keeps running exactly as you configured it, with the new rule alongside it on the framework objects.
- **If you deactivated the original rule** (opted out of card masking): the upgrade re-activates card masking through the new rule. To stay opted out, deactivate `kern__MaskPaymentCard` too.
- **If you wired the original rule to your own objects:** those targets keep working unchanged. To get the stronger detection there too, rebind each target's Rule to `kern__MaskPaymentCard` — the Data Masking Advisor labels the original rule as replaced and steers new configurations to the newer rule.
- **Prefer the original behaviour everywhere?** Deactivate `kern__MaskPaymentCard`; the original credit-card rule resumes the framework-object work on its own.

Fresh installs get the same end state out of the box: payment-card and secrets masking active on the four framework objects.

### Adopting the rest

When you're ready to adopt something, start with its guide above:

- **Mask your own objects** → open the Data Masking Advisor (the framework's own logs stay masked by default).
- **React to Change Data Capture** or **run post-trigger actions** → see the Triggers guide.
- **Tame noisy logs** → tag recurring entries for flood control; see the Logging guide.
- **Turn on the secret-scanning gate** → see the Code Scanning guide.
