---
navOrder: 30
---

# Strategic Guide - Personas

- **What this is:** a quick way to find the parts of the KernDX evaluation that matter to your role. Evaluating a framework looks different depending on whether you write the code, own the architecture, sign off on the budget, or carry the security risk. This guide gathers the decision factors for each role in one place.
- **Why it exists:** so you don't have to read every guide to find your own concerns.
- **Who should read it:** architects, technical leads, developers, package developers at an independent software vendor (ISV), admins, business stakeholders, executives, and security officers.
- **When to use it:** at the start of an evaluation, to jump straight to your role and the deep-dive guides behind it.

Read this alongside the [Strategic Guide](Strategic%20Guide%20-%20Overview.md). It pulls the decision factors together by stakeholder role, and each persona points to the relevant deep-dive. Start with the [Overview](Strategic%20Guide%20-%20Overview.md) for the one-page summary, then follow the per-persona pointers below
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

**KernDX fit.** The benefit for an architect is consistency: because every part of your codebase goes through one framework, the safety guarantees hold everywhere instead of in the places a developer happened to remember them. KernDX brings trigger, query, DML (database writes), web service, scheduled-job, logging, and Lightning Web Components (LWC) controller code under one roof, and those parts are designed to share context and call into each other (the classes are `TRG_Base`, `SEL_Base`, `DML_Builder`, `LOG_Builder`, `ComponentBuilder`, `API_Inbound`, and `API_Outbound`).

Because every code path runs through the same framework, four guarantees apply by default across the whole org, not piecemeal:

- Reads and writes both enforce the running user's permissions (FLS = field-level security; CRUD = object create/read/update/delete permissions).
- When someone turns off a safety check through the builders, a trigger bypass or a validation-rule bypass, the framework records what and why. So do the three lower-level save methods your code can call directly (`DML_Transaction.setAccessLevel(AccessLevel.SYSTEM_MODE)`, `DML_Transaction.commitWork(false)`, and `PROC_ExecuteDML` built with `AccessLevel.SYSTEM_MODE`).
- Inbound REST is protected against accidental replays: if the same request arrives twice the first result is returned again, but a repeat that reuses the key with a different body is rejected with HTTP 409 rather than silently masking the change (idempotency).
- Sensitive data is masked both where records are saved and where they are logged.

A drop-in library you assemble yourself cannot make those guarantees hold everywhere. Configuration lives in custom metadata, and the framework's own conventions are enforced for you by a code scanner that fails the build on a violation (a PMD ruleset and an ESLint plugin shipped in `scanner/`).

**Where KernDX ships the broadest coverage among the Apex frameworks surveyed.** The short version: of the Apex frameworks the team surveyed, KernDX covers the most capability areas in one package. It ships a production-ready implementation of all of these: Trigger Framework, Query Builder, DML, Web Services (Inbound), Web Services (Outbound), Resilience, Security, Data Masking, LWC, Async Patterns, Utilities, Health & Self-Diagnostics, and CI / Tooling.

There are three areas where another library has something KernDX does not, and you can mix it in:

