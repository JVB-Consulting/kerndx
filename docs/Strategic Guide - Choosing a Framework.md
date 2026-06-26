---
navOrder: 16
---

# KernDX — Choosing a Framework

> A capability-by-capability guide to choosing between KernDX and the established Salesforce Apex frameworks: [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common), [`taf`](https://github.com/mitchspano/apex-trigger-actions-framework), [`rflib`](https://github.com/j-fischer/rflib), [`nebula-logger`](https://github.com/jongpie/NebulaLogger), [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library),
> the [Apex Fluently libraries](https://github.com/beyond-the-cloud-dev), and others. Written by the KernDX team. Every claim about another framework is checkable against its public
> source.

**What this is:** a side-by-side comparison of KernDX against the Apex frameworks teams most often already use, judged on the things that actually drive a production decision. **Why it exists:** picking a framework is a long-term commitment, and the differences that matter (what each one does by default, how much it covers, what you have to wire together yourself) are easy to miss when you choose on familiarity alone. **Who should read it:** architects and tech leads making the call, plus the delivery managers and executives who sign off on it. **When to use it:** when your team is asking "why KernDX instead of the framework we already know?" Where another framework is the better fit, this guide says so plainly.

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
- [Other specialty libraries](#other-specialty-libraries)
- [Organisational fit](#organisational-fit)
- [Spotted something wrong?](#spotted-something-wrong)

---

## How to use this guide

If your team is asking *"why KernDX instead of the framework we already know?"*, this is the answer. Here is the fastest route through it:

- Start with [What actually separates these frameworks](#what-actually-separates-these-frameworks) for the differences that matter most.
- Use [Pick by capability](#pick-by-capability) to find the right tool for a specific need.
- Read the [head-to-head](#head-to-head) section for whichever framework you're weighing.
- Check [Organisational fit](#organisational-fit) for when KernDX is the right call, and when it isn't.

Two honest notes up front, stated once:

- **Licensing.** KernDX is licensed under BSL 1.1. The source is public, so you can read, modify, and deploy it. BSL is not an OSI-approved licence until it converts to Apache
  2.0 four years after release. Teams with a strict "OSI-approved at install time" procurement rule should weigh that, and organisations with a formal open-source-governance
  process should validate BSL alignment with their procurement requirements.
- **Maintainer model.** KernDX is currently maintained by a single primary developer, with an issues-only contribution model. One maintainer carrying most of the work is common across the Apex
  ecosystem rather than unique to KernDX. The `fflib` family is among the few examples of genuinely distributed maintainership.

Both are covered in depth in [Risks](Strategic%20Guide%20-%20Risks.md). They are not repeated throughout this guide.

This guide names other frameworks because you cannot make a real choice without naming the alternatives. Where another framework is the better fit for a need, it says so plainly.
Every comparison is a present-tense fact about each framework's published source, which you can verify yourself. Frameworks evolve, so treat this as a snapshot and check the
current source if a detail is load-bearing for your decision. Where this guide says no alternative does something, that is scoped to the frameworks compared here, not a claim about
the entire Apex ecosystem.

This guide compares frameworks on the dimensions that drive a real production decision:

- **what each does by default for security**
- **how much it covers**
- **how much wiring you have to do yourself**
- **how extensible it is**
- **its testing tooling**
- **what it lets you see in production**
- **how sustainably it is maintained**
- **its licensing**

**Comparison baseline:** each framework's published source as of May 2026.

---

## What actually separates these frameworks

Apex frameworks are not interchangeable, and the differences that matter most are not syntax preferences. They are what the framework does *by default* when a developer is moving fast
under a deadline. Three axes do most of the separating.

### Security defaults

This is one of the biggest differences, and the easiest to underestimate when picking on familiarity alone. The question it answers: when a developer writes a query or a save under time pressure, does data security get enforced for them, or do they have to remember to ask for it?

KernDX enforces field- and object-level security on every read and write by default (FLS = field-level security; CRUD = object create/read/update/delete permissions). Every read and write runs with the current user's permissions and record sharing enforced (USER_MODE) unless a call explicitly opts out. And every time that enforcement *is* bypassed, KernDX writes an audit log entry, so an emergency `P1` bypass and an accidental bypass inside a loop are both traceable. The benefit: security is the default outcome rather than something each developer has to remember. Most alternatives instead leave access control to the developer on each call and run in standard execution contexts that keep no audit trail:

- **`fflib`** does not enforce FLS/CRUD by default on its Query/DML surfaces. Access mode is the developer's responsibility per call, and `SimpleDML` writes run without FLS/CRUD.
- **`apex-libra`** defaults to *system mode* on DML writes, so you must override per call to get FLS/CRUD enforcement on writes.
- **`taf`, the Apex Fluently libraries, `fflib`, and most others** rely on standard platform execution contexts, so elevated access leaves no automated audit trail.

The practical difference is the audit posture: a missed or deliberate elevation in those libraries leaves no record, whereas KernDX logs it. So you depend less on every developer applying access control consistently. All of this is checkable in each framework's source.

This is not a claim that explicit access control is wrong. Some enterprise architectures deliberately centralise elevated access inside controlled service boundaries, which is a
legitimate pattern. The difference is the *default*: KernDX enforces security up front and makes every elevation an audited, per-call decision, rather than relying on each
developer to opt in.

### One deployment, opt-in at runtime

A common worry about any bundled framework is that installing it takes over your org. With KernDX it doesn't. KernDX installs as a single managed package, but it is **dormant by default**. Installing it adds the toolset to your org without attaching to your objects, changing your existing
triggers, or running on your transactions. Each capability activates only when you wire it in: a trigger-registration record, a builder call, a feature flag. You can adopt the
outbound-HTTP tools today and leave your existing `fflib` domains or hand-rolled triggers completely untouched.

So the usual "monolith" objection mostly dissolves. KernDX is **one deployment footprint with a modular runtime footprint**: a suite of tools available in your org, not a
framework that takes over your org. One honest caveat: the managed package's install footprint and dependency are real whether or not a capability is active. What stays dormant is
the runtime behaviour, not the on-org footprint. The flip side of bundling is covered in [The integration trade-off](#the-integration-trade-off) below.

### Quality discipline

When you adopt a framework, you also inherit how well it is tested and documented, because that determines how much safety net you get for free and how much you have to build yourself. KernDX enforces **100% per-file Apex coverage and 95% LWC statement/branch coverage at every release build**, ships ApexDoc on every class and method, and is clean against shipped
PMD and ESLint rulesets. How much testing and static analysis the alternatives apply varies widely. None of this guarantees a framework is bug-free: coverage targets
improve resistance to regressions, but they are not a proxy for whether the behaviour is actually correct. What they tell you is how much regression safety net you inherit and how much you'll be adding
yourself.

---

## Pick by capability

Got a specific need? This is the fast lookup. The "Consider an alternative when…" column names the cases where another framework genuinely fits better, so you can see at a glance where KernDX is the right answer and where it isn't.

| Capability                     | KernDX gives you                                                                                                                                                                                                                                                                                                                 | Consider an alternative when                                                                                                                    |
|--------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| **Trigger framework**          | Configuration-driven registration, four-level bypass (per-object / per-action / per-flow / framework-wide) with an audit log on every bypass, automatic recursion control, a searchable record of what each trigger actually did (execution observability), reacting to record-change events (Change Data Capture, with the change header available to Flow and Apex actions), and follow-up work that runs after the transaction commits (post-trigger finalizers) | `taf` if you're already invested in it and want triggers only. KernDX covers everything `taf` does and more                                    |
| **Query builder**              | A fluent SOQL API with no string concatenation, FLS/CRUD enforced by default, an audit log on every bypass, and a subclassable builder                                                                                                                                                                                           | `apex-fluently-soql` if a standalone fluent-DSL is all you want and developer-managed access control is acceptable                              |
| **DML**                        | Transactional batching, FLS/CRUD enforced on writes by default, audited bypass, async DML, and saves related records in the right multi-level order (parents before children), catching impossible loops                                                                                                                                                                      | `apex-fluently-dml` if you prefer its record-builder relationship DSL. Both resolve multi-level graphs; the difference is API shape, not depth |
| **Inbound REST**               | A two-class routing pattern that keeps REST plumbing out of business logic, small response classes that convert themselves to and from JSON (DTO marshalling), validation hooks, and a paired test harness                                                                                                                        | No framework alternative among those compared: hand-roll the dispatcher per endpoint, or adopt KernDX                                           |
| **Outbound HTTP**              | Production callouts with retry/backoff, a circuit breaker (after repeated failures it stops calling the failing system for a cool-off, then resumes), idempotency keys (the same request arriving twice returns the first result instead of re-running), a dead-letter queue (messages that fail after all retries are set aside for inspection, not lost), named-credential resolution, and a mock library | `apex-fluently-httpmock` ties on the *mock* surface only; it ships no production callout path                                                   |
| **Logging**                    | A lean Apex/LWC/Flow logging API that writes log records in the background by default, integrated with triggers/query/DML/async                                                                                                                                                                                                   | `nebula-logger` if you need multi-transport selection, all seven platform log levels, per-record retention, or a historical log-browser UI      |
| **Testing**                    | A builder-pattern test-data factory with parent-child wiring, DML-free query mocking, and framework-object assertion helpers                                                                                                                                                                                                     | `fflib-mocks` if you need Mockito-style behaviour verification (argument matchers, verification modes); KernDX has no equivalent               |
| **Resilience / feature flags** | A feature-flag framework you can extend (custom metadata + per-user/profile settings) consumable from Apex/Flow/LWC, with pluggable resolution strategies and retry utilities                                                                                                                                             | `rflib` if you need only a simple hierarchical kill-switch and no pluggable strategies                                                          |
| **Security**                   | FLS/CRUD enforced on reads and writes by default, an org-wide kill switch, per-call bypass, and an audit entry on every bypass                                                                                                                                                                                                   | None of the frameworks compared here ship both an org-wide kill switch *and* runtime audit-on-bypass                                            |
| **Data masking**               | Runtime masking on the call path (regex + credit-card detection + literal + JSON-key), four modes, three failure actions, caller scoping, and shipped rules                                                                                                                                                                      | `mask-sobject` for *batch* anonymisation of existing data (sandbox refresh): a complementary, different job                                    |
| **LWC**                        | A component base with five built-in modules (toast / Apex controller / navigation / Lightning Message / Flow nav) and opt-in activation                                                                                                                                                                                          | No comparable alternative ships a coherent LWC component framework                                                                              |
| **Async**                      | Chained queueables with shared state across transactions, recovery work that runs after the transaction commits (finalizer recovery), a kill switch, and per-step error/completion handlers                                                                                                                                       | A focused library (`apex-fluently-async`, `apex-promisify`) if you want only the standalone chaining shape                                      |

---

## The integration trade-off

The big advantage of single-capability libraries is that each one stays out of the others' way. You can swap a standalone logger without touching your DML layer, and each library is a small surface you can review on its own. That is a real engineering virtue.

The cost of that isolation is that **your team becomes the systems integrator**. As you install more libraries side by side, three kinds of ongoing work pile up, even when each library is free:

1. **Making the libraries work together.** Lining up namespaces, settings hierarchies, a shared tracking ID across them, and coordinating who is bypassed where is your job.
   Say you combine a trigger library with a separate logger: you wire the trigger-bypass events into the logging surface yourself, because neither library ships that bridge.
2. **Security review, repeated per library.** Each library is its own thing to review. Co-install four (triggers, query, DML, logging) and every upgrade means four separate review cycles: you re-check sharing
   declarations, FLS/CRUD posture, audit behaviour, and where each dependency came from, once per library.
3. **Upgrades and maintenance, repeated per library.** Each library releases on its own schedule, so every time any one of them tags a release you pin versions, track breaking changes, and test that they all still work together.

KernDX makes the opposite trade: it gives up the ability to swap one piece out for **integration that's already done for you**. The capabilities share one namespace, one security posture, one tracking ID that follows a user action across them,
one record of every bypass, and one release cadence. The wiring you'd otherwise do is done.

Neither side is free, and the honest framing is even-handed. An integrated package concentrates dependency ownership and widens the blast radius of an upgrade. A library stack
spreads that out, but it multiplies the work of integrating and reviewing the pieces. Because KernDX is [opt-in at runtime](#one-deployment-opt-in-at-runtime), you can also split the difference:
adopt it for most capabilities and keep a specialised library where that library is the better fit.

---

## Head-to-head

Seven frameworks come up most often when teams compare against KernDX. Each entry below follows the same shape: what it is, where it wins, where KernDX diverges, how they coexist, and the
rough migration effort. The migration-complexity rating measures how much of your established code would have to change, not implementation hours, and assumes you already have a codebase rather than starting from scratch.

### vs. fflib

**The library.** `fflib` ("Apex Enterprise Patterns" / `fflib-apex-common`) is the canonical implementation of the Service / Selector / Domain / Unit-of-Work pattern in Apex (Unit of Work means you register related records and save them together: all commit or all roll back). It is the
framework that established that architectural style on the platform. Licence: BSD 3-Clause. Mature, in maintenance mode (no release in several years).

**Where it wins.** You specifically want the Application/Service factory pattern (`fflib_Application`), your team is already trained on it, and you accept hand-rolling the surfaces
it doesn't cover.

**The KernDX divergence.** `fflib` ships no trigger framework, no FLS/CRUD enforcement by default on Query/DML, no outbound HTTP framework, no data masking, no health check, no LWC
framework, and no shipped scanner or coverage gate. KernDX covers those areas with security enforced by default and audited bypass.

**Coexistence.** Strong. The two ship in separate namespaces and don't collide, so you can let `fflib_Application` supply the Service/Domain factory while KernDX handles triggers, query,
DML, outbound, async, security, and masking.

**Migration complexity: Medium–High.** Re-pointing established Domain/Service/Selector layers is real work, so most teams coexist rather than migrate the domain layer.

> **Pick:** Start fresh on KernDX. Keep `fflib` for an existing Domain layer that depends on its factory patterns: the hybrid is supported.

### vs. taf

**The library.** `taf` ("Trigger Actions Framework") is a single-capability trigger framework that uses metadata-driven registration. It scopes to triggers only. Licence: Apache 2.0.

**Where it wins.** Little over KernDX on capability. KernDX covers everything `taf` does, including Change Data Capture dispatch and post-trigger finalizers, and adds bypass
auditing, per-action performance logging, a coverage gate, fuller documentation, and the other framework areas. There are two honest cases for `taf`. First, you already run it and want triggers
only, so a migration isn't worth the churn. Second, the licence case, which is narrow: if you are an ISV reselling a paid competing framework, `taf`'s Apache 2.0 licence matters to you. (Under BSL 1.1, ordinary teams and the consultants
deploying for them keep full production-use rights, and it converts to Apache 2.0 four years after publication.)

**The KernDX divergence.** `taf` bypasses run unaudited: no log, no platform event, no signal. You cannot plug your own registration logic into it, and it ships no coverage
gate. KernDX emits an audit entry on every bypass and covers the capability areas beyond triggers. Both frameworks dispatch trigger actions on Change Data Capture events (with the
change header available to Flow and Apex actions) and run post-trigger / transaction-finalizer actions; KernDX additionally emits a bypass audit and a per-action performance log on
those paths. (Teams already fluent in `taf`'s registration style transition with low friction, because the metadata shape is similar;
see [Adoption](Strategic%20Guide%20-%20Adoption.md#migration-narratives).)

**Coexistence.** Not typical. Both occupy the trigger scope, and running two trigger dispatchers at once invites unpredictable order-of-execution and recursion conflicts. Pick
one.

**Migration complexity: Low–Medium.** The metadata-driven registration concepts map closely.

> **Pick:** KernDX. `taf` is a well-regarded focused trigger framework (KernDX's own trigger layer evolved from it), but KernDX covers everything it does and more. Keep `taf`
> only if you're already invested and want triggers alone (or for the narrow paid-competing-framework licence case), accepting unaudited bypasses on the trigger layer.

### vs. apex-libra

**The library.** `apex-libra` is a multi-capability framework covering trigger registration, DML, logging, resilience, security, testing, and utilities. Of the frameworks here, it is the closest single-package
alternative to KernDX by breadth. Licence: MIT.

**Where it wins.** Your primary need is its functional / lambda utility surface (`IFunction` / `IConsumer` / `IPredicate`), which KernDX does not ship. (A permissive licence rarely
decides the choice on its own: BSL 1.1 grants you and the consultants deploying for you full production-use rights.)

**The KernDX divergence.** `apex-libra` defaults to *system mode* on DML writes, so you override per call to enforce FLS/CRUD on writes. Its bypasses are unaudited, it ships no
recursion-suppression mechanism, and it has no inbound REST, outbound HTTP, data masking, health check, or LWC framework. KernDX defaults to user mode on reads and writes, audits
every bypass, and suppresses recursion automatically.

**Coexistence.** Possible (separate namespaces), but the overlap on triggers/query/DML/testing means most teams pick one.

**Migration complexity: Medium.** Overlapping surfaces re-point to KernDX's default-on equivalents.

> **Pick:** KernDX when secure defaults and integrated capability breadth are priorities. Adopt `apex-libra` if functional/lambda utilities are your primary need and you accept
> default-system-mode writes plus unaudited bypasses.

### vs. rflib

**The library.** `rflib` is a multi-capability framework focused on logging, trigger orchestration, feature switches, and a few utilities. Of the multi-capability alternatives here, it is the most actively maintained. Licence: BSD 3-Clause.

**Where it wins.** You want a simple hierarchical feature-switch (user → group → profile → global) with no need for pluggable strategies; or its historical log-browser LWC; or its
admin per-row declarative-bypass shape.

**The KernDX divergence.** `rflib` has no FLS/CRUD enforcement defaults, audits bypass only partially (framework- and per-user gates, not the per-handler path), and its
feature-switch is sealed against extension. It ships no inbound REST, outbound HTTP, data masking, async-chain orchestration, health check, or scanner. KernDX covers those with
default-on security and full bypass audit.

**Coexistence.** Good for the log-browser surface, since the two run in separate namespaces. (Logging is parallel, not merged: entries emitted via KernDX are not picked up by `rflib`'s
viewer.)

**Migration complexity: Low.** Most value comes from coexisting for the log-browser rather than migrating.

> **Pick:** KernDX for full coverage. Keep `rflib` when its historical log-browser or admin per-row bypass is load-bearing: they co-install cleanly.

### vs. nebula-logger

**The library.** `nebula-logger` is a single-capability logging framework, and by surface area it is the deepest dedicated Salesforce logging implementation. Licence: Apache 2.0. Long,
mature release history.

**Where it wins.** Maximum logging depth: selectable transport (event bus / queueable / REST / synchronous), all seven platform log levels, per-record and per-scenario retention
overrides, and a dedicated historical log-browser LWC. KernDX's logging is leaner (single platform-event transport, four levels, no per-record retention field, no dedicated
log-browser UI).

**The KernDX divergence.** `nebula-logger` is logging-only. It has no trigger framework, query/DML framework, web services, async orchestration, or security defaults, and its
logging is not wired into a trigger/query/DML bypass-audit or async status signal, because those don't exist outside an integrated framework.

**Coexistence.** Strong, among the cleanest hybrids available. (Logging is parallel, not merged: KernDX's own entries, including bypass-audit logs, flow through its
`LogEntryEvent__e` / `LogEntry__c` channel and are not picked up by `nebula-logger`'s store. Bridging the two is custom work.)

**Migration complexity: Low.** You co-install it as the logging backend, so there's effectively nothing to migrate.

> **Pick:** Co-install both. `nebula-logger` as your logging backend (multi-transport, retention, log-browser); KernDX for everything else: triggers, query, DML, web services,
> async, security, masking, LWC, health, CI. Separate namespaces, no collision.

### vs. the Apex Fluently libraries

**The library.** A family of eight focused single-purpose libraries ([`-soql`](https://github.com/beyond-the-cloud-dev/soql-lib), [`-dml`](https://github.com/beyond-the-cloud-dev/dml-lib), [`-cache`](https://github.com/beyond-the-cloud-dev/cache-manager), [`-async`](https://github.com/beyond-the-cloud-dev/async-lib), [`-httpmock`](https://github.com/beyond-the-cloud-dev/http-mock-lib), [`-consts`](https://github.com/beyond-the-cloud-dev/apex-consts), [`-test`](https://github.com/beyond-the-cloud-dev/test-lib), [`-lwc`](https://github.com/beyond-the-cloud-dev/lwc-utils)): a "pick what you need" collection of fluent-DSL libraries, generally actively maintained, with `-soql` and `-dml` at
the highest cadence. Licence: MIT across the family.

**Where it wins.** You want a single capability without a bundled framework footprint, or you prefer a specific library's DSL ergonomics (for example, `apex-fluently-dml`'s record-builder
relationship syntax over KernDX's call-site registration; both resolve multi-level dependency graphs). (A permissive licence
rarely decides the choice on its own: BSL 1.1 grants you and the consultants deploying for you full production-use rights.)

**The KernDX divergence.** Access control is delegated and unaudited across the family. `apex-fluently-soql`'s executor is sealed (you can't subclass to extend the builder),
`apex-fluently-dml` ships no async DML path, and `apex-fluently-httpmock` is mock-only with no production callout path. Adopt several pieces and you get no shared bypass-audit or
tracking ID across them, because the libraries don't know about each other. KernDX provides default-on FLS/CRUD, audited bypass, async DML, production callouts, and cross-capability integration.

**Coexistence.** Technically possible (separate namespaces) but usually redundant. These libraries shine adopted standalone; KernDX shines when integrated guarantees are the
requirement.

**Migration complexity: Low–Medium per library.** Each DSL surface can be swapped independently.

> **Pick:** KernDX for integrated guarantees. Adopt an individual Apex Fluently library when you need exactly one capability without a bundled framework, or you specifically prefer
> its DSL, accepting developer-managed access control on that surface. (A permissive licence rarely decides the choice on its own: BSL 1.1 grants you and the consultants deploying
> for you full production-use rights.)

### vs. fflib-mocks

**The library.** [`fflib-mocks`](https://github.com/apex-enterprise-patterns/fflib-apex-mocks) (`fflib-apex-mocks`) is the canonical Mockito-style mocking library for Apex:
behaviour-verification mocking via stubs, argument matchers, and verification modes. Licence: BSD 3-Clause. Long-established, lightly maintained now.

**Where it wins.** You need Mockito-style behaviour verification: rich argument matchers, `times`/`atLeast`/`atMost`/`between`/`never` verification modes, sequence verification,
argument capture. **KernDX has no equivalent.**

**The KernDX divergence.** KernDX's testing scope is a builder-pattern test-data factory, DML-free selector mocking, and test helpers for async / Flow / outbound / framework-object
assertions: a different and complementary surface.

**Coexistence.** Recommended, since the two are complementary.

**Migration complexity: None.** Co-install; there's nothing to replace.

> **Pick:** Adopt both side-by-side. `fflib-mocks` for Mockito-style verification; KernDX's test-data builder and selector mocks for the rest.

---

## Other specialty libraries

Beyond the seven above, these single-purpose libraries each cover one specialty surface. In most cases KernDX already covers the same ground as part of its integrated scope; the table flags the exceptions where a specialty library is still worth reaching for.

<details>
<summary>Full specialty-library comparison (14 libraries)</summary>

| Library                  | What it does                                                               | KernDX equivalent                                                                                                                   | Recommendation                                                                                                         |
|--------------------------|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| `apex-async-linkable`    | Standalone queueable-link library                                          | `UTIL_AsyncChain` adds shared state, finalizer recovery, kill switch, orchestration                                                 | Use KernDX unless you need the standalone shape                                                                        |
| `apex-chainable`         | Queueable-chaining with chain-runtime exceptions                           | `UTIL_AsyncChain` chains at greater depth                                                                                           | Use KernDX                                                                                                             |
| `apex-fluently-async`    | Single-purpose async-chain library                                         | `UTIL_AsyncChain` adds shared state, recovery, kill switch, per-step handlers                                                       | Use KernDX unless you want the focused shape                                                                           |
| `apex-fluently-cache`    | Single-class platform-cache wrapper, three storage tiers, no auto-dispatch | `UTIL_Cache` adds auto-scope dispatch (`Scope.AUTO` picks the cache tier for you)                                                   | Use KernDX                                                                                                             |
| `apex-fluently-consts`   | Constant-organisation utility                                              | Covered by KernDX utility helpers                                                                                                   | Use KernDX utilities                                                                                                   |
| `apex-fluently-dml`      | Fluent DML DSL with record-builder relationships and graph resolution      | `DML_Builder` ships the same graph algorithm plus audited bypass, async DML, and FLS/CRUD on writes by default                      | Use KernDX for general DML; consider this for its DSL shape                                                            |
| `apex-fluently-httpmock` | HTTP-callout mock library, several resolution strategies                   | `API_MockFactory` ties on mocking; KernDX adds production outbound infrastructure                                                   | Use KernDX when already on it; use this when you need only the mock surface                                            |
| `apex-fluently-lwc`      | LWC toast-helper library                                                   | `ComponentBuilder` adds four more modules                                                                                           | Use KernDX                                                                                                             |
| `apex-fluently-soql`     | Fluent SOQL DSL                                                            | `QRY_Builder` adds audited bypass, FLS/CRUD by default, and a wider feature set; both default to user-mode reads                    | Use KernDX for general queries; consider this for the standalone DSL if developer-managed access control is acceptable |
| `apex-fluently-test`     | Focused test-data builder                                                  | `TST_Builder` adds parent-child wiring and cyclic overrides; the broader family adds selector mocks and async/Flow/outbound helpers | Use KernDX                                                                                                             |
| `apex-promisify`         | Promise-style API for queueables                                           | `UTIL_AsyncChain` adds shared state, recovery, kill switch                                                                          | Use KernDX unless the Promise-style API is the requirement                                                             |
| `mask-sobject`           | Batch anonymisation of existing org data                                   | `UTIL_FrameworkMasker` does runtime masking on the call path; batch scrub is the differentiator                                     | Use KernDX for runtime masking; use this for batch sandbox scrub (complementary)                                       |
| `nebula-triggers`        | Single-class metadata-driven trigger dispatcher                            | KernDX trigger framework adds recursion control, four-level audited bypass, observability                                           | Use KernDX                                                                                                             |
| `promise`                | Promise-style queueable chaining, no shared state                          | `UTIL_AsyncChain` adds shared state, recovery, kill switch                                                                          | Use KernDX                                                                                                             |

</details>

---

## Organisational fit

Capability fit is only half the decision. Organisational fit is the other half. The questions here are about your team and your constraints, not your code.

**KernDX fits well when:**

- **Greenfield or standardisation.** You're starting fresh, or standardising a codebase that lacks a consistent framework.
- **Governance by default.** Security governance is a priority and you want it enforced automatically rather than left to each developer's discipline.
- **Unified maintenance.** You want one integrated toolset with a single review surface and one upgrade cadence.
- **Lean platform teams.** When no dedicated architecture team is enforcing conventions in review, having governance on by default does *more* work for you, not less. A small
  team is a reason *for* built-in governance, not against it.

**Prefer specialised libraries when:**

- **Existing investment.** You have deep existing investment in one (for example, established `fflib` domains) and no reason to move it.
- **OSI-at-install procurement.** Strict procurement requires an OSI-approved licence at install time (KernDX is BSL 1.1 until its Apache 2.0 conversion).
- **Single narrow need.** You need exactly one narrow capability and nothing else.
- **Mature in-house standards.** You already operate mature internal patterns and governance controls and want to add a single focused library to fill one gap.

These are not mutually exclusive. Because KernDX is opt-in at runtime, a team can adopt it for the capabilities it wants and keep a specialised library where that library is the
better fit. See the per-framework coexistence notes above.

**Support posture.** KernDX support is issue-based: bug reports and questions go through GitHub issues, with no formal SLA. Hands-on help, direct source delivery, and
handover are available through consulting engagements. [Risks](Strategic%20Guide%20-%20Risks.md) and [Operations](Strategic%20Guide%20-%20Operations.md) cover the support and
survivability model in full.

---

## Spotted something wrong?

This guide is written by the KernDX team, and frameworks change. If you maintain or use one of the frameworks here and believe an assessment is inaccurate (a misread feature, a
detail that's changed since this was written, or a recommendation that doesn't match the current source),
please [open a GitHub issue](https://github.com/JVB-Consulting/kerndx/issues/new/choose). We'll re-check against the current source, correct the guide, and credit you in the
changelog.

---

[< Risks](Strategic%20Guide%20-%20Risks.md) | [Overview >](Strategic%20Guide%20-%20Overview.md)
