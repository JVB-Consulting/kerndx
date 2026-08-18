# Changelog

> **Audience:** subscribers. Each entry describes a publicly-tagged
> release. **Evaluating an upgrade? Start with the Release Notes for the
> version you're moving to** — e.g.
> [Kern 1.1](release-notes/Release%20Notes%20-%20Kern%201.1.md) (what's new
> since 1.0, grouped by capability with upgrade notes). The
> [Kern 1.0 notes](release-notes/Release%20Notes%20-%20Kern%201.0.md) remain
> the full feature reference. This file is the sequential per-release log;
> pair it with the Release Notes for narrative context.

All notable changes to KernDX are recorded here. The format is based on [Keep a Changelog](https://keepachangelog.com/), and KernDX adheres to [Semantic Versioning](https://semver.org/) within each major release line.

---

## [1.7.0-13] — 2026-08-18

**Subscriber package version id:** `04tfj000000ScTlAAK`

The operations release. 1.6 taught async chains to look after themselves; 1.7 hands the controls to the people watching them. An operator can re-run a failed chain from the step that failed, restart one from the beginning, sweep the stalled ones, and stop all chain processing org-wide, from the Chain Monitor and without a deployment. On the diagnosis side, the Log Console works out which errors are repeating on its own, with no code changes and no configuration.

### Added

- **Retry from the failed step.** Re-run a failed chain from the step that failed, on the same record, keeping its history. Offered only where the chain author declared that step re-runnable by overriding `isIdempotent()`.
- **Restart from the beginning.** Re-run a failed or aborted chain from step 1 as a fresh run with its own tracking ID, leaving the original record untouched for audit and linked to the new one. Offered only where the chain author called `allowRestart()`.
- **Clear stalled chains on demand.** Run the recovery sweep immediately over up to 40 stalled chains, with a counted result: how many were checked, re-driven, marked failed, and still waiting.
- **Suspend and resume chain processing.** One org-wide switch stops and restarts all chain processing during an incident, backed by the new `AsyncChainRuntimeSwitch__c` hierarchy custom setting. Abort deliberately stays available while processing is suspended.
- **Live activity stream.** Watch the selected chain's log entries arrive in the Chain Monitor's detail panel, seeded with the most recent 20 entries and holding 100 rows, with a visible disconnected state rather than a stale list.
- **Three new permission sets**, all assigned to nobody: Kern Async Chain Redrive, Kern Async Chain Kill Switch, and Kern Async Chain Monitor Read Only. Re-drive rights and stop-everything rights are deliberately separate grants, and the packaged Administrator set carries neither.
- **Problem grouping in the Log Console.** Problem summary collapses repeating errors that share an exception type, class and method, and level into one "this error, N times" row, with no code changes and no configuration. Three optional `LogSetting__c` settings tune it (occurrence floor, level scope, and an off switch), a status bar always states what the list is and is not showing, and the drawer offers a copyable snippet for naming a problem permanently.
- **Errors from Lightning components join problem grouping**, because a failure caught in a component now records the error's type alongside its message and the component it came from.
- **Paged reads at any table size.** `QRY_Builder.getPage` serves a page whichever way the platform allows for that query, so reads past 100,000 matching rows return a page instead of failing.
- **Permanent failures.** A step can return `failedPermanently(...)` so the chain fails on that attempt without spending retry budget on a deterministic failure, and the flag survives to later steps.
- **Retry only the statuses you list.** `ApiStep.retryOn(Set<Integer>)` restricts chain-level retry to specific HTTP statuses. A statusless failure stays retryable under every value.
- **Exception-aware finality.** `ChainContext.isFinalAttempt(Exception)` answers filter-aware finality from inside `work()`, so a last-chance side effect fires on the attempt that really is the last one.
- **Literal search.** `QRY_Condition.FieldCondition.containsLiteral(String)` treats `%`, `_` and `\` as ordinary characters, so a search box matches exactly what someone typed. `contains()` is unchanged.
- **A logging identity for a separate run.** `LOG_Builder.serializeContext(String)` builds a minimal logging context for a supplied correlation ID, so a restarted chain starts a clean trace.
- **Transport-failure mocking.** `API_MockFactory.forService(...).withTransportFailure()` simulates a call that never reaches the server.
- **Accessibility improvements across the packaged screens.** Unavailable Chain Monitor actions state their reason in visible text and to screen readers, the action toolbar is a named group, Escape closes the Log Console drawer and returns focus to the list, Kern Home has a correct heading outline with distinct button names and wrapping tool titles, the Health Check's passing-checks list is labelled, and small-text contrast meets the 4.5:1 floor.
- **Four proven composition patterns** in the Async Processing Guide: commit-coupled outbound delivery, a two-chain approval hand-off, a circuit breaker around a struggling integration, and a recurring scheduled chain.

### Fixed

- Scheduled clean-up no longer deletes live chains: the Health Check's one-click retention fix ages chain records on their completion timestamp instead of their created date, which previously purged Stalled and even Running chains at 90 days.
- A chain step wrapping one of your own web-service handlers no longer dies at the background hop with "Handler class not found".
- Recovery reaches a chain that dies before its first step finishes, and single-step chains, because the background job ID is stamped when the chain starts.
- Logging from a post-trigger action inside platform-event processing no longer throws, and a failing post-action no longer leaves the rest of the transaction unable to flush its log entries.
- Grouping keys are tidied where the stored key is built, so a key with stray edge whitespace or one longer than the field allows no longer fails to group silently.
- Grouped logging survives a database-level clash: only the affected row is involved, the rest of the batch still lands, and one warning entry records what happened.
- A count query honours `bypassSharing()`, which was previously accepted and ignored, so a bypassed count can no longer return fewer rows than the query it was sizing.
- A wildcard masking target no longer rewrites unique keys and external IDs, so an identifier field can no longer be redacted into a duplicate-value failure.
- The Log Console keeps working at volume: it declines to group above roughly 35,000 matching entries in the window and says so, the counts above Individual entries decline the per-level breakdown above their own ceiling while still reporting the exact total, a capped list says it was capped, a deep link loads once instead of twice, a failed read reports an error rather than "No logs match these filters", and the Log Number column sorts server-side.
- Opening a Scheduled Job record page no longer throws a component error on every view.
- An error caught by a component's error boundary logs its own message rather than a bare phrase.
- The chain list distinguishes "no chains at all" from "none in this status".
- Generated mock record IDs no longer collide at realistic build volumes, and the test factory no longer silently replaces a default-value provider you registered.
- `isFinalAttempt()` reads `true` in an `onError` handler for every failure that was final, including a retry denied by an exception filter while budget remained.
- A chain that fails with an oversized context stores no context rather than unreadable truncated data, a first-step delay no longer discards custom async options, and every Chain Monitor action guards against a double click.

### Changed

- **The org-wide chain switch moves to a custom setting.** Chain processing is driven by `AsyncChainRuntimeSwitch__c.ChainsEnabled__c` through a new strategy on the existing `AsyncChain` feature flag. An org that never edited that flag record is unaffected. An org that edited its *result when nothing matches* or *enabled by default* values can change behaviour on upgrade, in one direction or the other. Check that record before upgrading.
- **Asynchronous DML honours your access-mode and sharing choices end-to-end.** A `DML_Builder` chain ending in `.async()` no longer loses the access mode you set: a system-mode async write runs with record sharing enforced by default, and `.bypassSharing()` is the explicit opt-out carried across to the job. The scheduled record purge is unaffected.
- **Reusing a correlation ID across chains raises `UTIL_Exceptions.IllegalStateException`** where it previously surfaced a `DmlException`, so code catching `DmlException` around a chain launch for this case no longer catches it.
- **Paged queries can return a null `QueryPage.cursor`**, and a page size outside 1 to 2,000 is now rejected at the call with an `IllegalArgumentException`.
- **Wildcard masking targets narrow**, skipping unique and external-ID fields; add an explicit target to keep masking such a field.
- **An unhandled stall logs at error level** rather than warning. Orgs that page on error-level entries should review their filters.
- **The logging framework's background persistence runs with the sharing of the code that logged it**, rather than defaulting to full system access. A tightening, so nothing gains access it did not have.
- **Subclasses of `UTIL_SObjectBuilderDefaultProvider` must call `super.defineSObjectOptionalFields`** to keep User records buildable; an override that omitted it previously inherited the behaviour by accident.
- **Three Health Check rows are named differently.** "Organisation Cache" is now "Org Cache", matching Setup's own name; "Masking configuration" and "Masking coverage (custom objects)" changed capitalisation only, to "Masking Configuration" and "Masking Coverage (Custom Objects)". Update anything that matches check names exactly.
- **A step class must declare no constructor of its own** to be rebuilt when a chain resumes; the refusal names the rule instead of failing obscurely.
- The Chain Monitor's "View logs" link opens the chain's own run window instead of a flat 30-day view, operator actions sit on their own row, and the Timing card reports a run that stopped short honestly.
- Some released Custom Label wording was corrected, with placeholder counts unchanged; existing translations keep working but show the older wording until re-translated.

**Installing 1.6.0-3 fresh can fail.** To keep a standard button off the chain-execution page, the 1.6.0-3 layout named that button (`SmartFillEnrich`) in order to exclude it, and an org without the button rejects a layout that names it at all. 1.7 no longer names it, so install 1.7 or later. Orgs already running 1.6.0-3 upgrade normally.

Backward-compatible: the global Apex surface is purely additive (ten new members across four existing classes, nothing removed or changed in signature). For the full tour and every upgrade note, see [Kern 1.7 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.7.md).

## [1.6.0-3] — 2026-07-26

**Subscriber package version id:** `04tfj000000OKK9AAO`

The async release: chains now look after themselves. A chain that loses its background job is detected instead of sitting in Running forever, recovery restarts the ones that are provably safe to resume, and the people you nominate can stop a runaway chain from the Chain Monitor.

### Added

- **Stalled-chain detection and recovery.** A chain that loses its background job is marked `Stalled`, and the new Chain Watchdog scheduled job restarts a provably dead chain from the step where it stopped. The Health Check schedules the watchdog in one click. Run fencing guarantees a stale leftover job can never corrupt the resumed run.
- **Chain abort.** Operations users you nominate can abort a running or stalled chain from the Chain Monitor. Ships switched off: gated by a permission set assigned to nobody, plus an org-wide feature-flag off-switch.
- **Per-step retry.** A step can opt into automatic retry with backoff (a growing pause between attempts); the chain records `Retries Exhausted` when attempts run out.
- **Deduplication keys.** A keyed chain never runs twice at once; a second start lands on the run already in flight.
- **Failure Category.** Every chain that leaves the happy path records why (empty on healthy chains), and every ending writes a log entry.
- **Health Check grows to nine checks**, including a warning when an Install for All Users has silently granted the abort permission to every profile. Choose Install for Admins Only.

### Fixed

- Logging no longer throws in sessionless contexts such as login handlers and inbound email services.
- Partial-save DML no longer blanks a child's existing lookup when a parent insert fails.
- The Data Masking Advisor's inventory export now includes every actively masked field.
- All packaged dialogs render reliably after a platform update began requiring dialog titles.
- The test-data builder generates genuine Integer defaults.

### Changed

- The Chain Monitor list loads a far lighter query and caps page size at 100.
- Trigger action bypass names now match case-insensitively, so a bypass that never took effect because of a casing mismatch starts working. This is the one deliberate behaviour change.

Backward-compatible: the global Apex surface is purely additive (one new class and six new methods, nothing removed or changed in signature). For the full tour, see [Kern 1.6 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.6.md).

## [1.5.0-1] — 2026-07-13

**Subscriber package version id:** `04tfj000000MutBAAS`

A single-fix release for the Streaming Monitor. Its Change Data Capture list showed only custom-object change events; the standard ones, such as `AccountChangeEvent`, were missing because discovery looked for them under a publisher that no record on the platform uses. A single lookup now returns both, so the standard channels are back in the list, and every channel is labelled `Standard: <name>` or `Custom: <name>` (from two new Custom Labels) so you can tell them apart at a glance. KernDX publishes each release as a new minor version, so this standalone fix ships as 1.5 rather than a patch, and it carries nothing else. Backward-compatible: the Apex API and metadata surface are purely additive (two new Custom Labels, nothing removed or changed), so upgrading from 1.4 is the standard package upgrade with no migration steps. For the full context, see [Kern 1.5 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.5.md).

## [1.4.0-2] — 2026-07-12

**Subscriber package version id:** `04tfj000000MlrVAAS`

A quality release with two headlines: the framework's user interface is now translatable end to end (every display string across 28 component bundles moved to Custom Labels, 359 new labels, English rendering unchanged), and a systematic correctness sweep of every Lightning component fixed the defects it found, led by an async-chain fix where a continue-on-error chain could be marked Failed once its accumulated step messages grew long. Also in: Chain Monitor live refresh now works in unmanaged and renamed-namespace deploys, record forms report failed saves instead of looking saved, silent failures (clipboard copies, retention updates, job saves) now surface, the Streaming Monitor timeline is native SVG with no chart-library dependency, and lookups survive missing configuration. Backward-compatible: the Apex API and metadata surface are purely additive; a short list of deliberate behaviour changes is in the release notes. For the full tour, see [Kern 1.4 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.4.md).

## [1.3.0-3] — 2026-07-03

**Subscriber package version id:** `04tfj000000M0ZFAA0`

A purely additive release headlined by the Log Console: a dedicated screen for browsing past log entries, with recurring problems grouped by occurrence count, severity filtering, search, and a detail drawer that walks one operation end to end across triggers, jobs, and callouts, cross-linked both ways with the Chain Monitor. Alongside it: aliased multi-aggregate selections and aggregate ordering in the query builder (several aggregates in one query, read back by name), a contains filter and single-argument condition constructors, picklists on the Flow invocable-action inputs, a redesigned Org Limits view, and LWC logging that now persists the client's own error stack and context. Everything is additive, so upgrading from 1.2 is the standard package upgrade with no migration steps. For the full capability tour, see [Kern 1.3 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.3.md).

## [1.2.0-1] — 2026-06-27

**Subscriber package version id:** `04tfj000000LXH7AAO`

A purely additive release that hardens the async-chain framework and adds three smaller quick wins. Headlines: per-step idempotency keys so a chain step is safe to re-run without acting twice on an outbound call, a typed `getChainStatus()` accessor that returns a `ChainStatus` value object, and a first-step delay of up to ten minutes. Alongside those: deterministic ordering for trigger actions that share an order value, a record-id input on the Flow logging action, and fluent geolocation distance filtering in the query builder. Every change adds new surface, so upgrading from 1.1 is the standard package upgrade with no migration steps. For the full capability tour, see [Kern 1.2 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.2.md).

## [1.1.0-11] — 2026-06-15

**Subscriber package version id:** `04tfj000000KesXAAS`

First release of the Kern 1.1 line. Headlines: the Data Masking Advisor (a console to review, test, and deploy masking coverage), stronger payment-card masking via the new Mask Payment Card Numbers rule (it takes over from the original credit-card rule on framework objects automatically — see the upgrade notes), Change Data Capture and post-trigger actions in the trigger framework, a hardened Streaming Event Monitor, typed date functions in the query builder, Summer '26 (API 67.0) platform support, and a hosted documentation site. For the full capability tour with upgrade notes, see [Release Notes — Kern 1.1](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.1.md).

## [1.0.0-121] — 2026-05-22 (first public release)

**Subscriber package version id:** `04tfj000000JN0vAAG`

Initial publicly-tagged release. Every framework module, every Strategic Guide, every Fast Start, the full API reference, and the pipeline distribution flavor ship at this version. For a capability-by-capability tour of what's in v1.0, see [Release Notes — Kern 1.0](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.0.md).

[1.0.0-121]: https://github.com/JVB-Consulting/kerndx/tree/v1.0.0-121
[1.1.0-11]: https://github.com/JVB-Consulting/kerndx/tree/v1.1.0-11
[1.2.0-1]: https://github.com/JVB-Consulting/kerndx/tree/v1.2.0-1
[1.3.0-3]: https://github.com/JVB-Consulting/kerndx/tree/v1.3.0-3
[1.4.0-2]: https://github.com/JVB-Consulting/kerndx/tree/v1.4.0-2
[1.5.0-1]: https://github.com/JVB-Consulting/kerndx/tree/v1.5.0-1
[1.6.0-2]: https://github.com/JVB-Consulting/kerndx/tree/v1.6.0-2
[1.6.0-3]: https://github.com/JVB-Consulting/kerndx/tree/v1.6.0-3
[1.7.0-7]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-7
[1.7.0-8]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-8
[1.7.0-9]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-9
[1.7.0-10]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-10
[1.7.0-11]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-11
[1.7.0-12]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-12
[1.7.0-13]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-13
