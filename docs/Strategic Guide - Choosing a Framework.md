# KernDX — Choosing a Framework

> A capability-by-capability guide to choosing between KernDX and the established Salesforce Apex frameworks — `fflib`, `taf`, `rflib`, `nebula-logger`, `apex-libra`, the Apex Fluently libraries, and others. Written by the KernDX team. Every claim about another framework is checkable against its public source.

## Table of contents

- [How to use this guide](#how-to-use-this-guide)
- [What actually separates these frameworks](#what-actually-separates-these-frameworks)
- [Pick by capability](#pick-by-capability)
- [The integration trade-off](#the-integration-trade-off)
- [Head-to-head](#head-to-head)
  - [vs. fflib](#vs-fflib)
  - [vs. taf](#vs-taf)
  - [vs. apex-libra](#vs-apex-libra)
  - [vs. rflib](#vs-rflib)
  - [vs. nebula-logger](#vs-nebula-logger)
  - [vs. the Apex Fluently libraries](#vs-the-apex-fluently-libraries)
  - [vs. fflib-mocks](#vs-fflib-mocks)
- [Specialty libraries at a glance](#specialty-libraries-at-a-glance)
- [Organisational fit](#organisational-fit)
- [Spotted something wrong?](#spotted-something-wrong)

---

## How to use this guide

If your team is asking *"why KernDX instead of the framework we already know?"* — this is the answer. Start with [What actually separates these frameworks](#what-actually-separates-these-frameworks) for the differences that matter most, use [Pick by capability](#pick-by-capability) to find the right tool for a specific need, read the [head-to-head](#head-to-head) section for whichever framework you're weighing, and check [Organisational fit](#organisational-fit) for when KernDX is — and isn't — the right call.

Two honest notes up front, stated once:

- **Licensing.** KernDX is licensed under BSL 1.1. The source is public — you can read, modify, and deploy it — but BSL is not an OSI-approved license until it converts to Apache 2.0 four years after release. Teams with a strict "OSI-approved at install time" procurement rule should weigh that, and organisations with a formal open-source-governance process should validate BSL alignment with their procurement requirements.
- **Maintainer model.** KernDX is currently maintained by a single primary developer, with an issues-only contribution model. Maintainer concentration is common across the Apex ecosystem rather than unique to KernDX — the `fflib` family is among the few examples of genuinely distributed maintainership.

Both are covered in depth in [Risks](Strategic%20Guide%20-%20Risks.md). They are not repeated throughout this guide.

This guide names other frameworks because you cannot make a real choice without naming the alternatives. Where another framework is the better fit for a need, it says so plainly. Every comparison is a present-tense fact about each framework's published source, which you can verify yourself — frameworks evolve, so treat this as a snapshot and check the current source if a detail is load-bearing for your decision. Where this guide says no alternative does something, that is scoped to the frameworks compared here, not a claim about the entire Apex ecosystem.

This guide compares frameworks on the dimensions that drive a real production decision: **security defaults, capability breadth, operational integration burden, extensibility, testing tooling, observability, maintenance sustainability, and licensing.** **Comparison baseline:** each framework's published source as of May 2026.

---

## What actually separates these frameworks

Apex frameworks are not interchangeable. The differences that matter most are not syntax preferences — they are what the framework does *by default* when a developer is moving fast under a deadline. Three axes do most of the separating.

### 1. Security defaults

This is one of the biggest differences, and the easiest to underestimate when picking on familiarity alone.

KernDX enforces field- and object-level security (FLS/CRUD) on **both reads and writes by default** — every read and write runs in `USER_MODE` unless a call explicitly opts out — and writes an **audit log entry every time** that enforcement is bypassed, so an emergency `P1` bypass and an accidental bypass inside a loop are both traceable. Most alternatives delegate access control to the developer per call and run in standard, unaudited execution contexts:

- **`fflib`** does not enforce FLS/CRUD by default on its Query/DML surfaces; access mode is the developer's responsibility per call, and `SimpleDML` writes run without FLS/CRUD.
- **`apex-libra`** defaults to *system mode* on DML writes — you must override per call to get FLS/CRUD enforcement on writes.
- **`taf`, the Apex Fluently libraries, `fflib`, and most others** rely on standard platform execution contexts, so elevated access leaves no automated audit trail.

The practical difference is the audit posture: a missed or deliberate elevation in those libraries leaves no record, whereas KernDX logs it. Default-on enforcement reduces dependence on consistent developer implementation discipline. All of this is checkable in each framework's source.

This is not a claim that explicit access control is wrong — some enterprise architectures deliberately centralise elevated access inside controlled service boundaries, which is a legitimate pattern. The difference is the *default*: KernDX enforces security up front and makes every elevation an audited, per-call decision, rather than relying on each developer to opt in.

### 2. One deployment, opt-in at runtime

KernDX installs as a single managed package, but it is **dormant by default**. Installing it adds the toolset to your org without attaching to your objects, changing your existing triggers, or running on your transactions. Each capability activates only when you wire it in — a trigger-registration record, a builder call, a feature flag. You can adopt the outbound-HTTP tools today and leave your existing `fflib` domains or hand-rolled triggers completely untouched.

So the usual "monolith" objection mostly dissolves: KernDX is **one deployment footprint with a modular runtime footprint** — a suite of tools available in your org, not a framework that takes over your org. One honest caveat: the managed package's install footprint and dependency are real whether or not a capability is active — what stays dormant is the runtime behaviour, not the on-org footprint. The flip side of bundling is covered in [The integration trade-off](#the-integration-trade-off) below.

### 3. Quality discipline

KernDX enforces **100% per-file Apex coverage and 95% LWC statement/branch coverage at every release build**, ships ApexDoc on every class and method, and is clean against shipped PMD and ESLint rulesets. Coverage discipline and static-analysis posture vary widely across the alternatives. None of this guarantees a framework is bug-free: coverage targets improve regression resistance but are not a proxy for behavioural correctness. What they tell you is how much regression safety net you inherit and how much you'll be adding yourself.

---

## Pick by capability

For a specific need, this is the fast lookup. "Consider an alternative when…" names the cases where another framework genuinely fits better.

| Capability | KernDX gives you | Consider an alternative when |
|---|---|---|
| **Trigger framework** | Metadata-driven registration, four-level bypass (per-object / per-action / per-flow / framework-wide) with an audit log on every bypass, automatic recursion control, execution observability | `taf` if you specifically need Change Data Capture channel binding, or an Apache 2.0 license is a hard requirement |
| **Query builder** | A fluent SOQL API with no string concatenation, FLS/CRUD enforced by default, an audit log on every bypass, and a subclassable builder | `apex-fluently-soql` if a standalone fluent-DSL is all you want and developer-managed access control is acceptable |
| **DML** | Transactional batching, FLS/CRUD enforced on writes by default, audited bypass, async DML, and multi-level dependency-graph resolution with cycle detection | `apex-fluently-dml` if you prefer its record-builder relationship DSL — both resolve multi-level graphs; the difference is API shape, not depth |
| **Inbound REST** | A two-class routing pattern that keeps REST plumbing out of business logic, response-DTO marshalling, validation hooks, and a paired test harness | No framework alternative — hand-roll the dispatcher per endpoint, or adopt KernDX |
| **Outbound HTTP** | Production callouts with retry/backoff, circuit breaker, idempotency hashing, dead-letter queue, named-credential resolution, and a mock library | `apex-fluently-httpmock` ties on the *mock* surface only — it ships no production callout path |
| **Logging** | A lean Apex/LWC/Flow logging API with default-on async emission, integrated with triggers/query/DML/async | `nebula-logger` if you need multi-transport selection, all seven platform log levels, per-record retention, or a historical log-browser UI |
| **Testing** | A builder-pattern test-data factory with parent-child wiring, DML-free query mocking, and framework-object assertion helpers | `fflib-mocks` if you need Mockito-style behaviour verification (argument matchers, verification modes) — KernDX has no equivalent |
| **Resilience / feature flags** | A subscriber-extensible feature-flag framework (custom metadata + per-user/profile settings) consumable from Apex/Flow/LWC, with pluggable resolution strategies and retry utilities | `rflib` if you need only a simple hierarchical kill-switch and no pluggable strategies |
| **Security** | FLS/CRUD enforced on reads and writes by default, an org-wide kill switch, per-call bypass, and an audit entry on every bypass | None of the frameworks compared here ship both an org-wide kill switch *and* runtime audit-on-bypass |
| **Data masking** | Runtime masking on the call path (regex + credit-card detection + literal + JSON-key), four modes, three failure actions, caller scoping, and shipped rules | `mask-sobject` for *batch* anonymisation of existing data (sandbox refresh) — a complementary, different job |
| **LWC** | A component base with five built-in modules (toast / Apex controller / navigation / Lightning Message / Flow nav) and opt-in activation | No comparable alternative ships a coherent LWC component framework |
| **Async** | Chained queueables with shared state across transactions, finalizer recovery, a kill switch, and per-step error/completion handlers | A focused library (`apex-fluently-async`, `apex-promisify`) if you want only the standalone chaining shape |

---

## The integration trade-off

Single-capability libraries earn their popularity through **extreme isolation**: you can swap a standalone logger without touching your DML layer, and each library is a small, independently-reviewable surface. That is a real engineering virtue.

The cost of that isolation is that **your team becomes the systems integrator**. Three carrying costs accumulate as you co-install more libraries, even when each is free:

1. **Operational integration.** Making libraries coexist — namespace alignment, settings hierarchies, shared correlation IDs, cross-library bypass coordination — is your work. Combining a trigger library with a separate logger, for instance, means wiring trigger-bypass events into the logging surface yourself; neither library ships that bridge.
2. **Security review.** Each library is its own review surface. Co-installing four (triggers, query, DML, logging) means four independent review cycles per upgrade — sharing declarations, FLS/CRUD posture, audit behaviour, and dependency provenance re-checked for each.
3. **Upgrade and maintenance.** Independent release cadences mean version pinning, breaking-change tracking, and cross-library compatibility testing every time any one of them tags a release.

KernDX makes the opposite trade: it gives up per-library swappability for **pre-wired integration**. The capabilities share one namespace, one security posture, one correlation ID, one bypass-audit signal, and one release cadence — the wiring is done for you.

Neither side is free, and the honest framing is symmetric: an integrated package concentrates dependency ownership and widens the blast radius of an upgrade; a library stack distributes that but multiplies the integration and review surface. Because KernDX is [opt-in at runtime](#2-one-deployment-opt-in-at-runtime), you can also split the difference — adopt it for most capabilities and keep a specialised library where that library is the better fit.

---

## Head-to-head

Seven frameworks come up most often when teams compare against KernDX. Each follows the same shape: what it is, where it wins, where KernDX diverges, how they coexist, and the rough migration effort. Migration-complexity ratings reflect relative architectural displacement — how much established code has to change — not implementation hours, and assume an existing codebase rather than a greenfield start.

### vs. fflib

**The library.** `fflib` ("Apex Enterprise Patterns" / `fflib-apex-common`) is the canonical implementation of the Service / Selector / Domain / Unit-of-Work pattern in Apex — the framework that established that architectural style on the platform. License: BSD 3-Clause. Mature, in maintenance mode (no release in several years).

**Where it wins.** You specifically want the Application/Service factory pattern (`fflib_Application`), your team is already trained on it, and you accept hand-rolling the surfaces it doesn't cover.

**The KernDX divergence.** `fflib` ships no trigger framework, no FLS/CRUD enforcement by default on Query/DML, no outbound HTTP framework, no data masking, no health check, no LWC framework, and no shipped scanner or coverage gate. KernDX covers those areas with security enforced by default and audited bypass.

**Coexistence.** Strong. The two ship in separate namespaces and don't collide — let `fflib_Application` supply the Service/Domain factory while KernDX handles triggers, query, DML, outbound, async, security, and masking.

**Migration complexity: Medium–High** — re-pointing established Domain/Service/Selector layers is real work, so most teams coexist rather than migrate the domain layer.

> **Pick:** Start fresh on KernDX. Keep `fflib` for an existing Domain layer that depends on its factory patterns — the hybrid is supported.

### vs. taf

**The library.** `taf` ("Trigger Actions Framework") is a single-capability trigger framework using metadata-driven registration. It scopes to triggers only. License: Apache 2.0.

**Where it wins.** You need a trigger framework *only*, and you specifically need Change Data Capture channel binding (KernDX dispatches standard DML events only), or an Apache 2.0 license is a hard requirement. `taf` also ships an off-the-shelf GitHub Actions CI workflow.

**The KernDX divergence.** `taf` bypasses run unaudited — no log, no platform event, no signal. Its registration algorithm is not subscriber-pluggable, and it ships no coverage gate. KernDX emits an audit entry on every bypass and covers the capability areas beyond triggers. (Teams already fluent in `taf`'s registration style transition with low friction — the metadata shape is similar; see [Adoption](Strategic%20Guide%20-%20Adoption.md#migration-narratives).)

**Coexistence.** Not typical — both occupy the trigger scope, and running two trigger dispatchers at once invites unpredictable order-of-execution and recursion conflicts. Pick one.

**Migration complexity: Low–Medium** — the metadata-driven registration concepts map closely.

> **Pick:** KernDX by default. Keep `taf` when you need CDC channel binding or a hard Apache 2.0 requirement and accept unaudited bypasses on the trigger layer.

### vs. apex-libra

**The library.** `apex-libra` is a multi-capability framework covering trigger registration, DML, logging, resilience, security, testing, and utilities — the closest single-package alternative to KernDX by breadth. License: MIT.

**Where it wins.** Your primary need is its functional / lambda utility surface (`IFunction` / `IConsumer` / `IPredicate`), which KernDX does not ship, or MIT licensing is a hard requirement.

**The KernDX divergence.** `apex-libra` defaults to *system mode* on DML writes — you override per call to enforce FLS/CRUD on writes; bypasses are unaudited; it ships no recursion-suppression mechanism; and it has no inbound REST, outbound HTTP, data masking, health check, or LWC framework. KernDX defaults to user mode on reads and writes, audits every bypass, and suppresses recursion automatically.

**Coexistence.** Possible (separate namespaces), but the overlap on triggers/query/DML/testing means most teams pick one.

**Migration complexity: Medium** — overlapping surfaces re-point to KernDX's default-on equivalents.

> **Pick:** KernDX when secure defaults and integrated capability breadth are priorities. Adopt `apex-libra` if functional/lambda utilities are your primary need and you accept default-system-mode writes plus unaudited bypasses.

### vs. rflib

**The library.** `rflib` is a multi-capability framework focused on logging, trigger orchestration, feature switches, and a few utilities — the most actively maintained multi-capability alternative here. License: BSD 3-Clause.

**Where it wins.** You want a simple hierarchical feature-switch (user → group → profile → global) with no need for pluggable strategies; or its historical log-browser LWC; or its admin per-row declarative-bypass shape.

**The KernDX divergence.** `rflib` has no FLS/CRUD enforcement defaults, audits bypass only partially (framework- and per-user gates, not the per-handler path), and its feature-switch is sealed against extension. It ships no inbound REST, outbound HTTP, data masking, async-chain orchestration, health check, or scanner. KernDX covers those with default-on security and full bypass audit.

**Coexistence.** Good for the log-browser surface — the two run in separate namespaces. (Logging is parallel, not merged: entries emitted via KernDX are not picked up by `rflib`'s viewer.)

**Migration complexity: Low** — most value comes from coexisting for the log-browser rather than migrating.

> **Pick:** KernDX for full coverage. Keep `rflib` when its historical log-browser or admin per-row bypass is load-bearing — they co-install cleanly.

### vs. nebula-logger

**The library.** `nebula-logger` is a single-capability logging framework — the deepest dedicated Salesforce logging implementation by surface area. License: Apache 2.0. Long, mature release history.

**Where it wins.** Maximum logging depth — selectable transport (event bus / queueable / REST / synchronous), all seven platform log levels, per-record and per-scenario retention overrides, and a dedicated historical log-browser LWC. KernDX's logging is leaner (single platform-event transport, four levels, no per-record retention field, no dedicated log-browser UI).

**The KernDX divergence.** `nebula-logger` is logging-only. It has no trigger framework, query/DML framework, web services, async orchestration, or security defaults — and its logging is not wired into a trigger/query/DML bypass-audit or async status signal, because those don't exist outside an integrated framework.

**Coexistence.** Strong — among the cleanest hybrids available. (Logging is parallel, not merged: KernDX's own entries, including bypass-audit logs, flow through its `LogEntryEvent__e` / `LogEntry__c` channel and are not picked up by `nebula-logger`'s store — bridging the two is custom work.)

**Migration complexity: Low** — you co-install it as the logging backend; there's effectively nothing to migrate.

> **Pick:** Co-install both. `nebula-logger` as your logging backend (multi-transport, retention, log-browser); KernDX for everything else — triggers, query, DML, web services, async, security, masking, LWC, health, CI. Separate namespaces, no collision.

### vs. the Apex Fluently libraries

**The library.** A family of eight focused single-purpose libraries (`-soql`, `-dml`, `-cache`, `-async`, `-httpmock`, `-consts`, `-test`, `-lwc`) — a "pick what you need" collection of fluent-DSL libraries, generally actively maintained, with `-soql` and `-dml` at the highest cadence. License: MIT across the family.

**Where it wins.** MIT licensing is a hard requirement; you want a single capability without a bundled framework footprint; or you prefer a specific library's DSL ergonomics (e.g. `apex-fluently-dml`'s record-builder relationship syntax over KernDX's call-site registration — both resolve multi-level dependency graphs). Each library also ships a dedicated hosted docs site.

**The KernDX divergence.** Access control is delegated and unaudited across the family; `apex-fluently-soql`'s executor is sealed (you can't subclass to extend the builder); `apex-fluently-dml` ships no async DML path; `apex-fluently-httpmock` is mock-only with no production callout path; and adopting several pieces provides no shared bypass-audit or correlation ID — the libraries don't know about each other. KernDX provides default-on FLS/CRUD, audited bypass, async DML, production callouts, and cross-capability integration.

**Coexistence.** Technically possible (separate namespaces) but usually redundant — these libraries shine adopted standalone; KernDX shines when integrated guarantees are the requirement.

**Migration complexity: Low–Medium per library** — each DSL surface can be swapped independently.

> **Pick:** KernDX for integrated guarantees. Adopt individual Apex Fluently libraries when MIT licensing is mandatory or you specifically prefer a library's DSL and accept developer-managed access control on that surface.

### vs. fflib-mocks

**The library.** `fflib-mocks` (`fflib-apex-mocks`) is the canonical Mockito-style mocking library for Apex — behaviour-verification mocking via stubs, argument matchers, and verification modes. License: BSD 3-Clause. Long-established, lightly maintained now.

**Where it wins.** You need Mockito-style behaviour verification — rich argument matchers, `times`/`atLeast`/`atMost`/`between`/`never` verification modes, sequence verification, argument capture. **KernDX has no equivalent.**

**The KernDX divergence.** KernDX's testing scope is a builder-pattern test-data factory, DML-free selector mocking, and test helpers for async / Flow / outbound / framework-object assertions — a different and complementary surface.

**Coexistence.** Recommended — the two are complementary.

**Migration complexity: None** — co-install; there's nothing to replace.

> **Pick:** Adopt both side-by-side. `fflib-mocks` for Mockito-style verification; KernDX's test-data builder and selector mocks for the rest.

---

## Specialty libraries at a glance

Beyond the seven above, these single-purpose libraries each cover one specialty surface. In most cases KernDX already covers the same ground as part of its integrated scope.

| Library | What it does | KernDX equivalent | Recommendation |
|---|---|---|---|
| `apex-async-linkable` | Standalone queueable-link library | `UTIL_AsyncChain` adds shared state, finalizer recovery, kill switch, orchestration | Use KernDX unless you need the standalone shape |
| `apex-chainable` | Queueable-chaining with chain-runtime exceptions | `UTIL_AsyncChain` chains at greater depth | Use KernDX |
| `apex-fluently-async` | Single-purpose async-chain library | `UTIL_AsyncChain` adds shared state, recovery, kill switch, per-step handlers | Use KernDX unless you want the focused shape |
| `apex-fluently-cache` | Single-class platform-cache wrapper, three storage tiers, no auto-dispatch | `UTIL_Cache` adds auto-scope dispatch and opt-in graceful in-transaction fallback | Use KernDX |
| `apex-fluently-consts` | Constant-organisation utility | Covered by KernDX utility helpers | Use KernDX utilities |
| `apex-fluently-dml` | Fluent DML DSL with record-builder relationships and graph resolution | `DML_Builder` ships the same graph algorithm plus audited bypass, async DML, and FLS/CRUD on writes by default | Use KernDX for general DML; consider this for its DSL shape or MIT licensing |
| `apex-fluently-httpmock` | HTTP-callout mock library, several resolution strategies | `API_MockFactory` ties on mocking; KernDX adds production outbound infrastructure | Use KernDX when already on it; use this when you need only the mock surface |
| `apex-fluently-lwc` | LWC toast-helper library | `ComponentBuilder` adds four more modules | Use KernDX |
| `apex-fluently-soql` | Fluent SOQL DSL | `QRY_Builder` adds audited bypass, FLS/CRUD by default, and a wider feature set; both default to user-mode reads | Use KernDX for general queries; consider this for the standalone DSL if developer-managed access control is acceptable |
| `apex-fluently-test` | Focused test-data builder | `TST_Builder` adds parent-child wiring and cyclic overrides; the broader family adds selector mocks and async/Flow/outbound helpers | Use KernDX |
| `apex-promisify` | Promise-style API for queueables | `UTIL_AsyncChain` adds shared state, recovery, kill switch | Use KernDX unless the Promise-style API is the requirement |
| `mask-sobject` | Batch anonymisation of existing org data | `UTIL_FrameworkMasker` does runtime masking on the call path; batch scrub is the differentiator | Use KernDX for runtime masking; use this for batch sandbox scrub — complementary |
| `nebula-triggers` | Single-class metadata-driven trigger dispatcher | KernDX trigger framework adds recursion control, four-level audited bypass, observability | Use KernDX |
| `promise` | Promise-style queueable chaining, no shared state | `UTIL_AsyncChain` adds shared state, recovery, kill switch | Use KernDX |

---

## Organisational fit

Capability fit is only half the decision; organisational fit is the other half.

**KernDX fits well when:**

- **Greenfield or standardisation.** You're starting fresh, or standardising a codebase that lacks a consistent framework.
- **Governance by default.** Security governance is a priority and you want enforcement by default rather than per-developer discipline.
- **Unified maintenance.** You want one integrated toolset with a single review surface and one upgrade cadence.
- **Lean platform teams.** Default-on governance does *more* work for you when there's no dedicated architecture governance capability enforcing conventions in review — a small team is a reason *for* built-in governance, not against it.

**Prefer specialised libraries when:**

- **Existing investment.** You have deep existing investment in one (e.g., established `fflib` domains) and no reason to move it.
- **OSI-at-install procurement.** Strict procurement requires an OSI-approved license at install time (KernDX is BSL 1.1 until its Apache 2.0 conversion).
- **Single narrow need.** You need exactly one narrow capability and nothing else.
- **Mature in-house standards.** You already operate mature internal patterns and governance controls and want to add a single focused library to fill one gap.

These are not mutually exclusive. Because KernDX is opt-in at runtime, a team can adopt it for the capabilities it wants and keep a specialised library where that library is the better fit — see the per-framework coexistence notes above.

**Support posture.** KernDX support is issue-based — bug reports and questions go through GitHub issues, with no formal SLA — while hands-on help, direct source delivery, and handover are available through consulting engagements. [Risks](Strategic%20Guide%20-%20Risks.md) and [Operations](Strategic%20Guide%20-%20Operations.md) cover the support and survivability model in full.

---

## Spotted something wrong?

This guide is written by the KernDX team, and frameworks change. If you maintain or use one of the frameworks here and believe an assessment is inaccurate — a misread feature, a detail that's changed since this was written, or a recommendation that doesn't match the current source — please [open a GitHub issue](https://github.com/JVB-Consulting/kerndx/issues/new/choose). We'll re-check against the current source, correct the guide, and credit you in the changelog.

---

[< Risks](Strategic%20Guide%20-%20Risks.md) | [Overview >](Strategic%20Guide%20-%20Overview.md)
