---
navOrder: 12
---

# Strategic Guide — Architecture & Philosophy

> KernDX's design thesis, capabilities, Salesforce Well-Architected alignment, and open-source readiness.

Part of the [KernDX Strategic Guide](Strategic%20Guide%20-%20Overview.md).
See
also: [Adoption](Strategic%20Guide%20-%20Adoption.md) | [Operations](Strategic%20Guide%20-%20Operations.md) | [Risks](Strategic%20Guide%20-%20Risks.md) | [Glossary](Strategic%20Guide%20-%20Glossary.md) | [Personas](Strategic%20Guide%20-%20Personas.md)

---

<details><summary>Table of Contents</summary>

- [Design Thesis](#design-thesis)
- [Philosophy & Design Principles](#philosophy--design-principles)
    - [Configuration over Code](#configuration-over-code)
    - [Accelerator, not a Product](#accelerator-not-a-product)
    - [Integrated Stack](#integrated-stack)
    - [100% Coverage or Nothing](#100-coverage-or-nothing)
    - [AI-First Documentation](#ai-first-documentation)
    - [Trade-offs](#trade-offs)
    - [Modular in Practice](#modular-in-practice)
    - [Designed for the Subscriber](#designed-for-the-subscriber)
    - [Managed Package vs Source Distribution](#managed-package-vs-source-distribution)
- [Capabilities at a Glance](#capabilities-at-a-glance)
    - [Module Inventory](#module-inventory)
    - [Code Examples at a Glance](#code-examples-at-a-glance)
    - [Custom Metadata Topology](#custom-metadata-topology)
    - [Quantitative Summary](#quantitative-summary)
    - [Documentation Architecture](#documentation-architecture)
- [Salesforce Well-Architected Alignment](#salesforce-well-architected-alignment)
    - [Alignment Scorecard](#alignment-scorecard)
    - [Three Pillars: Detailed Analysis](#three-pillars-detailed-analysis)
    - [Framework Scope Clarification](#framework-scope-clarification)
    - [Well-Architected Risks and Considerations](#well-architected-risks-and-considerations)
    - [Well-Architected Decision Matrix](#well-architected-decision-matrix)
    - [Well-Architected Summary Scorecard](#well-architected-summary-scorecard)
    - [Well-Architected Quick Reference](#well-architected-quick-reference)
- [Security Benchmark for Salesforce Alignment](#security-benchmark-for-salesforce-alignment)
    - [SBS Alignment Scorecard](#sbs-alignment-scorecard)
    - [Where KernDX Provides a Mechanism](#where-kerndx-provides-a-mechanism)
    - [What Remains Yours](#what-remains-yours)
    - [SBS Summary Scorecard](#sbs-summary-scorecard)
- [Open-Source Readiness](#open-source-readiness)
    - [Current State](#current-state)
    - [Adoption Signal Profile](#adoption-signal-profile)
    - [Comparison with Other Frameworks' Open-Source Journeys](#comparison-with-other-frameworks-open-source-journeys)
    - [Bus Factor Mitigation](#bus-factor-mitigation)
    - [Licensing Considerations](#licensing-considerations)
    - [Community Building Strategy](#community-building-strategy)
    - [Open-Source Trade-offs](#open-source-trade-offs)

</details>

## Design Thesis

KernDX exists because most enterprise Salesforce orgs eventually build versions of these patterns themselves — over three to five years, accumulating tech debt at every layer (selectors, triggers, logging, web services, async, masking, FLS enforcement). KernDX is what those teams would build *if they had the budget and the cross-cutting design discipline
upfront*. Subscribers skip the accumulation cycle.

Five design choices flow from that thesis:

1. **Every feature ships for immediate value.** Capabilities are scoped to what most subscribers will actually use. `TST_Mock` query interception solves the day-one subscriber-test
   pain (DML-free testing without SOQL side effects) — KernDX deliberately omits a Mockito-style stub-and-verify DSL because the small population of Apex developers who already
   know that pattern do not justify the API surface for everyone else. Per-SObject masking opt-in is performance-aware: most subscribers do not push credit-card data through every
   log emit, and a default-on regex tax across every log entry is paid by every subscriber regardless.
2. **Easy to understand.** The framework uses a consistent fluent-builder pattern across every major surface. `TST_Builder`, `QRY_Builder`, `DML_Builder`, `LOG_Builder`,
   `UTIL_HttpClient`, and the rest follow the same chainable-build → terminal-execute shape — discoverable through IDE auto-complete, productive on day one. Learning one means
   learning the others.
3. **Solves what 95%+ of subscribers will use.** KernDX ships production-ready implementations of every core Salesforce capability — every core capability a Salesforce org needs is
   shipped, documented, and usable from day one, not just stubbed or aspirational. This is broader than other Apex frameworks the team has surveyed. The long tail of niche
   capabilities is deliberately not shipped.
4. **Integration is a feature, not an accident.** `TRG_Base`, `SEL_Base`, `DML_Builder`, `LOG_Builder`, `ComponentBuilder`, `API_Inbound`, and `API_Outbound` cooperate through
   shared context. Cross-module guarantees — FLS/CRUD enforced by default on read AND write, correlation IDs propagating from trigger through query through outbound HTTP, masking
   applied before persistence on every framework persistence path, every bypass writes an audit log at the trigger surface — are *only* possible because subscribers adopt the
   framework families together. A drop-in library cannot make those guarantees.
5. **Shortcut to enterprise tech-debt avoidance.** Adopting KernDX is a budget-and-time arbitrage: pay for the integration once, get the cross-cutting framework guarantees, skip
   three to five years of internal-platform-team rebuild cost.

**The cost of cohesion is the value.** Subscribers extend `TRG_Base` / `SEL_Base` / `DML_Builder` / `LOG_Builder` / `ComponentBuilder` / `API_Inbound` / `API_Outbound` to use the
corresponding capability families — that is the deliberate cohesion trade-off the framework exists to deliver, not a deficiency. Drop-in libraries make no cross-module guarantees;
that is what they trade away.

## Philosophy & Design Principles

The thesis above informs six architectural principles that distinguish KernDX from both single-vendor monolithic frameworks and modular library assembly.

### Configuration over Code

Every recurring architectural decision in KernDX is driven by custom metadata rather than hardcoded logic:

| Concern           | Metadata Type                                      | What It Controls                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
|-------------------|----------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Trigger execution | `TriggerAction__mdt` + `TriggerSetting__mdt`       | Handler registration, ordering, bypass, entry criteria (metadata-driven registration with per-event action records)                                                                                                                                                                                                                                                                                                                                                                           |
| Validation rules  | `ValidationRule__mdt` + `ValidationRuleGroup__mdt` | Formula-based validation with shadow mode                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Feature flags     | `FeatureFlag__mdt` + `FeatureFlagStrategy__mdt`    | Runtime feature toggles with extensible resolution strategies (mixed custom-metadata + hierarchy custom-setting storage; Apex, Flow, and LWC consumers)                                                                                                                                                                                                                                                                                                                                       |
| Web services      | `ApiSetting__mdt` + `ApiCredential__mdt`           | Endpoint configuration, retry, circuit breaker                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Mock responses    | `ApiMock__mdt`                                     | Mock-response resolution with fault simulation                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Logging           | `LogSetting__c`                                    | Log level thresholds, performance thresholds                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Data masking      | `MaskingRule__mdt` + `MaskingTarget__mdt`          | Runtime field redaction for any SObject or platform event before the record is persisted. Four masking modes (regex, JSON-key, exact-match, credit-card with Luhn validation) plus 18 built-in masking rules. Default ship set wires three active rules to four package objects through twelve `MaskingTarget__mdt` records; admins extend coverage to their own objects by adding more `MaskingTarget__mdt` records. Rules can be scoped via `MinInputLength__c` and `ApplicableFieldTypes__c`. |

Admins can reorder trigger handlers, toggle features, adjust retry strategies, and enable debug logging — all without code deployment.

### Accelerator, not a Product

KernDX is consultant-owned IP, not a SaaS product:

- **Zero licensing fees** — no recurring costs, no per-user pricing
- **Source publicly available under BSL 1.1** — the framework source is hosted on the public project repository, relicenses to Apache 2.0 after a four-year change date, and is
  delivered as part of every consulting engagement
- **Three exit paths:** continue managed package, deploy as source from the public repository, or repackage under client namespace
- **No vendor lock-in** — standard Apex patterns (selectors, triggers, DTOs, builders) that any experienced developer already understands

KernDX is designed to be adopted and then owned.

**Structural cost differences (qualitative — no specific dollar comparison):**

This guide does not publish a per-product dollar comparison against AppExchange alternatives because AppExchange pricing varies widely by product, org size, contract terms, and
negotiated discounts — any specific figure would be illustrative at best and misleading at worst. The structural differences that *do* hold across AppExchange product comparisons:

- **Recurring licensing.** AppExchange products typically carry recurring per-org, per-user, or per-transaction licensing fees. KernDX has zero recurring license fees during the
  BSL 1.1 period and relicenses to Apache 2.0 after the four-year change date.
- **Exit cost.** AppExchange products typically incur high exit cost: vendor lock-in, contractual end-of-term terms, data-migration effort, custom-code rewrite to switch vendors.
  KernDX exit cost is zero in licensing terms — the source is publicly available under BSL 1.1, so the subscriber can continue using it independently of any vendor relationship;
  consulting engagements include direct source delivery and handover support but are not a precondition for source access.
- **Customisation ceiling.** AppExchange product customisation is bounded by the vendor's extension points and what the managed package exposes. KernDX customisation is bounded
  only by what the subscriber chooses to modify after source-ownership transfer.

For a specific dollar comparison, run the cost numbers against the AppExchange product you are evaluating using your team's own implementation effort estimates; this guide cannot
do that comparison on your behalf.

### Integrated Stack

The Salesforce ecosystem offers two viable full-stack approaches: **modular assembly** (mix of single-capability libraries) and **integrated frameworks** (KernDX). Both cover the
same concerns. The difference is what happens *between* the components.

**What integration provides automatically (and what it costs):**

When a trigger action fails in KernDX, `LOG_Builder` automatically captures the error with trigger context, the correlation ID from the originating request, and performance timing.
If that trigger action calls an API via `UTIL_HttpClient`, the correlation ID propagates to the outbound request header. If a query runs during that same transaction, `QRY_Builder`
logs slow queries against the same correlation. If the entire feature needs to be disabled, a single `FeatureFlag__mdt` record prevents the trigger action from executing — which
means the API call and queries never fire either.

When an async chain needs to call external APIs, `UTIL_AsyncChain.ApiStep` wraps any existing `API_Outbound` handler as a chain step with zero changes to the handler. The handler's
full lifecycle — validation, callout, retry, circuit breaker, response parsing, DML, queue persistence — runs within the chain's Queueable transaction, with results flowing into a
shared context for downstream steps (shared state passes between async transactions; finalizer hooks; emergency kill switch). In a modular stack, connecting an async chain library
to an HTTP client library would require custom adapter code at every integration point.

In a modular stack, these integrations require explicit instrumentation at each boundary. However, this automatic coherence requires all code to flow through the framework —
increasing coupling to a single vendor's conventions and release cycle. Coherence is best understood as an entropy management mechanism (see [Operational Entropy and Maintainability in Multi-Team Environments](Strategic%20Guide%20-%20Adoption.md#operational-entropy-and-maintainability-in-multi-team-environments)),
not an inherent quality advantage.

| Concern                              | Modular Stack (5+ Libraries)                                                                                                      | KernDX                                                                                                                                                                                | KernDX Trade-Off                                                 |
|--------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| **Error propagation**                | Trigger exception → manually call a logger with context you assemble yourself                                                     | Automatic — trigger context, correlation ID, timing captured without developer code                                                                                                   | Opaque internals; harder to debug framework-internal behaviour   |
| **Log correlation**                  | Each library logs independently; no cross-layer correlation ID                                                                    | Correlation ID propagates: trigger → query → API → async job                                                                                                                          | Requires all code to flow through framework                      |
| **Mocking**                          | Separate mock systems for SOQL, DML, HTTP, and test setup                                                                         | Unified `TST_Mock` + `QRY_Builder.setMock()` + `API_MockFactory` — one pattern                                                                                                        | Framework-specific mock APIs; not transferable to other projects |
| **Feature flags**                    | Flag the trigger action manually; also manually disable the related query, API call, and logging                                  | `UTIL_FeatureFlag` integrates with the trigger dispatcher — one flag disables the entire feature path                                                                                 | Tight coupling between feature flags and framework internals     |
| **Security**                         | Each library handles CRUD/FLS independently; no single enforcement point                                                          | `QRY_Builder` and `DML_Builder` enforce FLS/CRUD by default on read AND write paths; per-call bypass is auditable; metadata kill-switches revert to system-mode without a code deploy | Single security implementation; defect affects all layers        |
| **Conventions**                      | Multiple API philosophies across libraries with different naming and method styles                                                | One prefix system (`QRY_*`, `TRG_*`, `API_*`, `SEL_*`, etc.) with consistent naming across all layers                                                                                 | Higher coupling to single vendor's conventions                   |
| **AI context**                       | Separate README files per library; no unified instruction file                                                                    | One `docs/Code Conventions - Guide.md` (~12K tokens) covering all modules with conventions, patterns, and anti-patterns                                                               | Single point of failure for AI context accuracy                  |
| **Async → API bridge**               | Write custom adapter to wire async chain library to HTTP client; manage serialization, error mapping, result propagation manually | `ApiStep` wraps any `API_Outbound` handler as a chain step — zero glue code, full lifecycle preserved                                                                                 | Only possible because both frameworks are in the same package    |
| **Cross-boundary error propagation** | Logger captures whatever context the developer manually provides                                                                  | Trigger context, API request/response, correlation ID, and stack trace captured in a single structured log entry                                                                      | Diagnostic detail dependent on framework version                 |

**The trade-off:** KernDX installs all 363 classes as a managed package, but unused code is genuinely inert — it does not count against the 6 MB Apex code limit, does not appear in
subscriber PMD scans or coverage reports, and consumes zero governor limits when not called. The modular stack gives control over what is *installed*, but in a managed package
context this distinction is less significant than it appears. The real difference is convention coupling: KernDX requires all code to flow through one vendor's patterns, while
modular stacks allow mixing approaches — at the cost of coherence discipline. Neither approach is categorically better — it depends on whether coherence or flexibility matters more
to your team.

**Worked example — Adding a new integration:**

| Step                                                                               | Modular Stack                                                                                                         | KernDX                                                                        |
|------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| 1. Build HTTP callout                                                              | Write custom `HttpCalloutMock`, `HttpRequest` builder                                                                 | Extend `API_Outbound`, set `defaultMockBody`                                  |
| 2. Add retry logic                                                                 | Find/write retry utility, configure per-callout                                                                       | `.withRetry(3).withExponentialBackoff()` on `UTIL_HttpClient`                 |
| 3. Add circuit breaker                                                             | Find/write circuit breaker, wire to callout                                                                           | `.withCircuitBreaker()` — already integrated                                  |
| 4. Add logging                                                                     | Instrument with logger calls at each layer                                                                            | Automatic — framework logs request/response with correlation                  |
| 5. Add monitoring                                                                  | Build custom dashboard                                                                                                | Configure `LogSetting__c` threshold                                           |
| 6. Add test                                                                        | Write `HttpCalloutMock` implementation per library                                                                    | `API_MockFactory.forService('MyAPI').body('{}').register()`                   |
| 7. Add feature flag                                                                | Write custom feature check, wire to each layer                                                                        | `FeatureFlag__mdt` record — automatic trigger action integration              |
| 8. Add to async chain                                                              | Write custom adapter to bridge async library and HTTP client; manage serialization, error mapping, result propagation | `.then(new UTIL_AsyncChain.ApiStep(API_MyService.class))` — zero adapter code |
| **Total effort (illustrative — measure against your team's actual delivery data)** | **Several days per new integration**                                                                                  | **Half a day to one day per new integration**                                 |

The specific day-counts above are illustrative — this guide does not measure per-step development time across stacks because that varies heavily with team experience, codebase
context, and the specific integration. The structural difference *is* load-bearing: a modular stack offers more control per step at the cost of writing the integration glue, while
KernDX offers faster delivery via configuration at the cost of all code flowing through the framework. For 10+ integrations the cumulative difference becomes material; subscribers
should measure step time against their own delivery data. Step 8 is particularly telling: in a modular stack, connecting an async chain library to an HTTP client library requires
custom adapter code per integration; in KernDX, the two frameworks already know about each other.

**Integration burden — amortized across capabilities.** KernDX bundles the 17 framework areas into one managed package with one namespace, one upgrade cadence, one security-review
surface, and one bypass-audit signal. Subscribers picking individual open-source libraries to assemble equivalent coverage accept three carrying costs that the bundled framework
amortizes: operational integration cost (configuring multiple libraries to coexist — namespace alignment, settings hierarchies, cross-library bypass coordination), security-review
carrying cost (each library is its own review surface per upgrade), and upgrade / maintenance carrying cost (independent release cadences across the library set). Because every
capability ships against the same shared framework infrastructure (trigger surface, logging, masking, bypass-audit signal), subscribers pay the integration cost once at framework
adoption rather than per library for each capability added. The Category considerations — integration burden analysis section lays out the category-level framing; this section
explains the architectural choice that makes the amortization possible.

### 100% Coverage or Nothing

KernDX enforces 100% per-file Apex coverage on every production class and 95% statement/branch coverage on every LWC. This is not a quality badge — it is a managed package
requirement.

Salesforce requires 75% coverage for production deployment and managed package upload. KernDX targets 100% because:

- **Managed packages cannot be patched** — a bug in a released version requires a push upgrade to every subscriber org. Coverage gaps become production risks.
- **Agent-driven modification requires test verification** — AI coding assistants validate changes via unit tests. Gaps in coverage mean gaps in AI safety.
- **Coverage discipline prevents test debt** — the difference between 95% and 100% is usually the error handling and edge cases that cause production incidents.

KernDX is the only Apex framework surveyed with a coverage gate enforced at every build (`coverage_gate_present = true`; `scripts/evaluate-coverage.js` enforces 100% Apex
per-file + 95% LWC statements + 95% LWC branches + ≥ committed baseline). Other comparators report coverage but do not gate on it.

### AI-First Documentation

KernDX maintains three AI context files, each with a distinct purpose:

| File                                                    | Tokens | Location  | Purpose                                                                                                                                                  |
|---------------------------------------------------------|--------|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `AGENTS.md`                                             | ~3K    | repo root | Tool-neutral entry point for AI coding assistants — points to the canonical conventions doc (recognised by Claude Code, Cursor, Cline, Agentforce Vibes) |
| `docs/Code Conventions - Guide.md`                      | ~12K   | `docs/`   | Canonical framework conventions, code patterns, critical rules for AI code generation                                                                    |
| [`AI Agent Instructions`](AI%20Agent%20Instructions.md) | ~10K   | `docs/`   | Complete per-module framework reference for deep AI-assisted development — architecture, module inventory, conventions, worked examples                  |

These files are not documentation afterthoughts — they are engineering artifacts that enable AI coding tools (Claude Code, Cursor, Cline, Agentforce Vibes) to generate
convention-compliant code from day one.

**Impact:** Standardised AI context files reduce ambiguity for AI code generation, improving convention compliance from the first interaction.

### Trade-offs

KernDX is not the right choice for every situation:

| Trade-off                                                       | Context                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|-----------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Single primary developer**                                    | Bus factor of 1. Mitigated by source ownership, the full documentation stack (see [Documentation Architecture](#documentation-architecture)), standard Apex patterns, and AI context files. Single-maintainer concentration is the norm across the comparable Apex frameworks surveyed — see [Bus Factor Mitigation](#bus-factor-mitigation) for the per-framework picture.                                                                                                                                                                                                                                                                                                                                                                                                              |
| **No public community yet**                                     | Cannot search Stack Overflow for KernDX errors. Mitigated by 26 developer documents (14 guides, 12 fast starts), 263 API references, and AI context.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **v1.0 — newly released, short public adoption history**        | First validated build packaged; testing-hardened (100% per-file Apex coverage gate, 95% LWC, 471 anon-Apex assertions in the subscriber e2e harness); publicly released under BSL 1.1 and promoted for production install, with one known external client engagement in active use at the snapshot date and public adoption still early. See [Adoption Signal Profile](#adoption-signal-profile) for what grows this track record, and [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for the current build identifier.                                                                                                                                                                                                                             |
| **Full package deployment**                                     | Managed package installs all 363 classes. Unused code is genuinely inert — exempt from 6 MB limit, invisible to subscriber PMD/coverage, zero governor impact. The cost is namespace prefix on references and a single (larger) upgrade cycle, not deployed footprint.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **Namespace verbosity**                                         | Subscriber code requires namespace prefix. Modern IDEs auto-complete this.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **No pre-built log browser**                                    | [`nebula-logger`](https://github.com/jongpie/NebulaLogger) ships a dedicated historical log browser (mixed transport, seven log levels, historical browser, retention purge). KernDX provides real-time log monitoring via Streaming Event Monitor and persists logs to `LogEntry__c` for subscriber-built reports and dashboards. KernDX also ships operational UI components (Chain Monitor, Streaming Event Monitor, API Test Harness, Health Check, Org Limits) but no dedicated log search/browse interface. **This is the one substantive UI surface where a comparator covers more aspects than KernDX.**                                                                                                                                                                         |
| **Deliberate non-goal: Domain / Service / Application pattern** | [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) ships the canonical Domain / Service / Application factory pattern (four factory inner classes — UnitOfWorkFactory, ServiceFactory, SelectorFactory, DomainFactory — each with a dedicated interface contract). KernDX does not ship a Domain class hierarchy. `DML_Builder` surfaces the transactional Unit-of-Work aspect (parent-child chaining, partial success, async DML) but KernDX deliberately omits service factory and Application factory patterns. Teams whose architecture requires the Service / Application factory with type-bound Selector / Domain / Unit-of-Work should install `fflib` alongside KernDX (the two coexist — `fflib` for domain modelling, KernDX for infrastructure).       |
| **Deliberate non-goal: Mockito-style mock DSL**                 | [`fflib-mocks`](https://github.com/apex-enterprise-patterns/fflib-apex-mocks) ships Mockito-style stub-and-verify (98 argument-matcher factories, verification modes `times/atLeast/atMost/between/never`, sequence verification). KernDX is absent by design on this aspect. KernDX's `TST_Mock.of(SObjectType).withOverride(field, value).build()` solves the day-one subscriber-test pain — DML-free testing without SOQL side effects — with zero learning curve. KernDX explicitly chose against shipping Mockito because the learning curve does not pay off for the small population of Apex developers who would use it, and an unused-but-shipping API surface is a maintenance liability. Teams already invested in Mockito-style mocking ship `fflib-mocks` alongside KernDX. |
| **Framework-internal system-mode selectors**                    | `QRY_Builder` and `DML_Builder` enforce FLS/CRUD by default. About three-quarters of the 44 selector classes opt back into system-mode via a documented per-selector hook (e.g., configuration reads, Chain Monitor aggregates). The opt-out is auditable in source, enforced by a CI-blocking scanner rule, and rollback-safe via metadata kill-switches. Subscribers who extend `SEL_Base` inherit FLS-enforced reads by default; opting out requires an explicit override.                                                                                                                                                                                                                                                                                                            |
| **Per-builder bypass audit emission is roadmap, not shipped**   | Every `TRG_Base.bypass*()` mutation writes an audit log. KernDX is one of two frameworks (alongside [`rflib`](https://github.com/j-fischer/rflib)) shipping built-in trigger bypass-audit emission (`bypass_audit_signal = event`). The per-builder toggles (`QRY_Builder.withSystemMode()`, `DML_Builder.bypassSharing()`, etc.) are calls subscribers write themselves in source — auditable via git + code review + source-grep, but do not yet emit runtime audit signals. Closing this gap (extending audit emission to the per-builder layer) is on the post-1.0 work plan.                                                                                                                                                                                                        |

### Modular in Practice

A common misconception is that adopting KernDX means "learning the whole framework" upfront. In practice, KernDX modules can be adopted individually, just like individual libraries
in a modular stack:

| Feature                  | Core Class            | Time to First Use       | What You Learn                                               |
|--------------------------|-----------------------|-------------------------|--------------------------------------------------------------|
| Test Data                | `TST_Builder`         | ~30 minutes             | `.of(SObjectType).build()` — one line of code                |
| Feature Flags            | `UTIL_FeatureFlag`    | ~25 minutes             | Metadata-driven runtime toggles via `isEnabled('Flag')`      |
| Caching                  | `UTIL_Cache`          | ~10 minutes             | `.put()`, `.get()`, `.contains()` — standard cache API       |
| Data Masking             | `MaskingRule__mdt`    | ~15 minutes             | Configure masking metadata; scan in the Data Masking Advisor |
| Query Builder            | `QRY_Builder`         | ~30 minutes             | Fluent query syntax, replaces inline SOQL                    |
| Transactional DML        | `DML_Builder`         | ~30 minutes             | Transactional DML with parent-child chaining                 |
| Logging                  | `LOG_Builder`         | ~30 minutes             | `.build().error(e).emitAt('Class.method')` — one line        |
| Validation               | `UTIL_ValidationRule` | ~25 minutes             | Formula-driven validation configured as ordered metadata     |
| Selectors                | `SEL_Base`            | ~30 minutes             | Extend `SEL_Base`, define `getFields()`, inherited methods   |
| Trigger Actions          | `TRG_Dispatcher`      | ~20 minutes             | Metadata-driven trigger actions, bypass patterns             |
| Outbound APIs            | `API_Outbound`        | ~30 minutes             | Outbound web service with mock, retry, circuit breaker       |
| Inbound APIs             | `API_Inbound`         | ~30 minutes             | Inbound REST routing with router/handler separation          |
| Async Chains             | `UTIL_AsyncChain`     | ~25 minutes             | Multi-step async chains with shared context and recovery     |
| Lightning Web Components | `ComponentBuilder`    | ~30 minutes             | Composable LWC modules instead of raw `LightningElement`     |
| Full framework           | —                     | Adopt incrementally     | All modules, each building on the previous                   |

Comparisons that measure total framework size against individual library size assume a developer learning *everything at once* — which no one does with modular stacks either. A
developer adopting a five-library modular stack also spends 1-2 weeks learning that many APIs with that many different conventions.

**The real comparison is per-module learning time, not total framework size.**

### Designed for the Subscriber

Most open-source Salesforce libraries are shared by developers in their own style — the code works, but it wasn't designed with the installer's experience in mind. KernDX takes a
different approach:

| Aspect                   | KernDX                                                                                                                       | Typical Open-Source Library                             |
|--------------------------|------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| **ApexDoc coverage**     | Every class and method carries ApexDoc; PMD's `ApexDoc` rule is in the framework's own ruleset and gates every release build | Varies — often minimal or absent                        |
| **PMD compliance**       | Full — zero violations                                                                                                       | Varies — often has violations that transfer to your org |
| **Documentation layers** | 5 tiers: README → Start Here → Fast Starts → Guides → API Reference                                                          | Usually 1: README                                       |
| **AI discoverability**   | `AGENTS.md` (tool-neutral pointer) + `docs/Code Conventions - Guide.md` (canonical conventions, patterns, anti-patterns)     | No AI context file                                      |
| **Naming conventions**   | Consistent prefixes (`QRY_*`, `SEL_*`, `TRG_*`, etc.)                                                                        | Library-specific, no cross-library convention           |
| **Code examples**        | Every guide includes copy-paste-ready examples following framework patterns                                                  | Varies                                                  |
| **Onboarding path**      | Structured: "I want to build X" → Fast Start → Guide → Reference                                                             | Self-directed: read the README                          |

When a new developer joins a team using KernDX, the path from "I've never seen this" to "I built my first trigger action" is documented. DORA research (2022) found that
high-quality documentation dramatically amplifies the performance lift of technical practices —
see [Build vs Buy: Cost Considerations](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) for the qualitative cost framing this implies.

**Why this matters for subscriber orgs:** Source-distributed libraries without ApexDoc or with PMD violations become part of the subscriber's code analysis from day one. Every PMD
violation in imported source becomes a violation in *your* org's analysis. A managed package encapsulates its code — it does not appear in the subscriber's code analysis.

### Managed Package vs Source Distribution

| Factor                             | Managed Package (KernDX)                                                                                                                                                                                                                                                                            | Source Distribution (open-source libraries)                                                                                                                                                       |
|------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Installation**                   | 1 package URL                                                                                                                                                                                                                                                                                       | Multiple separate installs (varies by stack)                                                                                                                                                      |
| **Upgrades**                       | 1 push upgrade                                                                                                                                                                                                                                                                                      | Multiple independent upgrade cycles                                                                                                                                                               |
| **Version compatibility**          | Internally tested (one package)                                                                                                                                                                                                                                                                     | Self-managed across multiple release cycles                                                                                                                                                       |
| **Org code limit impact**          | Exempt from 6 MB org limit                                                                                                                                                                                                                                                                          | Counts against 6 MB org limit                                                                                                                                                                     |
| **Code quality in subscriber org** | 100% per-file Apex coverage, ApexDoc on every class and method, PMD-clean — but encapsulated                                                                                                                                                                                                        | Source visible; quality varies per library                                                                                                                                                        |
| **AI context**                     | 1 set of conventions (`AGENTS.md` + `docs/Code Conventions - Guide.md`) covering all modules                                                                                                                                                                                                        | Separate README files per library (no unified AI context)                                                                                                                                         |
| **Conventions**                    | 1 naming system (`QRY_*`, `TRG_*`, `SEL_*`, etc.)                                                                                                                                                                                                                                                   | Multiple different APIs and naming patterns                                                                                                                                                       |
| **Documentation**                  | 26 developer documents (14 guides, 12 fast starts) and 263 API references, all published as a searchable documentation site                                                                                                                                                                                                                              | Per-library documentation sites                                                                                                                                                                   |
| **Customisability**                | Cannot modify managed package source directly while running the managed install; source is publicly available under BSL 1.1 and can be cloned, modified, and repackaged under the subscriber's own namespace                                                                                        | Full source access — modify anything                                                                                                                                                              |
| **Namespace**                      | Subscriber code uses namespace prefix                                                                                                                                                                                                                                                               | No namespace required                                                                                                                                                                             |
| **Community governance**           | Vendor-controlled roadmap                                                                                                                                                                                                                                                                           | Community-controlled roadmap                                                                                                                                                                      |
| **Subscriber deployment impact**   | Near zero. The framework's tests do not run during subscriber deployments (managed package tests are isolated unless `RunAllTestsInOrg` is forced). Installing or upgrading a 2GP is comparable to heavy managed packages already standard in enterprise pipelines (Financial Services Cloud, CPQ). | Framework tests run alongside subscriber code on every deployment, inflating CI/CD windows. Adding 100+ framework test classes to a subscriber's `RunLocalTests` scope compounds with org growth. |

**The trade-off:** Managed packages provide consistency, encapsulation, and simplified operations at the cost of customisability. Source distribution provides maximum flexibility
at the cost of maintenance burden, code quality variability, and operational complexity. KernDX mitigates the customisability concern with publicly available source under BSL 1.1 —
if you need to modify the framework, you can clone the public repository, modify per the licence, and repackage under your own namespace.

---

## Capabilities at a Glance

### Module Inventory

| Module                  | Classes | Purpose                                                                                                                                                                                                                                                                                                                    | Key Class                                                              |
|-------------------------|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| **Query Framework**     | 7       | Fluent SOQL builder with caching, pagination, mocking (extensive query API; no string concatenation needed)                                                                                                                                                                                                                | `QRY_Builder`                                                          |
| **Selector Framework**  | 44      | Object-specific query layer with default fields (selector pattern in the Query Builder family — typed subselects, semi-join + anti-join builder methods, unbounded subselect chain depth)                                                                                                                                  | `SEL_Base`                                                             |
| **DML Framework**       | 3       | Transactional DML with parent-child chaining and partial-success control — a lightweight Unit of Work surface (transactional batching across multiple operations; all five DML operations). See [Trade-offs → Deliberate non-goals](#trade-offs) for why KernDX does not ship the full Domain/Service/Application pattern. | `DML_Builder`                                                          |
| **Trigger Framework**   | 4       | Metadata-driven trigger dispatch with per-event action records and four-level bypass                                                                                                                                                                                                                                       | `TRG_Dispatcher`, `TRG_Base`                                           |
| **Web Services**        | 10+     | Inbound REST routing with two-class separation (sole framework covering this surface) plus outbound HTTP with retry, circuit breaker, queue                                                                                                                                                                                | `API_Outbound`, `API_Inbound`                                          |
| **Validation**          | 3       | Formula-driven declarative validation (code-driven validation framework where Apex-evaluated rules are configured as custom metadata and grouped for ordered execution)                                                                                                                                                    | `UTIL_ValidationRule`                                                  |
| **Feature Flags**       | 3       | Pluggable evaluation strategies (only Apex framework surveyed shipping a subscriber-pluggable resolution strategy)                                                                                                                                                                                                         | `UTIL_FeatureFlag`                                                     |
| **Logging**             | 6       | Async structured logging via platform events, with a live event/streaming monitor and org-usage metrics console                                                                                                                                                                                                            | `LOG_Builder`, `CTRL_EventMonitor`                                     |
| **Test Infrastructure** | 5       | Builders, factories, mocks                                                                                                                                                                                                                                                                                                 | `TST_Builder`, `TST_Mock`                                              |
| **Resilience**          | 3       | Circuit breaker, retry, cache                                                                                                                                                                                                                                                                                              | `UTIL_CircuitBreaker`, `UTIL_Retry`, `UTIL_Cache`                      |
| **Security**            | 2       | FLS/CRUD enforced by default on reads AND writes; encryption default-on; sharing control                                                                                                                                                                                                            | `QRY_Builder`, `DML_Builder`, `UTIL_SessionEncryption`                 |
| **Data Masking**        | 5       | Write-time field redaction via the trigger dispatcher (on by default), plus the Data Masking Advisor console for scanning, deployable configuration, and a regulated-field inventory                                                                                                                        | `UTIL_FrameworkMasker`, `CTRL_MaskingAdvisor`                          |
| **HTTP Client**         | 1       | Fluent HTTP facade                                                                                                                                                                                                                                                                                                         | `UTIL_HttpClient`                                                      |
| **Async Processing**    | 7       | Multi-step chain orchestration with shared context across transactions and finalizer-based recovery                                                                                                                                                                                                                        | `UTIL_AsynchronousJobLauncher`, `UTIL_AsyncChain`, `CTRL_ChainMonitor` |
| **LWC**                 | 63      | Component library with five built-in modules and registry-dispatch activation (only Apex framework surveyed with a component-base + module-mixin composition surface)                                                                                                                                                      | `ComponentBuilder`                                                     |
| **Utilities**           | 10+     | String, Date, Number, Set, List, Map, Schema (39 string helpers; null-safe by default)                                                                                                                                                                                                                                     | `UTIL_*`                                                               |
| **Flow Invocables**     | 16      | Flow integration points                                                                                                                                                                                                                                                                                                    | `FLOW_*`                                                               |

### Code Examples at a Glance

Each module can be summarized by its most common one-liner:

```apex
// Query — fluent SOQL with compile-time field safety
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<SObjectField>{Account.Name, Account.Industry})
    .condition(Account.Industry).equals('Technology')
    .withCache(300)
    .toList();

// Selector — object-specific query with inherited convenience methods
Account account = (Account)new SEL_Accounts().findById(accountId);
List<Account> techAccounts = new SEL_Accounts().findByIndustry('Technology');

// DML — transactional Unit of Work with parent-child chaining
DML_Builder.newTransaction()
    .doInsert(account)
    .doInsert(contact, Contact.AccountId, account)
    .execute();

// Trigger — one line per object, everything else is metadata
trigger TRG_Account on Account(before insert, before update, after insert, after update)
{
    new TRG_Dispatcher().run();
}

// Web Services — outbound with automatic retry and circuit breaker
HttpResponse response = UTIL_HttpClient.post('PaymentGateway', '/charges')
    .body(chargeRequest).withRetry(3).withCircuitBreaker().send();

// Logging — structured, auto-published, zero forgotten saveLog() calls
LOG_Builder.build().error(exception).forRecord(recordId)
    .withContext('amount', payment.Amount__c).emitAt('PaymentService.charge');

// Feature Flags — runtime toggles with pluggable strategies
if(UTIL_FeatureFlag.isEnabled('NewCheckoutFlow'))
{
    // new behavior
}

// Test Data — fluent builder with auto-required-field population
Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
    .withOverride(Account.Name, 'Test Corp').build();

// Mock Data — DML-free query interception for unit tests
Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
    .withOverride(Foobar__c.Name, 'Mock Record').build();
// SEL_Foobar queries now return mock data — no DML, no SOQL

// Validation — formula-driven via custom metadata
// Configure ValidationRule__mdt with formula: newRecord.Amount__c > 0
// Framework evaluates using Salesforce's native FormulaEval engine

// Async — adaptive strategy selection based on data volume
UTIL_AsynchronousJobLauncher.newJob(myAsyncHandler)
    .withRecords(largeRecordSet)
    .execute(); // AUTO selects Queueable, Batch, or Synchronous

// Async — chain orchestration with built-in API bridge
String executionId = UTIL_AsyncChain.newChain('OrderProcessing')
    .withInitialContext('orderId', order.Id)
    .then(new ValidateOrderStep())
    .then(new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
        .triggeringRecordFrom('orderId')
        .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99'))
    .then(new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
        .triggeringRecordFrom('orderId'))
    .onError(new NotifyAdminStep())
    .execute(); // Each step runs in its own Queueable transaction

// LWC — composable module system (never use raw LightningElement)
// export default class MyComponent extends ComponentBuilder('notification', 'controller')
```

### Custom Metadata Topology

KernDX's configuration-over-code approach is backed by 15 custom metadata types organized in a clear hierarchy:

```text
                    ┌─────────────────────────┐
                    │   Application Entry      │
                    │   Points                 │
                    └──────────┬──────────────┘
                               │
         ┌─────────────────────┼──────────────────────┐
         │                     │                       │
         ▼                     ▼                       ▼
┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────┐
│ TriggerSetting  │  │ ApiSetting      │  │ ValidationRuleGroup  │
│ (per object)    │  │ (per endpoint)  │  │ (per object+context) │
└───────┬─────────┘  └───────┬─────────┘  └──────────┬───────────┘
        │                    │                        │
        ▼                    │                        ▼
┌─────────────────┐  ┌──────┴──────────┐  ┌──────────────────────┐
│ TriggerAction   │  │ ApiCredential   │  │ ValidationRule       │
│PostTriggerAction│  │ ApiMock         │  │ (per formula)        │
│ (per handler)   │  │ MaskingRule     │  └──────────────────────┘
└─────────────────┘  │ MaskingTarget   │
                     └─────────────────┘
         ┌─────────────────────┼──────────────────────┐
         │                     │                       │
         ▼                     ▼                       ▼
┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────┐
│ FeatureFlag     │  │ AsyncJobSetting │  │ ClassTypeResolver    │
│ FeatureFlagStrat│  │ FieldSetGroup   │  │ (type resolution)    │
└─────────────────┘  └─────────────────┘  └──────────────────────┘
```

### Quantitative Summary

| Metric                     | Value                                                                                                                                                                                                                                                                                                         |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Apex classes               | 363 (189 production, 174 test)                                                                                                                                                                                                                                                                                |
| Selector classes           | 44 (most extend `SEL_Base`)                                                                                                                                                                                                                                                                                     |
| Flow invocable classes     | 16 (`FLOW_*`)                                                                                                                                                                                                                                                                                                 |
| Test methods               | ~6,340 (~3,700 Apex + ~2,640 Jest)                                                                                                                                                                                                                                                                            |
| Test coverage              | 100% per-file Apex, 95% statement/branch LWC (enforced at every release build)                                                                                                                                                                                                                                |
| Lines of code              | ~200K (~79K production Apex, ~76K Apex tests, ~13K LWC, ~31K Jest)                                                                                                                                                                                                                                            |
| LWC components             | 63                                                                                                                                                                                                                                                                                                            |
| Custom objects             | 10                                                                                                                                                                                                                                                                                                            |
| Custom metadata types      | 15                                                                                                                                                                                                                                                                                                            |
| Platform events            | 1                                                                                                                                                                                                                                                                                                             |
| Pre-built metadata records | 57                                                                                                                                                                                                                                                                                                            |
| Source API version         | 67.0 (pinned in `sfdx-project.json`)                                                                                                                                                                                                                                                                          |
| Latest packaged version    | See [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for the current build identifier; KernDX is v1.0 with the first validated build packaged and testing-hardened (see [Open-Source Readiness](#open-source-readiness) for milestone context and adoption-history caveat) |
| Documentation              | 33 developer documents (18 guides, 15 fast starts), 263 API reference pages                                                                                                                                                                                                                                   |

### Documentation Architecture

| Layer              | Documents                                                                                                                                | Purpose                                                                                                |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| **Onboarding**     | Start Here                                                                                                                               | First-day walkthrough building one implementation per module                                           |
| **Task-Oriented**  | 15 Fast Starts                                                                                                                           | Focused guides: "Build X in 30 minutes"                                                                |
| **Full Framework** | 18 Guides                                                                                                                                | Full framework capabilities, patterns, best practices                                                  |
| **Reference**      | 263 API References                                                                                                                       | Auto-generated ApexDoc for every class, method, property                                               |
| **Strategic**      | This document                                                                                                                            | Architecture, philosophy, and adoption guidance                                                        |
| **AI Context**     | `AGENTS.md` (repo root); `docs/Code Conventions - Guide.md` (canonical); [AI Agent Instructions](AI%20Agent%20Instructions.md) (`docs/`) | Tool-neutral pointer + canonical conventions + per-module framework reference for AI coding assistants |

> For current statistics and verification commands, see [Metrics](Strategic%20Guide%20-%20Metrics.md).

---

## Salesforce Well-Architected Alignment

This section evaluates how KernDX aligns with the [Salesforce Well-Architected Framework](https://architect.salesforce.com/well-architected/overview) — Salesforce's prescriptive
guidance for building solutions across the Trusted, Easy, and Adaptable pillars. This content is suitable for Architecture Review Boards and executive-level discussions.

> **Why This Matters:** Executives recognize the "Well-Architected" brand from AWS and Azure. Mapping KernDX to Salesforce's equivalent validates the architectural choice in
> executive-level discussions and Architecture Review Boards.

> **Critical Distinction:** Well-Architected defines *outcomes* to pursue. KernDX provides *implementation patterns* that support those outcomes. Framework adoption accelerates
> alignment — it does not replace architectural judgement.

**Audience Guide:**

| Reader                    | Start Here                           |
|---------------------------|--------------------------------------|
| **Executives & CTOs**     | Alignment Scorecard, Decision Matrix |
| **Enterprise Architects** | Pillar Evaluation, Framework Scope   |
| **Platform Leads**        | Risks, Recommended Next Steps        |
| **ARB Reviewers**         | Full section review                  |

### Alignment Scorecard

```text
╔═══════════════════════════════════════════════════════════════════════════════╗
║                KERNDX ↔ SALESFORCE WELL-ARCHITECTED™ ALIGNMENT               ║
║                            Executive Summary                                  ║
╚═══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────────┐
│  WHAT IS SALESFORCE WELL-ARCHITECTED?                                           │
│  Salesforce's prescriptive guidance for building solutions,                     │
│  organized into three pillars: Trusted, Easy, and Adaptable.                   │
│  Each pillar contains behaviours that Well-Architected solutions should         │
│  exhibit. See: architect.salesforce.com/well-architected/overview               │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│ Pillar      │ Behaviour    │ Alignment │ KernDX Capabilities                     │
├─────────────┼──────────────┼───────────┼─────────────────────────────────────────┤
│ TRUSTED     │ Secure       │ ✅ ALIGNED │ AES256 default, sharing, masking default│
│             │              │           │ CRUD/FLS default-on at query/DML        │
│ TRUSTED     │ Compliant    │ ⚠️ PARTIAL │ Audit logging, permissions; not GDPR     │
│ TRUSTED     │ Reliable     │ ✅ ALIGNED │ Circuit breaker, retry, cache, timers    │
│ EASY        │ Intentional  │ ✅ ALIGNED │ Naming conventions, metadata config, AI  │
│ EASY        │ Automated    │ ✅ ALIGNED │ Trigger framework, query builder, tests  │
│ EASY        │ Engaging     │ ⚠️ PARTIAL │ 63 LWC components; UI/UX out of scope    │
│ ADAPTABLE   │ Resilient    │ ✅ ALIGNED │ LOG_Builder, correlation, TST_Builder    │
│ ADAPTABLE   │ Composable   │ ✅ ALIGNED │ Managed package, namespace, metadata     │
└─────────────┴──────────────┴───────────┴─────────────────────────────────────────┘

OVERALL: 6 of 8 behaviours ALIGNED │ 2 PARTIAL (Compliant by regulatory scope;
         Engaging by UX-design scope)
```

### Three Pillars: Detailed Analysis

#### Pillar 1: Trusted

**Secure — ALIGNED**

| Well-Architected Requirement  | KernDX Implementation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Posture                                                                                                                                           |
|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| Enforce CRUD/FLS at query/DML | `QRY_Builder` and `DML_Builder` enforce FLS/CRUD by default on read AND write paths. KernDX is the only Apex framework surveyed with FLS/CRUD enforced by default on read AND write simultaneously, with an org-wide kill-switch and per-call bypass that writes an audit log. The `.withSystemMode()` and `SEL_Base.systemModeRequired()` opt-outs are subscriber-authored in source — auditable via git + code review — for framework selectors that need system-mode (configuration reads, Chain Monitor aggregates). A CI-blocking scanner rule fails builds on any undeclared access mode. The metadata kill-switches are emergency reversion — a single-record metadata deploy reverts to system-mode without touching Apex.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | default-on                                                                                                                                        |
| Encrypt sensitive data        | `UTIL_SessionEncryption` (AES256 with automatic key management).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | default-on (keys issued per session, no opt-in switch)                                                                                            |
| Control record sharing        | Sharing proxy in `QRY_Builder` (`.withSharing()`, `.bypassSharing()`); `UTIL_Sharing` for programmatic grants. Classes still must declare `with sharing` / `inherited sharing` / `without sharing` explicitly — KernDX's own convention rules require this.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | default-on at the class declaration layer; per-query overrides are calls subscribers write themselves in source (auditable via git + code review) |
| Prevent data exposure         | `MaskingRule__mdt` + `MaskingTarget__mdt` — runtime field redaction framework intercepting before-insert / before-update / before-publish on any SObject or platform event (masks via regex, Luhn for payment-card detection, literal-string, and JSON-key matching; four masking modes; three failure actions; 18 built-in masking rules; caller-class scoping). Sensitive content is rewritten in memory so the database never stores the raw value — redaction happens before persistence, distinct from `stripInaccessible` which filters after query. Ships with 18 masking-rule records (3 active by default plus 15 inactive templates) and twelve masking-target records wildcarded onto four high-risk package objects; admins extend coverage to their own org's objects via additional masking-target records. **Per-SObject opt-in is a deliberate design trade-off** — most subscribers do not push credit-card data through every log emit, and a default-on regex tax on every persistence path is paid by every subscriber regardless. Subscribers prioritising default-on out-of-the-box compliance hygiene with no configuration mix `nebula-logger` alongside KernDX for log-emit masking; subscribers prioritising per-SObject performance control plus extensibility to subscriber objects ship KernDX. The Data Masking Advisor scans your own custom objects for regulated fields that have no masking target and exports a regulated-field inventory, so the per-SObject opt-in is discoverable rather than silent. | default-on at the kill-switch level; per-SObject opt-in via `TriggerSetting.ApplyMasking__c`                                                      |
| Audit bypass usage            | Every trigger-bypass call writes a structured audit log carrying the correlation ID so bypasses are traceable across triggers, async chains, and API calls (`bypass_audit_signal = event`; bypass works at four levels — per-object, per-action, per-flow, framework-wide). KernDX is one of two frameworks (alongside `rflib`) shipping built-in trigger bypass-audit emission. Per-builder toggles (`QRY_Builder.withSystemMode()`, `DML_Builder.bypassSharing()`) are calls subscribers write themselves in source — auditable via git + code review + source-grep — but do not yet emit runtime audit signals; extending audit emission to the per-builder layer is on the post-1.0 work plan.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | default-on at the trigger surface                                                                                                                 |

**v1.0 security posture.** KernDX ships FLS/CRUD enforced by default on queries and DML, bypass audit logging at the trigger surface, idempotency body-hash returning HTTP 409 on
inbound replay divergence (a capability KernDX uniquely ships surveyed), and a CI-blocking scanner rule on undeclared access modes. The per-selector system-mode hook is the
documented opt-out for framework-internal read paths; metadata kill-switches are the emergency reversion (flip one record, no code deploy, to revert if a subscriber hits unexpected
FLS blocks). Encryption, sharing (at class-declaration layer), and masking surfaces remain default-on where they ship.

**Security defaults across the comparable Apex frameworks surveyed.** On the four signals that drive defect rate (sharing default, access-mode default, bypass audit, inbound
trust), KernDX defaults to the secure setting on all four. `rflib` covers more aspects of this dimension than any other Apex framework surveyed — partial bypass-audit emission and
partial FLS-enforced reads, with no shipped surface on inbound trust or FLS-enforced DML — vs KernDX shipping a complete secure-default implementation on all four signals. One
nuance remains: per-SObject masking is opt-in for custom objects (a deliberate performance trade-off, see *Prevent data exposure* row above) — the Data
Masking Advisor flags your own custom objects that hold regulated data but have no masking target, so the opt-in is discoverable rather than silent. The
repository ships a top-level `SECURITY.md` documenting the vulnerability-reporting process.

**Compliant — PARTIAL**

| Well-Architected Requirement | KernDX Implementation                                                                                                                                                                                                               | Gap                                                                                                                                                                                                                                |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Audit trail                  | `LOG_Builder` with transaction correlation, persistent `LogEntry__c` records                                                                                                                                                        | Regulatory-specific audit requirements (SOX, HIPAA) need dedicated controls                                                                                                                                                        |
| Permission enforcement       | CRUD/FLS enforced by default on `QRY_Builder` / `DML_Builder`; `.stripInaccessible()` and feature flags for conditional access                                                                                                      | Regulatory compliance programmes (GDPR, PCI-DSS) are policy, not infrastructure.                                                                                                                                                   |
| Data governance              | Field-level security enforcement default-on; runtime field redaction via the data masking framework (any SObject text field, declarative rules, in-memory rewrite before DML — default-on at kill-switch level, per-SObject opt-in) | Data classification, retention policies, right-to-erasure, and regulation-specific mapping of fields to rules (GDPR Art. 25, PCI-DSS Req. 3, HIPAA §164.514, CCPA/CPRA §1798.100(c)) are subscriber policy, not framework-provided |

*Gap rationale:* Regulatory compliance requires domain-specific controls (data classification policies, retention rules, consent management) that no technical framework can provide
generically. KernDX provides the infrastructure (audit logging, permission enforcement, encryption) on which compliance programmes are built.

**Reliable — ALIGNED**

| Well-Architected Requirement     | KernDX Implementation                                                                                               |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------|
| Handle external service failures | `UTIL_CircuitBreaker` (three-state: CLOSED, OPEN, HALF_OPEN); `UTIL_Retry` (linear/exponential backoff with jitter) |
| Ensure data consistency          | `DML_Builder` with transactional integrity; `API_Outbound` transactional outbox pattern                             |
| Monitor system health            | `LOG_Builder` with configurable performance timers; `LogSetting__c` for log level thresholds                        |
| Cache appropriately              | `UTIL_Cache` with AUTO mode (Session-to-Org fallback), bulk operations, compression for payloads >4KB               |
| Correlate across boundaries      | Transaction correlation IDs across sync/async boundaries; W3C `traceparent` header propagation                      |

#### Pillar 2: Easy

**Intentional — ALIGNED**

| Well-Architected Requirement | KernDX Implementation                                                                                                                                                                                                                            |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Consistent naming            | Standardised prefixes: `SEL_*`, `TRG_*`, `API_*`, `QRY_*`, `DML_*`, `LOG_*`, `UTIL_*`, `TST_*`, `FLOW_*`                                                                                                                                         |
| Self-documenting code        | ApexDoc required on all classes and methods; `@example` with valid code                                                                                                                                                                          |
| Discoverable architecture    | 33 developer documents (18 guides, 15 fast starts), 263 API references; `AGENTS.md` + `docs/Code Conventions - Guide.md` (repo root) + [`AI Agent Instructions`](AI%20Agent%20Instructions.md) (framework reference) for AI-assisted development |
| Metadata-driven behaviour    | 15 custom metadata types controlling triggers, post-trigger actions, validation, feature flags, web services, mocking, masking, async jobs, field sets                                                                                                                 |

**Automated — ALIGNED**

| Well-Architected Requirement   | KernDX Implementation                                                                                                              |
|--------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Reduce boilerplate             | `TRG_Dispatcher` — one-line trigger body; `SEL_Base` — inherited query methods; `TST_Builder` — auto-populated test records        |
| Eliminate manual orchestration | Metadata-driven trigger ordering, validation rule grouping, API retry strategies                                                   |
| Enforce quality gates          | 100% per-file Apex coverage gate; PMD compliance; secret scanning in CI; no inline SOQL; no `System.debug`                                                |
| Standardise testing            | `TST_Builder` (data creation), `TST_Mock` (query interception), `TST_Factory` (metadata records), `API_MockFactory` (HTTP mocking) |

**Engaging — PARTIAL**

| Well-Architected Requirement | KernDX Implementation                                                                                                                                                                                                                                                          | Gap                                                                                        |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| Delightful user experiences  | 63 LWC components with `ComponentBuilder` module system (five built-in modules — navigation, notification, lightning-message, controller, flow-navigation — with opt-in activation; clear error messages when modules aren't enabled; rejects invalid modules at registration) | Visual design, interaction patterns, and UX research are design authority responsibilities |
| Accessible interfaces        | Lightning base components used throughout                                                                                                                                                                                                                                      | WCAG compliance requires dedicated accessibility testing                                   |

#### Pillar 3: Adaptable

**Resilient — ALIGNED**

| Well-Architected Requirement | KernDX Implementation                                                                                  |
|------------------------------|--------------------------------------------------------------------------------------------------------|
| Signaling strategy           | `LOG_Builder` instrumentation across triggers, queries, APIs with structured context                   |
| Testing strategy             | `TST_Builder` + `TST_Mock` for data-driven testing; `API_MockFactory` for HTTP mocking                 |
| Continuity strategy          | Circuit breaker prevents cascading failures; dead letter queue preserves failed API calls for recovery |
| Correlation tracking         | Transaction IDs across async boundaries; W3C `traceparent` for distributed tracing                     |

**Composable — ALIGNED**

| Well-Architected Requirement | KernDX Implementation                                                                                             |
|------------------------------|-------------------------------------------------------------------------------------------------------------------|
| Modular architecture         | Managed package with namespace isolation; each module (triggers, queries, DML, web services) usable independently |
| Configuration over code      | 15 custom metadata types; `ClassTypeResolver__mdt` for type resolution                                            |
| External integration         | Platform event logging enables external observability integration; `API_Outbound` for structured callouts         |

### Framework Scope Clarification

KernDX provides infrastructure patterns. It does not replace organisational governance:

| Area                    | KernDX Provides                                                                | External Input Required                                                    |
|-------------------------|--------------------------------------------------------------------------------|----------------------------------------------------------------------------|
| **Architecture Review** | Consistent patterns, documented conventions                                    | ARB decisions, technology selection, integration strategy                  |
| **Compliance**          | Audit logging, encryption, CRUD/FLS enforcement                                | Regulatory policy definition, data classification, consent management      |
| **Design Authority**    | 63 LWC components, `ComponentBuilder` pattern                                  | UI/UX design, accessibility audits, user research                          |
| **Platform Governance** | Managed package versioning, namespace isolation                                | Org configuration, limits monitoring, release management, sandbox strategy |
| **Security Operations** | Write-time data masking (configurable per object), session encryption, permission enforcement | Penetration testing, threat modeling, incident response procedures         |

### Well-Architected Risks and Considerations

| Risk                                                            | Impact | Mitigation                                                                                                                                                                                                                                                                                                                                                                                                                               |
|-----------------------------------------------------------------|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Over-reliance on framework without governance                   | High   | Framework provides patterns, not policy. Establish Architecture Review Board and governance processes independently.                                                                                                                                                                                                                                                                                                                     |
| Framework-internal system-mode selectors (auxiliary read paths) | Low    | `QRY_Builder` and `DML_Builder` enforce FLS/CRUD by default. About three-quarters of the 44 selector classes opt back into system-mode via a documented per-selector hook — declarations are calls in source, auditable via git + code review, and enforced by a CI-blocking scanner rule. Subscribers extending `SEL_Base` inherit FLS-enforced reads by default. Metadata kill-switches are emergency reversion without a code deploy. |
| Per-builder bypass audit emission is roadmap, not shipped       | Low    | KernDX ships bypass-audit emission at the trigger surface; per-builder toggles emit no runtime audit signal yet. Subscribers' git history + code review + source-grep is the post-hoc audit infrastructure for the per-builder layer until audit emission extends down.                                                                                                                                                                  |
| Compliance gaps if only using KernDX                            | Medium | KernDX provides infrastructure for compliance (logging, encryption, masking, default-on FLS/CRUD enforcement). Layer regulatory controls on top.                                                                                                                                                                                                                                                                                         |
| Well-Architected alignment interpreted as certification         | Low    | "Aligned" means KernDX supports the prescribed outcomes. It does not constitute Salesforce certification or endorsement.                                                                                                                                                                                                                                                                                                                 |

### Well-Architected Decision Matrix

| Your Question                                           | If Yes                                                                                                                                                                                                                                                                                                                                                          | If No                                           |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| Does your org require Well-Architected alignment?       | Evaluate KernDX alignment scorecard against specific pillar requirements (Secure is ALIGNED)                                                                                                                                                                                                                                                                    | Standard framework selection criteria apply     |
| Are you presenting to an ARB?                           | Use the scorecard and pillar evaluation tables above                                                                                                                                                                                                                                                                                                            | Focus on technical deep dives                   |
| Do you need regulatory compliance?                      | KernDX provides infrastructure; layer compliance controls on top                                                                                                                                                                                                                                                                                                | Standard security patterns sufficient           |
| Does FLS-by-default at query/DML matter above all else? | Both [`apex-fluently-soql`](https://github.com/beyond-the-cloud-dev/soql-lib) and KernDX default to FLS-enforced reads. On writes, KernDX is the only Apex framework surveyed shipping FLS-enforced DML by default; `apex-fluently-soql` does not ship a DML primitive. Choose based on read-path syntax breadth, write-path coverage, or integration coherence | Either framework works on read-path enforcement |
| Do you need custom UI?                                  | KernDX provides `ComponentBuilder`; design authority drives UX decisions                                                                                                                                                                                                                                                                                        | Apex-only implementation may suffice            |

### Well-Architected Summary Scorecard

```text
╔════════════════════════════════╤═══════════════════╤══════════════════════════════╗
║ Pillar / Behaviour             │ Alignment         │ Key Evidence                 ║
╠════════════════════════════════╪═══════════════════╪══════════════════════════════╣
║ TRUSTED                        │                   │                              ║
║   Secure                       │ ✅ ALIGNED        │ FLS-by-default on query and  ║
║                                │                   │ DML, encryption + masking,   ║
║                                │                   │ bypass audit at trigger      ║
║   Compliant                    │ ⚠️  PARTIAL       │ Audit logging, encryption    ║
║                                │                   │ Gap: regulatory policy       ║
║   Reliable                     │ ✅ ALIGNED        │ Circuit breaker, retry,      ║
║                                │                   │ transactional outbox, cache  ║
╠════════════════════════════════╪═══════════════════╪══════════════════════════════╣
║ EASY                           │                   │                              ║
║   Intentional                  │ ✅ ALIGNED        │ Naming conventions, ApexDoc, ║
║                                │                   │ prefix system, metadata      ║
║   Automated                    │ ✅ ALIGNED        │ Trigger framework, query     ║
║                                │                   │ builder, test infrastructure ║
║   Engaging                     │ ⚠️  PARTIAL       │ 63 LWC components; UI/UX    ║
║                                │                   │ out of scope                 ║
╠════════════════════════════════╪═══════════════════╪══════════════════════════════╣
║ ADAPTABLE                      │                   │                              ║
║   Resilient                    │ ✅ ALIGNED        │ Feature flags, circuit       ║
║                                │                   │ breaker, degradation         ║
║   Composable                   │ ✅ ALIGNED        │ Managed package, namespace,  ║
║                                │                   │ metadata, extension points   ║
╠════════════════════════════════╪═══════════════════╪══════════════════════════════╣
║ OVERALL                        │ 6/8 ALIGNED       │ v1.0: Secure aligned         ║
║                                │ 2/8 PARTIAL       │ with FLS-by-default on read  ║
║                                │                   │ AND write + trigger bypass   ║
║                                │                   │ audit; Compliant + Engaging  ║
║                                │                   │ are intentional scope limits ║
╚════════════════════════════════╧═══════════════════╧══════════════════════════════╝
```

### Well-Architected Quick Reference

| Pillar        | KernDX Strength                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | KernDX Gap                                                                                         |
|---------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| **Trusted**   | FLS/CRUD enforced by default on `QRY_Builder` AND `DML_Builder` (KernDX is the only Apex framework surveyed with FLS-by-default on read AND write —;); encryption default-on (AES256 with automatic key management); runtime masking on any SObject or platform event (four masking modes, 18 built-in rules, three failure actions, caller-class scoping); every trigger bypass writes an audit log; idempotent inbound REST with body-hash 409 (KernDX uniquely covers surveyed); sharing declared explicitly by convention. On the four signals that drive defect rate (sharing, access mode, bypass audit, inbound trust), KernDX defaults to the secure setting on all four. | Regulatory compliance policy is organisational, not framework; per-builder bypass audit is roadmap |
| **Easy**      | Consistent conventions, metadata-driven config, full documentation stack (see [Documentation Architecture](#documentation-architecture)), AI context                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | UI/UX design patterns require design expertise                                                     |
| **Adaptable** | Circuit breaker, retry, dead letter queue, correlation tracking, managed package isolation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Platform governance (org config, limits monitoring) is operational                                 |

---

## Security Benchmark for Salesforce Alignment

This section evaluates how KernDX aligns with the [Security Benchmark for Salesforce](https://github.com/Salesforce-Security-Benchmark) (SBS) — a
practitioner-developed, CIS-style standard of **54 binary controls across 12 domains** (Foundations, OAuth Security, Integrations, Access Controls,
Authentication, Code Security, Customer Portals, Data Security, Deployments, Security Configuration, File Security, and Event Monitoring), each rated
Critical, High, or Moderate and tagged to regulatory frameworks (HIPAA, GDPR, NIST, CCPA/CPRA, SOC 2, ISO 27001). The benchmark is independent of both
Salesforce and KernDX. This content is written for GRC teams, auditors, and Architecture Review Boards.

> **Why This Matters:** The SBS is the checklist a growing number of security teams and auditors run a Salesforce org against. Mapping KernDX to it shows,
> control by control, exactly where the framework gives you a working mechanism or audit-ready evidence — and, just as importantly, where it does not, so
> nobody mistakes a framework install for a compliant org.

> **Critical Distinction:** The SBS audits *orgs*, not packages. KernDX ships mechanisms and evidence for specific controls; it **cannot make an org
> compliant**, and most SBS controls remain your configuration and process. A posture that reads *"provides the mechanism for"* or *"provides evidence
> for"* never means *"complies with"* — running the control, certifying it, and keeping it certified stay with you.

**Audience Guide:**

| Reader                     | Start Here                                          |
|----------------------------|-----------------------------------------------------|
| **GRC & Compliance teams** | SBS Alignment Scorecard, What Remains Yours         |
| **Auditors**               | Where KernDX Provides a Mechanism (the evidence rows) |
| **ARB Reviewers**          | Full section review                                 |
| **Platform Leads**         | What Remains Yours, native-tool pointers            |

### SBS Alignment Scorecard

KernDX provides a working mechanism or audit-ready evidence for **15 of the 54 controls**; the remaining **39 are org configuration and process** that no
managed package can own on your behalf. Nothing here continuously monitors your org's security posture — KernDX surfaces problems about *its own* configuration or
a KernDX capability and ships fixes (the masking engine, the durable logger, the pipeline gates). The one place it reaches into your own objects is the
on-demand Data Masking Advisor scan and its inventory export, which you run. Org-wide posture monitoring is handed to the tools built
for it: the native Salesforce Security Health Check, Salesforce Optimizer, Salesforce Shield / Event Monitoring, and AppOmni.

| Domain                 | Controls | KernDX provides a mechanism / evidence for | Remains your configuration            |
|------------------------|---------:|--------------------------------------------|---------------------------------------|
| Foundations            |        1 | FDNS-001 (evidence)                        | —                                     |
| OAuth Security         |        4 | —                                          | all 4                                 |
| Integrations           |        4 | INT-003 (KernDX's own credentials)         | INT-001, INT-002, INT-004             |
| Access Controls        |       12 | ACS-010 (evidence)                         | the other 11                          |
| Authentication         |        4 | —                                          | all 4                                 |
| Code Security          |        4 | CODE-001, CODE-002, CODE-003, CODE-004     | —                                     |
| Customer Portals       |        5 | CPORTAL-001, CPORTAL-004 (guidance)        | CPORTAL-002, CPORTAL-003, CPORTAL-005 |
| Data Security          |        4 | DATA-001, DATA-002, DATA-004               | DATA-003                              |
| Deployments            |        6 | DEP-003, DEP-004, DEP-005                  | DEP-001, DEP-002, DEP-006             |
| Security Configuration |        2 | —                                          | both                                  |
| File Security          |        3 | —                                          | all 3                                 |
| Event Monitoring       |        5 | —                                          | all 5                                 |

> The strongest alignment is in **Code Security** (all four controls) and **Deployments** (source-driven builds and secret scanning), where KernDX and its
> CI pipeline supply the mechanism directly. **Data Security** is where KernDX reaches furthest beyond its own footprint: the Data Masking Advisor detects
> regulated data and exports a field inventory across your own objects.

### Where KernDX Provides a Mechanism

Posture is stated as *provides the mechanism for* (KernDX ships the working control), *provides evidence for* (KernDX produces an artifact your process
consumes), or *provides guidance for* (KernDX documents the secure pattern). None of these mean *complies with*.

**Code Security**

| SBS Control                          | KernDX Mechanism                                                                                                                                                              | Posture                                                                       |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| CODE-001 Mandatory peer review       | The CI pipeline's ingress gate requires approving reviews before a merge, with a bypass that raises an alert.                                                                 | provides the mechanism for                                                    |
| CODE-002 Pre-merge static analysis   | The Salesforce Code Analyzer gate runs PMD's Apex security rules (SOQL injection, CRUD/FLS, sharing) alongside the KernDX rule set and blocks the pull request on a high-severity finding. | provides the mechanism for                                        |
| CODE-003 Persistent Apex logging     | `LOG_Builder` / `LOG_Engine` write durable `LogEntry__c` records with transaction correlation.                                                                               | provides the mechanism for                                                    |
| CODE-004 Prevent sensitive data in logs | The data-masking engine runs on by default and redacts the framework's log and diagnostic objects before they persist; the Data Masking Advisor scans your own custom objects and flags regulated fields that have no masking. | provides the mechanism for (custom objects need a masking target — the Advisor finds the gaps) |

**Deployments**

| SBS Control                                       | KernDX Mechanism                                                                                                                                                            | Posture                          | Where it stops                                                  |
|---------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------|----------------------------------------------------------------|
| DEP-003 Monitor unauthorized metadata modifications | Source-driven deployment discipline is KernDX's half: deterministic builds, a refusal to build from a dirty tree, and the bypass-alert pair.                              | provides part of the mechanism for | Org-wide config-drift detection is Salesforce Shield / AppOmni, not a package |
| DEP-004 Source-driven development                 | Package and distribution builds are deterministic and refuse to run against an uncommitted working tree.                                                                    | provides the mechanism for       | —                                                              |
| DEP-005 Secret scanning                           | The pipeline ships a Salesforce-aware secret-scan command and a GitHub Actions check — blocking in CI, advisory on the workstation — and the same pattern set gates KernDX's own release build. | provides the mechanism for | Enable native push protection too, and rotate any committed secret |

**Data Security**

| SBS Control                                  | KernDX Mechanism                                                                                          | Posture                    | Where it stops                              |
|----------------------------------------------|----------------------------------------------------------------------------------------------------------|----------------------------|---------------------------------------------|
| DATA-001 Detect regulated data in long-text fields | The Data Masking Advisor scans an object or your custom objects for sensitive fields.              | provides the mechanism for | —                                           |
| DATA-002 Inventory fields holding regulated data | The Advisor exports a regulated-field inventory as CSV or JSON, with a "sensitive fields only" filter. | provides the mechanism for | —                                           |
| DATA-004 Field history tracking for sensitive fields | The inventory flags a "history-tracking recommended" column.                                       | provides evidence for      | Turning on field history is org configuration; the recommendation is a heuristic, not an authoritative data classification |

**Foundations, Integrations, and Access Controls (evidence)**

| SBS Control                                   | KernDX Mechanism                                                                                                                                                                                  | Posture                                                                  |
|-----------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| FDNS-001 Centralized security system of record | Masking-configuration export and the regulated-field inventory feed the system of record you already run (see [Security Governance Evidence](Security%20-%20Guide.md#security-governance-evidence)). | provides evidence for (KernDX is the source and automation, not the system of record) |
| INT-003 Named Credentials inventory           | KernDX documents and justifies the two named credentials it ships; your org-wide credential inventory comes from native Setup and AppOmni.                                                        | provides evidence for (its own footprint only)                           |
| ACS-010 Periodic access review & recertification | Login Frequency reporting and the Deactivate Inactive Users job supply the activity evidence and one common remediation a review depends on (see [Security Governance Evidence](Security%20-%20Guide.md#security-governance-evidence)). | provides evidence and remediation for (not a recertification engine)     |

**Customer Portals (guidance)**

| SBS Control                                       | KernDX Mechanism                                                                                                                                                                       | Posture                              |
|---------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------|
| CPORTAL-001 Parameter-based record access in Apex | `QRY_Builder` and `DML_Builder` run in `USER_MODE` by default, so a portal request is checked against the running user's access; the Security guide documents the insecure-direct-object-reference pattern to avoid. | provides the mechanism and guidance for |
| CPORTAL-004 Parameter-based record access in Flows | The Security guide documents the Flow input-variable hygiene pattern for portal-invoked flows.                                                                                        | provides guidance for                |

### What Remains Yours

These controls are org configuration and human process. A managed package cannot own your org's identity, configuration, backup, or deployment access — at
most it points you at the native tool that does. Run this list as a checklist against your own org, not as a KernDX gap report.

| Domain                 | Controls you own                                                                                                                                                            | Where it lives                                                                                                                              |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| OAuth Security         | OAUTH-001/002/003/004 — connected-app install approval, access scoping, criticality classification, vendor due diligence                                                   | Org setup, plus the native Security Health Check / Optimizer / AppOmni                                                                      |
| Integrations           | INT-001 browser-extension governance · INT-002 Remote Site inventory · INT-004 retain API-usage logs                                                                       | Device/network policy; native Health Check / AppOmni; Event Monitoring. `ApiCall__c` records KernDX-routed callouts only, not org-wide API usage |
| Access Controls        | ACS-001…009, ACS-011, ACS-012 — permission-set model, API-enabled and super-admin justification, custom profiles, non-human-identity inventory, change governance, login-hours classification | Org access review (native Health Check / Optimizer / AppOmni) and the Setup Audit Trail. KernDX deliberately does not host a subscriber identity inventory |
| Authentication         | AUTH-001/002/003/004 — SSO enforcement, SSO-bypass governance, login-IP ranges, strong MFA                                                                                 | Org identity configuration                                                                                                                 |
| Customer Portals       | CPORTAL-002 guest-user record access · CPORTAL-003 portal-exposed Apex/Flow inventory · CPORTAL-005 portal penetration testing                                             | Org configuration and your application-security program (keep `.withUserMode()` on guest-facing queries)                                    |
| Data Security          | DATA-003 tested backup and recovery                                                                                                                                        | A backup and recovery solution — KernDX ships no org backup                                                                                 |
| Deployments            | DEP-001 deployment identity · DEP-002 high-risk-metadata prohibited list · DEP-006 CLI token expiry                                                                        | Org IAM and your deployment platform's governance                                                                                          |
| Security Configuration | SECCONF-001/002 — Health Check baseline and remediation cadence                                                                                                            | The **native** Salesforce Security Health Check. KernDX's own Health Check verifies KernDX configuration (cache, masking posture, scheduled jobs); it is not the org-wide security baseline |
| File Security          | FILE-001/002/003 — public-link expiry, passwords, periodic review                                                                                                          | Org file-sharing configuration                                                                                                             |
| Event Monitoring       | MON-001/002/003/004/005 — enable and retain event logs, monitor suspicious logins and API activity, API-versus-limit monitoring                                            | Salesforce Shield / Event Monitoring and your SIEM. The Event Monitor surfaces KernDX-routed callouts for transparency; org-wide monitoring is Shield's |

### SBS Summary Scorecard

**Overall: KernDX provides a mechanism or evidence for 15 of the 54 SBS controls; the other 39 are org configuration and process.** The alignment is
concentrated where a framework can legitimately help — your code, your build pipeline, and your data — and absent where the control is purely org identity or
configuration. KernDX evidences these controls; it does not certify them, and an install is not a compliant org.

| Domain                 | KernDX posture                                                                         |
|------------------------|----------------------------------------------------------------------------------------|
| Code Security          | ✅ Mechanism — all four controls (peer review, static analysis, logging, log masking)   |
| Deployments            | ✅ Mechanism — source-driven builds + secret scanning (org-drift monitoring is yours)   |
| Data Security          | ✅ Mechanism — masking detection + regulated-field inventory (backup is yours)          |
| Foundations            | 🟡 Evidence — feeds your security system of record                                      |
| Integrations           | 🟡 Evidence — KernDX's own credentials (org-wide inventory is yours)                    |
| Access Controls        | 🟡 Evidence — access-review primitives (the other 11 controls are yours)               |
| Customer Portals       | 🟡 Guidance — IDOR and Flow-hygiene patterns on top of secure-by-default `USER_MODE`    |
| OAuth Security         | ⚪ Yours — connected-app governance (org configuration)                                 |
| Authentication         | ⚪ Yours — SSO and MFA (org identity)                                                   |
| Security Configuration | ⚪ Yours — the native Salesforce Security Health Check                                  |
| File Security          | ⚪ Yours — public-link controls (org configuration)                                     |
| Event Monitoring       | ⚪ Yours — Salesforce Shield / Event Monitoring                                         |

**SBS edition mapped.** This mapping reflects the benchmark's current published control set — 54 controls across the 12 domains listed above. The Security
Benchmark for Salesforce is pre-1.0 and still evolving; KernDX treats re-mapping on each benchmark release as a periodic review, the same way it audits for
source-and-org drift.

---

## Open-Source Readiness

### Current State

KernDX is licensed under BSL 1.1 (Business Source License), which converts to Apache 2.0 after four years. The source is published publicly on GitHub under BSL 1.1. This section
documents KernDX's open-source posture against the dimensions an architecture review board weighs.

| Dimension               | KernDX                                                                                                                                                                                                                                        | Open-source benchmark                                                                                                                                                                                  |
|-------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Source availability** | Public GitHub repository                                                                                                                                                                                                                      | Public GitHub repository — met                                                                                                                                                                         |
| **License**             | BSL 1.1 (converts to Apache 2.0 after 4 years)                                                                                                                                                                                                | OSI-approved license (MIT, Apache 2.0, or BSD-3) — BSL is source-available but not OSI-approved until the Apache 2.0 conversion (a deliberate choice during the commercial period, not a gap to close) |
| **Documentation**       | 26 developer documents (14 guides, 12 fast starts), 263 API references, `AGENTS.md` + `docs/Code Conventions - Guide.md` (repo-root AI instructions) + [AI Agent Instructions](AI%20Agent%20Instructions.md) (per-module framework reference) | Public README, docs, contribution guide — met                                                                                                                                                          |
| **Test coverage**       | 100% per-file Apex + 95% LWC statements + 95% LWC branches enforced at every release build                                                                                                                                                    | Maintained with public CI — met                                                                                                                                                                        |
| **CI/CD**               | Public GitHub Actions (`.github/workflows/ci.yml`)                                                                                                                                                                                            | Public CI — met                                                                                                                                                                                        |
| **Issue tracking**      | Public GitHub Issues with bug-report + feature-request templates                                                                                                                                                                              | Public issues — met                                                                                                                                                                                    |
| **Community**           | `CONTRIBUTING.md` + Code of Conduct published; single-maintainer, issues-only contribution model (external PRs not accepted at this stage by design)                                                                                          | Contribution guidelines + code of conduct — met                                                                                                                                                        |
| **Distribution**        | Managed package + source deploy + repackage-under-namespace                                                                                                                                                                                   | Package + source — met                                                                                                                                                                                 |

### Adoption Signal Profile

KernDX is **v1.0** with the first validated build packaged and testing-hardened (100% per-file Apex coverage gate, 95% LWC, 471 anonymous-Apex assertions in the subscriber e2e
harness, 158 `@IsTest` methods across 22 subscriber test classes, extended load suite, rolling perf-history baselines, drift-audit cycle). The honest adoption-history caveat:
KernDX is publicly released under BSL 1.1 and promoted for production install, with one known external client engagement in active use at the snapshot date and public adoption
still early. For the current build identifier and activity counts, see [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot).

**KernDX adoption activity at the snapshot date**:

| Activity signal                    | KernDX value |
|------------------------------------|--------------|
| Published managed-package versions | 107          |
| Contributors                       | 1            |

KernDX adoption activity reflects two structural conditions: the public repository is newly published (so GitHub-stars history has not yet accumulated) and the framework ships with
a single contributor. Adoption activity and per-capability coverage are reported separately throughout this guide — adoption activity is orthogonal to per-capability coverage and
never caps a capability score.

**Capability coverage across the comparable Apex frameworks surveyed.** On the axes that drive defect rate — security defaults, framework integration, capability breadth — KernDX
measures favourably against those alternatives:

| Axis                       | KernDX                                                                                                                                                                                                                                                                                                                                                                                                   | Cohort observation                                                                                                                                                                     |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Core-capability footprint  | Every core Salesforce capability shipped as a production-ready implementation                                                                                                                                                                                                                                                                                                                            | The next-broadest libraries the team has surveyed (`rflib`, [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library)) ship implementations across fewer of these areas. |
| Security defaults          | KernDX defaults to the secure setting on all four signals that drive defect rate (sharing, access mode, bypass audit, inbound trust)                                                                                                                                                                                                                                                                     | `rflib` is the next-strongest framework on this dimension — bypass audit and partial FLS-read posture; every other comparator is weaker still.                                         |
| Code quality               | PMD-clean; ApexDoc on every class and method; 100% per-file Apex test coverage                                                                                                                                                                                                                                                                                                                           | KernDX covers more aspects of the framework-level static-analysis posture than any other Apex framework surveyed — measured by violation counts after triage.                          |
| Test depth                 | 174 test classes vs 189 production classes (~92% test-to-production ratio); per-file 100% Apex coverage gate + 95% statement/branch LWC, enforced at every release build; subscriber-realism e2e harness (471 anonymous-Apex assertions across 71 sections plus 158 `@IsTest` methods across 22 subscriber test classes); extended load testing suite; rolling perf-history baselines; drift audit cycle | KernDX is the only Apex framework surveyed with a coverage gate enforced at every build.                                                                                               |
| Trigger bypass audit       | Every trigger-bypass call writes a structured audit log                                                                                                                                                                                                                                                                                                                                                  | Only `rflib` ships built-in bypass-audit on the trigger surface; every other comparator with bypass capability ships silent toggles.                                                   |
| Threat model documentation | Bespoke 2,027-line Security Guide                                                                                                                                                                                                                                                                                                                                                                        | 11 of 21 comparators ship no `SECURITY.md` at all; 4 ship the same templated `SECURITY.md`.                                                                                            |

**Trigger framework comparison.** `taf` and KernDX both ship declarative trigger registration. KernDX additionally ships bypass-audit emission that `taf` lacks — `taf`'s
programmatic bypass surface writes no audit log. `rflib` also ships broad Trigger Framework coverage and matches KernDX on two pieces: recursion-control and per-event ordering.
`taf` carries a longer accumulated tagged-release history; KernDX is newly released at v1.0 with at least one known external client engagement at the snapshot date.

**What closes the adoption-activity gap.** As production references accumulate over time — closed external user issues, downstream consumer adoption, or third-party references —
adoption activity grows. Subscribers evaluating frameworks on capability-level readiness (security defaults, code quality, test depth, capability breadth, integration coherence)
should weight broad capability coverage (see [Overview § Key Findings](Strategic%20Guide%20-%20Overview.md#key-findings)) over adoption activity. Subscribers evaluating frameworks
on "history of being used by other orgs" should weight the libraries that have accumulated that history accordingly.

### Comparison with Other Frameworks' Open-Source Journeys

| Framework                | Open-Source Journey                                                                                                                                                                                                                                                                                            |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **`taf`**                | Started as a personal project, published on GitHub under Apache 2.0. Has grown to several hundred GitHub stars at a recent fetch. A widely-referenced metadata-driven trigger framework.                                                                                                                       |
| **`apex-fluently-soql`** | Published with MIT license and dedicated documentation site. Active maintenance with 147 commits in the last 12 months and 36 tagged releases. Adopted by `rflib` — a documented downstream-consumer adoption signal.                                                                                          |
| **`nebula-logger`**      | Published early, iterated in public. MIT license. Has grown past eight hundred GitHub stars at a recent fetch, with 25+ contributors over 8 years. Featured in Trailhead and Dreamforce. The main reference among the comparable Apex libraries surveyed for community engagement on a single-purpose library. |
| **KernDX**               | BSL 1.1 licensed, 2+ years development. Published publicly on GitHub with the full developer documentation set (26 developer documents, 263 API references), public CI (`ci.yml`), issue templates, `CONTRIBUTING.md`, and a Code of Conduct. Converts to Apache 2.0 four years after release.                 |

### Bus Factor Mitigation

**Context — single-maintainer concentration is the norm across the open-source Apex framework ecosystem, not a KernDX outlier.** Most of the community libraries the team has
surveyed are effectively single-maintainer. Only the `fflib` family has genuinely distributed maintainership across multiple contributors.

What matters for risk in practice is (a) whether the maintainer is still shipping, (b) whether adopters can access source and documentation sufficient to self-maintain, and (c)
whether the codebase is scoped and tested well enough to fork cleanly. KernDX addresses (b) and (c) structurally: source is publicly available under BSL 1.1 (relicensing to Apache
2.0 after the four-year change date), 263 API references, 100% per-file Apex coverage, and AI-context files (`AGENTS.md` + `docs/Code Conventions - Guide.md`). Any team — engaged
consulting subscriber or self-installer — can fork and self-maintain on the same source. The modular-OSS "distributed risk" argument is defensible at the portfolio level (a
bus-factor event in one of several adopted libraries takes out a fraction of the stack, not all of it), but it does not mean individual components have multiple maintainers — for
most community libraries outside the `fflib` family, they do not.

The single-developer risk below is therefore not a KernDX-specific weakness; it is the default posture for nearly every Apex library outside the `fflib` family. The mitigations
that follow apply to any single-maintainer component KernDX included.

1. **Source publicly available under BSL 1.1** — clients (and any other adopter) can maintain independently from the public repository; consulting engagements include direct source
   delivery and handover support
2. **Layered documentation** — 26 developer documents (14 guides, 12 fast starts), 263 API references
3. **Standard Apex patterns** — selectors, triggers, DTOs, builders recognizable from `fflib`, `taf`, and `apex-fluently-soql`
4. **AI context files** — `AGENTS.md` (~3K tokens, tool-neutral entry point) ships at repo root and points to `docs/Code Conventions - Guide.md` (~12K tokens, canonical
   conventions); the per-module [`AI Agent Instructions`](AI%20Agent%20Instructions.md) reference (~10K tokens, in `docs/`) carries the deep framework walk-through. Together they
   document conventions, patterns, critical rules, and architectural rationale. Developers using Claude Code, Cursor, Cline, or Agentforce Vibes can generate convention-compliant
   code and diagnose framework internals without prior KernDX experience — which narrows (but does not eliminate) the tribal-knowledge gap of a single-developer framework.
5. **Exit strategy** — three paths: managed package, source deploy, or repackage under client namespace. For teams equipped with agentic AI tooling loaded against the AI-context
   files above, the deeply-adopted exit is routinely absorbable inside a single sprint (~1-2 days wall-clock) — the mitigation is concrete and AI-executable, not merely documented.
   Teams without agentic tooling should expect the conventional 1-2 week human-only effort.
6. **Metadata-driven isolation** — bypass mechanisms (`TRG_Base.bypassAction()`, `TriggerSetting__mdt.BypassExecution__c`, `FeatureFlag__mdt`) let subscribers disable problematic
   handlers or feature paths without code changes or a vendor push upgrade (see [Technical Risks](Strategic%20Guide%20-%20Risks.md#technical-risks))

**KernDX should never be adopted without a documented exit strategy.** Pre-adoption requirements to mitigate single-maintainer risk:

1. **Architecture Decision Records (ADRs)** documenting why KernDX was chosen, what alternatives were evaluated, and under what conditions the decision should be revisited
2. **Pattern documentation independent of framework** — document the architectural patterns (selectors, trigger handlers, DTOs) so knowledge survives framework removal
3. **CI enforcement rules** that validate framework conventions (naming prefixes, test coverage, ApexDoc) — reducing reliance on tribal knowledge
4. **Documented transition playbook** to a modular stack (reference [Migration Checklists](Strategic%20Guide%20-%20Operations.md#migration-checklists) for migration recipes)
5. **Named secondary maintainer** or documented ownership of `AGENTS.md`, `docs/Code Conventions - Guide.md`, and the [`AI Agent Instructions`](AI%20Agent%20Instructions.md)
   framework reference within the adopting organisation

### Licensing Considerations

| License        | Pros                                                              | Cons                                                         | Frameworks Using                              |
|----------------|-------------------------------------------------------------------|--------------------------------------------------------------|-----------------------------------------------|
| **MIT**        | Maximum adoption, minimal friction                                | No patent protection, no copyleft                            | `apex-fluently-soql`, `nebula-logger`         |
| **Apache 2.0** | Patent protection, contributor clarity                            | Slightly more restrictive                                    | `taf`                                         |
| **BSD-3**      | Simple, permissive                                                | No patent grant                                              | `fflib`, `rflib`                              |
| **BSL 1.1**    | Commercial-restriction window + guaranteed open-source conversion | Limits adoption until Change Date, community pushback common | KernDX (converts to Apache 2.0 after 4 years) |

**Current state:** KernDX uses BSL 1.1 with a 4-year change date to Apache 2.0. This protects the commercial model while guaranteeing eventual open-source availability. After the
change date, the code is Apache 2.0 licensed — permissive, with patent protection.

### Community Building Strategy

Open-source publishing is not just a license change — it requires deliberate community investment:

| Phase                 | Timeline  | Activities                                                                                      |
|-----------------------|-----------|-------------------------------------------------------------------------------------------------|
| **1. Foundation**     | Month 1-2 | Public repository, README, CONTRIBUTING.md, code of conduct, issue templates, GitHub Actions CI |
| **2. Awareness**      | Month 2-4 | Blog series ("Why KernDX"), conference submissions, Salesforce community posts                  |
| **3. Adoption**       | Month 4-8 | Unlocked package listing, video tutorials, community Discord/Slack, first external contributor  |
| **4. Sustainability** | Month 8+  | Multiple maintainers, release cadence, AppExchange listing                                      |

**Success metrics:** GitHub stars (target: 100 in year 1), external contributors (target: 3 in year 1), Salesforce community mentions.

**Comparative timeline (GitHub-star counts cited inline are recent-fetch values for the named external repositories — they will continue to drift as those projects accrue more
stars, but the order-of-magnitude profile is what's load-bearing here):** `taf` accumulated several hundred stars over 4 years. `apex-fluently-soql` accumulated low hundreds of
stars over 3 years. `nebula-logger` accumulated past eight hundred stars over 8 years. Realistic expectations for KernDX with active promotion: 50-150 stars in year 1.

### Open-Source Trade-offs

Opening the source creates new dynamics that must be managed:

| Benefit                                                   | Risk                                    | Mitigation                                               |
|-----------------------------------------------------------|-----------------------------------------|----------------------------------------------------------|
| Community contributions improve quality                   | Low-quality PRs consume maintainer time | Strict contribution guidelines, automated CI gates       |
| Public issues surface real-world bugs faster              | Issue tracker becomes support forum     | Issue templates, FAQ document, separate discussion board |
| Stars and forks build credibility                         | Forks diverge, creating confusion       | Clear versioning, active release cadence                 |
| Adoption drives documentation improvements                | Feature requests outpace capacity       | Public roadmap, "contributions welcome" labels           |
| External validation (downstream-consumer adoption signal) | Dependencies on external CI systems     | Self-hosted CI fallback, minimal external dependencies   |

**The single biggest risk of open-sourcing:** Maintainer burnout. The Salesforce Apex open-source projects with the longest sustained release cadence (`nebula-logger`, `taf`,
`apex-fluently-soql`) are each maintained by one or two primary developers. KernDX's full documentation set and AI context files reduce contributor onboarding friction, but the
framework's breadth (triggers + queries + web services + resilience + testing + LWC) means the surface area for community contributions is large.

---

[Strategic Guide (Overview)](Strategic%20Guide%20-%20Overview.md)
