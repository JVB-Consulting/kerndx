---
navOrder: 30
---

# Strategic Guide — Personas

Supplementary to the [Strategic Guide](Strategic%20Guide%20-%20Overview.md). Consolidates decision factors by stakeholder role. Each persona points at the relevant deep-dive —
start with the [Overview](Strategic%20Guide%20-%20Overview.md) for the one-page summary, then follow the per-persona pointers below
into [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md), [Adoption](Strategic%20Guide%20-%20Adoption.md), [Operations](Strategic%20Guide%20-%20Operations.md),
or [Risks](Strategic%20Guide%20-%20Risks.md).

See also: [Glossary](Strategic%20Guide%20-%20Glossary.md)

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Architect](#architect)
2. [Technical Lead](#technical-lead)
3. [Developer](#developer)
4. [ISV / Package Developer](#isv--package-developer)
5. [Admin / Ops](#admin--ops)
6. [Business Stakeholder](#business-stakeholder)
7. [Executive / Product Manager](#executive--product-manager)
8. [Security / Risk Officer](#security--risk-officer)

</details>

---

## Architect

**Primary concerns:** long-term maintainability, architectural consistency, technical debt, governance.

**Start here:** [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) for the design rationale.

**KernDX fit.** KernDX consolidates trigger, query, DML, web service, schedulable, logging, and LWC controller paths into a single framework — `TRG_Base`,
`SEL_Base`, `DML_Builder`, `LOG_Builder`, `ComponentBuilder`, `API_Inbound`, and `API_Outbound` share context types and call into each other by design.
Because every code path uses framework primitives, you get FLS/CRUD enforced by default on reads and writes simultaneously, audit logging on every bypass, body-hash
idempotency on inbound REST returning HTTP 409 on replay divergence, and masking hooks woven into both the runtime persistence path and the logging path —
guarantees a drop-in library cannot make. Configuration lives in custom metadata; conventions are enforced by a CI-blocking PMD ruleset and ESLint plugin
shipped in `scanner/`.

**Where KernDX ships the broadest coverage among the Apex frameworks surveyed.** On Trigger Framework, Query Builder, DML, Web
Services — Inbound, Web Services — Outbound, Resilience, Security, Data Masking, LWC, Async Patterns, Utilities, Health & Self-Diagnostics, and CI / Tooling,
KernDX ships a production-ready implementation that is broader than the comparable Apex libraries the team has surveyed. Three framework areas where another library covers more
aspects:

- Logging & Diagnostics → [`nebula-logger`](https://github.com/jongpie/NebulaLogger) ships log retention, real-time event monitoring UI, and four selectable transport modes; KernDX
  `LOG_Builder` is a
  smaller-surface Apex builder with default-on async via Platform Event and tight integration with the rest of the namespace. Mix `nebula-logger` alongside
  KernDX for log retention/UI depth.
- Testing (Mockito-style mocking aspect) → [`fflib-mocks`](https://github.com/apex-enterprise-patterns/fflib-apex-mocks) ships the canonical Mockito-style verifier (stub-and-verify) where KernDX deliberately has no
  equivalent; KernDX covers more aspects of test-data and mock-query coverage via `TST_Builder` / `TST_Mock`.
- Domain Patterns → [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) (Application factory) plus [`at4dx`](https://github.com/apex-enterprise-patterns/at4dx) (cross-package extension injection) define the Domain / Service / Application layering; KernDX
  deliberately ships light on Domain scaffolding. Adopt `fflib` alongside KernDX if you need the factory pattern.

**Core-capability footprint.** KernDX ships production-ready implementations of every core Salesforce capability — every core capability a Salesforce org needs is shipped,
documented, and usable from day one (not stubbed or aspirational). This is broader than the comparable Apex frameworks the team has surveyed; the next-broadest libraries are [`rflib`](https://github.com/j-fischer/rflib) and [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library).

**Security defaults.** `QRY_Builder` and `DML_Builder` default to `USER_MODE` — every query and DML operation enforces FLS/CRUD by default. Framework-internal
read paths that need `SYSTEM_MODE` (configuration reads, Chain Monitor aggregates) opt out via the documented `SEL_Base.systemModeRequired()` hook;
declarations are auditable in source and enforced by a CI-blocking scanner rule. Feature-flag kill-switches revert to `SYSTEM_MODE` without a code deploy if a
subscriber hits unexpected FLS blocks. KernDX is the only Apex framework the team has surveyed that defaults `USER_MODE` on both read and write paths with both feature-flag kill
switches and structured audit emission on bypass.

**When KernDX is not the best fit.** If your architecture is built on `fflib`'s Domain + Service + Application pattern, stay there — `fflib` defines that pattern
(`fflib_SObjectDomain`, `fflib_Application`), and KernDX does not ship an equivalent `SVC_Base` or Application factory. If you need only one or two framework
capabilities (triggers only → [TAF](https://github.com/mitchspano/apex-trigger-actions-framework); queries only → [SOQL Lib](https://github.com/beyond-the-cloud-dev/soql-lib)), the
modular approach gives you less framework surface area to govern.

**Framework evaluation criteria:**

- Does this framework prevent anti-patterns (inline SOQL, trigger recursion, tightly-coupled code)?
- Can we enforce standards at scale (PMD rules, code review checklists, framework conventions)?
- What is the upgrade path and backward compatibility story?
- How does this integrate with existing architectural decisions (ISV packages, integration patterns)?

**Framework compliance scanner (plug-and-play).** KernDX ships two shareable rulesets subscribers drop into their existing CI — no bespoke tooling required.
A 24-rule Apex PMD ruleset works with any PMD runner (Salesforce Code Analyzer, Copado CI, Copado Robotic, Gearset CI, Azure Pipelines, GitHub Actions,
standalone `pmd`). A 6-rule LWC ESLint plugin adds as an npm dev-dependency and extends the recommended config in the subscriber's existing `.eslintrc`.
Together they enforce the framework's own conventions (no inline SOQL, no `System.debug`, no `LightningElement`, no `fflib` patterns, explicit sharing,
coverage-theatre detection) inside the subscriber's pipeline, so violations fail the same PR check that already runs on every branch. See
[`Code Scanning - Guide`](Code%20Scanning%20-%20Guide.md) and [`Fast Start - Code Scanning`](Fast%20Start%20-%20Code%20Scanning.md).

**Alternative frameworks:**

- **Modular open-source stack:** TAF + SOQL Lib + `nebula-logger` — each library is a single-family specialist (TAF on declarative trigger registration, SOQL Lib
  on aggregates / cursor / semi-join, `nebula-logger` on log retention + Flow logging actions).
- **Domain-driven design:** `fflib` — `fflib_SObjectDomain` + `fflib_Application` Domain/Service/Application layering; KernDX has no equivalent.
- **Query-only adoption:** SOQL Lib — minimal architectural footprint, `USER_MODE`-by-default on read paths.
- **Granular assembly:** [Apex Fluently](https://github.com/beyond-the-cloud-dev) — eight independently-shipped libraries (SOQL
  Lib, [DML Lib](https://github.com/beyond-the-cloud-dev/dml-lib), [Async Lib](https://github.com/beyond-the-cloud-dev/async-lib), [Cache Manager](https://github.com/beyond-the-cloud-dev/cache-manager), [HTTP Mock Lib](https://github.com/beyond-the-cloud-dev/http-mock-lib), [Test Lib](https://github.com/beyond-the-cloud-dev/test-lib), [LWC Utils](https://github.com/beyond-the-cloud-dev/lwc-utils),
  [Apex Consts](https://github.com/beyond-the-cloud-dev/apex-consts)); install only the concerns you need.
- **Utilities + selectors + UoW from source:** `apex-libra` — a separate ecosystem from Apex Fluently (different authors; `apex-libra` first commit June 2019,
  Apex Fluently first commit May 2025), spanning nine module families including 28 pre-built `QueryObject` selectors and a `DatabaseUnitOfWork`.

**Pilot first.** Deploy KernDX's `TRG_Dispatcher` (or TAF) on a single object with 2-3 trigger actions. Demonstrate metadata-driven handler reordering to
stakeholders in a 30-minute session.

**Key questions to ask:**

- How will we handle framework version upgrades across multiple sandboxes and production?
- What happens if the framework is deprecated or maintainer moves on? (KernDX: source publicly available under BSL 1.1; clone and self-maintain regardless of vendor status; TAF:
  Apache 2.0, actively maintained — fork and self-maintain if needed; SOQL Lib:
  active community.)
- Can we enforce framework usage via PMD rules or CI/CD gates?
- How do we prevent framework bypass (developers writing inline SOQL despite framework availability)?

**Governance fit.** Best at Level 2-3 governance maturity (Controlled Enterprise or Platform-as-Product). At Level 1 (no central architecture function), invest in
governance foundations first — a framework alone will not enforce consistency without organisational support. See
[Governance Maturity](Strategic%20Guide%20-%20Adoption.md#governance-maturity-and-framework-suitability) and [Glossary](Strategic%20Guide%20-%20Glossary.md).

**Navigation:** [Philosophy & Design Principles](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#philosophy--design-principles) |
[Decision Matrix](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence) |
[Risks & Mitigations](Strategic%20Guide%20-%20Risks.md)

---

## Technical Lead

**Primary concerns:** team productivity, code quality, onboarding time, debugging efficiency.

**Start here:** [Adoption](Strategic%20Guide%20-%20Adoption.md) for roll-out guidance; [Operations](Strategic%20Guide%20-%20Operations.md) for the operational signals
underlying day-2 ownership.

**KernDX fit.** KernDX is built around the 95% rule: every shipping feature is what most developers will actually use, every name follows a documented
convention, and there is no API surface that ships only for completeness rather than for daily use. The framework ships 12 Fast Start guides, 14 topic
guides, and AI-context files (`AGENTS.md` + `docs/Code Conventions - Guide.md` at repo root plus the [AI Agent Instructions](AI%20Agent%20Instructions.md) per-module framework
reference) — new
developers can build their first selector, trigger action, or API call within hours. The naming conventions (`SEL_*`, `TRG_*`, `API_*`, `UTIL_*`, `LOG_*`,
`DML_*`, `QRY_*`) make code self-documenting and IDE auto-complete the primary discovery surface. For teams larger than 10 developers, code reviews are easier
to scan when every selector follows the `SEL_*` pattern, every trigger is a one-line dispatch, and every log emit follows
`LOG_Builder.build().error(e).emitAt(...)`. See [Success Metrics](Strategic%20Guide%20-%20Adoption.md#success-metrics) for measured deltas in code review
cycle time and onboarding time.

**Operational signals a technical lead typically cares about.** A library-agnostic PMD ruleset shareable for subscriber CI; a 100% per-file Apex coverage gate enforced at
every release build; a 95% LWC statement/branch coverage gate enforced; an end-to-end subscriber harness covering 471 anonymous-Apex assertions across 71
sections plus 151 test methods across 22 subscriber test classes; an extended load test suite and rolling performance-history baselines; a release runbook;
and a recurring drift-audit cycle. KernDX is the only Apex framework surveyed with a per-file 100% Apex coverage gate enforced at every build. The subscriber install harness,
extended load suite, drift-audit cycle, and release runbook are KernDX-specific operational practices.

**When KernDX is not the best fit.** If your team specifically wants OSI-permissive licensing on every dependency (BSL 1.1 is source-available but not OSI-approved
during the four-year period before relicense to Apache 2.0), or your codebase is already standardised on Apex Fluently / TAF / `nebula-logger` and the migration
cost outweighs the integration benefit, then a modular stack is the better fit. KernDX itself is incremental — you install once and opt into modules, so the
"too much framework surface" objection is not load-bearing; the per-module learning time is comparable across comparable Apex frameworks
(see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison)). Apex Fluently's eight independently-installable libraries
remain a valid composable alternative when license model is the decisive criterion.

**Framework evaluation criteria:**

- Can new developers become productive quickly (< 2 weeks)?
- Does the framework improve or hinder debugging (stack traces, error messages, test isolation)?
- Are there clear patterns for common use cases (pagination, caching, error handling)?
- How much boilerplate is required for simple operations?

**Alternative frameworks:**

- **High developer velocity:** SOQL Lib (hours to learn, minimal boilerplate).
- **Balanced productivity:** TAF + SOQL Lib (Flow-first, metadata-driven).
- **Team > 20 developers:** KernDX or `fflib` (both enforce conventions across many developers via shared base classes and naming patterns).

**Pilot first.** Have one developer build a selector using KernDX (`SEL_Base` + `QRY_Builder`) and another using SOQL Lib. Measure time from "first look at docs"
to "working, tested code." Use this as an onboarding benchmark.

**Key questions to ask:**

- How long does it take a mid-level developer to write their first selector / trigger / query using this framework?
- Are error messages clear and actionable? (Test by introducing common mistakes.)
- Can we build internal accelerators on top of the framework (templates, snippets, code generators)?
- How do we handle framework-related questions and support (community Slack, internal champions, vendor support)?

**Navigation:** [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison) |
[Adoption Roadmap](Strategic%20Guide%20-%20Adoption.md#adoption-roadmap)

---

## Developer

**Primary concerns:** ease of use, documentation quality, debugging, testing patterns.

**Start here:** [Architecture & Philosophy — Code Examples at a Glance](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#code-examples-at-a-glance) for the everyday APIs.

**KernDX fit.** KernDX is designed so the most-used APIs are immediately productive — there is no DSL to memorise. The four APIs developers touch most are
immediate-value:

- `TST_Builder.of(SObjectType).withOverride(field, value).build()` — fluent test data, DML-or-mock-ID at developer choice (`.withoutInsertion()` for in-memory).
- `QRY_Builder.selectFrom(SObjectType).fields(...).condition(field).equals(value).toList()` — fluent queries with compile-time field safety; `USER_MODE` by default.
- `LOG_Builder.build().error(e).emitAt('MyClass.myMethod')` — async logging via the platform event channel; no `System.debug`.
- `DML_Builder.newTransaction().doInsert(record).execute()` — fluent DML; `USER_MODE` by default; parent-child relationship resolution; governor pre-check throws
  before DML if row count exceeds the limit.

Every method name surfaces via IDE auto-complete. The framework follows the same chainable-build → terminal-execute fluent shape across every major surface
(`TST_Builder`, `QRY_Builder`, `DML_Builder`, `LOG_Builder`, `UTIL_HttpClient`); learning one means learning the others. The `AGENTS.md` + `docs/Code Conventions - Guide.md` files
help AI coding
assistants (Claude Code, Cursor, Windsurf) follow framework conventions when generating new code. The framework's test infrastructure — `TST_Builder` for
fluent data creation, `TST_Mock` for DML-free query interception, `TST_Factory` for metadata setup, `API_MockFactory` for two-tier web service mocking —
addresses common subscriber-test pain points (DML-free testing and SOQL-free assertions) in one or two lines.

KernDX deliberately does not ship a Mockito-style stub-and-verify DSL because the learning curve isn't justified by the API's everyday use. Subscribers wanting Mockito patterns can
install `fflib-mocks` alongside KernDX. KernDX's `TST_Mock.of(SObjectType).withOverride(...).build()` auto-registers for `SEL_*` queries with zero ceremony — combined with
`withoutInsertion()`, that
addresses common selector-test pain. SOQL Lib goes deeper on aggregate, cursor, and semi-join query patterns; subscribers needing those facets can pair SOQL
Lib alongside KernDX `QRY_Builder`.

**If you already know TAF, KernDX's trigger actions will feel familiar.** KernDX's `TRG_*` framework is a direct evolution of TAF — same metadata-driven
dispatcher, same class-per-concern discipline, same context interfaces (`BeforeInsert`, `AfterUpdate`, etc.). The Apex you write looks nearly identical (see the
code comparison below). TAF-literate developers should be productive within hours, given the same metadata-driven dispatcher pattern and context interfaces;
what changes is naming (`TA_*` → `TRG_*`, `sObject_Trigger_Setting__mdt` → `TriggerSetting__mdt`) and the action-context binding (TAF's 7 per-context
MetadataRelationship fields → KernDX's `Event__c` picklist + single `TriggerSetting__c` lookup). KernDX additionally ships audit logging on every trigger-bypass
mutation — every action and reason is observable through the same log infrastructure. See the
[TAF → KernDX migration narrative](Strategic%20Guide%20-%20Adoption.md#migration-narratives) for the honest
keep/give-up/gain breakdown.

**When KernDX is not the best fit.** If you find the naming conventions (`UTIL_*`, `SEL_*`, `QRY_*`) too verbose, or prefer the minimalism of SOQL Lib's
single-class API on the query surface specifically, the lighter option reduces cognitive load on that one family. Both SOQL Lib and KernDX `QRY_Builder`
default to `USER_MODE` on the read path. KernDX's managed package overhead also adds framework classes to stack traces.

**Framework evaluation criteria:**

- Is the API intuitive (self-documenting method names, clear parameter types)?
- Are there code examples for common scenarios?
- Can I write tests easily (mocking, test data builders, assertions)?
- Does the framework make debugging harder (deep stack traces, framework abstractions obscuring business logic)?

**Alternative frameworks:**

- **Easiest to learn for queries:** SOQL Lib — fluent API, `USER_MODE` default on read paths.
- **Shallower stack traces:** TAF + SOQL Lib — unmanaged-package source in your own org, no framework namespace prefix in stack traces.
- **AI-assisted development:** frameworks shipping instruction files (`AGENTS.md`, cursor rules) help AI assistants follow framework conventions when generating
  new code — KernDX ships `AGENTS.md` (tool-neutral pointer) and `docs/Code Conventions - Guide.md` (canonical conventions) at repo root plus
  the [AI Agent Instructions](AI%20Agent%20Instructions.md) per-module framework reference.

**Pilot first.** Replace 3-5 inline SOQL queries with `QRY_Builder` (or SOQL Lib) equivalents in an afternoon. Immediate readability improvement with minimal risk.

**Code comparison:**

```apex
// KernDX — fluent query with compile-time field safety + USER_MODE default
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<SObjectField>{Account.Name, Account.AnnualRevenue})
    .condition(Account.AnnualRevenue).greaterThan(1000000)
    .toList();

// SOQL Lib — similar fluency, different API
List<Account> accounts = SOQL.of(Account.SObjectType)
    .with(Account.Name, Account.AnnualRevenue)
    .whereAre(SOQL.Filter.with(Account.AnnualRevenue).greaterThan(1000000))
    .toList();

// TAF trigger action — similar structure to KernDX TRG_Base
public class TA_Account_SetDefaults implements TriggerAction.BeforeInsert
{
    public void beforeInsert(List<Account> newList) { /* ... */ }
}
```

**Navigation:** [Code Examples at a Glance](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#code-examples-at-a-glance)

---

## ISV / Package Developer

**Primary concerns:** AppExchange review, namespace management, dependency minimization, upgrade safety, subscriber impact.

**Start here:** [Architecture & Philosophy — Open-Source Readiness](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#open-source-readiness) for the
managed-package-readiness frame; [Operations — Packaging & Distribution](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy) for the
exit path.

**KernDX fit.** KernDX was designed as a managed package framework — it addresses the specific challenges ISVs face that general-purpose frameworks do not:
namespace-aware type resolution (`UTIL_TypeResolver`), subscriber-first custom permission resolution, configurable namespace deployment, and 100% test coverage
gated per-file at build time. The `global` API surface is explicitly minimised and annotated with `@since` tags for version tracking. For inbound REST surfaces
— a common security-review focus — KernDX ships body-hash idempotency validation returning HTTP 409 on replay divergence, a feature most other Apex frameworks
don't address.

**When KernDX is not the best fit.** For AppExchange apps that need zero dependencies to minimise package size and review complexity, avoid any framework. For
ISVs already deep in `fflib`, migration cost may exceed benefit — freeze `fflib` usage and adopt KernDX patterns for new modules only.

**Framework evaluation criteria:**

- Does the framework work within a managed package namespace?
- What is the `global` API surface area and can it be controlled?
- How does the framework handle subscriber customization without breaking upgrades?
- Does the framework pass security review without issues?

**ISV-specific considerations:**

| Concern                    | KernDX approach                                                                                                                                                                                                                                                                              | Alternative                                                                                                                              |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| Namespace resolution       | `UTIL_TypeResolver` chain: subscriber namespace → package namespace                                                                                                                                                                                                                          | Manual `Type.forName()`                                                                                                                  |
| Subscriber extensibility   | Metadata-driven configuration (triggers, validations, feature flags)                                                                                                                                                                                                                         | Custom settings, hardcoded                                                                                                               |
| Security review            | Explicit sharing on every class, no inline SOQL, `USER_MODE` default on `QRY_Builder` / `DML_Builder`, audit-logged bypass across query / DML / validation / trigger surfaces, body-hash idempotency with HTTP 409 on replay divergence, CI-blocking scanner rule on undeclared access modes | Manual review; SOQL Lib defaults `USER_MODE` on read paths; most other Apex frameworks ship enforcement toggles that emit no audit event |
| Package size               | 351 classes (183 production, 168 test) — integrated-stack footprint                                                                                                                                                                                                                          | SOQL Lib: ~15 classes; Apex Fluently: 8 libraries you install independently                                                              |
| Upgrade safety             | `@since` tags on all `global` members, no breaking changes policy, validated-build gate on every release (see [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for current build identifier and package-version count)                                    | Manual tracking                                                                                                                          |
| Test coverage              | 100% per-file Apex enforced at every release build; 3,564 `@IsTest` methods across 168 test classes; end-to-end subscriber harness                                                                                                                                                           | Varies by framework                                                                                                                      |
| Install-blocker discipline | An early install-blocker on default-OWD orgs was discovered and closed in the next package version — observable in the release record. See [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for the current build identifier.                             | Varies by framework                                                                                                                      |

**Pilot first.** If evaluating KernDX for a new package, deploy the selector framework (`SEL_Base` + `QRY_Builder`) first — it provides immediate value (no inline
SOQL, cacheable queries, mock support) with the least disruption.

**Key questions to ask:**

- What percentage of my package's Apex classes will depend on framework classes? (Higher coupling = harder to exit.)
- Can subscribers override framework behaviour without modifying package code? (KernDX: yes, via metadata.)
- How does the framework interact with managed package push upgrades?
- What is the exit strategy if the framework becomes a liability? (See [Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy).)

**Navigation:** [Packaging & Distribution](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy) |
[Open-Source Readiness](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#open-source-readiness) |
[Capabilities at a Glance](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#capabilities-at-a-glance)

---

## Admin / Ops

**Primary concerns:** configuration vs. code, deployment complexity, production support, monitoring.

**Start here:** [Operations](Strategic%20Guide%20-%20Operations.md) for day-2 ownership.

**KernDX fit.** KernDX's metadata-driven architecture means admins can control trigger execution order, enable/disable triggers without code deployment, toggle
feature flags, and configure validation rules — all through Setup UI. The circuit breaker and retry mechanisms provide production resilience without admin
intervention. `LogEntry__c` provides a queryable log object for building reports and dashboards. Every bypass mutation on the trigger, query, DML, or
validation surface emits a structured audit log so when a bypass is in effect, ops can see who set it and why through the same log infrastructure. KernDX also
ships admin consoles as Lightning tabs — a Streaming Event Monitor for platform-event and Change Data Capture traffic with event-usage metrics, a Chain Monitor
for async chains, and a Data Masking Advisor for reviewing and exporting masking coverage.

**Operational discipline.** KernDX ships a release runbook, a recurring drift-audit cycle (re-run every ~4 weeks or before any package build), an end-to-end
subscriber harness (471 anonymous-Apex assertions across 71 sections), an extended load-test suite (`npm run test:load:extended`), and rolling
performance-history baselines (`npm run test:perf:report`). For the current build identifier, commit count, and package-version count, see
[Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot). An early install-blocker on default-OWD orgs was discovered and closed in the next package
version —
observable in the release record.

**When KernDX is not the best fit.** If your primary need is log analytics and a dedicated log-browser UI, `nebula-logger` ships log-browsing LWCs (`logViewer`,
`relatedLogEntries`, `logEntryEventStream`) plus retention scheduler and admin dashboards that KernDX does not match on the dashboard surface. KernDX
`LogEntry__c` is fully queryable + masking-applied, but the gap is the UI shell, not the data model — subscribers wanting a log-browsing UI either ship
`nebula-logger` alongside or build a custom LWC over `LogEntry__c`. TAF's Flow-based bypass mechanism (`TriggerActionFlowBypass`) may also be more intuitive for
admins already comfortable with Flows.

**Framework evaluation criteria:**

- Can I configure framework behavior without deploying code (custom metadata, custom settings)?
- How do I troubleshoot issues in production (debug logs, monitoring dashboards, error logs)?
- What is the deployment footprint (number of classes, metadata types, dependencies)?
- Can I disable framework behavior temporarily for emergency maintenance?

**Alternative frameworks:**

- **Most admin-friendly trigger config:** TAF (Flow integration, metadata-driven, declarative-path audit via Setup Audit Trail).
- **Best log-browser UI:** `nebula-logger` (`logViewer` / `relatedLogEntries` / `logEntryEventStream` LWCs, retention scheduler, admin dashboards).
- **Easiest deployment:** SOQL Lib (lightweight, zero dependencies).

**Pilot first.** Set up trigger bypass via metadata (`TriggerSetting__mdt.BypassExecution__c` in KernDX, or `TriggerActionFlowBypass` in TAF) and demonstrate
emergency trigger disablement without code deployment. With KernDX, the bypass also appears in `LogEntry__c` as an audit event so the ops team can see who set
it and why.

**KernDX admin capabilities:**

| Capability               | Configuration method                           | Code required? |
|--------------------------|------------------------------------------------|----------------|
| Disable a trigger        | `TriggerSetting__mdt.BypassExecution__c`       | No             |
| Disable a trigger action | `TriggerAction__mdt.BypassExecution__c`        | No             |
| Toggle a feature         | `FeatureFlag__mdt` + strategy                  | No             |
| Add a validation rule    | `ValidationRule__mdt` + formula                | No             |
| Configure retry strategy | `ApiSetting__mdt`                              | No             |
| Toggle FLS/CRUD on read  | Feature-flag kill-switch (metadata)            | No             |
| Toggle FLS/CRUD on write | Feature-flag kill-switch (metadata)            | No             |
| Toggle masking framework | Feature-flag kill-switch (metadata)            | No             |
| Review masking coverage  | Data Masking Advisor tab (scan + inventory export) | No         |
| View error logs          | `LogEntry__c` reports/dashboards               | No             |
| View bypass audit        | `LogEntry__c` filtered to audit-event category | No             |
| Circuit breaker status   | Platform Cache (read-only)                     | No             |
| Monitor event & API usage | Streaming Event Monitor + Chain Monitor tabs  | No             |

**Navigation:** [Capabilities at a Glance](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#capabilities-at-a-glance) |
[Enterprise Delivery](Strategic%20Guide%20-%20Adoption.md#enterprise-delivery)

---

## Business Stakeholder

**Primary concerns:** time to market, cost of change, business continuity, risk.

**Start here:** [Overview — Executive Tear Sheet](Strategic%20Guide%20-%20Overview.md#one-page-executive-tear-sheet) for the one-page summary;
[Adoption — Build vs Buy TCO](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) for the 3-year cost picture.

**KernDX fit.** KernDX's "accelerator, not a product" model means zero licensing fees and source publicly available under BSL 1.1 (relicenses to Apache 2.0
after a four-year change date) — subscribers own access to the framework from day one, with `Unmanaged.zip` delivery available via consulting engagement for
direct source handover. The 3-year cost picture in the Adoption guide shows KernDX delivering the lowest total cost for managed package scenarios. The
integrated test infrastructure (`TST_Builder`, `TST_Mock`, `TST_Factory`, `API_MockFactory`) plus the 100% per-file Apex coverage gate enforced at every
release build reduce regression risk during feature delivery. The release runbook, drift-audit cycle, and end-to-end subscriber harness produce evidence of
release quality at each version cut.

**Governance by Design vs. developer vigilance.** Every read and every write that flows through the framework records its data-access decision as compliant by default;
the absence of an explicit, audited override is itself the audit record. Frameworks that require each developer to declare data-access governance per query and
per DML call rely on constant developer vigilance. KernDX shifts that operational burden by enforcing security by default, moving the
question your audit team asks from "did the developer remember?" to "is there an audited override on this line?" — and the answer is enumerable from source.

**Developer tax: where engineering hours actually go.** Without framework-bundled standards, engineering teams pay a recurring tax — every sprint, developers
hand-write boilerplate access checks, hand-write logging emit, hand-write idempotency on inbound webhooks, and code reviewers spend cycles confirming those
patterns are correct. KernDX bundles these as defaults: coverage is gate-enforced, data-access governance is default-on, inbound REST ships body-hash
idempotency that returns HTTP 409 on replay divergence. Your engineering capacity moves from re-implementing baseline plumbing to shipping the differentiated
features the business actually paid for.

**SI turnover reality — your automated technical lead.** Most enterprise Salesforce delivery runs on SI partner teams whose engineers rotate annually, every
sprint, or every release. The risk is not who leaves; the risk is whether the next engineer can accidentally degrade integrity before anyone notices. KernDX's
100% per-file coverage gate plus default-on data-access governance plus audit-trailed bypasses act as a technical lead that does not turn over — junior
developers cannot ship code that bypasses coverage, cannot ship code that silently bypasses access governance, and cannot ship a bypass at all without an
audit record. The technical-lead function is encoded in the build pipeline, not in any single individual on the SI team.

**Automated governance, not developer preference.** The framework-bundled standards are compliance hard-coded into CI/CD and into the framework defaults —
not a style guide your team could quietly opt out of. The CI pipeline blocks the merge; the data-access mode is default-on; the bypass writes the audit
record. Subscribers who want exceptions write them as audited, source-visible overrides, not as silent local choices.

**When KernDX is not the best fit.** When the project specifically requires OSI-permissive licensing on every dependency, or the client's existing team is
already standardised on a different framework (TAF + SOQL Lib, full Apex Fluently stack, or `fflib` + `at4dx` for Domain-Driven Design), hand off in whichever
framework the client team already uses so they continue with what they know. The "small team / tight timeline" framing is not load-bearing — KernDX is
incremental (install once, opt into modules), and per-module onboarding times are comparable across comparable Apex frameworks
(see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison)).

**ROI indicators — directional, not benchmarked against KernDX-specific deployments:**

The ranges below describe the kind of operational improvement that framework-enforced quality standards typically deliver (per the industry research summarised
in [Adoption — Build vs Buy: Cost Considerations](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) — IBM/NIST on defect cost,
DORA on documentation lift, Besker on technical-debt time). KernDX does not yet have a long enough public production track record to confirm KernDX-specific
values. Subscribers should treat these as **adoption milestones to measure against the team's own pre-framework baseline**, not as guaranteed outcomes.

| Metric                            | Without framework       | With KernDX                                                  | With TAF + SOQL Lib      |
|-----------------------------------|-------------------------|--------------------------------------------------------------|--------------------------|
| New developer onboarding          | 3-4 weeks               | 1-2 weeks                                                    | 1-2 weeks                |
| Code review cycle time            | 2-3 days                | 0.5-1 day                                                    | 0.5-1 day                |
| Production defect rate            | Higher                  | Lower                                                        | Lower                    |
| Integration development time      | High (custom each time) | Low (`API_Outbound` + `API_Inbound` + body-hash idempotency) | Medium (per-integration) |
| Framework migration cost if wrong | N/A                     | Medium (integrated stack)                                    | Low (modular)            |

> **Adoption milestones.** The Strategic Guide [Success Metrics](Strategic%20Guide%20-%20Adoption.md#success-metrics) section turns these directional ranges into
> measurable targets — 30-50% production defect reduction, code review cycle time from 2-5 days to 1-2 days, new developer onboarding from 4-8 weeks to
> 1-2 weeks — that subscribers should compare against their own pre-framework baseline at 90 / 180 / 365 days.

**Pilot first.** Calculate the cost of past incidents caused by inline SOQL, trigger recursion, or inconsistent error handling. Frameworks that prevent these
classes of bugs offset their adoption cost over time.

**Key questions to ask:**

- How long until the team is productive with this framework (weeks, months)?
- What is the cost of migration if we choose wrong? (KernDX: medium, integrated-stack surface area; TAF / SOQL Lib: low, small surface area per library;
  `fflib`: high, pervasive Domain/UoW patterns throughout business logic.)
- Can we deliver business features while learning the framework (parallel tracks)?
- What is the vendor lock-in risk? (See [Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy).)

**Change management.** Pilot with 2-3 developers before mandating org-wide adoption. Measure concrete metrics during the pilot — code review cycle time,
production defect rate, and new developer onboarding time — to build a data-driven case for broader rollout. See also the
[Adoption Roadmap](Strategic%20Guide%20-%20Adoption.md#adoption-roadmap) for phased rollout guidance.

**Navigation:** [Build vs Buy TCO](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) |
[Adoption Roadmap](Strategic%20Guide%20-%20Adoption.md#adoption-roadmap) |
[Risks & Mitigations](Strategic%20Guide%20-%20Risks.md)

---

## Executive / Product Manager

**Primary concerns:** delivery velocity, team scalability, strategic risk, competitive positioning.

**Start here:** [Overview — Executive Tear Sheet](Strategic%20Guide%20-%20Overview.md#one-page-executive-tear-sheet) for the one-page summary.

**KernDX fit.** For executives evaluating framework investments: KernDX is a zero-license-cost, source-ownership framework that standardises how your team
builds on Salesforce. The business value is convention enforcement at scale — when 10+ developers follow the same patterns, code review and onboarding benefit
(see [Success Metrics](Strategic%20Guide%20-%20Adoption.md#success-metrics) for measurable targets: 30-50% production defect reduction, code review cycle time
from 2-5 days to 1-2 days, new developer onboarding from 4-8 weeks to 1-2 weeks). The trade-off is adoption investment: KernDX requires more initial learning
than modular alternatives because it covers more areas.

**Strategic posture.** KernDX is compared against the alternative Salesforce frameworks the team has surveyed. KernDX ships broad coverage
across Trigger Framework, Query Builder, DML, Web Services — Inbound, Web Services —
Outbound, Resilience, Security, Data Masking, LWC, Async Patterns, Utilities, Health & Self-Diagnostics, and CI / Tooling — broader than the comparable Apex libraries the team has
surveyed. Three framework areas where another library covers more aspects (Logging & Diagnostics → `nebula-logger`; Mockito-style behaviour verification → `fflib-mocks`; Domain /
Service / Application factory
pattern → `fflib` + `at4dx`) point at mix-alongside opportunities, not replacements. KernDX defaults `with sharing` on every class; Data Access Governance is
enforced by default on reads and writes simultaneously; every bypass mutation emits an audit log. KernDX is testing-hardened at v1.0 (100% per-file Apex coverage gate, 95% LWC, 471
anonymous-Apex assertions in the subscriber e2e harness), is publicly released under BSL 1.1 and promoted for production install, and is in active use at one known external client
engagement at the snapshot date; public adoption is still early. Established alternatives (`fflib`, `nebula-logger`, `rflib`) have years of publicly-referenceable production
history; KernDX is newly public and does not yet have a comparable public adoption track record (installs of a source-available, promoted package aren't centrally tracked).
Subscribers weighting external production-adoption history as a primary signal should factor that against KernDX's capability coverage; subscribers weighting capability coverage
and security defaults should weight those above the adoption picture.

**Audit liability as a capacity cost.** Audit and regulatory exposure for data access is not a developer-discretion problem in your accounting — it is a
financial and reputational liability that lands on your company, not on the SI partner. KernDX shifts the framing from "did the developer remember to enforce
access governance on this query?" to "the framework enforces access governance by default, every read and write, and any override writes an audit record." For
your General Counsel, your CISO, and your auditors, the question becomes enumerable from source: a Governance by Design baseline you can defend, not an Honor
System you have to vouch for.

**Developer tax: the TCO line item your forecast is missing.** Each hand-written data-access-mode declaration, each hand-rolled bypass without an audit record, each
sprint that re-litigates the "should this query enforce access governance?" question is engineering capacity converted to non-feature work. KernDX bundles
these as defaults so that capacity flows back to the differentiated features your roadmap actually depends on. The line item is small per query and large per
quarter — and it compounds across every new feature your team ships.

**SI turnover risk: organizational continuity without organizational dependency.** Most enterprise Salesforce delivery runs on SI partner teams whose engineers
rotate at every release. Talent rotation is a known risk window if the gates that protect production are documented in heads, not in pipelines. KernDX encodes
the "is this safe to ship?" gate in the build itself — the 100% per-file coverage gate, the default-on data-access governance, and the audit-trailed bypasses
do not depend on which engineer the SI partner staffed this sprint. The framework acts as a technical lead that does not turn over, so the organizational risk
of rotation is bounded by source-visible defaults rather than by individual vigilance.

**Automated governance, not vendor preference.** This is the framing to bring to your vendor-diligence and your audit committee: KernDX-bundled standards are
compliance hard-coded into CI/CD and into the framework defaults — not a developer-preference style guide your team could quietly opt out of. The audit posture
is "the framework enforces this, the build blocks it, the bypass writes a record"; the audit posture is not "the developer chose to apply best practice on
this change." That distinction is what makes the posture defensible to auditors and to acquirers.

**Key decision from the Strategic Guide:**

> "Adopt KernDX when you need default-on coverage across Trigger, Query, DML, Inbound REST, Resilience, Security, Data Masking, LWC, Async, Utilities, Health,
> Outbound, and CI tooling in a single managed package; mix in `nebula-logger` for logging-surface depth, `fflib-mocks` for behaviour-verification mocking,
> or `fflib` + `at4dx` for the Service / Application factory pattern." See
> [Overview](Strategic%20Guide%20-%20Overview.md#one-page-executive-tear-sheet).

**What you need to know:**

- **All major open-source frameworks are free** — TAF (Apache 2.0), SOQL Lib / Apex Fluently (MIT), `nebula-logger` (MIT), `fflib` (BSD-3), `apex-libra` (MIT),
  `rflib` (BSD-3). KernDX ships under BSL 1.1 as a managed package with source publicly available (and direct source delivery on consulting engagements). The cost is training and
  maintenance, not licenses.
- **The ecosystem has shifted** — from monolithic frameworks (`fflib`, 2013) to modular libraries (SOQL Lib, TAF, 2020+) and granular suites (Apex Fluently's 8
  independent libraries).
- **AI may change the calculus** — Salesforce's Agentforce (announced 2024, GA October 2024) creates demand for frameworks AI agents can interpret. Frameworks
  shipping instruction files (KernDX ships `AGENTS.md` + `docs/Code Conventions - Guide.md` at repo root plus the [AI Agent Instructions](AI%20Agent%20Instructions.md) per-module
  framework reference;
  some community projects are adding cursor rules) provide AI agents with explicit conventions to follow.
- **Framework choice affects how new engineers ramp** — `fflib` has the largest accumulated ecosystem footprint (10+ years, 83 contributors, referenced in
  Salesforce certification materials), so engineers with prior `fflib` exposure are more common in the market; TAF / SOQL Lib use standard Apex patterns any
  Salesforce developer can read and pick up from public READMEs; KernDX has no external production-deployment history yet (private until v1.0), so internal
  ramp via `AGENTS.md` + `docs/Code Conventions - Guide.md` + the 14 developer guides + 12 Fast Starts is the adoption path. This guide does not measure
  hiring-market depth for any of these frameworks; subscribers should reference their team's own historical onboarding data, not generic market-depth claims.

**Governance fit.** KernDX delivers most value at Level 2+ governance maturity (Controlled Enterprise or above). If your org is Level 1 (no central architecture
function), framework adoption alone will not solve structural problems — invest in governance foundations first. See
[Governance Maturity](Strategic%20Guide%20-%20Adoption.md#governance-maturity-and-framework-suitability) and [Glossary](Strategic%20Guide%20-%20Glossary.md).

**Pilot first.** Ask your architects to present the [Decision Matrix](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence) mapped to your specific
org situation. A 1-hour session can align technical strategy with business priorities.

**Navigation:**

- [Executive Tear Sheet](Strategic%20Guide%20-%20Overview.md#one-page-executive-tear-sheet) (1 page) — complete landscape overview.
- [Build vs Buy Analysis](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) — TCO comparisons.
- [Risks & Mitigations](Strategic%20Guide%20-%20Risks.md) — due diligence.

---

## Security / Risk Officer

**Primary concerns:** vendor risk, attack surface, supply chain integrity, PII in logs, regulatory compliance.

**Start here:** [Architecture & Philosophy — Salesforce Well-Architected Alignment](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#salesforce-well-architected-alignment) and the
sibling [Security Benchmark for Salesforce Alignment](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#security-benchmark-for-salesforce-alignment) for the
security posture; [Risks](Strategic%20Guide%20-%20Risks.md) for the threat-model treatment.

**KernDX fit.** KernDX defaults to security-conscious patterns across the framework. Every class declares explicit sharing; there is no inline SOQL anywhere in
the framework, eliminating injection vectors; `QRY_Builder` and `DML_Builder` default to `USER_MODE` on the read and write paths simultaneously; every
framework-wide bypass mutation (trigger / query / DML / validation surfaces) emits a structured audit log traceable through the W3C correlation pipeline;
inbound REST surfaces ship body-hash idempotency returning HTTP 409 on replay divergence; the masking framework rewrites sensitive content on any SObject
(standard, custom, or platform event) in memory before the database stores it; and `UTIL_SessionEncryption` handles data encryption. The source ownership model
means your security team can audit every line before deployment. On the four signals that drive defect rate (sharing default, access-mode default, bypass audit
emission, inbound trust), KernDX defaults to the secure setting. One nuance remains: per-custom-object masking is opt-in by design (see below) — the Data
Masking Advisor surfaces the custom objects that need it.

**Threat model documentation.** KernDX ships a bespoke, comprehensive Security Guide (`docs/Security - Guide.md`) plus a top-level `SECURITY.md`
vulnerability-reporting policy at the repository root. Most of the comparable Apex frameworks surveyed in this guide ship no `SECURITY.md` at all; 4 of the Beyond-The-Cloud libraries (DML Lib, SOQL Lib, Apex Consts, HTTP Mock — that is, `apex-fluently-dml`,
`apex-fluently-soql`, `apex-fluently-consts`, `apex-fluently-httpmock`) ship the same Beyond-The-Cloud project-template `SECURITY.md` verbatim — a reporting
channel without a bespoke threat model. `nebula-logger` ships a discoverable security narrative but no `SECURITY.md` either.

**Query / DML defaults.** `QRY_Builder` and `DML_Builder` default to `USER_MODE` — FLS/CRUD is enforced by default on every query and DML operation. **KernDX is
the only Apex framework the team has surveyed that defaults `USER_MODE` on both read and write paths and ships both feature-flag kill-switches and structured
audit emission on bypass.** The next closest comparators (`apex-fluently-soql`, `rflib`) default to `USER_MODE` on reads only and ship per-call explicit-method
opt-out with no audit emission on bypass. Framework-internal read paths that genuinely need `SYSTEM_MODE` (configuration reads, Chain Monitor aggregates) opt
out via the documented `SEL_Base.systemModeRequired()` hook; declarations are auditable in source and enforced by a CI-blocking scanner rule. The kill-switch
metadata flags revert to `SYSTEM_MODE` without a code deploy if a subscriber hits unexpected FLS blocks.

**Bypass audit emission.** Every framework-wide bypass call — trigger (`TRG_Base.bypass*`), query (`QRY_Builder.withSystemMode` / `bypassSharing` /
`withoutSecurity`), DML (`DML_Builder.withSystemMode` / `bypassSharing`), validation (`UTIL_ValidationRule.bypassObject` / `bypassGroup` / `bypassRule`) —
emits a structured audit record with action, surface, target, and optional reason, transaction-rollback-survivable via Platform Event semantics. A master
kill-switch lets subscribers suspend audit emission in noisy environments. `rflib` ships built-in bypass-audit emission on the trigger surface — the only other
Apex framework surveyed currently doing this on any surface, and only on the trigger surface. Most other Apex frameworks (`apex-libra`,
`fflib`, `apex-fluently-dml`, `apex-fluently-soql`, TAF programmatic surface) ship enforcement toggles that emit no audit event when bypass occurs.

**Masking framework with kill switch (per-SObject opt-in by design).** `MaskingRule__mdt` + `MaskingTarget__mdt` rewrites sensitive content on any SObject before
the database stores it. The framework is default-on at the kill-switch level (subscribers can toggle the masking framework off via a single metadata flag);
per-SObject opt-in is via `MaskingTarget__mdt` and `TriggerSetting.ApplyMasking__c = true`. `MaskingBlockedException` is catchable by type. The per-SObject
opt-in is a deliberate performance-aware design choice — most subscribers don't ship credit-card data through every log emission, and default-on regex matching
across every SObject would impose regex-execution overhead on the org's full logging volume. Subscribers prioritising default-on out-of-the-box compliance
hygiene typically pair KernDX masking with `nebula-logger`'s regex matching on log emission specifically (`nebula-logger` ships 4 default-on regex rules);
subscribers prioritising performance + domain-specific masking control adopt KernDX's per-SObject opt-in as-is. The **Data Masking Advisor** console closes the
discoverability side of the opt-in: it scans your own custom objects for regulated fields that have no masking target, exports a regulated-field inventory
(CSV or JSON, with a *Sensitive fields only* filter) and a deployable masking-config bundle, and feeds the
[Security Governance Evidence](Security%20-%20Guide.md#security-governance-evidence) your auditors ask for.

**Regulatory anchors the masking framework supports** (subscriber maps specific fields to rules; framework provides the infrastructure, not the policy):

- **GDPR** Article 25 (data protection by design and by default), Article 5(1)(c) (data minimization).
- **PCI-DSS** v4.0 Requirement 3 (protect stored account data).
- **HIPAA** Privacy Rule §164.514 (de-identification / Safe Harbor).
- **CCPA/CPRA** §1798.100(c).
- Optional for enterprise buyers: **ISO 27001:2022** A.8.11 (named "data masking"), **SOC 2** CC6.

**When KernDX is not the best fit.** For organisations with strict open-source-only policies, the modular stack (TAF, SOQL Lib, `nebula-logger` — all MIT / BSD
licensed with public GitHub repos) provides full auditability with community oversight. KernDX ships under BSL 1.1 (source-available; Change License Apache 2.0
after a four-year clock).

**Framework evaluation criteria:**

- Does the framework introduce third-party dependencies that expand the supply chain attack surface?
- Can we audit the source code before deployment (open-source, source-available, or full handover)?
- Does the logging layer expose PII or sensitive data in debug output or platform events?
- How is framework code patched — what is the vulnerability response timeline?

**Security comparison:**

| Security concern        | KernDX                                                                                                                                                                                                                               | Modular stack (TAF + SOQL Lib + `nebula-logger`)                                                                                                                              | `fflib`                                                                                            |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Source audit            | Public GitHub repo (BSL 1.1)                                                                                                                                                                                                         | Public GitHub repos                                                                                                                                                           | Public GitHub repo                                                                                 |
| Sharing enforcement     | Mandatory `with sharing` declaration on every class                                                                                                                                                                                  | Developer responsibility                                                                                                                                                      | Developer responsibility                                                                           |
| Query security default  | `USER_MODE` default-on on read paths and audited via subscriber-written explicit opt-out (`SEL_Base.systemModeRequired()` plus metadata kill-switch)                                                                                 | SOQL Lib: `USER_MODE` default-on on read paths and audited; SOQLCache constructor silently downgrades to `SYSTEM_MODE` on the cache extension surface                         | Developer responsibility; `newQueryFactory().setCondition(String)` accepts arbitrary WHERE strings |
| DML security default    | `USER_MODE` default-on on write paths and audited via subscriber-written explicit opt-out (metadata kill-switch; configuration changes tracked via Setup Audit Trail)                                                                | DML Lib: `USER_MODE` default-on on write paths but `userMode()` / `systemMode()` / `withSharing()` / `withoutSharing()` mutate `Configuration` in-place silently              | SimpleDML default bypasses FLS/CRUD on every write                                                 |
| Bypass audit emission   | Every framework-wide bypass mutation (trigger / query / DML / validation surfaces) emits a structured audit record — action, surface, target, optional reason, transaction-rollback-survivable; master kill-switch is the off-switch | `rflib`: WARN log on trigger-bypass only. Most other Apex frameworks (`apex-libra`, `fflib`, `apex-fluently-dml`, `apex-fluently-soql`, TAF programmatic) ship silent toggles | Silent static-Boolean kill-switch                                                                  |
| SOQL injection          | Eliminated (no inline SOQL, bind variables only)                                                                                                                                                                                     | SOQL Lib: bind variables                                                                                                                                                      | Developer responsibility (see `fflib_QueryFactory.setCondition` string concatenation surface)      |
| Inbound REST trust      | Body-hash idempotency returning HTTP 409 on replay divergence                                                                                                                                                                        | Not provided                                                                                                                                                                  | Not provided                                                                                       |
| Runtime field redaction | `MaskingRule__mdt` + `MaskingTarget__mdt` — any SObject's text fields, before the database stores them; framework kill-switch default-on, per-SObject opt-in                                                                         | Manual implementation per call site (`nebula-logger` masks log entries only; default-on regex with 4 shipped rules SSN+Visa+MasterCard+Amex applied before-publish)           | Not provided                                                                                       |
| Log PII protection      | Same framework as runtime field redaction — same metadata, different target wirings                                                                                                                                                  | `nebula-logger`: default-on masking with 4 shipped regex rules + extension point; suspendSaving / resumeSaving silently disable emit                                          | Not provided                                                                                       |
| Encryption              | `UTIL_SessionEncryption` (AES256, session-scoped keys)                                                                                                                                                                               | Manual implementation                                                                                                                                                         | Not provided                                                                                       |
| Threat model            | Bespoke 2,027-line Security Guide                                                                                                                                                                                                    | `nebula-logger` ships a discoverable security narrative; 11 of 21 alternative Apex frameworks surveyed ship no `SECURITY.md`                                                  | No `SECURITY.md`                                                                                   |
| Dependencies            | Zero external                                                                                                                                                                                                                        | Zero external (each library)                                                                                                                                                  | Zero external                                                                                      |

**Pilot first.** Run a static analysis scan (PMD, Checkmarx, or CodeScan) against the framework source code before adoption. KernDX ships its own shareable PMD
ruleset (24 Apex rules) and an ESLint plugin (6 LWC rules) that plug into the subscriber's existing CI without bespoke tooling. Verify that no hardcoded
credentials, SOQL-injection vectors, or unrestricted `without sharing` patterns exist.

**Navigation:** [Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#philosophy--design-principles) |
[Risks & Mitigations](Strategic%20Guide%20-%20Risks.md)
