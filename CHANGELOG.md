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
