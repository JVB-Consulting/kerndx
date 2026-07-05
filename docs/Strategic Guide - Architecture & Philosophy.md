---
navOrder: 12
---

# Strategic Guide — Architecture & Philosophy

> KernDX's design thesis, capabilities, Salesforce Well-Architected alignment, and open-source readiness.

Part of the [KernDX Strategic Guide](Strategic%20Guide%20-%20Overview.md).
See
also: [Adoption](Strategic%20Guide%20-%20Adoption.md) | [Operations](Strategic%20Guide%20-%20Operations.md) | [Risks](Strategic%20Guide%20-%20Risks.md) | [Glossary](Strategic%20Guide%20-%20Glossary.md) | [Personas](Strategic%20Guide%20-%20Personas.md)

---

## What this guide helps you decide

This guide is a plain-English explanation of how KernDX is built and why, plus how it lines up against Salesforce's own architecture guidance and against the open-source Apex libraries you might assemble instead. It exists so you can judge whether KernDX fits your org before you install anything. Architects and tech leads choosing a framework should read it, and so should the delivery managers and executives who need the trade-offs without reading code. Use it during framework selection, an Architecture Review Board, or a build-versus-buy decision. Throughout, "FLS" means field-level security and "CRUD" means object create, read, update, and delete permissions.

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
    - [Designed for You](#designed-for-you)
    - [Managed Package vs Source Distribution](#managed-package-vs-source-distribution)
- [Capabilities at a Glance](#capabilities-at-a-glance)
    - [Module Inventory](#module-inventory)
    - [Code Examples at a Glance](#code-examples-at-a-glance)
    - [How the Configuration Records Relate](#how-the-configuration-records-relate)
    - [KernDX by the numbers](#kerndx-by-the-numbers)
    - [Documentation Architecture](#documentation-architecture)
- [Salesforce Well-Architected Alignment](#salesforce-well-architected-alignment)
    - [Alignment Scorecard](#alignment-scorecard)
    - [The Three Pillars in Detail](#the-three-pillars-in-detail)
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

KernDX is a ready-built foundation layer for Salesforce orgs. It ships tested solutions for the plumbing every serious org needs: database access, automation triggers, logging, integrations, background jobs, data protection, and security checks. Most teams build that plumbing themselves over three to five years, picking up maintenance debt at every layer along the way (selectors, triggers, logging, web services, async jobs, masking, security enforcement). KernDX is that same foundation, designed up front by one team. You skip the build-it-yourself cycle and the debt that comes with it.

Five design choices flow from that thesis:

1. **Every feature earns its place.** Each capability is scoped to what most orgs will actually use. For example, `TST_Mock` lets you write unit tests that return canned query results without saving any data, which removes a day-one pain in testing your own org. KernDX deliberately leaves out a Mockito-style stub-and-verify testing language, because only a small group of Apex developers already know that pattern, and shipping it for everyone else would not pay off. Masking is another example: you turn it on per object rather than across every log line, because most orgs do not push payment-card data through every log entry, and a default-on scan of every entry would cost every org regardless.
2. **Easy to learn once, then reuse.** Every major part of the framework is configured the same way: you make a few short chained calls to set it up, then one call runs it and returns the result. `TST_Builder`, `QRY_Builder`, `DML_Builder`, `LOG_Builder`, `UTIL_HttpClient`, and the rest all share that shape. Your editor's auto-complete reveals the options, so learning one builder teaches you the others.
3. **It covers what 95%+ of orgs need.** KernDX ships ready-to-use, documented implementations of every core Salesforce capability, not stubs or "coming soon" placeholders. That coverage is broader than other Apex frameworks the team has surveyed. The long tail of rare, niche capabilities is deliberately left out.
4. **The pieces work together by design, not by luck.** `TRG_Base`, `SEL_Base`, `DML_Builder`, `LOG_Builder`, `ComponentBuilder`, `API_Inbound`, and `API_Outbound` share a common context as a request flows through them. That shared context is what makes the cross-module promises possible: permissions enforced by default on both reads and writes; one tracking ID following a single user action from trigger to query to outbound HTTP call (a correlation ID); sensitive data masked before anything is saved on every framework save path; and an audit log written every time a trigger safety check is turned off. These promises are *only* possible because you adopt the framework families together. A drop-in library, picked one piece at a time, cannot make those guarantees.
5. **A shortcut past years of tech debt.** Adopting KernDX trades money and time once for the integrated guarantees above, so you skip the three to five years (and the rebuild cost) of an internal platform team building the same thing.

**The cost of cohesion is the value.** To use a capability family, you extend its base class (`TRG_Base`, `SEL_Base`, `DML_Builder`, `LOG_Builder`, `ComponentBuilder`, `API_Inbound`, or `API_Outbound`). Routing your code through those base classes is the deliberate trade the framework exists to make, not a flaw: it is what lets the pieces cooperate. Drop-in libraries make no cross-module guarantees, and that is exactly what they trade away in return for independence.

## Philosophy & Design Principles

That thesis leads to six design principles. Together they set KernDX apart from two other options: a single-vendor framework that is one big locked block, and a modular stack you assemble yourself from separate libraries.

### Configuration over Code

The outcome here is that admins can change how the framework behaves without a developer and without a deployment. The way it works: every recurring architectural decision in KernDX is driven by configuration records (custom metadata) instead of hardcoded logic.

| Concern           | Metadata Type                                      | What It Controls                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
|-------------------|----------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Trigger execution | `TriggerAction__mdt` + `TriggerSetting__mdt`       | Handler registration, ordering, bypass, entry criteria (metadata-driven registration with per-event action records)                                                                                                                                                                                                                                                                                                                                                                           |
| Validation rules  | `ValidationRule__mdt` + `ValidationRuleGroup__mdt` | Formula-based validation, with a watch-only mode that runs in production and logs what it would block without blocking yet (shadow mode)                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Feature flags     | `FeatureFlag__mdt` + `FeatureFlagStrategy__mdt`    | Runtime feature toggles with extensible resolution strategies (mixed custom-metadata + hierarchy custom-setting storage; Apex, Flow, and LWC consumers)                                                                                                                                                                                                                                                                                                                                       |
| Web services      | `ApiSetting__mdt` + `ApiCredential__mdt`           | Endpoint configuration, retry, circuit breaker (after repeated failures the framework stops calling a failing system for a cool-off, then resumes)                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Mock responses    | `ApiMock__mdt`                                     | Mock-response resolution with fault simulation                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Logging           | `LogSetting__c`                                    | Log level thresholds, performance thresholds                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Data masking      | `MaskingRule__mdt` + `MaskingTarget__mdt`          | Runtime field redaction for any SObject or platform event before the record is persisted. Four masking modes (regex, JSON-key, exact-match, credit-card with Luhn validation) plus 18 built-in masking rules. Default ship set wires three active rules to four package objects through twelve `MaskingTarget__mdt` records; admins extend coverage to their own objects by adding more `MaskingTarget__mdt` records. Rules can be scoped via `MinInputLength__c` and `ApplicableFieldTypes__c`. |

So an admin can reorder trigger handlers, toggle features on or off, adjust retry strategies, and turn on debug logging, all by editing records and none of it requiring a code deployment.

### Accelerator, not a Product

The outcome that matters here: you own what you adopt, and there are no recurring fees or vendor lock-in. KernDX is consultant-owned intellectual property, not a subscription product. In practice that means:

- **No licensing fees.** No recurring costs and no per-user pricing.
- **Source is publicly available under the BSL 1.1 license.** The framework source lives on the public project repository, converts to the permissive Apache 2.0 license after a four-year change date, and is delivered as part of every consulting engagement.
- **Three exit paths.** Keep running the managed package, deploy the source straight from the public repository, or repackage it under your own namespace.
- **No vendor lock-in.** The code uses standard Apex patterns (selectors, triggers, small data-transfer classes, and builders) that any experienced developer already recognises.

The aim is for you to adopt KernDX and then own it.

**How the costs differ (described in plain terms, with no specific dollar figures):**

This guide does not put a dollar figure next to AppExchange alternatives, because their pricing swings widely with product, org size, contract terms, and negotiated discounts. Any number we printed would be a guess at best and misleading at worst. What does hold across those comparisons are three structural differences:

- **Recurring licensing.** AppExchange products usually charge ongoing fees, per org, per user, or per transaction. KernDX charges no recurring licence fee during the BSL 1.1 period, and converts to Apache 2.0 after the four-year change date.
- **Cost to leave.** Switching away from an AppExchange product is usually expensive: vendor lock-in, end-of-contract terms, data migration, and rewriting custom code for a new vendor. Leaving KernDX costs nothing in licensing terms. The source is publicly available under BSL 1.1, so you can keep using it with or without any vendor relationship. Consulting engagements add direct source delivery and handover support, but they are not required to get the source.
- **How far you can customise.** With an AppExchange product, you can only customise as far as the vendor's extension points allow. With KernDX, you can customise as far as you choose once you take ownership of the source.

For an actual dollar comparison, run the numbers against the specific AppExchange product you are weighing, using your own team's effort estimates. This guide cannot make that comparison for you.

### Integrated Stack

There are two workable ways to cover all the plumbing a serious org needs. You can assemble a **modular stack** by picking one library per capability, or you can use an **integrated framework** like KernDX. Both cover the same concerns. The difference is what happens *between* the pieces.

**What you get for free when the pieces are integrated (and what it costs):**

A worked example makes this concrete. When a trigger action fails in KernDX, `LOG_Builder` automatically records the error along with the trigger context, the correlation ID (one tracking ID that follows a single user action across triggers, queries, callouts and jobs) from the originating request, and timing. If that same trigger action calls an API through `UTIL_HttpClient`, the correlation ID rides along in the outbound request header. If a query runs in the same transaction, `QRY_Builder` logs any slow query against the same correlation ID. And if you need to switch the whole feature off, a single `FeatureFlag__mdt` record stops the trigger action from running, which means the API call and the queries never fire either.

Here is a second example. When a background chain of steps needs to call external APIs, `UTIL_AsyncChain.ApiStep` wraps any existing `API_Outbound` handler as a step in the chain with no changes to the handler. The handler's full sequence (validation, callout, retry, circuit breaker, response parsing, save, and queue persistence) runs inside the chain's background transaction, and the results flow into a shared context for the steps that follow (state carries between background transactions; there are hooks for code that runs after the transaction commits, called finalizers, plus an emergency off-switch). In a modular stack, wiring a separate async-chain library to a separate HTTP-client library would mean writing custom adapter code at every connection point.

In a modular stack, integrations like these need you to wire each boundary by hand. The trade-off runs the other way too: getting this coherence for free requires all your code to flow through the framework, which ties you more tightly to one vendor's conventions and release cycle. The right way to read this coherence is as a way to slow the gradual drift toward inconsistent code as different teams pick different patterns (see [the related discussion in the Adoption guide](Strategic%20Guide%20-%20Adoption.md#code-drift-in-multi-team-environments)). It is not, by itself, an inherent quality advantage.

| Concern                              | Modular Stack (5+ Libraries)                                                                                                      | KernDX                                                                                                                                                                                | KernDX Trade-Off                                                 |
|--------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| **Error propagation**                | Trigger exception → manually call a logger with context you assemble yourself                                                     | Automatic: trigger context, correlation ID, timing captured without developer code                                                                                                   | Opaque internals; harder to debug framework-internal behaviour   |
| **Log correlation**                  | Each library logs independently; no cross-layer correlation ID                                                                    | Correlation ID propagates: trigger → query → API → async job                                                                                                                          | Requires all code to flow through framework                      |
| **Mocking**                          | Separate mock systems for SOQL, DML, HTTP, and test setup                                                                         | Unified `TST_Mock` + `QRY_Builder.setMock()` + `API_MockFactory`: one pattern                                                                                                        | Framework-specific mock APIs; not transferable to other projects |
| **Feature flags**                    | Flag the trigger action manually; also manually disable the related query, API call, and logging                                  | `UTIL_FeatureFlag` integrates with the trigger dispatcher: one flag disables the entire feature path                                                                                 | Tight coupling between feature flags and framework internals     |
| **Security**                         | Each library handles CRUD/FLS independently; no single enforcement point                                                          | `QRY_Builder` and `DML_Builder` enforce FLS/CRUD by default on read AND write paths; turning a check off per call is recorded in an audit log; a master off-switch you flip in one configuration record (no code deploy) reverts to running without those checks | Single security implementation; defect affects all layers        |
| **Conventions**                      | Multiple API philosophies across libraries with different naming and method styles                                                | One prefix system (`QRY_*`, `TRG_*`, `API_*`, `SEL_*`, etc.) with consistent naming across all layers                                                                                 | Higher coupling to single vendor's conventions                   |
| **AI context**                       | Separate README files per library; no unified instruction file                                                                    | One `docs/Code Conventions - Guide.md` (~12K tokens) covering all modules with conventions, patterns, and anti-patterns                                                               | Single point of failure for AI context accuracy                  |
| **Async → API bridge**               | Write custom adapter to wire async chain library to HTTP client; manage data conversion, error mapping, result hand-off manually | `ApiStep` wraps any `API_Outbound` handler as a chain step: zero glue code, the whole call sequence (validate, send, retry, parse, save) preserved                                                                                 | Only possible because both frameworks are in the same package    |
| **Cross-boundary error propagation** | Logger captures whatever context the developer manually provides                                                                  | Trigger context, API request/response, correlation ID, and stack trace captured in a single structured log entry                                                                      | Diagnostic detail dependent on framework version                 |

**The trade-off:** KernDX installs all [365 classes](Strategic%20Guide%20-%20Metrics.md#package-codebase) as a managed package, but the code you do not use stays genuinely inert. It does not count against the 6 MB Apex code limit, does not show up in your own PMD scans or coverage reports, and uses zero governor limits unless it is called. A modular stack gives you control over what is *installed*, which is a real advantage. In a managed-package context, though, that distinction matters less than it first appears. The difference that does matter is convention coupling: KernDX asks all your code to flow through one vendor's patterns, while a modular stack lets you mix approaches, at the cost of keeping those approaches consistent. Neither approach is categorically better. It comes down to whether consistency or flexibility matters more to your team.

**Worked example: adding a new integration.**

| Step                                                                               | Modular Stack                                                                                                         | KernDX                                                                        |
|------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| 1. Build HTTP callout                                                              | Write custom `HttpCalloutMock`, `HttpRequest` builder                                                                 | Extend `API_Outbound`, set `defaultMockBody`                                  |
| 2. Add retry logic                                                                 | Find/write retry utility, configure per-callout                                                                       | `.withRetry(3).withExponentialBackoff()` on `UTIL_HttpClient`                 |
| 3. Add circuit breaker                                                             | Find/write circuit breaker, wire to callout                                                                           | `.withCircuitBreaker()` (already integrated)                                  |
| 4. Add logging                                                                     | Instrument with logger calls at each layer                                                                            | Automatic: framework logs request/response with correlation                  |
| 5. Add monitoring                                                                  | Build custom dashboard                                                                                                | Configure `LogSetting__c` threshold                                           |
| 6. Add test                                                                        | Write `HttpCalloutMock` implementation per library                                                                    | `API_MockFactory.forService('MyAPI').body('{}').register()`                   |
| 7. Add feature flag                                                                | Write custom feature check, wire to each layer                                                                        | `FeatureFlag__mdt` record: automatic trigger action integration              |
| 8. Add to async chain                                                              | Write custom adapter to bridge async library and HTTP client; manage data conversion, error mapping, result hand-off | `.then(new UTIL_AsyncChain.ApiStep(API_MyService.class))`: zero adapter code |
| **Total effort (illustrative; measure against your team's actual delivery data)** | **Several days per new integration**                                                                                  | **Half a day to one day per new integration**                                 |

The day-counts above are illustrative, not measured. This guide does not time each step across stacks, because that varies heavily with team experience, the surrounding codebase, and the specific integration. The structural difference is the load-bearing part: a modular stack gives you more control at each step in exchange for writing the connecting glue, while KernDX gives you faster delivery through configuration in exchange for all your code flowing through the framework. Across 10 or more integrations the gap adds up, so measure step time against your own delivery data. Step 8 is the clearest case: in a modular stack, connecting an async-chain library to an HTTP-client library needs custom adapter code for every integration, whereas in KernDX the two parts already know about each other.

**You pay the integration work once, not per library.** KernDX bundles the 17 framework areas into one managed package: one namespace, one upgrade cadence, one security-review surface, and one place that records every safety-check bypass. Assembling the same coverage from separate open-source libraries means carrying three ongoing costs that the bundle absorbs once:

- The work of making the libraries coexist (lining up namespaces, settings hierarchies, and bypass coordination across libraries).
- A separate security review for each library on every upgrade.
- Independent release schedules to track across the whole library set.

Because every KernDX capability is built on the same shared foundation (the trigger surface, logging, masking, and the bypass-audit record), you do that integration work once when you adopt the framework, rather than again for each library you add. The Adoption guide frames this at the category level; this section explains the architectural choice that makes it possible.

### 100% Coverage or Nothing

The outcome: bugs are far less likely to reach your org through a coverage gap. KernDX holds every production Apex class to 100% per-file test coverage and every Lightning (LWC) component to 95% statement and branch coverage. This is not a vanity badge. It is a practical requirement of shipping a managed package.

Salesforce only requires 75% coverage to deploy to production or upload a managed package. KernDX targets 100%, for three reasons:

- **A released managed package cannot be quietly patched.** Fixing a bug means pushing an upgrade to every org that installed it, so any gap in coverage turns straight into production risk.
- **AI coding assistants lean on the tests to check their own work.** When an AI tool changes the code, it verifies the change by running the unit tests. A gap in coverage is a gap in that safety net.
- **Closing the last few percent is where the real risk lives.** The difference between 95% and 100% is usually the error handling and edge cases that cause production incidents.

KernDX is the only Apex framework surveyed with a coverage gate enforced at every build (`coverage_gate_present = true`; the `scripts/evaluate-coverage.js` gate requires 100% Apex per-file, 95% LWC statements, 95% LWC branches, and never below the committed baseline). Other frameworks we compared report their coverage but do not block a build on it.

### AI-First Documentation

The outcome: an AI coding assistant can write code that follows KernDX conventions from the very first prompt, because the framework ships the context those tools need. KernDX maintains three such context files, each with its own job:

| File                                                    | Tokens | Location  | Purpose                                                                                                                                                  |
|---------------------------------------------------------|--------|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `AGENTS.md`                                             | ~3K    | repo root | Tool-neutral entry point for AI coding assistants: points to the canonical conventions doc (recognised by Claude Code, Cursor, Cline, Agentforce Vibes) |
| `docs/Code Conventions - Guide.md`                      | ~12K   | `docs/`   | Canonical framework conventions, code patterns, critical rules for AI code generation                                                                    |
| [`AI Agent Instructions`](AI%20Agent%20Instructions.md) | ~10K   | `docs/`   | Complete per-module framework reference for deep AI-assisted development: architecture, module inventory, conventions, worked examples                  |

These are not documentation afterthoughts. They are engineering artifacts, written so AI coding tools (Claude Code, Cursor, Cline, Agentforce Vibes) generate code that matches the framework's conventions from day one.

**Why this matters for you:** standard, machine-readable context removes guesswork for AI code generation, so the code it produces follows your conventions from the first interaction instead of after several rounds of correction.

### Trade-offs

KernDX is not the right choice for every situation. Here are the honest costs and where a specialist tool goes deeper:

| Trade-off                                                       | Context                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|-----------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Single primary developer**                                    | Bus factor of 1. Mitigated by source ownership, the full documentation stack (see [Documentation Architecture](#documentation-architecture)), standard Apex patterns, and AI context files. Single-maintainer concentration is the norm across the comparable Apex frameworks surveyed; see [Bus Factor Mitigation](#bus-factor-mitigation) for the per-framework picture.                                                                                                                                                                                                                                                                                                                                                                                                              |
| **No public community yet**                                     | You cannot search Stack Overflow for KernDX errors yet. Offset by 37 developer documents (21 guides, 16 fast starts), 269 API references, and the AI context files.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **v1.0: newly released, short public adoption history**        | First validated build packaged; testing-hardened (100% per-file Apex coverage gate, 95% LWC, 561 anon-Apex assertions in the subscriber e2e harness); publicly released under BSL 1.1 and promoted for production install, with one known external client engagement in active use at the snapshot date and public adoption still early. See [Adoption Signal Profile](#adoption-signal-profile) for what grows this track record, and [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for the current build identifier.                                                                                                                                                                                                                             |
| **Full package deployment**                                     | Managed package installs all [365 classes](Strategic%20Guide%20-%20Metrics.md#package-codebase). Unused code is genuinely inert: exempt from 6 MB limit, invisible to your org's PMD/coverage, zero governor impact. The cost is namespace prefix on references and a single (larger) upgrade cycle, not deployed footprint.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **Namespace verbosity**                                         | Your code has to carry the namespace prefix. Modern editors auto-complete it for you.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **Leaner logging surface than the logging specialist**          | [`nebula-logger`](https://github.com/jongpie/NebulaLogger) goes deeper on the logging area itself: a choice of how logs are saved (mixed transports), all seven platform log levels, per-record retention overrides and purge, and log analytics dashboards. KernDX ships four log levels on a single async transport, and its Log Console covers the browse side: past entries searchable and filterable by severity, recurring problems grouped with occurrence counts, and a per-entry drilldown that follows one operation across triggers, jobs, and callouts. The remaining differences are transport choice, level count, retention overrides, and dashboards, where the specialist still leads.                                                                                                                                                                         |
| **Deliberate non-goal: Domain / Service / Application pattern** | [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) ships the canonical Domain / Service / Application factory pattern (four factory inner classes: UnitOfWorkFactory, ServiceFactory, SelectorFactory, DomainFactory, each with a dedicated interface contract). KernDX does not ship a Domain class hierarchy. `DML_Builder` surfaces the transactional Unit-of-Work aspect (parent-child chaining, partial success, async DML) but KernDX deliberately omits service factory and Application factory patterns. Teams whose architecture requires the Service / Application factory with type-bound Selector / Domain / Unit-of-Work should install `fflib` alongside KernDX (the two coexist: `fflib` for domain modelling, KernDX for infrastructure).       |
| **Deliberate non-goal: Mockito-style mock DSL**                 | [`fflib-mocks`](https://github.com/apex-enterprise-patterns/fflib-apex-mocks) ships Mockito-style stub-and-verify (98 argument-matcher factories, verification modes `times/atLeast/atMost/between/never`, sequence verification). KernDX is absent by design on this aspect. KernDX's `TST_Mock.of(SObjectType).withOverride(field, value).build()` solves the day-one testing pain (DML-free testing without SOQL side effects) with zero learning curve. KernDX explicitly chose against shipping Mockito because the learning curve does not pay off for the small population of Apex developers who would use it, and an unused-but-shipping API surface is a maintenance liability. Teams already invested in Mockito-style mocking ship `fflib-mocks` alongside KernDX. |
| **Framework-internal system-mode selectors**                    | `QRY_Builder` and `DML_Builder` enforce FLS/CRUD by default. About three-quarters of the 44 selector classes opt back into running without those permission checks (system mode) via a documented per-selector hook (e.g., configuration reads, Chain Monitor aggregates). The opt-out is visible in the source, enforced by a build-blocking scanner rule, and reversible via a master off-switch in metadata. When you extend `SEL_Base` you inherit permission-checked reads by default; opting out requires an explicit override.                                                                                                                                                                                                                                                                                                            |
| **Per-builder bypass audit emission is roadmap, not shipped**   | Every `TRG_Base.bypass*()` mutation writes an audit log. KernDX is one of two frameworks (alongside [`rflib`](https://github.com/j-fischer/rflib)) shipping built-in trigger bypass-audit emission (`bypass_audit_signal = event`). The per-builder toggles (`QRY_Builder.withSystemMode()`, `DML_Builder.bypassSharing()`, etc.) are calls you write yourself in source, auditable via git + code review + source-grep, but do not yet emit runtime audit signals. Closing this gap (extending audit emission to the per-builder layer) is on the post-1.0 work plan.                                                                                                                                                                                                        |

### Modular in Practice

People often assume that adopting KernDX means learning the whole framework before you can use any of it. That is not how it works. You can adopt one module at a time, the same way you would add one library at a time to a modular stack. Here is how quickly each module pays off on its own:

| Feature                  | Core Class            | Time to First Use       | What You Learn                                               |
|--------------------------|-----------------------|-------------------------|--------------------------------------------------------------|
| Test Data                | `TST_Builder`         | ~30 minutes             | `.of(SObjectType).build()`: one line of code                |
| Feature Flags            | `UTIL_FeatureFlag`    | ~25 minutes             | Metadata-driven runtime toggles via `isEnabled('Flag')`      |
| Caching                  | `UTIL_Cache`          | ~10 minutes             | `.put()`, `.get()`, `.contains()`: standard cache API       |
| Data Masking             | `MaskingRule__mdt`    | ~15 minutes             | Configure masking metadata; scan in the Data Masking Advisor |
| Query Builder            | `QRY_Builder`         | ~30 minutes             | Fluent query syntax, replaces inline SOQL                    |
| Transactional DML        | `DML_Builder`         | ~30 minutes             | Transactional DML with parent-child chaining                 |
| Logging                  | `LOG_Builder`         | ~30 minutes             | `.build().error(e).emitAt('Class.method')`: one line        |
| Validation               | `UTIL_ValidationRule` | ~25 minutes             | Formula-driven validation configured as ordered metadata     |
| Selectors                | `SEL_Base`            | ~30 minutes             | Extend `SEL_Base`, define `getFields()`, inherited methods   |
| Trigger Actions          | `TRG_Dispatcher`      | ~20 minutes             | Metadata-driven trigger actions, bypass patterns             |
| Outbound APIs            | `API_Outbound`        | ~30 minutes             | Outbound web service with mock, retry, circuit breaker       |
| Inbound APIs             | `API_Inbound`         | ~30 minutes             | Inbound REST routing with router/handler separation          |
| Async Chains             | `UTIL_AsyncChain`     | ~25 minutes             | Multi-step async chains with shared context and recovery     |
| Lightning Web Components | `ComponentBuilder`    | ~30 minutes             | Composable LWC modules instead of raw `LightningElement`     |
| Full framework           | —                     | Adopt incrementally     | All modules, each building on the previous                   |

When someone compares the size of the whole framework against a single library, they are assuming a developer learns *everything at once*. No one does that, and no one does it with a modular stack either. A developer adopting a five-library modular stack also spends 1-2 weeks learning that many separate APIs, each with its own conventions.

**So the fair comparison is per-module learning time, not the total size of the framework.**

### Designed for You

Most open-source Salesforce libraries are shared by developers in their own style. The code works, but it was not built with the person installing it in mind. KernDX takes a different approach, and the table below shows what that looks like next to a typical open-source library:

| Aspect                   | KernDX                                                                                                                       | Typical Open-Source Library                             |
|--------------------------|------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| **ApexDoc coverage**     | Every class and method carries ApexDoc; PMD's `ApexDoc` rule is in the framework's own ruleset and gates every release build | Varies, often minimal or absent                        |
| **PMD compliance**       | Full: zero violations                                                                                                       | Varies, often has violations that transfer to your org |
| **Documentation layers** | 5 tiers: README → Start Here → Fast Starts → Guides → API Reference                                                          | Usually 1: README                                       |
| **AI discoverability**   | `AGENTS.md` (tool-neutral pointer) + `docs/Code Conventions - Guide.md` (canonical conventions, code patterns, and common mistakes to avoid)     | No AI context file                                      |
| **Naming conventions**   | Consistent prefixes (`QRY_*`, `SEL_*`, `TRG_*`, etc.)                                                                        | Library-specific, no cross-library convention           |
| **Code examples**        | Every guide includes copy-paste-ready examples following framework patterns                                                  | Varies                                                  |
| **Onboarding path**      | Structured: "I want to build X" → Fast Start → Guide → Reference                                                             | Self-directed: read the README                          |

When a new developer joins a team that uses KernDX, the path from "I have never seen this" to "I built my first trigger action" is written down. DORA research (2022) found that high-quality documentation strongly amplifies the performance gains of good technical practices. See [Build vs Buy: Cost Considerations](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) for the cost picture this implies, described qualitatively.

**Why this matters for your org:** when you pull in a source-distributed library that has no ApexDoc or carries PMD (static-analysis) violations, that code becomes part of your own code analysis from day one. Every PMD violation in the imported source shows up as a violation in *your* org. A managed package keeps its code sealed off, so it never appears in your code analysis at all.

### Managed Package vs Source Distribution

KernDX ships as a managed package. Open-source libraries ship as source you install directly. The two delivery models behave very differently once they are in your org, so it helps to see them side by side. Each row credits the side that wins on that factor:

| Factor                             | Managed Package (KernDX)                                                                                                                                                                                                                                                                            | Source Distribution (open-source libraries)                                                                                                                                                       |
|------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Installation**                   | 1 package URL                                                                                                                                                                                                                                                                                       | Multiple separate installs (varies by stack)                                                                                                                                                      |
| **Upgrades**                       | 1 push upgrade                                                                                                                                                                                                                                                                                      | Multiple independent upgrade cycles                                                                                                                                                               |
| **Version compatibility**          | Internally tested (one package)                                                                                                                                                                                                                                                                     | Self-managed across multiple release cycles                                                                                                                                                       |
| **Org code limit impact**          | Exempt from 6 MB org limit                                                                                                                                                                                                                                                                          | Counts against 6 MB org limit                                                                                                                                                                     |
| **Code quality in your org** | 100% per-file Apex coverage, ApexDoc on every class and method, PMD-clean, but encapsulated                                                                                                                                                                                                        | Source visible; quality varies per library                                                                                                                                                        |
| **AI context**                     | 1 set of conventions (`AGENTS.md` + `docs/Code Conventions - Guide.md`) covering all modules                                                                                                                                                                                                        | Separate README files per library (no unified AI context)                                                                                                                                         |
| **Conventions**                    | 1 naming system (`QRY_*`, `TRG_*`, `SEL_*`, etc.)                                                                                                                                                                                                                                                   | Multiple different APIs and naming patterns                                                                                                                                                       |
| **Documentation**                  | 37 developer documents (21 guides, 16 fast starts) and 269 API references, all published as a searchable documentation site                                                                                                                                                                                                                              | Per-library documentation sites                                                                                                                                                                   |
| **Customisability**                | Cannot modify managed package source directly while running the managed install; source is publicly available under BSL 1.1 and can be cloned, modified, and repackaged under your own namespace                                                                                        | Full source access: modify anything                                                                                                                                                              |
| **Namespace**                      | Your code uses namespace prefix                                                                                                                                                                                                                                                               | No namespace required                                                                                                                                                                             |
| **Community governance**           | Vendor-controlled roadmap                                                                                                                                                                                                                                                                           | Community-controlled roadmap                                                                                                                                                                      |
| **Deployment impact on your org**   | Near zero. The framework's tests do not run during your deployments (managed package tests are isolated unless `RunAllTestsInOrg` is forced). Installing or upgrading a 2GP is comparable to heavy managed packages already standard in enterprise pipelines (Financial Services Cloud, CPQ). | Framework tests run alongside your own code on every deployment, inflating CI/CD windows. Adding 100+ framework test classes to your org's `RunLocalTests` scope compounds with org growth. |

**The trade-off:** a managed package gives you consistency, sealed-off code, and simpler operations, in exchange for less ability to customise. Source distribution gives you maximum flexibility, in exchange for the maintenance burden, the variation in code quality, and the operational complexity of carrying that code yourself. KernDX softens the customisability cost because its source is publicly available under BSL 1.1: if you need to change the framework, you can clone the public repository, modify it under the licence, and repackage it under your own namespace.

---

## Capabilities at a Glance

This part of the guide is the at-a-glance inventory: what ships, how much of it, and the one-line example for each module. Skim it to see the breadth; the developer guides cover each module in depth.

### Module Inventory

The table below lists every module, how many classes it contains, what it does, and the class you start from. The competitive depth notes (typed subselects, the inbound-REST surface, the pluggable feature-flag strategy, and so on) are facts about each module's reach.

<details><summary>Every module: class count, purpose, and the class you start from</summary>

| Module                  | Classes | Purpose                                                                                                                                                                                                                                                                                                                    | Key Class                                                              |
|-------------------------|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| **Query Framework**     | 7       | Fluent SOQL builder with caching, pagination, mocking (extensive query API; no string concatenation needed)                                                                                                                                                                                                                | `QRY_Builder`                                                          |
| **Selector Framework**  | 44      | Object-specific query layer with default fields (selector pattern in the Query Builder family: typed subselects, semi-join + anti-join builder methods, unbounded subselect chain depth)                                                                                                                                  | `SEL_Base`                                                             |
| **DML Framework**       | 3       | Transactional DML with parent-child chaining and partial-success control: register related records and save them together so they all commit or all roll back (a lightweight Unit of Work surface; all five DML operations). See [Trade-offs → Deliberate non-goals](#trade-offs) for why KernDX does not ship the full Domain/Service/Application pattern. | `DML_Builder`                                                          |
| **Trigger Framework**   | 4       | Metadata-driven trigger dispatch with per-event action records and four-level bypass                                                                                                                                                                                                                                       | `TRG_Dispatcher`, `TRG_Base`                                           |
| **Web Services**        | 10+     | Inbound REST routing with two-class separation (sole framework covering this surface) plus outbound HTTP with retry, circuit breaker, queue                                                                                                                                                                                | `API_Outbound`, `API_Inbound`                                          |
| **Validation**          | 3       | Formula-driven declarative validation (code-driven validation framework where Apex-evaluated rules are configured as custom metadata and grouped for ordered execution)                                                                                                                                                    | `UTIL_ValidationRule`                                                  |
| **Feature Flags**       | 3       | Pluggable evaluation strategies (only Apex framework surveyed shipping a resolution strategy you can plug your own logic into)                                                                                                                                                                                                         | `UTIL_FeatureFlag`                                                     |
| **Logging**             | 6       | Async structured logging via platform events, with a live event/streaming monitor and org-usage metrics console                                                                                                                                                                                                            | `LOG_Builder`, `CTRL_EventMonitor`                                     |
| **Test Infrastructure** | 5       | Builders, factories, mocks                                                                                                                                                                                                                                                                                                 | `TST_Builder`, `TST_Mock`                                              |
| **Resilience**          | 3       | Circuit breaker, retry, cache                                                                                                                                                                                                                                                                                              | `UTIL_CircuitBreaker`, `UTIL_Retry`, `UTIL_Cache`                      |
| **Security**            | 2       | FLS/CRUD enforced by default on reads AND writes; encryption default-on; sharing control                                                                                                                                                                                                            | `QRY_Builder`, `DML_Builder`, `UTIL_SessionEncryption`                 |
| **Data Masking**        | 5       | Write-time field redaction via the trigger dispatcher (on by default), plus the Data Masking Advisor console for scanning, deployable configuration, and a regulated-field inventory                                                                                                                        | `UTIL_FrameworkMasker`, `CTRL_MaskingAdvisor`                          |
| **HTTP Client**         | 1       | Fluent HTTP facade                                                                                                                                                                                                                                                                                                         | `UTIL_HttpClient`                                                      |
| **Async Processing**    | 7       | Multi-step chain orchestration with shared context across transactions and finalizer-based recovery                                                                                                                                                                                                                        | `UTIL_AsynchronousJobLauncher`, `UTIL_AsyncChain`, `CTRL_ChainMonitor` |
| **LWC**                 | 67      | Component library with five built-in modules and registry-dispatch activation (only Apex framework surveyed that ships a base component with the common LWC wiring already built in for you to extend)                                                                                                                                                      | `ComponentBuilder`                                                     |
| **Utilities**           | 10+     | String, Date, Number, Set, List, Map, Schema (39 string helpers; null-safe by default)                                                                                                                                                                                                                                     | `UTIL_*`                                                               |
| **Flow Invocables**     | 16      | Flow integration points                                                                                                                                                                                                                                                                                                    | `FLOW_*`                                                               |

</details>

### Code Examples at a Glance

Each module can be summarised by its most common one-liner:

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

### How the Configuration Records Relate

The configuration-over-code approach above rests on 15 custom metadata types (the configuration-record types admins edit). The diagram shows how those records are laid out and relate to each other:

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

### KernDX by the numbers

| Metric                     | Value                                                                                                                                                                                                                                                                                                         |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Apex classes               | [365 (190 production, 175 test)](Strategic%20Guide%20-%20Metrics.md#package-codebase)                                                                                                                                                                                                                                                                                |
| Selector classes           | 44 (most extend `SEL_Base`)                                                                                                                                                                                                                                                                                     |
| Flow invocable classes     | 16 (`FLOW_*`)                                                                                                                                                                                                                                                                                                 |
| Test methods               | ~6,600 (~3,900 Apex + ~2,750 Jest)                                                                                                                                                                                                                                                                            |
| Test coverage              | 100% per-file Apex, 95% statement/branch LWC (enforced at every release build)                                                                                                                                                                                                                                |
| Lines of code              | ~255K (~96K production Apex, ~97K Apex tests, ~22K LWC, ~40K Jest)                                                                                                                                                                                                                                            |
| LWC components             | 67                                                                                                                                                                                                                                                                                                            |
| Custom objects             | 10                                                                                                                                                                                                                                                                                                            |
| Custom metadata types      | 15                                                                                                                                                                                                                                                                                                            |
| Platform events            | 1                                                                                                                                                                                                                                                                                                             |
| Pre-built metadata records | 62                                                                                                                                                                                                                                                                                                            |
| Source API version         | 67.0 (pinned in `sfdx-project.json`)                                                                                                                                                                                                                                                                          |
| Latest packaged version    | See [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for the current build identifier; KernDX is v1.0 with the first validated build packaged and testing-hardened (see [Open-Source Readiness](#open-source-readiness) for milestone context and adoption-history caveat) |
| Documentation              | 37 developer documents (21 guides, 16 fast starts), 269 API reference pages                                                                                                                                                                                                                                   |

### Documentation Architecture

The documentation is layered so you can enter at the right level for what you are doing, from a first-day walkthrough up to per-class API reference:

| Layer              | Documents                                                                                                                                | Purpose                                                                                                |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| **Onboarding**     | Start Here                                                                                                                               | First-day walkthrough building one implementation per module                                           |
| **Task-Oriented**  | 16 Fast Starts                                                                                                                           | Focused guides: "Build X in 30 minutes"                                                                |
| **Full Framework** | 21 Guides                                                                                                                                | Full framework capabilities, patterns, best practices                                                  |
| **Reference**      | 269 API References                                                                                                                       | Auto-generated ApexDoc for every class, method, property                                               |
| **Strategic**      | This document                                                                                                                            | Architecture, philosophy, and adoption guidance                                                        |
| **AI Context**     | `AGENTS.md` (repo root); `docs/Code Conventions - Guide.md` (canonical); [AI Agent Instructions](AI%20Agent%20Instructions.md) (`docs/`) | Tool-neutral pointer + canonical conventions + per-module framework reference for AI coding assistants |

> For current statistics and verification commands, see [Metrics](Strategic%20Guide%20-%20Metrics.md).

---

## Salesforce Well-Architected Alignment

Salesforce publishes its own guidance for building solid solutions, the [Salesforce Well-Architected Framework](https://architect.salesforce.com/well-architected/overview), organised around three pillars: Trusted, Easy, and Adaptable. This section maps KernDX against that guidance so you can see where it helps and where it does not. It is written for Architecture Review Boards and executive-level discussions.

> **Why this matters:** executives already know the "Well-Architected" brand from AWS and Azure. Mapping KernDX to Salesforce's version of it gives you a recognised vocabulary for validating the architectural choice in front of an Architecture Review Board or a leadership team.

> **One important distinction:** Well-Architected describes the *outcomes* to aim for. KernDX provides *implementation patterns* that help you reach them. Adopting the framework speeds up that alignment. It does not replace architectural judgement.

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
│ EASY        │ Engaging     │ ⚠️ PARTIAL │ 67 LWC components; UI/UX out of scope    │
│ ADAPTABLE   │ Resilient    │ ✅ ALIGNED │ LOG_Builder, correlation, TST_Builder    │
│ ADAPTABLE   │ Composable   │ ✅ ALIGNED │ Managed package, namespace, metadata     │
└─────────────┴──────────────┴───────────┴─────────────────────────────────────────┘

OVERALL: 6 of 8 behaviours ALIGNED │ 2 PARTIAL (Compliant by regulatory scope;
         Engaging by UX-design scope)
```

### The Three Pillars in Detail

The tables below take each pillar in turn. For every Well-Architected requirement, they show what KernDX actually provides and how default-on that behaviour is. Where the framework does not cover something, the gap is stated plainly rather than glossed over.

#### Pillar 1: Trusted

**Secure: ALIGNED**

| Well-Architected Requirement  | KernDX Implementation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Posture                                                                                                                                           |
|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| Enforce CRUD/FLS at query/DML | `QRY_Builder` and `DML_Builder` enforce FLS/CRUD by default on read AND write paths. KernDX is the only Apex framework surveyed with FLS/CRUD enforced by default on read AND write simultaneously, with an org-wide master off-switch you can flip in an incident without a deployment (a kill-switch) and a per-call bypass that writes an audit log. The `.withSystemMode()` and `SEL_Base.systemModeRequired()` opt-outs are authored by you in source (auditable via git + code review) for framework selectors that need system-mode (configuration reads, Chain Monitor aggregates). A CI-blocking scanner rule fails builds on any undeclared access mode. The metadata kill-switches are emergency reversion: a single-record metadata deploy reverts to system-mode without touching Apex.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | default-on                                                                                                                                        |
| Encrypt sensitive data        | `UTIL_SessionEncryption` (AES256 with automatic key management).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | default-on (keys issued per session, no opt-in switch)                                                                                            |
| Control record sharing        | Sharing proxy in `QRY_Builder` (`.withSharing()`, `.bypassSharing()`); `UTIL_Sharing` for programmatic grants. Classes still must declare `with sharing` / `inherited sharing` / `without sharing` explicitly (KernDX's own convention rules require this).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | default-on at the class declaration layer; per-query overrides are calls you write yourself in source (auditable via git + code review) |
| Prevent data exposure         | `MaskingRule__mdt` + `MaskingTarget__mdt`: a runtime field redaction framework intercepting before-insert / before-update / before-publish on any SObject or platform event (masks via regex, Luhn for payment-card detection, literal-string, and JSON-key matching; four masking modes; three failure actions; 18 built-in masking rules; caller-class scoping). Sensitive content is rewritten in memory so the database never stores the raw value: redaction happens before the record is saved, which is different from Salesforce's `stripInaccessible` that removes fields the user cannot see after a query has already run. Ships with 18 masking-rule records (3 active by default plus 15 inactive templates) and twelve masking-target records wildcarded onto four high-risk package objects; admins extend coverage to their own org's objects via additional masking-target records. **Per-SObject opt-in is a deliberate design trade-off:** most orgs do not push credit-card data through every log emit, and a default-on regex tax on every persistence path is paid by every org regardless. This is not a default-on-versus-opt-in choice: KernDX masking is itself default-on. Secret, payment-card and credit-card rules redact all four high-risk diagnostic objects, log events included, before persistence with no configuration. `nebula-logger`'s masking is likewise default-on but confined to its own log payload and cannot reach an arbitrary SObject. KernDX defaults to the universally-relevant rules (card numbers, secrets) and ships 15 more tested rules (spanning US and international identifiers) that activate on any object or field, so you enable exactly what your jurisdiction and data warrant. The Data Masking Advisor scans your own custom objects for regulated fields that have no masking target and exports a regulated-field inventory, so the per-SObject opt-in is discoverable rather than silent. | default-on at the kill-switch level; per-SObject opt-in via `TriggerSetting.ApplyMasking__c`                                                      |
| Audit bypass usage            | Every trigger-bypass call writes a structured audit log carrying the correlation ID so bypasses are traceable across triggers, async chains, and API calls (`bypass_audit_signal = event`; bypass works at four levels: per-object, per-action, per-flow, framework-wide). KernDX is one of two frameworks (alongside `rflib`) shipping built-in trigger bypass-audit emission. Per-builder toggles (`QRY_Builder.withSystemMode()`, `DML_Builder.bypassSharing()`) are calls you write yourself in source (auditable via git + code review + source-grep) but do not yet emit runtime audit signals; extending audit emission to the per-builder layer is on the post-1.0 work plan.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | default-on at the trigger surface                                                                                                                 |

**v1.0 security posture.** Out of the box, KernDX enforces FLS and CRUD permissions by default on both queries and DML; writes a bypass audit log at the trigger surface; rejects an inbound request that replays an old one with changed content (it compares a hash of the body and returns HTTP 409, a capability KernDX uniquely ships among those surveyed); and blocks any build whose code leaves an access mode undeclared. For framework-internal read paths, the documented opt-out is a per-selector system-mode hook. The emergency reversion is a metadata kill-switch (a master off-switch you flip in one record, with no code deploy, if you hit unexpected permission blocks). Encryption, sharing at the class-declaration layer, and masking all stay default-on wherever they ship.

**Security defaults across the comparable Apex frameworks surveyed.** Four settings tend to drive defect rate: the sharing default, the access-mode default, whether bypasses are audited, and whether inbound requests are trusted by default. KernDX defaults to the secure choice on all four. Among the frameworks surveyed, `rflib` covers more of this ground than any other: it ships partial bypass-audit and partial FLS-enforced reads, but no surface for inbound trust or FLS-enforced DML. KernDX ships a complete secure-default implementation across all four signals. One honest nuance remains: for your own custom objects, masking is opt-in (a deliberate performance trade-off, explained in the *Prevent data exposure* row above). The Data Masking Advisor flags any custom object that holds regulated data but has no masking target, so that opt-in is discoverable, not silent. The repository ships a top-level `SECURITY.md` documenting how to report a vulnerability.

**Compliant: PARTIAL**

| Well-Architected Requirement | KernDX Implementation                                                                                                                                                                                                               | Gap                                                                                                                                                                                                                                |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Audit trail                  | `LOG_Builder` with transaction correlation, persistent `LogEntry__c` records                                                                                                                                                        | Regulatory-specific audit requirements (SOX, HIPAA) need dedicated controls                                                                                                                                                        |
| Permission enforcement       | CRUD/FLS enforced by default on `QRY_Builder` / `DML_Builder`; `.stripInaccessible()` and feature flags for conditional access                                                                                                      | Regulatory compliance programmes (GDPR, PCI-DSS) are policy, not infrastructure.                                                                                                                                                   |
| Data governance              | Field-level security enforcement default-on; runtime field redaction via the data masking framework (any SObject text field, declarative rules, in-memory rewrite before DML; default-on at kill-switch level, per-SObject opt-in) | Data classification, retention policies, right-to-erasure, and regulation-specific mapping of fields to rules (GDPR Art. 25, PCI-DSS Req. 3, HIPAA §164.514, CCPA/CPRA §1798.100(c)) are your policy, not framework-provided |

*Why the gap exists:* regulatory compliance needs domain-specific controls, such as data-classification policies, retention rules, and consent management, that no technical framework can provide generically. What KernDX gives you is the infrastructure that compliance programmes are built on: audit logging, permission enforcement, and encryption.

**Reliable: ALIGNED**

| Well-Architected Requirement     | KernDX Implementation                                                                                               |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------|
| Handle external service failures | `UTIL_CircuitBreaker` (three-state: CLOSED, OPEN, HALF_OPEN); `UTIL_Retry` (linear/exponential backoff with jitter) |
| Ensure data consistency          | `DML_Builder` with transactional integrity; `API_Outbound` transactional outbox pattern                             |
| Monitor system health            | `LOG_Builder` with configurable performance timers; `LogSetting__c` for log level thresholds                        |
| Cache appropriately              | `UTIL_Cache` with AUTO mode (Session-to-Org fallback), bulk operations, compression for payloads >4KB               |
| Correlate across boundaries      | Transaction correlation IDs across sync/async boundaries; W3C `traceparent` header propagation (`traceparent` is the HTTP-header form that carries that tracking ID across services)                      |

#### Pillar 2: Easy

**Intentional: ALIGNED**

| Well-Architected Requirement | KernDX Implementation                                                                                                                                                                                                                            |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Consistent naming            | Standardised prefixes: `SEL_*`, `TRG_*`, `API_*`, `QRY_*`, `DML_*`, `LOG_*`, `UTIL_*`, `TST_*`, `FLOW_*`                                                                                                                                         |
| Self-documenting code        | ApexDoc required on all classes and methods; `@example` with valid code                                                                                                                                                                          |
| Discoverable architecture    | 37 developer documents (21 guides, 16 fast starts), 269 API references; `AGENTS.md` + `docs/Code Conventions - Guide.md` (repo root) + [`AI Agent Instructions`](AI%20Agent%20Instructions.md) (framework reference) for AI-assisted development |
| Metadata-driven behaviour    | 15 custom metadata types controlling triggers, post-trigger actions, validation, feature flags, web services, mocking, masking, async jobs, field sets                                                                                                                 |

**Automated: ALIGNED**

| Well-Architected Requirement   | KernDX Implementation                                                                                                              |
|--------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Reduce boilerplate             | `TRG_Dispatcher`: one-line trigger body; `SEL_Base`: inherited query methods; `TST_Builder`: auto-populated test records        |
| Eliminate manual orchestration | Metadata-driven trigger ordering, validation rule grouping, API retry strategies                                                   |
| Enforce quality gates          | 100% per-file Apex coverage gate; PMD compliance; secret scanning in CI; no inline SOQL; no `System.debug`                                                |
| Standardise testing            | `TST_Builder` (data creation), `TST_Mock` (query interception), `TST_Factory` (metadata records), `API_MockFactory` (HTTP mocking) |

**Engaging: PARTIAL**

| Well-Architected Requirement | KernDX Implementation                                                                                                                                                                                                                                                          | Gap                                                                                        |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| Delightful user experiences  | [67 LWC components](Strategic%20Guide%20-%20Metrics.md#lwc-components) with `ComponentBuilder` module system (five built-in modules: navigation, notification, lightning-message, controller, flow-navigation, with opt-in activation; clear error messages when modules aren't enabled; rejects invalid modules at registration) | Visual design, interaction patterns, and UX research are design authority responsibilities |
| Accessible interfaces        | Lightning base components used throughout                                                                                                                                                                                                                                      | WCAG compliance requires dedicated accessibility testing                                   |

#### Pillar 3: Adaptable

**Resilient: ALIGNED**

| Well-Architected Requirement | KernDX Implementation                                                                                  |
|------------------------------|--------------------------------------------------------------------------------------------------------|
| Signaling strategy           | `LOG_Builder` instrumentation across triggers, queries, APIs with structured context                   |
| Testing strategy             | `TST_Builder` + `TST_Mock` for data-driven testing; `API_MockFactory` for HTTP mocking                 |
| Continuity strategy          | Circuit breaker prevents cascading failures; dead letter queue (messages that fail after all retries are set aside for inspection, not silently lost) preserves failed API calls for recovery |
| Correlation tracking         | Transaction IDs across async boundaries; W3C `traceparent` for distributed tracing                     |

**Composable: ALIGNED**

| Well-Architected Requirement | KernDX Implementation                                                                                             |
|------------------------------|-------------------------------------------------------------------------------------------------------------------|
| Modular architecture         | Managed package with namespace isolation; each module (triggers, queries, DML, web services) usable independently |
| Configuration over code      | 15 custom metadata types; `ClassTypeResolver__mdt` for type resolution                                            |
| External integration         | Platform event logging lets outside monitoring tools see what your code actually did in production (a searchable, kept record); `API_Outbound` for structured callouts         |

### Framework Scope Clarification

It is worth being explicit about where the framework's job ends and yours begins. KernDX provides infrastructure patterns. It does not replace the governance your organisation has to run itself. The table shows that split, area by area:

| Area                    | KernDX Provides                                                                | External Input Required                                                    |
|-------------------------|--------------------------------------------------------------------------------|----------------------------------------------------------------------------|
| **Architecture Review** | Consistent patterns, documented conventions                                    | ARB decisions, technology selection, integration strategy                  |
| **Compliance**          | Audit logging, encryption, CRUD/FLS enforcement                                | Regulatory policy definition, data classification, consent management      |
| **Design Authority**    | [67 LWC components](Strategic%20Guide%20-%20Metrics.md#lwc-components), `ComponentBuilder` pattern                                  | UI/UX design, accessibility audits, user research                          |
| **Platform Governance** | Managed package versioning, namespace isolation                                | Org configuration, limits monitoring, release management, sandbox strategy |
| **Security Operations** | Write-time data masking (configurable per object), session encryption, permission enforcement | Penetration testing, threat modelling, incident response procedures         |

### Well-Architected Risks and Considerations

No framework is risk-free. The table below names the honest risks of adopting KernDX, how serious each one is, and what reduces it:

| Risk                                                            | Impact | Mitigation                                                                                                                                                                                                                                                                                                                                                                                                                               |
|-----------------------------------------------------------------|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Over-reliance on framework without governance                   | High   | Framework provides patterns, not policy. Establish Architecture Review Board and governance processes independently.                                                                                                                                                                                                                                                                                                                     |
| Framework-internal system-mode selectors (auxiliary read paths) | Low    | `QRY_Builder` and `DML_Builder` enforce FLS/CRUD by default. About three-quarters of the 44 selector classes opt back into system-mode via a documented per-selector hook: declarations are calls in source, auditable via git + code review, and enforced by a CI-blocking scanner rule. When you extend `SEL_Base` you inherit FLS-enforced reads by default. Metadata kill-switches are emergency reversion without a code deploy. |
| Per-builder bypass audit emission is roadmap, not shipped       | Low    | KernDX ships bypass-audit emission at the trigger surface; per-builder toggles emit no runtime audit signal yet. Your git history + code review + source-grep is the post-hoc audit infrastructure for the per-builder layer until audit emission extends down.                                                                                                                                                                  |
| Compliance gaps if only using KernDX                            | Medium | KernDX provides infrastructure for compliance (logging, encryption, masking, default-on FLS/CRUD enforcement). Layer regulatory controls on top.                                                                                                                                                                                                                                                                                         |
| Well-Architected alignment interpreted as certification         | Low    | "Aligned" means KernDX supports the prescribed outcomes. It does not constitute Salesforce certification or endorsement.                                                                                                                                                                                                                                                                                                                 |

### Well-Architected Decision Matrix

Use this matrix to turn the analysis above into a decision. Find the question that matches your situation and follow the "If Yes" or "If No" column:

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
║   Engaging                     │ ⚠️  PARTIAL       │ 67 LWC components; UI/UX    ║
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

If you want the one-table takeaway for each pillar, this is it: the main strength on the left, and the honest gap on the right.

| Pillar        | KernDX Strength                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | KernDX Gap                                                                                         |
|---------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| **Trusted**   | FLS/CRUD enforced by default on `QRY_Builder` AND `DML_Builder` (KernDX is the only Apex framework surveyed with FLS-by-default on read AND write); encryption default-on (AES256 with automatic key management); runtime masking on any SObject or platform event (four masking modes, 18 built-in rules, three failure actions, caller-class scoping); every trigger bypass writes an audit log; an inbound request that arrives twice returns the first result instead of re-running, but a repeat that reuses the same key with a different body is rejected with HTTP 409 rather than silently masking the change (KernDX uniquely ships this among those surveyed); sharing declared explicitly by convention. On the four signals that drive defect rate (sharing, access mode, bypass audit, inbound trust), KernDX defaults to the secure setting on all four. | Regulatory compliance policy is organisational, not framework; per-builder bypass audit is roadmap |
| **Easy**      | Consistent conventions, metadata-driven config, full documentation stack (see [Documentation Architecture](#documentation-architecture)), AI context                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | UI/UX design patterns require design expertise                                                     |
| **Adaptable** | Circuit breaker, retry, dead letter queue, correlation tracking, managed package isolation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Platform governance (org config, limits monitoring) is operational                                 |

---

## Security Benchmark for Salesforce Alignment

The Security Benchmark for Salesforce (SBS) is an independent, practitioner-built security checklist for Salesforce orgs, modelled on the CIS style. It defines **54 yes-or-no controls across 12 domains** (Foundations, OAuth Security, Integrations, Access Controls, Authentication, Code Security, Customer Portals, Data Security, Deployments, Security Configuration, File Security, and Event Monitoring). Each control is rated Critical, High, or Moderate and tagged to regulatory frameworks (HIPAA, GDPR, NIST, CCPA/CPRA, SOC 2, ISO 27001). It is governed by neither Salesforce nor KernDX. This section maps KernDX against it, and is written for GRC teams, auditors, and Architecture Review Boards. The benchmark itself lives [on GitHub](https://github.com/Salesforce-Security-Benchmark).

> **Why this matters:** the SBS is the checklist a growing number of security teams and auditors run an org against. Mapping KernDX to it shows you, control by control, exactly where the framework hands you a working mechanism or audit-ready evidence, and, just as importantly, where it does not, so no one mistakes installing a framework for having a compliant org.

> **One important distinction:** the SBS audits *orgs*, not packages. KernDX ships mechanisms and evidence for specific controls. It **cannot make an org compliant**, and most SBS controls stay your configuration and your process. A posture of *"provides the mechanism for"* or *"provides evidence for"* never means *"complies with"*. Running the control, certifying it, and keeping it certified all stay with you.

**Audience Guide:**

| Reader                     | Start Here                                          |
|----------------------------|-----------------------------------------------------|
| **GRC & Compliance teams** | SBS Alignment Scorecard, What Remains Yours         |
| **Auditors**               | Where KernDX Provides a Mechanism (the evidence rows) |
| **ARB Reviewers**          | Full section review                                 |
| **Platform Leads**         | What Remains Yours, native-tool pointers            |

### SBS Alignment Scorecard

KernDX provides a working mechanism or audit-ready evidence for **15 of the 54 controls**. The remaining **39 are org configuration and process** that no managed package can own for you. Nothing here continuously monitors your org's security posture. KernDX surfaces problems about *its own* configuration or a KernDX capability and ships the fixes (the masking engine, the durable logger, the pipeline gates). The one place it reaches into your own objects is the on-demand Data Masking Advisor scan and its inventory export, which you run yourself. Watching your org's overall posture is left to the tools built for that job: the native Salesforce Security Health Check, Salesforce Optimizer, Salesforce Shield / Event Monitoring, and AppOmni.

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

Each row states a posture, which means one of three things. *Provides the mechanism for*: KernDX ships the working control. *Provides evidence for*: KernDX produces an artifact your process then uses. *Provides guidance for*: KernDX documents the secure pattern. None of the three means *complies with*.

**Code Security**

| SBS Control                          | KernDX Mechanism                                                                                                                                                              | Posture                                                                       |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| CODE-001 Mandatory peer review       | The CI pipeline's ingress gate requires approving reviews before a merge, with a bypass that raises an alert.                                                                 | provides the mechanism for                                                    |
| CODE-002 Pre-merge static analysis   | The Salesforce Code Analyzer gate runs PMD's Apex security rules (SOQL injection, CRUD/FLS, sharing) alongside the KernDX rule set and blocks the pull request on a high-severity finding. | provides the mechanism for                                        |
| CODE-003 Persistent Apex logging     | `LOG_Builder` / `LOG_Engine` write durable `LogEntry__c` records with transaction correlation.                                                                               | provides the mechanism for                                                    |
| CODE-004 Prevent sensitive data in logs | The data-masking engine runs on by default and redacts the framework's log and diagnostic objects before they persist; the Data Masking Advisor scans your own custom objects and flags regulated fields that have no masking. | provides the mechanism for (custom objects need a masking target; the Advisor finds the gaps) |

**Deployments**

| SBS Control                                       | KernDX Mechanism                                                                                                                                                            | Posture                          | Where it stops                                                  |
|---------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------|----------------------------------------------------------------|
| DEP-003 Monitor unauthorized metadata modifications | Source-driven deployment discipline is KernDX's half: deterministic builds, a refusal to build from a dirty tree, and the bypass-alert pair.                              | provides part of the mechanism for | Org-wide config-drift detection is Salesforce Shield / AppOmni, not a package |
| DEP-004 Source-driven development                 | Package and distribution builds are deterministic and refuse to run against an uncommitted working tree.                                                                    | provides the mechanism for       | —                                                              |
| DEP-005 Secret scanning                           | The pipeline ships a Salesforce-aware secret-scan command and a GitHub Actions check (blocking in CI, advisory on the workstation), and the same pattern set gates KernDX's own release build. | provides the mechanism for | Enable native push protection too, and rotate any committed secret |

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
| CPORTAL-001 Parameter-based record access in Apex | `QRY_Builder` and `DML_Builder` run with the current user's read/write permissions and record sharing enforced (`USER_MODE`) by default, so a portal request is checked against that user's access; the Security guide documents the insecure-direct-object-reference pattern to avoid (where a request can reach a record it shouldn't by guessing its ID). | provides the mechanism and guidance for |
| CPORTAL-004 Parameter-based record access in Flows | The Security guide documents the Flow input-variable hygiene pattern for portal-invoked flows.                                                                                        | provides guidance for                |

### What Remains Yours

These controls are org configuration and human process. A managed package cannot own your org's identity, configuration, backup, or deployment access. At most it can point you at the native tool that does. Read this list as a checklist for your own org, not as a list of things KernDX is missing.

| Domain                 | Controls you own                                                                                                                                                            | Where it lives                                                                                                                              |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| OAuth Security         | OAUTH-001/002/003/004: connected-app install approval, access scoping, criticality classification, vendor due diligence                                                   | Org setup, plus the native Security Health Check / Optimizer / AppOmni                                                                      |
| Integrations           | INT-001 browser-extension governance · INT-002 Remote Site inventory · INT-004 retain API-usage logs                                                                       | Device/network policy; native Health Check / AppOmni; Event Monitoring. `ApiCall__c` records KernDX-routed callouts only, not org-wide API usage |
| Access Controls        | ACS-001…009, ACS-011, ACS-012: permission-set model, API-enabled and super-admin justification, custom profiles, non-human-identity inventory, change governance, login-hours classification | Org access review (native Health Check / Optimizer / AppOmni) and the Setup Audit Trail. KernDX deliberately does not host your org's identity inventory |
| Authentication         | AUTH-001/002/003/004: SSO enforcement, SSO-bypass governance, login-IP ranges, strong MFA                                                                                 | Org identity configuration                                                                                                                 |
| Customer Portals       | CPORTAL-002 guest-user record access · CPORTAL-003 portal-exposed Apex/Flow inventory · CPORTAL-005 portal penetration testing                                             | Org configuration and your application-security program (keep `.withUserMode()` on guest-facing queries)                                    |
| Data Security          | DATA-003 tested backup and recovery                                                                                                                                        | A backup and recovery solution (KernDX ships no org backup)                                                                                 |
| Deployments            | DEP-001 deployment identity · DEP-002 high-risk-metadata prohibited list · DEP-006 CLI token expiry                                                                        | Org IAM and your deployment platform's governance                                                                                          |
| Security Configuration | SECCONF-001/002: Health Check baseline and remediation cadence                                                                                                            | The **native** Salesforce Security Health Check. KernDX's own Health Check verifies KernDX configuration (cache, masking posture, scheduled jobs); it is not the org-wide security baseline |
| File Security          | FILE-001/002/003: public-link expiry, passwords, periodic review                                                                                                          | Org file-sharing configuration                                                                                                             |
| Event Monitoring       | MON-001/002/003/004/005: enable and retain event logs, monitor suspicious logins and API activity, API-versus-limit monitoring                                            | Salesforce Shield / Event Monitoring and your SIEM. The Event Monitor surfaces KernDX-routed callouts for transparency; org-wide monitoring is Shield's |

### SBS Summary Scorecard

**Overall: KernDX provides a mechanism or evidence for 15 of the 54 SBS controls; the other 39 are org configuration and process.** The help is concentrated exactly where a framework can legitimately help, namely your code, your build pipeline, and your data, and absent where the control is purely org identity or configuration. KernDX produces evidence for these controls. It does not certify them, and an install is not a compliant org.

| Domain                 | KernDX posture                                                                         |
|------------------------|----------------------------------------------------------------------------------------|
| Code Security          | ✅ Mechanism: all four controls (peer review, static analysis, logging, log masking)   |
| Deployments            | ✅ Mechanism: source-driven builds + secret scanning (org-drift monitoring is yours)   |
| Data Security          | ✅ Mechanism: masking detection + regulated-field inventory (backup is yours)          |
| Foundations            | 🟡 Evidence: feeds your security system of record                                      |
| Integrations           | 🟡 Evidence: KernDX's own credentials (org-wide inventory is yours)                    |
| Access Controls        | 🟡 Evidence: access-review primitives (the other 11 controls are yours)               |
| Customer Portals       | 🟡 Guidance: patterns for avoiding records reached by guessing an ID (IDOR) and for keeping Flow inputs clean, on top of `USER_MODE` reads being on automatically |
| OAuth Security         | ⚪ Yours: connected-app governance (org configuration)                                 |
| Authentication         | ⚪ Yours: SSO and MFA (org identity)                                                   |
| Security Configuration | ⚪ Yours: the native Salesforce Security Health Check                                  |
| File Security          | ⚪ Yours: public-link controls (org configuration)                                     |
| Event Monitoring       | ⚪ Yours: Salesforce Shield / Event Monitoring                                         |

**Which edition this maps to.** This reflects the benchmark's current published control set: 54 controls across the 12 domains listed above. The Security Benchmark for Salesforce is still pre-1.0 and evolving, so KernDX treats re-mapping on each new benchmark release as a regular review, the same way it audits for drift between source and org.

---

## Open-Source Readiness

This part of the guide answers the questions a review board asks about any open-source dependency: is the source really available, who maintains it, how mature is it, and what happens if the maintainer stops. It also compares KernDX honestly against the adoption and longevity of the open-source Apex libraries you might use instead.

### Current State

KernDX is published publicly on GitHub under the BSL 1.1 (Business Source License), which converts to the permissive Apache 2.0 license after four years. The table below checks KernDX against the standard markers a review board uses to judge an open-source project, with the open-source benchmark stated in the right-hand column:

| Dimension               | KernDX                                                                                                                                                                                                                                        | Open-source benchmark                                                                                                                                                                                  |
|-------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Source availability** | Public GitHub repository                                                                                                                                                                                                                      | Public GitHub repository, met                                                                                                                                                                         |
| **License**             | BSL 1.1 (converts to Apache 2.0 after 4 years)                                                                                                                                                                                                | OSI-approved licence (MIT, Apache 2.0, or BSD-3); BSL is source-available but not OSI-approved until the Apache 2.0 conversion (a deliberate choice during the commercial period, not a gap to close) |
| **Documentation**       | 37 developer documents (21 guides, 16 fast starts), 269 API references, `AGENTS.md` + `docs/Code Conventions - Guide.md` (repo-root AI instructions) + [AI Agent Instructions](AI%20Agent%20Instructions.md) (per-module framework reference) | Public README, docs, contribution guide, met                                                                                                                                                          |
| **Test coverage**       | 100% per-file Apex + 95% LWC statements + 95% LWC branches enforced at every release build                                                                                                                                                    | Maintained with public CI, met                                                                                                                                                                        |
| **CI/CD**               | Public GitHub Actions (`.github/workflows/ci.yml`)                                                                                                                                                                                            | Public CI, met                                                                                                                                                                                        |
| **Issue tracking**      | Public GitHub Issues with bug-report + feature-request templates                                                                                                                                                                              | Public issues, met                                                                                                                                                                                    |
| **Community**           | `CONTRIBUTING.md` + Code of Conduct published; single-maintainer, issues-only contribution model (external PRs not accepted at this stage by design)                                                                                          | Contribution guidelines + code of conduct, met                                                                                                                                                        |
| **Distribution**        | Managed package + source deploy + repackage-under-namespace                                                                                                                                                                                   | Package + source, met                                                                                                                                                                                 |

### Adoption Signal Profile

KernDX is at **v1.0**: the first validated build is packaged and testing-hardened (a 100% per-file Apex coverage gate, 95% LWC, 561 anonymous-Apex assertions in the [subscriber e2e harness](Strategic%20Guide%20-%20Metrics.md#release-testing), 190 `@IsTest` methods across 41 subscriber test classes, an extended load suite, rolling performance baselines, and a drift-audit cycle). The honest caveat on adoption history: KernDX is publicly released under BSL 1.1 and promoted for production install, with one known external client engagement in active use at the snapshot date and public adoption still early. For the current build identifier and activity counts, see [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot).

**KernDX adoption activity at the snapshot date**:

| Activity signal                    | KernDX value |
|------------------------------------|--------------|
| Published managed-package versions | [120](Strategic%20Guide%20-%20Metrics.md#activity-snapshot)          |
| Contributors                       | 1            |

Those numbers reflect two facts about where KernDX is, not how good the code is. The public repository is newly published, so a history of GitHub stars has not had time to build up, and the framework currently ships with a single contributor. This guide keeps adoption activity and per-capability coverage as two separate measures on purpose: how widely something has been adopted is a different question from how well it covers a capability, and adoption activity never lowers a capability rating.

**Capability coverage across the comparable Apex frameworks surveyed.** Three things tend to drive defect rate: secure defaults, how well the pieces integrate, and how broad the capability coverage is. On those three, KernDX measures favourably against the alternatives surveyed. The right-hand column credits where each of the other frameworks stands:

| Axis                       | KernDX                                                                                                                                                                                                                                                                                                                                                                                                   | Where the others stand                                                                                                                                                                     |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Core-capability footprint  | Every core Salesforce capability shipped as a production-ready implementation                                                                                                                                                                                                                                                                                                                            | The next-broadest libraries the team has surveyed (`rflib`, [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library)) ship implementations across fewer of these areas. |
| Security defaults          | KernDX defaults to the secure setting on all four signals that drive defect rate (sharing, access mode, bypass audit, inbound trust)                                                                                                                                                                                                                                                                     | `rflib` is the next-strongest framework on this dimension: bypass audit and partial FLS-read posture; every other comparator is weaker still.                                         |
| Code quality               | PMD-clean; ApexDoc on every class and method; 100% per-file Apex test coverage                                                                                                                                                                                                                                                                                                                           | On code-quality checking that runs without executing the code (static analysis), KernDX comes out cleaner than any other Apex framework surveyed, measured by violation counts after triage.                          |
| Test depth                 | [175 test classes vs 190 production classes](Strategic%20Guide%20-%20Metrics.md#package-codebase) (~92% test-to-production ratio); per-file 100% Apex coverage gate + 95% statement/branch LWC, enforced at every release build; subscriber-realism e2e harness (561 anonymous-Apex assertions across 74 sections plus 190 `@IsTest` methods across 41 subscriber test classes); extended load testing suite; rolling perf-history baselines; drift audit cycle | KernDX is the only Apex framework surveyed with a coverage gate enforced at every build.                                                                                               |
| Trigger bypass audit       | Every trigger-bypass call writes a structured audit log                                                                                                                                                                                                                                                                                                                                                  | Only `rflib` ships built-in bypass-audit on the trigger surface; every other comparator with bypass capability ships silent toggles.                                                   |
| Threat model documentation | Bespoke [2,326-line Security Guide](Strategic%20Guide%20-%20Metrics.md#documentation)                                                                                                                                                                                                                                                                                                                                                                        | 11 of 22 comparators ship no `SECURITY.md` at all; 4 ship the same templated `SECURITY.md`.                                                                                            |

**Trigger framework comparison.** `taf` and KernDX both ship declarative trigger registration. On top of that, KernDX writes a bypass-audit log that `taf` does not: `taf`'s programmatic bypass surface writes no audit log at all. `rflib` also ships broad Trigger Framework coverage, and it matches KernDX on two specific pieces: recursion control and per-event ordering. One honest point in `taf`'s favour: `taf` carries a longer accumulated history of tagged releases, while KernDX is newly released at v1.0, with at least one known external client engagement at the snapshot date.

**What closes the adoption-activity gap.** Adoption activity grows as production references build up over time: external user issues closed, downstream consumers adopting it, or third-party references. If you are judging a framework on capability-level readiness (secure defaults, code quality, test depth, breadth, and how well the pieces integrate), weight broad capability coverage (see [Overview § Key Findings](Strategic%20Guide%20-%20Overview.md#key-findings)) over adoption activity. If you are judging it specifically on "how many other orgs have used it in production," then weight the libraries that have actually accumulated that history accordingly.

### Comparison with Other Frameworks' Open-Source Journeys

For context, here is where the well-known Apex libraries are on their own open-source journeys, alongside KernDX. The star counts and ages are facts about how long each has been building an audience:

| Framework                | Open-Source Journey                                                                                                                                                                                                                                                                                            |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **`taf`**                | Started as a personal project, published on GitHub under Apache 2.0. Has grown to several hundred GitHub stars at a recent fetch. A widely-referenced metadata-driven trigger framework.                                                                                                                       |
| **`apex-fluently-soql`** | Published with MIT license and dedicated documentation site. Active maintenance with 147 commits in the last 12 months and 36 tagged releases. Adopted by `rflib`: a documented downstream-consumer adoption signal.                                                                                          |
| **`nebula-logger`**      | Published early, iterated in public. MIT license. Has grown past eight hundred GitHub stars at a recent fetch, with 25+ contributors over 8 years. Featured in Trailhead and Dreamforce. The main reference among the comparable Apex libraries surveyed for community engagement on a single-purpose library. |
| **KernDX**               | BSL 1.1 licensed, 2+ years development. Published publicly on GitHub with the full developer documentation set (37 developer documents, 269 API references), public CI (`ci.yml`), issue templates, `CONTRIBUTING.md`, and a Code of Conduct. Converts to Apache 2.0 four years after release.                 |

### Bus Factor Mitigation

**Context: one maintainer is the norm across open-source Apex frameworks, not something unusual to KernDX.** Most of the community libraries the team has surveyed are effectively run by a single maintainer. Only the `fflib` family has genuinely distributed maintainership across multiple contributors.

What actually drives the risk is three things: whether the maintainer is still shipping releases; whether adopters can get enough source and documentation to maintain it themselves; and whether the codebase is scoped and tested well enough to fork cleanly. KernDX addresses the last two by design. The source is publicly available under BSL 1.1 (converting to Apache 2.0 after the four-year change date), backed by 269 API references, 100% per-file Apex coverage, and the AI-context files (`AGENTS.md` plus `docs/Code Conventions - Guide.md`). Any team, whether an engaged consulting client or a self-installer, can fork and maintain the same source. The modular open-source "distributed risk" argument is a fair point at the portfolio level: if one of several adopted libraries loses its maintainer, you lose a fraction of the stack, not all of it. But it does not mean the individual components each have multiple maintainers, and for most community libraries outside the `fflib` family, they do not.

So the single-developer risk described below is not a KernDX-specific weakness. It is the default for nearly every Apex library outside the `fflib` family, and the mitigations that follow apply to any single-maintainer component, KernDX included.

1. **Source publicly available under BSL 1.1.** Clients, and any other adopter, can maintain the framework independently from the public repository. Consulting engagements add direct source delivery and handover support.
2. **Layered documentation.** 37 developer documents (21 guides, 16 fast starts) and 269 API references.
3. **Standard Apex patterns.** Selectors, triggers, small data-transfer classes, and builders, all recognisable from `fflib`, `taf`, and `apex-fluently-soql`, so the knowledge transfers.
4. **AI context files.** `AGENTS.md` (~3K tokens, a tool-neutral entry point) ships at the repo root and points to `docs/Code Conventions - Guide.md` (~12K tokens, the canonical conventions). The per-module [`AI Agent Instructions`](AI%20Agent%20Instructions.md) reference (~10K tokens, in `docs/`) carries the deep framework walk-through. Together they document the conventions, patterns, critical rules, and design rationale. A developer using Claude Code, Cursor, Cline, or Agentforce Vibes can generate convention-compliant code and diagnose framework internals with no prior KernDX experience, which narrows (without eliminating) the tribal-knowledge gap of a single-developer framework.
5. **Exit strategy.** Three paths: keep the managed package, deploy the source, or repackage under your own namespace. For teams equipped with AI agent tooling loaded against the context files above, even a deeply adopted exit usually fits inside a single sprint (about 1-2 days of wall-clock work), so the mitigation is something you can actually run, not just something documented. Teams without agent tooling should expect the conventional 1-2 week human-only effort.
6. **Metadata-driven isolation.** The bypass mechanisms (`TRG_Base.bypassAction()`, `TriggerSetting__mdt.BypassExecution__c`, `FeatureFlag__mdt`) let you disable a problematic handler or feature path with no code change and no vendor push upgrade (see [Technical Risks](Strategic%20Guide%20-%20Risks.md#technical-risks)).

**Never adopt KernDX without a documented exit strategy.** Before you commit, put these five things in place to reduce single-maintainer risk:

1. **Architecture Decision Records (ADRs).** Write down why KernDX was chosen, what alternatives you evaluated, and the conditions under which you would revisit the decision.
2. **Pattern documentation that does not depend on the framework.** Document the architectural patterns (selectors, trigger handlers, data-transfer classes) so the knowledge survives even if you later remove the framework.
3. **CI enforcement rules.** Have your build validate the framework conventions (naming prefixes, test coverage, ApexDoc) so the team relies on the rules, not on tribal knowledge.
4. **A documented transition playbook** for moving to a modular stack (see [Migration Checklists](Strategic%20Guide%20-%20Operations.md#migration-checklists) for the recipes).
5. **A named secondary maintainer,** or documented ownership inside your organisation of `AGENTS.md`, `docs/Code Conventions - Guide.md`, and the [`AI Agent Instructions`](AI%20Agent%20Instructions.md) framework reference.

### Licensing Considerations

Different Apex libraries use different licences, each with its own trade-offs. The table lays out the common ones, their pros and cons, and which frameworks use each, so you can weigh KernDX's BSL 1.1 choice in context:

| License        | Pros                                                              | Cons                                                         | Frameworks Using                              |
|----------------|-------------------------------------------------------------------|--------------------------------------------------------------|-----------------------------------------------|
| **MIT**        | Maximum adoption, minimal friction                                | No patent protection, no copyleft                            | `apex-fluently-soql`, `nebula-logger`         |
| **Apache 2.0** | Patent protection, contributor clarity                            | Slightly more restrictive                                    | `taf`                                         |
| **BSD-3**      | Simple, permissive                                                | No patent grant                                              | `fflib`, `rflib`                              |
| **BSL 1.1**    | Commercial-restriction window + guaranteed open-source conversion | Limits adoption until Change Date, community pushback common | KernDX (converts to Apache 2.0 after 4 years) |

**Where KernDX stands today:** it uses BSL 1.1 with a 4-year change date to Apache 2.0. That protects the commercial model while guaranteeing the code becomes fully open-source in time. After the change date, the code is Apache 2.0 licensed: permissive, and with patent protection.

### Community Building Strategy

Publishing source is only the start. Building an actual community takes deliberate, ongoing investment, and here is the staged plan for it:

| Phase                 | Timeline  | Activities                                                                                      |
|-----------------------|-----------|-------------------------------------------------------------------------------------------------|
| **1. Foundation**     | Month 1-2 | Public repository, README, CONTRIBUTING.md, code of conduct, issue templates, GitHub Actions CI |
| **2. Awareness**      | Month 2-4 | Blog series ("Why KernDX"), conference submissions, Salesforce community posts                  |
| **3. Adoption**       | Month 4-8 | Unlocked package listing, video tutorials, community Discord/Slack, first external contributor  |
| **4. Sustainability** | Month 8+  | Multiple maintainers, release cadence, AppExchange listing                                      |

**Success metrics:** GitHub stars (target: 100 in year 1), external contributors (target: 3 in year 1), Salesforce community mentions.

**A realistic timeline for comparison** (the GitHub-star counts below are recent-fetch values for the named external repositories; they will keep drifting as those projects gain more stars, so it is the rough order of magnitude that matters here, not the exact figure): `taf` accumulated several hundred stars over 4 years. `apex-fluently-soql` accumulated low hundreds of stars over 3 years. `nebula-logger` accumulated past eight hundred stars over 8 years. A realistic expectation for KernDX with active promotion is 50-150 stars in year 1.

### Open-Source Trade-offs

Opening the source brings benefits, but each one comes with a risk to manage. The table pairs them:

| Benefit                                                   | Risk                                    | Mitigation                                               |
|-----------------------------------------------------------|-----------------------------------------|----------------------------------------------------------|
| Community contributions improve quality                   | Low-quality PRs consume maintainer time | Strict contribution guidelines, automated CI gates       |
| Public issues surface real-world bugs faster              | Issue tracker becomes support forum     | Issue templates, FAQ document, separate discussion board |
| Stars and forks build credibility                         | Forks diverge, creating confusion       | Clear versioning, active release cadence                 |
| Adoption drives documentation improvements                | Feature requests outpace capacity       | Public roadmap, "contributions welcome" labels           |
| External validation (downstream-consumer adoption signal) | Dependencies on external CI systems     | Self-hosted CI fallback, minimal external dependencies   |

**The single biggest risk of open-sourcing is maintainer burnout.** The Salesforce Apex open-source projects with the longest sustained release cadence (`nebula-logger`, `taf`, and `apex-fluently-soql`) are each maintained by one or two primary developers. KernDX's full documentation set and AI context files lower the friction of onboarding a contributor, but the breadth of the framework (triggers, queries, web services, resilience, testing, and LWC) means there is a lot of surface area for the community to contribute against.

---

[Strategic Guide (Overview)](Strategic%20Guide%20-%20Overview.md)