- Logging & Diagnostics: [`nebula-logger`](https://github.com/jongpie/NebulaLogger) ships the choice of how each log is saved (four save methods), seven log levels, a retention date per log entry or scenario, and archiving to a Big Object. KernDX's `LOG_Builder` logs asynchronously by default (through a Salesforce Platform Event), works with the rest of the framework, and ships the Log Console and a live event monitor. If you need the deeper retention, archiving or save-method choice, run `nebula-logger` alongside KernDX.
- Testing (Mockito-style mocking): [`fflib-mocks`](https://github.com/apex-enterprise-patterns/fflib-apex-mocks) ships the canonical "set up a fake, then verify how it was called" style of mocking, which KernDX deliberately does not include. KernDX instead covers more of the test-data and mock-query side through `TST_Builder` and `TST_Mock`.
- Domain Patterns: [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) (its Application factory) together with [`at4dx`](https://github.com/apex-enterprise-patterns/at4dx) (cross-package extension injection) define the Domain / Service / Application layering. KernDX ships the domain layer through trigger actions, but no service layer or application factory. Adopt `fflib` alongside KernDX if you need the factory pattern.

**What ships.** Every core capability a Salesforce org needs is shipped, documented, and usable from day one, not stubbed out or left as a roadmap promise. That breadth is wider than the comparable Apex frameworks the team has surveyed; the next-broadest libraries are [`rflib`](https://github.com/j-fischer/rflib) and [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library).

**Security defaults.** The safe behaviour is on automatically: every query and every write runs with the current user's read/write permissions and record sharing enforced (this is Salesforce's `USER_MODE`), so by default no code can read or write data the user is not allowed to.

A few framework-internal reads genuinely need to skip the object and field permission checks (configuration reads and Chain Monitor aggregates):

- They opt out through `SEL_Base.systemModeRequired()` (`SYSTEM_MODE`), a documented method a selector overrides, which leaves record sharing following the calling class.
- Every one of those opt-outs is declared in source, where git history and code review see it.
- The access-mode scanner, which blocks the build in continuous integration (CI), fails a build when a query or save written with the builders names no access mode. It does not look at selector reads, so it does not check these opt-outs.

If your org hits an unexpected permission block in production, a metadata off-switch (a feature-flag kill-switch) can revert to `SYSTEM_MODE` without a code deployment.

Among the Apex frameworks the team surveyed, KernDX is the only one that runs with permissions enforced by default on both reads and writes while also shipping both the metadata kill-switch and a recorded audit entry when a call turns that default off through the builders, triggers or validation rules.

**When KernDX is not the best fit.** If your architecture is already built on `fflib`'s Domain + Service + Application pattern, stay there. `fflib` defines that pattern (`fflib_SObjectDomain`, `fflib_Application`), and KernDX does not ship an equivalent `SVC_Base` or Application factory.

Needing only one or two of these capabilities (triggers only, or queries only) is not a reason to look elsewhere: you adopt just those KernDX features, and the rest of the package stays inert. When you install the managed package, KernDX's code does not count toward your org's 6 MB Apex limit and is not copied into your org as your own source.

[TAF](https://github.com/mitchspano/trigger-actions-framework) (triggers) and [SOQL Lib](https://github.com/beyond-the-cloud-dev/soql-lib) (queries) are good single-purpose libraries. Weigh both sides: neither is a managed package. TAF installs as an unlocked package. SOQL Lib installs as a released unlocked package in the `btcdev` namespace (shared by the Beyond The Cloud packages), and you can also deploy it as source; the Apex of a library you deploy as source counts toward your org's 6 MB Apex limit. A set of them is connected, upgraded and security-reviewed one library at a time.

**Framework evaluation criteria:**

- Does this framework prevent anti-patterns (inline SOQL, trigger recursion, tightly-coupled code)?
- Can we enforce standards at scale (PMD rules, code review checklists, framework conventions)?
- What is the upgrade path and backward compatibility story?
- How does this integrate with existing architectural decisions (ISV packages, integration patterns)?

**Framework compliance scanner (plug-and-play).** A framework only stays consistent if its conventions are actually enforced. KernDX ships two rule sets you drop into the CI you already run, so you don't have to build or maintain your own tooling. An Apex ruleset works with any PMD runner (Salesforce Code Analyzer, Copado CI, Copado Robotic, Gearset CI, Azure Pipelines, GitHub Actions, or standalone `pmd`). An LWC ESLint plugin installs as an npm dev-dependency and extends the recommended config in your existing `.eslintrc`. [Metrics](Strategic%20Guide%20-%20Metrics.md#code-quality--scanning) has the current rule counts.

Together they enforce the framework's own conventions inside your pipeline (no inline SOQL, no `System.debug`, no `LightningElement`, explicit sharing, and detection of tests written only to pad coverage). The benefit: a violation fails the same pull-request check that already runs on every branch, so bad patterns can't merge. See [`Code Scanning - Guide`](Code%20Scanning%20-%20Guide.md) and [`Fast Start - Code Scanning`](Fast%20Start%20-%20Code%20Scanning.md).

**Alternative frameworks:**

- **Modular open-source stack:** TAF + SOQL Lib + `nebula-logger`. Each library does one job: TAF on declarative trigger registration, SOQL Lib on fluent queries, `nebula-logger` on log retention plus Flow logging actions. You connect the three yourself, and upgrade and security-review each one separately.
- **Domain-driven design:** `fflib`, with its `fflib_SObjectDomain` + `fflib_Application` Domain/Service/Application layering. KernDX has no equivalent.
- **Another query library:** SOQL Lib and KernDX's query builder both run reads with the user's permissions by default (`USER_MODE`), and either can be adopted on its own. Only KernDX records it when a call opts out, with the user and the reason; SOQL Lib's opt-out is a per-call method that leaves no record, and it has no org-wide off-switch. SOQL Lib installs as a released unlocked package in the `btcdev` namespace, or as source. KernDX's code does not count toward your org's 6 MB Apex limit when you install the managed package.
- **Granular assembly:** [Apex Fluently](https://github.com/beyond-the-cloud-dev), eight independently-shipped libraries (SOQL
  Lib, [DML Lib](https://github.com/beyond-the-cloud-dev/dml-lib), [Async Lib](https://github.com/beyond-the-cloud-dev/async-lib), [Cache Manager](https://github.com/beyond-the-cloud-dev/cache-manager), [HTTP Mock Lib](https://github.com/beyond-the-cloud-dev/http-mock-lib), [Test Lib](https://github.com/beyond-the-cloud-dev/test-lib), [LWC Utils](https://github.com/beyond-the-cloud-dev/lwc-utils),
  [Apex Consts](https://github.com/beyond-the-cloud-dev/apex-consts)). Each installs on its own, and none is a managed package: six install as released unlocked packages in the shared `btcdev` namespace, and Cache Manager and Apex Consts are deployed as source (the Apex of a library you deploy as source counts toward your org's 6 MB Apex limit). KernDX features are also adopted one at a time, and they already work together.
- **Utilities + selectors + Unit of Work:** `apex-libra`, installed as unlocked packages (one per module, no namespace), a separate ecosystem from Apex Fluently (different authors; `apex-libra` first commit June 2019, Apex Fluently first commit May 2025). It spans nine groups of modules, including 28 pre-built `QueryObject` selectors and a `DatabaseUnitOfWork` (register related records and save them together so they all commit or all roll back).

**Pilot first.** Deploy KernDX's `TRG_Dispatcher` (or TAF) on a single object with 2-3 trigger actions. Demonstrate metadata-driven handler reordering to
stakeholders in a 30-minute session.

**Key questions to ask:**

- How will we handle framework version upgrades across multiple sandboxes and production?
- What happens if the framework is deprecated or the maintainer moves on? (KernDX, TAF and SOQL Lib give the same answer: each is open source, so you can fork it and maintain it yourself regardless of the maintainer's status, and each has one main author.)
- Can we enforce framework usage via PMD rules or CI/CD gates?
- How do we prevent framework bypass (developers writing inline SOQL despite framework availability)?

**Governance fit.** KernDX fits best when your org already has some central control over how it builds. If you have no central architecture function yet, put those foundations in place first. A framework on its own will not enforce consistency without organisational support behind it. See [Governance Readiness](Strategic%20Guide%20-%20Adoption.md#governance-readiness-and-framework-suitability) and [Glossary](Strategic%20Guide%20-%20Glossary.md).

**Navigation:** [Philosophy & Design Principles](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#philosophy--design-principles) |
[Decision Matrix](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence) |
[Risks & Mitigations](Strategic%20Guide%20-%20Risks.md)

---

## Technical Lead

**Primary concerns:** team productivity, code quality, onboarding time, debugging efficiency.

**Start here:** [Adoption](Strategic%20Guide%20-%20Adoption.md) for roll-out guidance, and [Operations](Strategic%20Guide%20-%20Operations.md) for the operational signals behind day-2 ownership.

**KernDX fit.** For a technical lead, the point is faster onboarding and easier code review. New developers can build their first selector, trigger action, or API call within hours, helped by the 17 Fast Start guides, 21 topic guides, and AI-context files (`AGENTS.md` plus `docs/Code Conventions - Guide.md` at the repo root, and the per-module [AI Agent Instructions](AI%20Agent%20Instructions.md) reference).

That speed comes from a deliberate design choice KernDX calls the 95% rule: build for what most developers actually use day to day, rather than adding API methods just to look complete. Every name follows a documented convention (`SEL_*`, `TRG_*`, `API_*`, `UTIL_*`, `LOG_*`, `DML_*`, `QRY_*`), which makes code self-documenting and turns IDE auto-complete into the main way developers discover what's available.

On larger teams (more than 10 developers) this pays off in review. Reviews are quicker to scan when every selector follows the `SEL_*` pattern, every trigger is a one-line dispatch, and every log call follows `LOG_Builder.build().error(e).emitAt(...)`. See [Success Metrics](Strategic%20Guide%20-%20Adoption.md#success-metrics) for the measured improvements in code-review cycle time and onboarding time.

**Operational signals a technical lead typically cares about.** These are the day-2 quality signals KernDX ships, each one a thing you would otherwise have to build and maintain yourself:

| Signal | What it gives you |
|---|---|
| Library-agnostic PMD ruleset | Shareable for your own CI |
| 100% per-file Apex coverage gate | Enforced at every release build |
| 95% LWC statement/branch coverage gate | Enforced |
| [End-to-end release tests](Strategic%20Guide%20-%20Metrics.md#release-testing), run in a separate org with the package installed the way you would install it | Anonymous-Apex assertions across its numbered sections, plus `@IsTest` methods across the test classes in that org |
| Extended load-test suite + rolling performance-history baselines | Catches performance regressions |
| Release runbook | A repeatable release process |
| Recurring drift-audit cycle | Keeps source and org in step |

Two of these stand out compared with the other frameworks: among the Apex frameworks surveyed, KernDX is the only one with a per-file 100% Apex coverage gate enforced at every build. The end-to-end release tests, the extended load suite, the drift-audit cycle, and the release runbook are operational practices specific to KernDX.

**If your codebase already runs on another stack.** If your code is standardised on Apex Fluently, TAF or `nebula-logger`, weigh both costs. Moving costs the migration. Staying keeps what those libraries leave out: a TAF trigger bypass or a SOQL Lib opt-out from permission checks leaves no record, and you keep connecting and upgrading the libraries one at a time. If you rely on one of `nebula-logger`'s four extras (see [Admin / Ops](#admin--ops)), keep it alongside KernDX.

Note that the "too much framework to take on" worry doesn't really apply here. KernDX is incremental, so you install it once and opt into modules as you need them.

Each module has a timed, guided Fast Start and ApexDoc in your IDE (see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison); its columns are not measured alike: KernDX's is timed on a guided path, the others are estimates from reference pages).

Apex Fluently's eight separately installed libraries are a valid alternative too. Weigh both sides: KernDX's features are also adopted one at a time, and they already work together, so you do not connect them yourself or upgrade and review each one separately.

**Framework evaluation criteria:**

- Can new developers become productive quickly (< 2 weeks)?
- Does the framework improve or hinder debugging (stack traces, error messages, test isolation)?
- Are there clear patterns for common use cases (pagination, caching, error handling)?
- How much boilerplate is required for simple operations?

**Alternative frameworks:**

- **A fluent query library:** SOQL Lib (hours to learn, minimal boilerplate). KernDX's `QRY_Builder` is learnt in hours too, and it works with the rest of KernDX without extra wiring.
- **A trigger and query pair:** TAF + SOQL Lib (Flow-first, metadata-driven). You connect the two and upgrade each separately; KernDX covers both areas in one package, Flow trigger actions included.
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

**Start here:** [Architecture & Philosophy: Code Examples at a Glance](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#code-examples-at-a-glance) for the everyday APIs.

**KernDX fit.** For a developer, the everyday experience is the thing: the APIs you touch most are productive on day one, with no special mini-language to memorise. Here are the four you'll use most, each configured with short chained calls and then run with one terminal call:

- `TST_Builder.of(SObjectType).withOverride(field, value).build()`: fluent test data. You choose whether it does real DML or just hands back a mock Id (`.withoutInsertion()` keeps it in memory).
- `QRY_Builder.selectFrom(SObjectType).fields(...).condition(field).equals(value).toList()`: fluent queries with compile-time field safety, running with the user's permissions enforced (`USER_MODE`) by default.
- `LOG_Builder.build().error(e).emitAt('MyClass.myMethod')`: logging that saves asynchronously through the platform event channel, instead of `System.debug`.
- `DML_Builder.newTransaction().doInsert(record).execute()`: fluent database writes, running with the user's permissions enforced (`USER_MODE`) by default. It resolves parent-child relationships, and it checks the row count up front, throwing before the write if you'd blow past the governor limit.

Every method name shows up in IDE auto-complete. And the shape is the same everywhere: you configure with short chained calls, then one call runs it and returns the result. Because `TST_Builder`, `QRY_Builder`, `DML_Builder`, `LOG_Builder`, and `UTIL_HttpClient` all follow that shape, learning one means you've largely learned the others. The `AGENTS.md` and `docs/Code Conventions - Guide.md` files help AI coding assistants (Claude Code, Cursor, Windsurf) follow the framework's conventions when they generate new code.

Testing is where this saves the most time. Four pieces handle the parts of test setup that are usually painful, in one or two lines each: `TST_Builder` creates test data fluently, `TST_Mock` intercepts queries so you can test without DML, `TST_Factory` sets up metadata, and `API_MockFactory` mocks web service calls at two levels. Together they remove the two biggest test chores, setting up data without DML and asserting results without writing SOQL.

KernDX deliberately leaves out the "set up a fake, then verify how it was called" (Mockito-style) mocking, because the learning curve isn't worth it for how rarely most teams need it day to day. If you do want that style, install `fflib-mocks` alongside KernDX, which goes deeper on it. For the common case, `TST_Mock.of(SObjectType).withOverride(...).build()` registers itself for `SEL_*` queries with no extra setup, and combined with `withoutInsertion()` it covers most selector-test needs.

For queries, you do not need a second library for aggregate, cursor or semi-join patterns: `QRY_Builder` ships them (`groupBy` with `rollup()` and `cube()`, `toCursor()` and `getPage()`, and `isIn(Builder)` / `notIn(Builder)` for a subquery).

**If you already know TAF, KernDX's trigger actions will feel familiar.** KernDX's `TRG_*` framework is a direct evolution of TAF. It keeps the same metadata-driven dispatcher, the same one-class-per-concern discipline, and the same context interfaces (`BeforeInsert`, `AfterUpdate`, and so on), so the Apex you write looks nearly identical (see the code comparison below). A developer who knows TAF should be productive within hours.

What changes is mostly naming and one binding detail:

- Naming: `TA_*` becomes `TRG_*`, and `sObject_Trigger_Setting__mdt` becomes `TriggerSetting__mdt`.
- Action-context binding: TAF's 7 per-context MetadataRelationship fields become KernDX's `Event__c` picklist plus a single `TriggerSetting__c` lookup.

KernDX also adds something TAF doesn't: it records an audit entry when code bypasses a trigger and data changes, so each trigger bypass made in code, with its reason, is visible through the same log infrastructure. See the [TAF to KernDX migration narrative](Strategic%20Guide%20-%20Adoption.md#migration-narratives) for the honest breakdown of what you keep, give up, and gain.

**If you prefer another style.** If you find the naming conventions (`UTIL_*`, `SEL_*`, `QRY_*`) too verbose, or you prefer the style of SOQL Lib's single-class API for queries, that is a fair matter of taste. Weigh it against what you give up:

- KernDX's query builder already works with its selectors, logging and test mocks.
- Both SOQL Lib and KernDX's `QRY_Builder` run reads with the user's permissions by default (`USER_MODE`), but only KernDX records it when a call opts out, with the user and the reason. SOQL Lib's opt-out is a per-call method that leaves no record, and it has no org-wide off-switch.

On stack traces: KernDX is a managed package, so in your org each of its frames shows only as `(kern)`, with no class name or line number, while the frames of your own code show as usual. Those hidden frames are the cost. Its source is public, so you can still read the code they ran.

**Framework evaluation criteria:**

- Is the API intuitive (self-documenting method names, clear parameter types)?
- Are there code examples for common scenarios?
- Can I write tests easily (mocking, test data builders, assertions)?
- Does the framework make debugging harder (deep stack traces, framework abstractions obscuring business logic)?

**Alternative frameworks:**

- **Another fluent query API:** SOQL Lib, a fluent API that runs reads with the user's permissions by default (`USER_MODE`); its per-call opt-out leaves no record.
- **AI-assisted development:** frameworks that ship instruction files (such as `AGENTS.md` or cursor rules) help AI assistants follow the framework's conventions when generating new code. KernDX ships `AGENTS.md` (a tool-neutral pointer) and `docs/Code Conventions - Guide.md` (the canonical conventions) at the repo root, plus the per-module [AI Agent Instructions](AI%20Agent%20Instructions.md) reference.

**Pilot first.** Replace 3-5 inline SOQL queries with `SEL_Base` selector reads (or SOQL Lib equivalents) in an afternoon. Immediate readability improvement with minimal risk.

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

**Primary concerns:** AppExchange review, namespace management, keeping dependencies to a minimum, upgrade safety, impact on your customers' orgs.

**Start here:** [Architecture & Philosophy: Open-Source Readiness](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#open-source-readiness) for the
managed-package-readiness frame; [Operations: Packaging & Distribution](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy) for the
exit path.

**KernDX fit.** If you ship a managed package yourself, KernDX was built for the same world you live in, and it handles problems a general-purpose framework leaves to you:

- It finds the right Apex classes whether they're in your namespace or the package's (`UTIL_TypeResolver`).
- It resolves custom permissions with the installing org taking priority.
- It can be deployed under a namespace you configure.
- It holds 100% test coverage per file, checked at build time.

The public (`global`) API is kept deliberately small and tagged with `@since` so you can track which version added what. And for inbound REST, which reviewers always scrutinise, KernDX ships idempotency protection: if the same request arrives twice the first result is returned again, but a repeat that reuses the key with a different body is rejected with HTTP 409 rather than silently overwriting. Most other Apex frameworks don't address this.

**When KernDX is not the best fit.** If your AppExchange app must have no package dependency at all, avoid any framework, including this one. A source library does not make the review lighter, though: its classes become part of your package and are reviewed with it.

If you're already deep in `fflib`, weigh both costs:

- **Migrating** takes real work, because its patterns run through your business logic.
- **Staying** keeps `fflib`'s defaults: its selectors check object read access by default, but field permissions, sharing and writes are not checked by default, and no record is kept when a check is turned off.
- **A middle path** is to freeze your `fflib` usage and adopt KernDX patterns only for new modules.

**Framework evaluation criteria:**

- Does the framework work within a managed package namespace?
- How large is the `global` API, and can it be controlled?
- How does the framework handle your customers' customisation without breaking upgrades?
- Does the framework pass security review without issues?

**ISV-specific considerations:**

| Concern                    | KernDX approach                                                                                                                                                                                                                                                                              | Alternative                                                                                                                              |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| Namespace resolution       | `UTIL_TypeResolver` chain: your namespace → package namespace                                                                                                                                                                                                                                | Manual `Type.forName()`                                                                                                                  |
| Customer extensibility     | Metadata-driven configuration (triggers, validations, feature flags)                                                                                                                                                                                                                         | Custom settings, hardcoded                                                                                                               |
| Security review            | Explicit sharing on every class that reads or writes data; no inline SOQL; the user's permissions enforced by default (`USER_MODE`) on `QRY_Builder` / `DML_Builder`; each opt-out made through the query and DML builders, triggers and validation rules is recorded with what and why, and so are the three lower-level save methods; an inbound REST guard so that if the same request arrives twice the first result is returned again, and a repeat that reuses the key with a different body is rejected with HTTP 409; and a scanner rule that fails the build on an undeclared access mode | Manual review. SOQL Lib runs with the user's permissions enforced (`USER_MODE`) on read paths. Most other Apex frameworks let you turn the checks off but keep no record of it |
| Package size               | [The whole framework in one package](Strategic%20Guide%20-%20Metrics.md#package-codebase), production and test classes together. Unused code is inert. When you install the managed package, KernDX's code does not count toward your org's 6 MB Apex limit and is not copied into your package as your own source | SOQL Lib: ~15 classes, installed as an unlocked package in the `btcdev` namespace or deployed as source (the Apex of a library you deploy as source counts toward your org's 6 MB Apex limit). Apex Fluently: 8 libraries you install independently |
| Upgrade safety             | `@since` tags on all `global` members, no breaking changes policy, validated-build gate on every release (see [Metrics: Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for current build identifier and package-version count)                                    | Manual tracking                                                                                                                          |
| Test coverage              | 100% per-file Apex enforced at every release build; [an `@IsTest` suite across the framework's test classes](Strategic%20Guide%20-%20Metrics.md#package-codebase); end-to-end release tests in a separate install org                                                                                                                                                          | Varies by framework                                                                                                                      |
| Install-blocker discipline | An early install-blocker on orgs that still use the default organisation-wide sharing settings (OWD) was found and closed in the next package version, and you can see it in the release record. See [Metrics: Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for the current build identifier.                             | Varies by framework                                                                                                                      |

**Pilot first.** If you're evaluating KernDX for a new package, deploy the selector framework (`SEL_Base` + `QRY_Builder`) first. It gives you immediate value (no inline SOQL, cacheable queries, mock support) with the least disruption.

**Key questions to ask:**

- What percentage of my package's Apex classes will depend on framework classes? (Higher coupling = harder to exit.)
- Can your customers override framework behaviour without modifying package code? (KernDX: yes, via metadata.)
- How does the framework interact with managed package push upgrades?
- What is the exit strategy if the framework becomes a liability? (See [Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy).)

**Navigation:** [Packaging & Distribution](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy) |
[Open-Source Readiness](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#open-source-readiness) |
[Capabilities at a Glance](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#capabilities-at-a-glance)

---

## Admin / Ops

**Primary concerns:** configuration vs. code, deployment complexity, production support, monitoring.

**Start here:** [Operations](Strategic%20Guide%20-%20Operations.md) for day-2 ownership.

**KernDX fit.** For an admin, the headline is that you can control a lot of behaviour from Setup without waiting on a deployment. Because configuration lives in metadata, you can set trigger execution order, turn triggers on or off, toggle feature flags, and configure validation rules, all from the Setup UI.

Resilience is handled for you without code: after repeated failures the framework stops calling a failing system for a cool-off and then resumes (a circuit breaker, switched on for each service with one setting), and it retries automatically. For day-to-day support, `LogEntry__c` is a real, queryable log object you can build reports and dashboards on. And when a call bypasses a safety check through the builders, triggers or validation rules, the framework records who set it and why in that same log, so you can see what your code has turned off.

KernDX also ships three admin consoles as Lightning tabs:

- a **Streaming Event Monitor** for platform-event and Change Data Capture traffic, with event-usage metrics;
- a **Chain Monitor** for asynchronous job chains, which is also where you stop one that has gone wrong;
- a **Data Masking Advisor** for reviewing and exporting your data-masking coverage.

**Async chains: what is on already, and what you switch on.** Three protections apply from the moment a chain runs, with nothing for you to configure:

- Each run carries its own key, so a superseded or duplicate copy of a job cannot write over the live run.
- Every chain that ends, however it ends, writes a final log entry.
- A run that failed records the reason it failed.

Two more are decisions a developer makes in code, not something you switch on from Setup:

- A chain given a deduplication key refuses a duplicate start while a run is already in flight.
- An individual step can retry itself a bounded number of times with a widening delay.

Two capabilities are yours to run, and each needs one deliberate setup step before you can rely on it:

- **Stopping a running chain.** The Chain Monitor carries a stop action for a chain that has gone wrong. Set it up before you need it, because it ships switched off for everybody: the action sits behind a permission set that ships assigned to nobody, and whoever you assign it to also needs a permission set that can read the chain records, such as Kern Async Chain Monitor Read Only. The stop takes effect at the next step boundary rather than part-way through a step.
- **Recovering chains that stalled.** A scheduled job (`SCHED_ChainWatchdog`) checks whether a stalled chain's work is genuinely still running.
  - It recovers the ones it can prove died: it runs the stalled step again only when that is safe, and otherwise ends the chain as failed so nothing is done twice.
  - It leaves anything it cannot prove dead untouched, flagging it for a person instead.
  - It runs only once you schedule it. The Health Check, KernDX's configuration self-check screen, offers a one-click remedy that schedules it for you.
  - One thing worth knowing before you rely on it: a restarted run picks up under the framework's default settings rather than the settings its original builder chose.

**Operational discipline.** KernDX ships the practices that keep a release trustworthy over time: a release runbook, a recurring drift-audit cycle (re-run every ~4 weeks or before any package build), end-to-end release tests in a separate install org ([anonymous-Apex assertions](Strategic%20Guide%20-%20Metrics.md#release-testing) across its numbered sections), an extended load-test suite (`npm run test:load:extended`), and rolling performance-history baselines (`npm run test:perf:report`). For the current build identifier, commit count, and package-version count, see [Metrics: Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot).

As one concrete example of that discipline, an early install-blocker on orgs that still use the default sharing settings (OWD) was found and closed in the next package version, and it's visible in the release record.

**When KernDX is not the best fit.** If you rely on one of four logging features KernDX does not have, keep `nebula-logger` for it: the choice of how each log is saved, seven log levels, a retention date per log entry or scenario, and archiving to a Big Object.

KernDX's Log Console covers the browsing side (past entries searchable and filterable by severity, recurring problems grouped, and a per-operation drilldown), and `LogEntry__c` is fully queryable with masking applied, so reports and dashboards on it are ordinary org configuration you build yourself. The gap is those four features, not the browsing screen or the data.

If your admins work in Flows, note that both KernDX and TAF offer a bypass action for Flow; KernDX records each bypass made through it with who turned the check off and why.

**Framework evaluation criteria:**

- Can I configure framework behaviour without deploying code (custom metadata, custom settings)?
- How do I troubleshoot issues in production (debug logs, monitoring dashboards, error logs)?
- What is the deployment footprint (number of classes, metadata types, dependencies)?
- Can I disable framework behaviour temporarily for emergency maintenance?

**Alternative frameworks:**

- **Flow trigger actions with a typed collection input:** TAF has one piece KernDX lacks: its Flow trigger actions can take a typed `List<SObject>` collection input, where KernDX runs Flow actions one record at a time because of a platform limit. That is not a reason to choose TAF: KernDX covers everything else it does. Both configure trigger actions in custom metadata, both run Flows as actions and both offer a bypass action for Flow; KernDX records each trigger bypass made through the framework with who and why.
- **More logging options:** `nebula-logger` (the choice of how each log is saved, seven log levels, a retention date per log entry or scenario, and archiving to a Big Object; KernDX's Log Console covers browsing, search, grouped recurring problems and a per-operation drilldown).
- **Deployment:** SOQL Lib installs as a released unlocked package in the `btcdev` namespace, or you deploy it as source with zero dependencies, so its classes become your own code. KernDX installs as one managed package with zero external dependencies, and its code is not copied into your org as your own source.

**Pilot first.** Set up a trigger bypass through metadata (`TriggerSetting__mdt.BypassExecution__c` in KernDX, or `TriggerActionFlowBypass` in TAF) and show that you can disable a trigger in an emergency without a code deployment. With KernDX, the bypass also shows up in `LogEntry__c` as an audit event, so the ops team can see who set it and why.

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
| View bypass audit | Log Console, or `LogEntry__c` where `Fingerprint__c` starts with `detail:bypass:` (the user is in `UserId__c`); see the [Security Guide](Security%20-%20Guide.md#how-do-i-see-who-turned-a-check-off) for the query. Bypass entries are saved at every log level while logging is on | No |
| Circuit breaker status   | Platform Cache (read-only)                     | No             |
| Monitor event & API usage | Streaming Event Monitor + Chain Monitor tabs  | No             |
| Stop a running chain     | Chain Monitor tab (assign the Kern Async Chain Abort permission set first)           | No             |
| Recover stalled chains   | Schedule the `SCHED_ChainWatchdog` job (one-click remedy in the Health Check)    | No             |

**Navigation:** [Capabilities at a Glance](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#capabilities-at-a-glance) |
[Enterprise Delivery](Strategic%20Guide%20-%20Adoption.md#enterprise-delivery)

---

## Business Stakeholder

**Primary concerns:** time to market, cost of change, business continuity, risk.

**Start here:** [Overview: Executive Tear Sheet](Strategic%20Guide%20-%20Overview.md#one-page-executive-tear-sheet) for the one-page summary;
[Adoption: Build vs Buy total cost of ownership (TCO)](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) for the 3-year cost picture.

**KernDX fit.** For a business stakeholder, three things matter: cost, risk, and continuity, and KernDX is designed around all three. There are no licensing fees, and KernDX is open source under the Apache License 2.0, so you own access to the framework from day one. If you want the source handed over directly, `Unmanaged.zip` delivery is available through a consulting engagement. The 3-year cost picture in the Adoption guide shows KernDX coming out lowest in total cost for managed-package scenarios.

On risk, the built-in test tools (`TST_Builder`, `TST_Mock`, `TST_Factory`, `API_MockFactory`) plus the 100% per-file Apex coverage gate enforced on every release build mean new features are far less likely to break what already works. And the release runbook, drift-audit cycle, and end-to-end release tests produce real evidence of release quality every time a version is cut, which is the kind of assurance that's hard to point to when a team builds its plumbing ad hoc.

**Built-in checks vs. developer vigilance.** Here the difference is between checks that are built-in and on by default, and checks that rely on every developer remembering them. In KernDX, every read and every write that goes through the framework enforces security by default, and the only way to skip that is a deliberate, recorded override. So the absence of an override is itself proof the safe path was taken.

Frameworks that ask each developer to declare data-access rules on every query and every write depend on constant vigilance. KernDX removes that burden by making the safe behaviour the default. That changes the question your audit team has to ask: not "did the developer remember?" but "is there a recorded override on this line?", and you can answer that by reading the source.

**Developer tax: where engineering hours actually go.** Without standards bundled into the framework, teams pay the same cost over and over. Every sprint, developers hand-write access checks, hand-write logging, and hand-write protection against duplicate inbound webhook calls, and reviewers then spend time confirming all of that was done right.

KernDX bundles these as defaults: coverage is enforced by the build, security is on by default, and inbound REST already handles the duplicate-request case (returning HTTP 409 when a repeat reuses a key with a different body). The benefit is direct: your engineering capacity moves off rebuilding baseline plumbing and onto the features the business is actually paying for.

**SI turnover reality: your automated technical lead.** Most enterprise Salesforce delivery runs on systems-integrator (SI) partner teams whose engineers rotate often, sometimes every release. The real risk isn't that people leave; it's that the next engineer can quietly weaken the codebase before anyone notices.

KernDX guards against that automatically. Its 100% per-file coverage gate, security-on-by-default, and recorded bypasses act like a technical lead who never leaves: a junior developer can't ship code that skips coverage, can't silently turn off security, and can't opt out of a check through the builders, triggers or validation rules without leaving an audit record. That oversight lives in the build pipeline, not in any one person on the SI team.

**Automated governance, not developer preference.** The standards bundled in the framework are compliance built into CI/CD and into the defaults, not a style guide your team could quietly skip. The CI pipeline blocks the merge, and security is on by default. Each time a check is turned off through the framework's builders, a trigger bypass or a validation-rule bypass, the framework writes an audit record. If you want an exception, you write it as an audited, source-visible override, not as a silent local choice.

**Handing over to a client team that knows another stack.** Weigh both costs; no library is the pick here.

- **Staying** in the stack the client team knows means that in most other Apex libraries a bypass leaves no record, and the team keeps connecting and upgrading separate libraries itself.
- **Moving** costs the migration and the time to learn each KernDX feature you hand over.
- **The exception:** if the team relies on the `fflib` Application factory (with `at4dx`) for Domain-Driven Design, that is a capability KernDX does not have, and a reason to keep `fflib`.

Note that "small team" or "tight timeline" is not a reason against KernDX: it's incremental (install once, opt into modules), and each module has a timed, guided Fast Start and ApexDoc in your IDE (see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison); its columns are not measured alike: KernDX's is timed on a guided path, the others are estimates from reference pages).

**Return on investment (ROI) indicators (a rough estimate, not benchmarked against KernDX-specific deployments):**

The ranges below describe the kind of operational improvement that framework-enforced quality standards typically deliver. They come from published industry research summarised in [Adoption - Build vs Buy: Cost Considerations](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) (IBM/NIST on defect cost, the DevOps Research and Assessment programme (DORA) on documentation lift, Besker on technical-debt time). KernDX does not yet have a long enough public production track record to confirm KernDX-specific numbers, so treat these as **adoption milestones to measure against your own pre-framework baseline**, not as guaranteed outcomes.

| Metric                            | Without framework       | With KernDX                                                  | With TAF + SOQL Lib      |
|-----------------------------------|-------------------------|--------------------------------------------------------------|--------------------------|
| New developer onboarding          | 3-4 weeks               | 1-2 weeks                                                    | 1-2 weeks                |
| Code review cycle time            | 2-3 days                | 0.5-1 day                                                    | 0.5-1 day                |
| Production defect rate            | Higher                  | Lower                                                        | Lower                    |
| Integration development time      | High (custom each time) | Low (`API_Outbound` + `API_Inbound` + built-in protection against a request that arrives twice) | Medium (per-integration) |
| Framework migration cost if wrong | N/A                     | Grows with the number of features you adopted                | Low per library          |

> **Adoption milestones.** The Strategic Guide [Success Metrics](Strategic%20Guide%20-%20Adoption.md#success-metrics) section turns these rough ranges into
> measurable targets (30-50% production defect reduction, code review cycle time from 2-5 days to 1-2 days, new developer onboarding from 4-8 weeks to
> 1-2 weeks) that you should compare against your own pre-framework baseline at 90 / 180 / 365 days.

**Pilot first.** Calculate the cost of past incidents caused by inline SOQL, trigger recursion, or inconsistent error handling. Frameworks that prevent these
classes of bugs offset their adoption cost over time.

**Key questions to ask:**

- How long until the team is productive with this framework (weeks, months)?
- What is the cost of migration if we choose wrong? (KernDX: it grows with the number of features you adopted, because you move only the ones you use. TAF / SOQL Lib: low per library, but leaving a stack of several means leaving each one. `fflib`: high, because its Domain and Unit of Work patterns run throughout the business logic.)
- Can we deliver business features while learning the framework (parallel tracks)?
- What is the vendor lock-in risk? (See [Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy).)

**Change management.** Pilot with 2-3 developers before you mandate org-wide adoption. Measure concrete metrics during the pilot (code review cycle time, production defect rate, and new developer onboarding time) so you can build a data-driven case for a broader rollout. See also the [Adoption Roadmap](Strategic%20Guide%20-%20Adoption.md#adoption-roadmap) for phased rollout guidance.

**Navigation:** [Build vs Buy TCO](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations) |
[Adoption Roadmap](Strategic%20Guide%20-%20Adoption.md#adoption-roadmap) |
[Risks & Mitigations](Strategic%20Guide%20-%20Risks.md)

---

## Executive / Product Manager

**Primary concerns:** delivery velocity, team scalability, strategic risk, competitive positioning.

**Start here:** [Overview: Executive Tear Sheet](Strategic%20Guide%20-%20Overview.md#one-page-executive-tear-sheet) for the one-page summary.

**KernDX fit.** For an executive weighing the investment: KernDX is a framework with no licence cost and source ownership that standardises how your team builds on Salesforce. The business value is consistency at scale. When 10 or more developers follow the same patterns, code review and onboarding both improve (see [Success Metrics](Strategic%20Guide%20-%20Adoption.md#success-metrics) for measurable targets: 30-50% production defect reduction, code review cycle time from 2-5 days to 1-2 days, and new developer onboarding from 4-8 weeks to 1-2 weeks).

The up-front investment is learning each feature you adopt. KernDX is adopted one feature at a time, and each one has a timed, guided Fast Start and ApexDoc in your IDE (see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison); its columns are not measured alike: KernDX's is timed on a guided path, the others are estimates from reference pages).

**Where KernDX stands.** Measured against the other Salesforce frameworks the team surveyed, KernDX covers the most capability areas in one package: Trigger Framework, Query Builder, DML, Web Services (Inbound), Web Services (Outbound), Resilience, Security, Data Masking, LWC, Async Patterns, Utilities, Health & Self-Diagnostics, and CI / Tooling. That breadth is wider than the comparable Apex libraries surveyed.

There are three areas where another library goes deeper, and these are mix-alongside opportunities rather than reasons to look elsewhere: logging and diagnostics (`nebula-logger`), Mockito-style behaviour verification (`fflib-mocks`), and the Domain / Service / Application factory pattern (`fflib` + `at4dx`).

On security, KernDX declares sharing explicitly on its classes. Most use `inherited sharing`, so they follow the sharing of the code that calls them. It enforces data-access governance by default on both reads and writes, and records an audit entry for each opt-out made through its builders, triggers and validation rules.

On maturity, an honest read: KernDX is testing-hardened (a 100% per-file Apex coverage gate, 95% LWC coverage, and [anonymous-Apex assertions](Strategic%20Guide%20-%20Metrics.md#release-testing) in the end-to-end release tests), is publicly released under the Apache License 2.0 and promoted for production install, and is in active use at one known external client engagement today (see the date in the Metrics guide), with no named external production deployments yet.

Public adoption is still early. Established alternatives (`fflib`, `nebula-logger`, `rflib`) have years of publicly-referenceable production history; KernDX is newly public and does not yet have a comparable public adoption track record (installs of an open-source, promoted package aren't centrally tracked).

If you weight external production-adoption history as your primary signal, set that against KernDX's capability coverage; if you weight capability coverage and security defaults more, weight those above the adoption picture.

**Audit liability as a capacity cost.** Audit and regulatory exposure for data access isn't a matter of developer discretion on your books: it's a financial and reputational liability that lands on your company, not on the SI partner.

KernDX changes the question. Instead of "did the developer remember to enforce access governance on this query?", it becomes "the framework enforces access governance by default on every read and write, and any opt-out through the builders, triggers or validation rules writes an audit record." For your General Counsel, your chief information security officer (CISO), and your auditors, the answer is something you can read straight from the source: checks that are built-in and on by default, which you can defend, rather than a reliance on every developer remembering, which you'd have to vouch for.

**Developer tax: the TCO line item your forecast is missing.** Every hand-written access-mode declaration, every hand-rolled bypass without an audit record, and every sprint that re-argues "should this query enforce access governance?" is engineering capacity spent on non-feature work. KernDX bundles those as defaults, so that capacity flows back to the features your roadmap actually depends on. The cost is small per query but large per quarter, and it compounds with every new feature your team ships.

**SI turnover risk: organisational continuity without organisational dependency.** Most enterprise Salesforce delivery runs on systems-integrator (SI) partner teams whose engineers rotate at every release. That rotation is a known risk window when the checks that protect production live in people's heads rather than in the pipeline.

KernDX encodes the "is this safe to ship?" check in the build itself: the 100% per-file coverage gate, security on by default, and audit-trailed bypasses don't depend on which engineer the SI partner happened to staff this sprint. The framework acts as a technical lead who never leaves, so the risk of rotation is bounded by source-visible defaults rather than by any one person's vigilance.

**Automated governance, not vendor preference.** This is the framing to bring to your vendor diligence and your audit committee: the standards KernDX bundles are compliance built into CI/CD and into the framework defaults, not a developer-preference style guide your team could quietly opt out of. The answer you give an auditor is "the framework enforces this, the build blocks it, the bypass writes a record," not "the developer chose to apply best practice on this change." That distinction is what makes your answer defensible to auditors and to acquirers.

**Key decision from the Strategic Guide:**

> "Adopt KernDX for one or all of Trigger, Query, DML, Inbound REST, Resilience, Security, Data Masking, LWC, Async, Utilities, Health, Outbound, and CI tooling, in a single managed package you take up one feature at a time. Mix in nebula-logger where you need a choice of how each log is saved, all seven log levels, a retention date per log entry or per scenario, or Big Object archiving; fflib-mocks for behaviour-verification mocking; or fflib + at4dx for the Service / Application factory pattern." See
> [Overview](Strategic%20Guide%20-%20Overview.md#one-page-executive-tear-sheet).

**What you need to know:**

- **All major open-source frameworks are free.** TAF (Apache 2.0), SOQL Lib / Apex Fluently (MIT), `nebula-logger` (MIT), `fflib` (BSD-3), `apex-libra` (MIT), and `rflib` (BSD-3). KernDX is free too: it ships as a managed package, open source under the Apache License 2.0 (and with direct source delivery on consulting engagements). The cost is training and maintenance, not licences.
- **You have both kinds to choose from:** integrated frameworks (`fflib`, 2013; KernDX) and single-area libraries (SOQL Lib, TAF, 2020+), including Apex Fluently's 8 independent libraries. Neither has replaced the other.
- **AI may change the calculus.** Salesforce's Agentforce (announced 2024, generally available (GA) October 2024) creates demand for frameworks AI agents can interpret. Frameworks that ship instruction files give AI agents explicit conventions to follow. KernDX ships `AGENTS.md` and `docs/Code Conventions - Guide.md` at the repo root plus the per-module [AI Agent Instructions](AI%20Agent%20Instructions.md) reference, and some community projects are adding cursor rules.
- **Framework choice affects how new engineers ramp.**
  - `fflib` has the largest accumulated ecosystem footprint (10+ years, 74 contributors, referenced in Salesforce certification materials); that is adoption history, not a measure of the hiring market.
  - TAF and SOQL Lib use standard Apex patterns any Salesforce developer can read and pick up from public READMEs.
  - KernDX is in active use at one known external client engagement today (see the date in the Metrics guide) but has no named external production-deployment history yet, so the adoption path is internal ramp via `AGENTS.md`, `docs/Code Conventions - Guide.md`, the 21 developer guides, and 17 Fast Starts.
  - This guide does not measure hiring-market depth for any of these frameworks; reference your team's own historical onboarding data, not generic market-depth claims.

**Governance fit.** KernDX delivers most value once your org has some central control over how it builds. If your org has no central architecture function, adopting a framework on its own won't fix structural problems. Put those governance foundations in place first. See [Governance Readiness](Strategic%20Guide%20-%20Adoption.md#governance-readiness-and-framework-suitability) and [Glossary](Strategic%20Guide%20-%20Glossary.md).

**Pilot first.** Ask your architects to present the [Decision Matrix](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence) mapped to your specific
org situation. A 1-hour session can align technical strategy with business priorities.

**Navigation:**

- [Executive Tear Sheet](Strategic%20Guide%20-%20Overview.md#one-page-executive-tear-sheet) (1 page): complete landscape overview.
- [Build vs Buy Analysis](Strategic%20Guide%20-%20Adoption.md#build-vs-buy-cost-considerations): TCO comparisons.
- [Risks & Mitigations](Strategic%20Guide%20-%20Risks.md): due diligence.

---

## Security / Risk Officer

**Primary concerns:** vendor risk, attack surface, supply chain integrity, personal data (PII, personally identifiable information) in logs, regulatory compliance.

**Start here:** [Architecture & Philosophy: Salesforce Well-Architected Alignment](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#salesforce-well-architected-alignment) and the
sibling [Security Benchmark for Salesforce Alignment](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#security-benchmark-for-salesforce-alignment) for the
security defaults; [Risks](Strategic%20Guide%20-%20Risks.md) for the threat-model treatment.

**KernDX fit.** For a security or risk officer, the value is that the safe choice is the default everywhere, so you're auditing exceptions rather than hoping each developer did the right thing. The framework's security defaults are:

- Every class that reads or writes data declares its sharing explicitly.
- There is no inline SOQL anywhere in the framework.
  - Values in a query are always sent as bind variables (beside the query text, never inside it) or escaped (quote marks made harmless).
  - The query builder's condition, sort and group methods accept only a field name where they expect one. So a value, or a field name passed to those methods, cannot change the query.
  - Field names you select are not checked: pass them as tokens or constants. The one exception is a read that skips record sharing with `bypassSharing()` but keeps the user's checks (no `withSystemMode()`): there, anything in the select list that is not a field name or a path such as `Account.Name` is refused.
- Queries and writes run with the user's permissions enforced (`USER_MODE`) on both the read and write paths.
- Every bypass made through the builders, every trigger bypass and every validation-rule bypass writes a structured audit record, and you can trace it through one tracking ID that follows a single user action across triggers, queries, callouts, and jobs (a correlation ID, W3C-format). The three lower-level save methods your code can call directly (`DML_Transaction.setAccessLevel(AccessLevel.SYSTEM_MODE)`, `DML_Transaction.commitWork(false)`, and `PROC_ExecuteDML` built with `AccessLevel.SYSTEM_MODE`) write such a record too.
- Inbound REST protects against accidental replays: a repeat that reuses a key with a different body is rejected with HTTP 409 (idempotency).
- The masking framework rewrites sensitive content on any SObject (standard, custom, or platform event) in memory before the database stores it.
- `UTIL_SessionEncryption` handles data encryption.

Because you own the source, your security team can audit every line before deployment. On the four signals that most drive defect rate (sharing default, access-mode default, audit on bypass, and inbound trust), KernDX defaults to the secure setting. One nuance to know up front: masking per custom object is opt-in by design (see below), and the Data Masking Advisor surfaces the custom objects that still need it.

**Threat model documentation.** KernDX ships a bespoke Security Guide written specifically for the framework (`docs/Security - Guide.md`) plus a top-level `SECURITY.md` vulnerability-reporting policy at the repository root. 17 of the 25 comparable Apex frameworks surveyed in this guide ship no `SECURITY.md` at all (checked in each framework's source at its pinned commit). Seven Beyond-The-Cloud libraries (`apex-fluently-async`, `-cache`, `-consts`, `-dml`, `-httpmock`, `-soql` and `-test`) ship the same project-template `SECURITY.md`, which gives you a reporting channel but not a threat model written for the library, and `sf-bedrock` ships its own. `nebula-logger` ships a discoverable security narrative but no `SECURITY.md` either.

**Query / DML defaults.** `QRY_Builder` and `DML_Builder` default to `USER_MODE`, so the user's field-level and object permissions (FLS and CRUD) are enforced by default on every query and write. **Among the Apex frameworks the team surveyed, KernDX is the only one that defaults `USER_MODE` on both read and write paths and ships both a metadata kill-switch and a recorded audit entry on bypass.**

- The next closest is ApexKit, which checks permissions on reads and writes by default on its main paths and has a write path that cannot be switched off, but leaves no record when its other paths skip the check, and some of its reads (`getQueryLocator`, aggregate queries, SOSL) skip it silently.
- `apex-fluently-dml` checks writes by default, and `apex-fluently-soql` and `rflib` check reads by default; all three offer a per-call opt-out with no audit entry.

The few framework-internal reads that genuinely need to skip those checks (configuration reads and Chain Monitor aggregates) opt out through `SEL_Base.systemModeRequired()` (`SYSTEM_MODE`), a documented method a selector overrides. Every one of those is declared in source, where git history and code review see it. The access-mode scanner that blocks the build in CI fails a build when a query or save written with the builders names no access mode, but it does not look at selector reads, so it does not check these opt-outs.

If your org hits an unexpected permission block, the kill-switch metadata flags revert to `SYSTEM_MODE` without a code deployment.

**A record when a check is turned off through the framework's bypass calls.** When a safety check is turned off through one of these calls, KernDX writes a record of what and why. This covers:

- trigger bypasses (`TRG_Base.bypass*`);
- query bypasses (`QRY_Builder.withSystemMode` / `bypassSharing` / `withoutSecurity`);
- DML bypasses (`DML_Builder.withSystemMode` / `bypassSharing`);
- validation bypasses (`UTIL_ValidationRule.bypassObject` / `bypassGroup` / `bypassRule`).

The record captures the user, the action, the part of the framework, the target, and an optional reason, and because it's written as a Salesforce Platform Event it survives a transaction rollback. The three lower-level save methods your code can call directly (`DML_Transaction.setAccessLevel(AccessLevel.SYSTEM_MODE)`, `DML_Transaction.commitWork(false)`, and `PROC_ExecuteDML` built with `AccessLevel.SYSTEM_MODE`) write the same record.

One query lists each distinct bypass with its user and first reason: `LogEntry__c` rows whose `Fingerprint__c` starts with `detail:bypass:`, with the user in `UserId__c`; the `rollup:bypass:` rows give the days and counts of repeats. Bypass entries are saved at every log level, ERROR included, while logging is on. A master kill-switch lets you suspend audit emission in noisy environments.

Here is how the other frameworks compare: no other Apex framework surveyed records bypasses with the user and the reason. Two others write something in narrow cases: ApexKit saves a free-text entry, with no field for the user, for one kind of explicit trigger bypass, and `rflib` writes a warning at its org-wide and per-user trigger switches that is not saved by default. Most others (`apex-libra`, `fflib`, `apex-fluently-dml`, `apex-fluently-soql`, and TAF's bypass methods) ship enforcement toggles that write no audit event when a bypass occurs.

**Masking framework with kill switch (per-SObject opt-in by design).** The masking framework rewrites sensitive content on any SObject before the database stores it, configured with `MaskingRule__mdt` and `MaskingTarget__mdt`. The framework as a whole is on by default and can be turned off with a single metadata flag (the kill-switch). Out of the box it already masks card numbers and secrets on the framework's own log events, API calls, API issues and chain runs. For your own objects you switch it on per object via `MaskingTarget__mdt` and `TriggerSetting.ApplyMasking__c = true`, and `MaskingBlockedException` is catchable by type.

The per-object opt-in is a deliberate performance choice. Most orgs don't push credit-card data through every record write, and running regex matching against every SObject would add regex overhead to the org's entire write volume. There's a clear trade-off to make:

- If you want more of your logs masked by default, for example US social security numbers, pair KernDX with `nebula-logger`, which goes deeper here. It ships 4 default-on regex rules and applies them to the log message, the record data and the HTTP and REST bodies it logs.
- If you prefer performance plus domain-specific control over what gets masked, adopt KernDX's per-object opt-in as-is.

The **Data Masking Advisor** console handles the discoverability side, so opt-in doesn't mean "easy to forget." It scans your own custom objects for regulated fields that have no masking target, exports a regulated-field inventory (CSV or JSON, with a *Sensitive fields only* filter) and a deployable masking-config bundle, and feeds the [Security Governance Evidence](Security%20-%20Guide.md#security-governance-evidence) your auditors ask for.

**Regulatory anchors the masking framework supports** (you map specific fields to rules; the framework provides the infrastructure, not the policy):

- **GDPR** Article 25 (data protection by design and by default), Article 5(1)(c) (data minimisation).
- **PCI-DSS** v4.0 Requirement 3 (protect stored account data).
- **HIPAA** Privacy Rule §164.514 (de-identification / Safe Harbor).
- **CCPA/CPRA** §1798.100(c).
- Optional for enterprise buyers: **ISO 27001:2022** A.8.11 (named "data masking"), **SOC 2** CC6.

**When your procurement rule requires several maintainers.** Only the `fflib` project has several maintainers. KernDX is open source under the Apache License 2.0 with a public repository, but it has a single maintainer, a short public commit history, and does not accept pull requests from outside contributors yet (issues and feature requests are welcome). TAF, SOQL Lib and `nebula-logger` each have one main author too.

**Framework evaluation criteria:**

- Does the framework introduce third-party dependencies that expand the supply chain attack surface?
- Can we audit the source code before deployment (open-source, source-available, or full handover)?
- Does the logging layer expose PII or sensitive data in debug output or platform events?
- How is framework code patched, and what is the vulnerability response timeline?

**Security comparison.** The full side-by-side (KernDX, the modular stack, and `fflib`) is collapsed below so it doesn't wall off the front of this section. Expand it for the row-by-row detail.

<details>
<summary>Security comparison: KernDX vs. modular stack vs. <code>fflib</code></summary>

| Security concern        | KernDX                                                                                                                                                                                                                               | Modular stack (TAF + SOQL Lib + `nebula-logger`)                                                                                                                              | `fflib`                                                                                            |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Source audit            | Public GitHub repo (Apache 2.0)                                                                                                                                                                                                       | Public GitHub repos                                                                                                                                                           | Public GitHub repo                                                                                 |
| Sharing enforcement     | Mandatory `with sharing` declaration on every class                                                                                                                                                                                  | Developer responsibility                                                                                                                                                      | Developer responsibility                                                                           |
| Query security default  | `USER_MODE` (the user's permissions enforced) on by default on read paths, and any opt-out is one you write in source, where code review sees it (`SEL_Base.systemModeRequired()` plus a metadata off-switch)                                                                                 | SOQL Lib: `USER_MODE` on by default on read paths; a per-call opt-out leaves no record, and there is no org-wide off-switch; the `SOQLCache` constructor quietly drops to `SYSTEM_MODE` (those checks skipped) in its cache extension                         | Developer responsibility; `newQueryFactory().setCondition(String)` accepts arbitrary WHERE strings |
| DML security default    | `USER_MODE` on by default on write paths, and any opt-out is one you write in source and is recorded (a metadata off-switch; configuration changes tracked via Setup Audit Trail)                                                                | DML Lib: `USER_MODE` on by default on write paths, but `userMode()` / `systemMode()` / `withSharing()` / `withoutSharing()` change `Configuration` in place with no record of it              | SimpleDML default skips field-level and object permission checks (FLS/CRUD) on every write                                                 |
| Record when a check is turned off | Each opt-out made through the builders, triggers and validation rules writes a record of what and why (user, action, part of the framework, target, optional reason) that survives a rollback, and so do the three lower-level save methods; a single master off-switch can suspend it | ApexKit: a free-text entry with no user field, for one kind of explicit trigger bypass; `rflib`: a trigger-switch warning that is not saved by default. Most other Apex frameworks (`apex-libra`, `fflib`, `apex-fluently-dml`, `apex-fluently-soql`, TAF programmatic) let you turn the checks off but keep no record of it | A silent on/off flag, no record kept                                                                  |
| SOQL injection          | No inline SOQL; values are sent as bind variables or escaped; the query builder's condition, sort and group methods accept only a field name where they expect one; field names you select are not checked, so pass them as tokens or constants | SOQL Lib: values are bound by default. Three exceptions: `whereAre(String)` and `have(String)` add your text to the query as written; so do its methods that take a field name as text; and its multi-select picklist filters add values without escaping them | Developer responsibility (see `fflib_QueryFactory.setCondition`, which joins strings into the query)      |
| Inbound REST trust      | If the same request arrives twice the first result is returned again; a repeat that reuses the key with a different body is rejected with HTTP 409                                                                                                                                                                        | Not provided                                                                                                                                                                  | Not provided                                                                                       |
| Runtime field redaction | `MaskingRule__mdt` + `MaskingTarget__mdt`: any SObject's text fields, before the database stores them; the framework is on by default with a single off-switch, and you opt in per SObject                                                                         | Manual implementation per call site (`nebula-logger` masks log entries only; on by default, with 4 shipped pattern rules SSN+Visa+MasterCard+Amex that run before the log is written. They cover the message, record data and HTTP and REST bodies, but not exception messages or headers)           | Not provided                                                                                       |
| Log PII protection      | Same framework as runtime field redaction: same metadata, different target wirings                                                                                                                                                  | `nebula-logger`: masking on by default with 4 shipped pattern rules + an extension point; `suspendSaving` / `resumeSaving` quietly stop logs being written, with no record of it                                          | Not provided                                                                                       |
| Encryption              | `UTIL_SessionEncryption` (AES256, session-scoped keys)                                                                                                                                                                               | Manual implementation                                                                                                                                                         | Not provided                                                                                       |
| Threat model            | Bespoke, detailed [Security Guide](Strategic%20Guide%20-%20Metrics.md#documentation)                                                                                                                                                | `nebula-logger` ships a discoverable security narrative; 17 of 25 alternative Apex frameworks surveyed ship no `SECURITY.md`                                                  | No `SECURITY.md`                                                                                   |
| Dependencies            | Zero external                                                                                                                                                                                                                        | Zero external (each library)                                                                                                                                                  | Zero external                                                                                      |

</details>

**Pilot first.** Run a static analysis scan (PMD, Checkmarx, or CodeScan) against the framework source before you adopt it. KernDX ships its own shareable PMD ruleset for Apex and an ESLint plugin for LWC (see [Metrics](Strategic%20Guide%20-%20Metrics.md#code-quality--scanning) for the current rule counts) that plug into your existing CI without bespoke tooling. Verify that no hardcoded credentials, SOQL-injection vectors, or unrestricted `without sharing` patterns exist.

**Navigation:** [Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#philosophy--design-principles) |
[Risks & Mitigations](Strategic%20Guide%20-%20Risks.md)
