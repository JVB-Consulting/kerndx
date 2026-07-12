---
navOrder: 10
---

# KernDX — Strategic Overview

A self-assessment of the KernDX Salesforce framework, its design philosophy, and how it compares to alternatives in the Salesforce framework ecosystem, authored by the KernDX team. Where another framework covers an area more thoroughly than KernDX, this guide names that framework and explains the trade-off.

**What it is:** KernDX is a Salesforce managed-package framework, a single installable package that gives your org ready-made, tested building blocks for the work almost every serious org needs: trigger handling, database queries and writes, web-service integrations, background jobs, validation, logging, data masking, and security checks. **Why it exists:** most teams build these themselves over three to five years; KernDX ships them up front so you skip the rebuild. **Who should read this:** executives sizing up the framework, architects and tech leads choosing one, developers who will use it day to day, delivery managers weighing cost and risk, and ISVs building managed packages. **When to use it:** when you want broad, consistent coverage of these areas in one package, and you want to know honestly where a specialist library still goes deeper. **Where to start:** read this overview, then follow the reading path for your role in the [Who should read what](#who-should-read-what) table at the end.

KernDX is one architectural approach in a maturing Salesforce framework ecosystem. It is a managed-package alternative built for enterprise delivery, managed-package development, and integration-heavy environments. It is not intended to replace open-source frameworks in every case. This guide compares KernDX against the alternative Salesforce frameworks the team has surveyed, and it acknowledges that different team constraints lead to different best choices.

---

**How this guide set is organised.** The full picture is split into focused documents so you can read just the part that matters to you, or read them in order for the whole story.

| Document                                                                                    | What's Inside                                                                                                                                                                              |
|---------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Overview** (this document)                                                                | Executive tear sheet, key findings, recommendations, navigation                                                                                                                            |
| **[Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md)** | Design principles, capabilities, Well-Architected alignment, open-source readiness                                                                                                         |
| **[Adoption](Strategic%20Guide%20-%20Adoption.md)**                                         | Enterprise delivery, TCO model, AI tooling alignment, decision matrices, coexistence patterns, brownfield roll-out roadmap                                                                 |
| **[Choosing a Framework](Strategic%20Guide%20-%20Choosing%20a%20Framework.md)**             | Capability-by-capability comparison against the established Apex frameworks (`fflib`, `taf`, `nebula-logger`, …), pick-by-capability guidance, head-to-head trade-offs, organisational fit |
| **[Operations](Strategic%20Guide%20-%20Operations.md)**                                     | Packaging, distribution, exit strategy, post-handover support tiers, performance and governor limits                                                                                       |
| **[Risks](Strategic%20Guide%20-%20Risks.md)**                                               | Risks and mitigations, "when not to use KernDX", adoption gates, hard questions architecture review boards will ask                                                                        |
| **[Personas](Strategic%20Guide%20-%20Personas.md)**                                         | Stakeholder-specific decision views (CTO, architect, developer, PM, ISV)                                                                                                                   |
| **[Glossary](Strategic%20Guide%20-%20Glossary.md)**                                         | Term definitions used in this guide                                                                                                                                                        |
| **[Metrics](Strategic%20Guide%20-%20Metrics.md)**                                           | Framework-internal metrics: class counts, test coverage, metadata totals                                                                                                                  |

---

## What makes KernDX different

Three standards are built in and turned on by default. You can switch any of them off for a single call, but every time you do, KernDX records why, so an audit later answers itself.

**1. Test coverage can't slip.** Code is only released once every Apex class is 100% covered by tests and every Lightning (LWC) component hits 95% of its statements and 95% of its
branches. The check runs automatically on every release build (the `scripts/evaluate-coverage.js` gate). *What this means for your team:* coverage gaps can't reach production through
neglect or a rushed merge. More detail in [Risks](Strategic%20Guide%20-%20Risks.md).

**2. Permission checks are on automatically, on reads and writes.** Every query through `QRY_Builder` and every write through `DML_Builder` runs in `USER_MODE` by default. That
means the current user's own field-level security (which fields they can see and edit) and object permissions (which records they can create, read, update, and delete) are enforced
for both reading AND writing, not just reading. *What this means for your team:* if a profile hides a field, the framework honours that automatically, with no per-class developer effort.
The design reasoning is in [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md).

**3. Every safety-check bypass is recorded.** When a query, write, validation, or trigger turns off one of these default-on checks, the framework writes an audit entry (through
`TRG_Base` and `UTIL_BypassAudit`) noting what was bypassed and why. *What this means for your team:* a security-review board can answer "where, when, and why did we bypass a check?"
by querying the audit log, instead of hunting through the codebase. More on the audit posture in [Risks](Strategic%20Guide%20-%20Risks.md).

---

## One-page executive tear sheet

**What is KernDX**

| Field | Value |
|---|---|
| **Type** | An enterprise Salesforce managed-package framework |
| **Namespace** | Configurable |
| **API version** | 67.0 |
| **Build status** | v1.0 packaged (first validated build; testing-hardened against 100% per-file Apex coverage, 95% LWC, and an extensive subscriber e2e harness) |
| **Licensing fees** | Zero |
| **Licence** | Source publicly available under BSL 1.1 (relicenses to Apache 2.0 after a four-year change date) |

- First validated build packaged; subsequent releases tracked in the Metrics doc (linked below)
- Single contributor at the snapshot date
- 100% per-file Apex coverage + 95% LWC statements + 95% LWC branches, enforced by `scripts/evaluate-coverage.js` at every release build
- For current class counts, LWC bundle counts, commits and package versions, see the Metrics doc (linked below)

**Capability areas KernDX covers broadly**

Production-ready, end-to-end implementations across all of these areas:

| | | |
|---|---|---|
| Trigger Framework | Query Builder | DML |
| Web Services — Inbound | Web Services — Outbound | |
| Resilience | Security | Data Masking |
| LWC | Async Patterns | Utilities |
| Health & Self-Diag. | CI / Tooling | |

**Where to mix KernDX with other libraries**

| Area | Guidance |
|---|---|
| Logging & Diagnostics | KernDX ships a `LOG_Engine` for capture + audit; pair with nebula-logger when you need a broader logging-surface (custom dashboards, per-class log levels, Pharos integration). |
| Testing (mock library) | KernDX mocks the query and HTTP layers rather than shipping a mock class family: `TST_Mock` registers in-memory records that framework queries and selectors return instead of running SOQL (WHERE conditions evaluated in memory where a context class is available, plus in-memory ORDER BY and LIMIT), `API_MockFactory` stubs HTTP callouts with call verification and fault simulation, and `TST_InvokeFlowMock` cans Flow responses. There is no DML stubbing: DML-free tests come from intercepting the query layer and building records without insertion. Pair with fflib-mocks when you specifically need Mockito-style behaviour-verification mocking. |
| Domain Patterns | KernDX ships light on the Domain layer; pair with fflib + at4dx if you need the Service / Application factory pattern. |

**When to adopt KernDX**

"Adopt KernDX when you need broad coverage across Trigger, Query, DML, Inbound REST, Resilience, Security, Data Masking, LWC, Async, Utilities, Health, Outbound, and CI tooling in a single managed package; mix in nebula-logger for logging-surface depth, fflib-mocks for behaviour-verification mocking, or fflib + at4dx for the Service / Application factory pattern."

---

## Table of Contents

<details>
<summary>Expand full contents across all documents</summary>

### [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md)

- [Philosophy & Design Principles](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#philosophy--design-principles)
- [Capabilities at a Glance](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#capabilities-at-a-glance)
- [Salesforce Well-Architected Alignment](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#salesforce-well-architected-alignment)
- [Open-Source Readiness](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#open-source-readiness)

### [Adoption](Strategic%20Guide%20-%20Adoption.md)

- [Enterprise Delivery](Strategic%20Guide%20-%20Adoption.md#enterprise-delivery)
- [AI & Modern Platform](Strategic%20Guide%20-%20Adoption.md#ai--modern-platform)
- [Decision Matrix & Coexistence](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence)
- [Adoption Roadmap](Strategic%20Guide%20-%20Adoption.md#adoption-roadmap)
- [Conclusion](Strategic%20Guide%20-%20Adoption.md#conclusion)

### [Operations](Strategic%20Guide%20-%20Operations.md)

- [Packaging, Distribution & Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy)
- [Post-Handover Support Model](Strategic%20Guide%20-%20Operations.md#post-handover-support-model)
- [Performance & Governor Limits](Strategic%20Guide%20-%20Operations.md#performance--governor-limits)

### [Risks](Strategic%20Guide%20-%20Risks.md)

- [When NOT to Use KernDX](Strategic%20Guide%20-%20Risks.md#when-not-to-use-kerndx)
- [When Modular Architectures Clearly Excel](Strategic%20Guide%20-%20Risks.md#when-modular-architectures-clearly-excel)
- [Risks, Mitigations & Trade-offs](Strategic%20Guide%20-%20Risks.md#risks-mitigations--trade-offs)

### [Glossary](Strategic%20Guide%20-%20Glossary.md)

### [Personas](Strategic%20Guide%20-%20Personas.md)

### [Metrics](Strategic%20Guide%20-%20Metrics.md)

</details>

---

### What KernDX is and how it compares

**What KernDX is built on.** KernDX follows five design principles (the full design narrative is in the [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) doc):

1. **Every feature earns its place.** It ships because it delivers real value today, not because it's clever to have.
2. **Learn one part, you've learned the rest.** Every major part of the framework works the same way: you configure it with a few short chained method calls and finish with one
   call that runs it and returns the result. `TST_Builder`, `QRY_Builder`, `DML_Builder`, `LOG_Builder`, `UTIL_HttpClient`, and the rest all follow that same shape, so learning one
   teaches you the others.
3. **It solves what almost everyone needs.** The work 95%+ of teams will actually do, not the long tail of rare cases.
4. **The parts work together out of the box.** Calls flow through one shared context, so `TRG_Base`, `SEL_Base`, `DML_Builder`, and `LOG_Builder` cooperate without you writing any
   glue code to connect them.
5. **It skips the slow tech-debt build-up.** It's the foundation a well-resourced enterprise team would build up front, given the budget to do it once instead of accreting it over
   years.

> **The headline finding.** KernDX covers most of the framework areas a Salesforce org needs, broadly, meaning it ships a complete, end-to-end implementation you don't have to assemble from separate libraries. That holds for Trigger Framework, Query Builder, DML, Web Services — Inbound, Resilience, Security, Data Masking, LWC, Async Patterns, Utilities, Health & Self-Diagnostics, and CI / Tooling. On Web Services — Outbound, KernDX ships the broadest implementation of the comparable Apex libraries we surveyed.

Three areas are different. KernDX does **not** cover them broadly, and a specialist library goes deeper:

- **Logging & Diagnostics:** [`nebula-logger`](https://github.com/jongpie/NebulaLogger) ships a broader logging surface; run it alongside KernDX when you need that depth.
- **Testing:** KernDX ships broad stubbing, but [`fflib-mocks`](https://github.com/apex-enterprise-patterns/fflib-apex-mocks) covers Mockito-style behaviour verification (checking
  *how* code was called, not just its result), which KernDX has no equivalent for.
- **Domain Patterns:** [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) ships the Application factory and [`at4dx`](https://github.com/apex-enterprise-patterns/at4dx)
  adds cross-package injection; KernDX ships light on the Domain layer.

On the outbound mock-library piece specifically, KernDX matches [`apex-fluently-httpmock`](https://github.com/beyond-the-cloud-dev/http-mock-lib), a single-purpose HTTP-mock library, and goes no further on that one piece.

Beyond those comparisons, every core capability KernDX claims is shipped, documented, and usable from day one, not stubbed out or aspirational.

**Capability and adoption activity are reported separately, and on purpose.** This guide keeps two questions apart: *what does each framework do* (its capability coverage) and *how active is each framework* (its commits, contributors, tagged releases, days since last release, and outside citations). The activity track is reported on its own and never decides which framework covers more. KernDX's current contributor, commit, tag, and package-version counts live in the [Metrics](Strategic%20Guide%20-%20Metrics.md) doc, which is the authoritative source. Some frameworks have a longer track record than KernDX, including [`rflib`](https://github.com/j-fischer/rflib), [`apex-fluently-soql`](https://github.com/beyond-the-cloud-dev/soql-lib) and [`apex-fluently-dml`](https://github.com/beyond-the-cloud-dev/dml-lib), yet cover fewer capabilities. So choosing KernDX is a different decision from choosing `rflib` or `fflib`: weigh capability coverage and track record independently, because they don't move together.

**KernDX is an accelerator you can own, not a product you rent.** There are no licensing fees, and the source is publicly available under the Business Source License 1.1 (which automatically relicenses to the permissive Apache 2.0 after a four-year change date). You have three documented ways to walk away from the managed package without losing the framework: keep using the managed package, deploy it as source from the public repository, or repackage it under your own namespace using the tooling KernDX ships. KernDX is one of the few Apex frameworks that documents that repackage-under-your-own-namespace path as a first-class exit; the full analysis is in [Packaging, Distribution & Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy).

**How to read this document.** If a comparison looks wrong or out of date relative to a linked library's current state, please open an issue in this repository.

#### What is KernDX?

KernDX is a Salesforce managed-package framework. It gives you ready-made, integrated handling for trigger logic, data access, database writes (DML), web-service integrations,
background processing, validation, logging, hiding sensitive field values at runtime (data masking), and a set of utilities. You can adopt it on any existing or brand-new org,
either all at once or one piece at a time.

**Key facts:**

|                           |                                                                                                                                                                                                                                                                                                            |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Package Type**          | Managed Package (2GP)                                                                                                                                                                                                                                                                                      |
| **API Version**           | 67.0 (`sourceApiVersion` per `sfdx-project.json`)                                                                                                                                                                                                                                                          |
| **Licence**               | Business Source License 1.1: source-available, four-year clock to Apache 2.0                                                                                                                                                                                                                              |
| **Status**                | First validated build shipped and packaged, testing-hardened (100% per-file Apex coverage gate + 95% LWC + subscriber e2e harness); publicly released under BSL 1.1 and promoted for production install, in active use at one known external client engagement at the snapshot date, with no named external production deployments yet and public adoption still early |
| **Coverage gate**         | 100% Apex per-file + 95% LWC statements + 95% LWC branches enforced by `scripts/evaluate-coverage.js` at every release build                                                                                                                                                                               |
| **Latest packaged build** | See [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for the current build identifier                                                                                                                                                                                   |

For current Apex class counts, LWC bundle counts, commit and package-version counts, and the full set of framework-internal metrics (Apex method counts, Flow invocables, selectors,
surface method counts, documentation page counts), see the [Metrics](Strategic%20Guide%20-%20Metrics.md) doc, which is the authoritative source. Other guides link here rather than
carrying their own snapshot counts.

KernDX source is publicly available under BSL 1.1 on the project repository (and relicenses to Apache 2.0 after a four-year change date). You can keep using the managed package,
deploy it as source from the public repository, or repackage it under your own namespace using the repackaging tooling and `Unmanaged.zip` artifact KernDX ships: three documented
exit paths, not just source-on-GitHub. Consulting engagements include direct source delivery and handover support.

#### Key findings

The findings below summarise how KernDX compares against the alternative Salesforce frameworks this guide surveyed. Where another library covers an area more thoroughly, that library
is named together with the specific feature that makes the difference.

**1. KernDX ships a complete, ready-to-use implementation of every core Salesforce capability.** Each core capability a Salesforce org needs is shipped, documented, and usable from
day one, not stubbed out or aspirational. This is broader coverage than the other Apex frameworks the team surveyed; `rflib` and
[`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library) come closest. Three of these capabilities are uncommon among the libraries surveyed: inbound REST routing
that keeps the routing layer separate from the implementation (a `REST_*` / `API_*` two-class pattern), the LWC component framework with its 5 modules and registry-based
activation, and converting data between LWC and Apex as small purpose-built classes (LWC ↔ Apex DTO marshalling; a DTO, Data Transfer Object, is a small class holding exactly the
fields you want to move, that converts itself to and from JSON).

**2. KernDX covers most framework areas broadly,** meaning a complete, end-to-end implementation you don't assemble from separate libraries. For each area below, the *decisive
features* are what make the difference in the comparison:

- **Trigger Framework.** Decisive features: every bypass writes an audit log you can monitor; bypass works at four levels (per-object, per-action, per-flow, framework-wide).
- **Query Builder.** Decisive features: extensive query API; no SOQL string concatenation needed; field-level security and object permissions (FLS/CRUD) enforced by default,
  with a per-query bypass that's audited.
- **DML.** Decisive features: a multi-step save runs as one all-or-nothing transaction; all five DML operations supported; FLS/CRUD enforced on writes by default, with a
  per-write bypass that's audited.
- **Web Services — Inbound.** KernDX is one of the few Apex frameworks surveyed that ships inbound REST routing. Decisive features: REST routing kept separate from business
  logic; a central dispatcher; uniform error responses.
- **Resilience.** Decisive features: feature flags via custom metadata or per-user/per-profile settings; read those flags from Apex, Flow, and LWC; an extensible strategy
  design you can plug into.
- **Security.** Decisive features: reads enforce field-level security by default; a master off-switch and per-method opt-out; bypasses are audit-logged.
- **Data Masking.** Decisive features: masks values by regex, by Luhn check (which detects payment-card numbers), by literal string, and by JSON key; four masking modes; three
  failure actions; 18 built-in masking rules; and a Data Masking Advisor console that scans which fields are covered and exports an inventory of regulated fields.
- **LWC.** Decisive features: five built-in LWC component modules you turn on as needed; clear error messages when a module isn't enabled; invalid modules are rejected at
  registration.
- **Async Patterns.** Decisive features: finalizer hooks; state carries from one background transaction to the next; an emergency off-switch.
- **Utilities.** Decisive features: 39 utility helpers; null-safe by default; masking helpers that combine with the Data Masking engine.
- **Health & Self-Diagnostics.** KernDX is one of the few Apex frameworks surveyed that ships a health-check capability. Decisive features: a seven-dimension self-diagnostic with
  actionable results.
- **CI / Tooling.** Decisive features: [25 PMD scanner rules](Strategic%20Guide%20-%20Metrics.md#code-quality--scanning) + a 6-rule ESLint plugin + 4 Node scanners; a coverage gate enforcing 100% Apex per-file and 95% LWC statements /
  95% LWC branches; the `kerndx-pipeline` distribution drops 10 GitHub Actions workflow templates into your repo (including `sfca-quality-gate`, which runs `sf code-analyzer run`
  against `force-app/**`, and a secret-scanning gate that blocks committed credentials) plus 2 branch-rule templates + 6 CI-tool adapters, all via `kerndx init`.
- **Web Services — Outbound.** KernDX ships the broadest implementation of this area among the Apex libraries surveyed. On the mock-library piece, KernDX matches
  `apex-fluently-httpmock`, a single-purpose HTTP-mock library. Decisive features: full Outbound coverage, plus a built-in mock library that matches the dedicated specialty tool.

**3. Where another library goes deeper, or ties KernDX on one piece, and why that distinction matters.** "Covers a whole area more broadly" and "matches KernDX on a single piece of
one area" are two different things, and this guide keeps them apart so each competitor gets the credit it's actually due. The table below summarises the three areas where a
specialist goes deeper; the per-piece tie that sits inside an otherwise broadly-covered area is detailed beneath it.

<details>
<summary>Full table: where a specialist goes deeper, and where one ties KernDX (4 rows, with the whole-area vs single-piece distinction)</summary>

| Area | What KernDX ships | Where a specialist goes deeper | Whole-area vs single-piece |
|---|---|---|---|
| **Logging & Diagnostics** | One delivery path via `LogEntryEvent__e`, 4 log levels | `nebula-logger`: several ways to record a log (event bus + queueable + REST + synchronous), seven log levels, a large surface, and a retention purge. Run it alongside KernDX; the two coexist. | Whole area: `nebula-logger` ships a broader implementation than KernDX. |
| **Domain Patterns** | KernDX deliberately ships light on Domain-layer scaffolding | `fflib` (Application factory): `fflib_Application` with its UnitOfWorkFactory / ServiceFactory / SelectorFactory / DomainFactory inner classes. `at4dx`: cross-package field and process injection. Adopt `fflib` (plus `at4dx`) alongside KernDX. | Whole area: `fflib` + `at4dx` ship a broader implementation than KernDX. |
| **Testing — Mockito-style mocking** | `TST_Mock`: DML-free query interception, a structurally different thing; no Mockito-style equivalent | `fflib-mocks`: 98 argument-matcher factories in `fflib_Match`, and verification modes `times/atLeast/atMost/between/never` via `fflib_VerificationMode`. Add it alongside KernDX `TST_Builder`. | Single piece inside Testing (an area KernDX otherwise covers broadly). |
| **Outbound — HTTP-callout mock library** | `API_MockFactory`, plus a broader Outbound surface than the standalone library | `apex-fluently-httpmock`: 4 ways to resolve a mock (exact match + closest-prefix + a sequential queue + a StaticResource body source), and coverage of 7 HTTP verbs. KernDX matches this. | Single piece inside Outbound (an area KernDX otherwise covers broadly). KernDX ties; it does not fall behind. |

</details>

The first two rows are areas where another library ships a broader implementation than KernDX. The last two are single-purpose libraries that tie KernDX on one piece inside an area KernDX otherwise covers broadly: on the Testing piece KernDX has no Mockito-style equivalent, while on the Outbound piece KernDX matches `apex-fluently-httpmock` and ships a broader Outbound surface than the standalone library.

**4. Where the picture is more nuanced: single pieces inside areas KernDX covers broadly.**

- **[TAF](https://github.com/mitchspano/apex-trigger-actions-framework)** (a Trigger Framework specialist) ties KernDX on the metadata-driven bypass-framework piece and on one
  other Trigger piece. There are no pieces where TAF goes further on its own. The decisive KernDX difference: KernDX writes its bypass audit signal to the event bus, where TAF's
  signal is SDLC-only.
- **RFLIB** (a Trigger Framework specialist) goes further on the bypass-via-feature-switch piece, and its log viewer goes further on the archival piece (it reads archived entries
  back from a Big Object and exports CSV, which KernDX's Log Console does not). Recursion control is a tie. KernDX covers the rest of the Trigger surface broadly.
- **`apex-libra`** (multi-area) goes further on the bypass framework, Mockito-style mocking, and functional/lambda-utility pieces. The Trigger Framework area as a whole is
  KernDX-covered, not `apex-libra`-covered. The decisive KernDX differences: KernDX enforces FLS/CRUD on writes by default where `apex-libra` enforces none, and KernDX audit-logs
  bypasses where `apex-libra` emits no audit signal.
- **`apex-fluently-soql`** (a Query Builder specialist) ties KernDX on 4 Query Builder pieces and 1 Domain Patterns piece. There are no pieces where it goes further on its own.
  The decisive KernDX difference: KernDX writes its bypass audit signal to the event bus, where `apex-fluently-soql`'s signal is SDLC-only.

**5. Deliberate design trade-offs (per the principle of solving what almost everyone needs).** Three places where KernDX deliberately chose differently from a top-tier specialist
library:

- **Data masking model.** KernDX masks per-object, opt-in, with a master off-switch and room for your own custom rules (a combined regex/Luhn/literal/JSON-key engine, 3 failure
  actions, caller-scope support). `nebula-logger` instead applies default-on regex matching across log emissions. KernDX ships a broader runtime-masking surface; if you
  specifically need masking applied to every log call before it's written, adopt `nebula-logger` for that.
- **Mocking model.** KernDX ships DML-free query interception via `TST_Mock`, using the same `of/withOverride/build` shape as `TST_Builder`. `fflib-mocks` ships Mockito-style
  behaviour verification. The two are structurally different, intercepting the query layer vs verifying *how* methods were called. If you need both, run them in parallel.
- **Adopting it in your own namespace.** To adopt KernDX you extend `TRG_Base` / `SEL_Base` / `DML_Builder` / `LOG_Builder` / `ComponentBuilder`. Drop-in libraries don't ask you
  to inherit from anything. The guarantees that span layers depend on that shared class hierarchy: default-on FLS/CRUD on read AND write, a shared trigger context, one tracking ID
  that follows a single user action across triggers, queries, callouts, and jobs (a correlation ID), and framework-wide bypass audit logging. Those guarantees are exactly
  what lets KernDX cover Trigger / Query / DML / Security / Async / LWC broadly.

**6. A note on `fflib`'s activity.** At the snapshot date `fflib` has 1 tagged release, 16 commits in the last 12 months, and roughly 2884 days since its last release. It remains the
canonical implementation of the Application factory pattern. If you already run `fflib` and need that pattern, keep it; if you have no Domain-layer requirement, you don't need it.

> **Exit strategy.** KernDX transfers at $0 in licence cost. The source is publicly available under BSL 1.1, so you own access to the framework from day one. Three documented ways out: keep using the managed package (zero effort), deploy it as source from the public repository, or repackage it under your own namespace using the tooling KernDX ships. See [Packaging, Distribution & Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy) for the full analysis.

#### How the frameworks we compared break down

The Apex libraries this guide surveyed fall into three groups: full-stack frameworks (KernDX, `fflib` + `at4dx`, `apex-libra`, `rflib`, and [`sf-bedrock`](https://github.com/force-creators/sf-bedrock)); single-capability libraries (the Apex
Fluently family, 8 libraries, plus `nebula-logger`, `taf`, and [`nebula-triggers`](https://github.com/aidan-harding/nebula-core)); and single-purpose tools (`fflib-mocks`,
[`mask-sobject`](https://github.com/tprouvot/mask-sobject), [`promise`](https://github.com/codefriar/promise), [`apex-chainable`](https://github.com/rsoesemann/apex-chainable),
[`apex-promisify`](https://github.com/oguzalp/apex-promisify), [`apex-async-linkable`](https://github.com/scolladon/apex-async-linkable)). The per-area findings above point to the
specific comparisons. For a capability-by-capability comparison with head-to-head trade-offs and pick-by-capability guidance, see
[Choosing a Framework](Strategic%20Guide%20-%20Choosing%20a%20Framework.md).

#### Recommendations by context

A framework's activity track record informs a pick but never decides it; capability coverage is judged on its own.

##### ISV managed packages

**Recommendation:** Adopt KernDX as-is. Decisive features: inbound REST routing that keeps routing separate from implementation (uncommon among the Apex libraries surveyed); a
coverage gate enforcing 100% Apex per-file + 95% LWC per-file at every release build; and metadata-driven trigger registration via custom metadata, with one action record per event.
KernDX was designed for managed-package development.

##### Enterprise org implementations

**Recommendation:** Adopt KernDX as-is. Decisive features: field-level security enforced on reads AND writes by default; every bypass writes an audit log you can monitor, across
triggers, queries, and DML. If you'd rather use drop-in, single-purpose libraries with a longer public track record, see the per-framework comparisons for `taf`, `apex-fluently-soql`,
and `nebula-logger`.

##### Small teams (< 5 developers)

**Recommendation:** Adopt KernDX incrementally, starting with `TRG_*` + `QRY_Builder` + `TST_Builder`. KernDX covers all three of these broadly. Adopting one module costs about as much
as adopting a drop-in library, and the framework's cross-layer guarantees (a shared context, default-on FLS/CRUD, framework-wide bypass audit) add up as you adopt more modules. If
you'd rather mix single-purpose drop-in libraries, you can combine `taf` + `apex-fluently-soql`; neither ships a broader implementation in the same areas, though `apex-fluently-soql`
has a longer activity track record than KernDX.

##### Integration-heavy projects

**Recommendation:** Adopt KernDX as-is. Decisive features: KernDX ships the broadest Outbound surface of the Apex libraries surveyed, and ties `apex-fluently-httpmock` on the
mock-library piece. KernDX ships a circuit breaker (after an external system keeps failing, the framework stops calling it for a cool-off period, then resumes when it recovers),
retry with backoff, named-credential resolution, idempotency keys (if the exact same request arrives twice, the framework returns the first result again instead of re-running it, and
rejects a repeat that reuses the key with a *different* body, rather than silently masking the change), and an `ApiStep` that bridges an async chain to an outbound call, wired through
`UTIL_AsyncChain`. If you use HTTP paths other than `API_Outbound`, you can add `apex-fluently-httpmock` for the mock surface; if you're already on KernDX, you get the matching mock
via `API_MockFactory`.

##### AppExchange applications

**Recommendation:** Adopt KernDX when building a managed package. Decisive features: an enforced coverage gate, plus a ready-to-use implementation of every core capability, both speed
up the security-review path. If you need the smallest possible dependency footprint for the simplest possible security review, don't adopt any framework at all; KernDX adds framework
surface that introduces a single managed-package dependency.

#### Should you migrate off `fflib`?

Use this rough model to decide.

```text
Migration Cost = (Classes Using fflib × Average Refactor Hours) + (Developer Training Hours × Team Size)
Break-Even Point = Migration Cost ÷ (Quarterly Maintenance Savings + Quarterly Velocity Gain)
```

**Migrate if:** you're actively developing (>10 commits/quarter), your team is changing, and break-even is under 4 quarters.
**Do NOT migrate if:** the codebase is in maintenance mode, break-even is over 6 quarters, or the team is already proficient.
**Freeze-and-contain:** stop expanding `fflib`; adopt modular libraries for new work; refactor opportunistically.

`fflib` activity at the snapshot date: 1 tagged release, 16 commits in the last 12 months, roughly 2884 days since the last release. `fflib` remains the canonical implementation of
the Application factory pattern. See [Migration Checklists](Strategic%20Guide%20-%20Operations.md#migration-checklists) for a worked-example migration cost calculation.

#### Who should read what

| Reader                      | Read                                                                                                                                                                                                                      |
|-----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Executives**              | This overview + [Decision Matrix & Coexistence](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence)                                                                                                         |
| **Architects**              | [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) + [Decision Matrix](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence) + [Risks](Strategic%20Guide%20-%20Risks.md) |
| **Developers**              | This overview's Key findings + [Adoption Roadmap](Strategic%20Guide%20-%20Adoption.md#adoption-roadmap)                                                                                                                   |
| **Product Managers**        | This overview + [Enterprise Delivery](Strategic%20Guide%20-%20Adoption.md#enterprise-delivery) + [Risks & Trade-offs](Strategic%20Guide%20-%20Risks.md#risks-mitigations--trade-offs)                                     |
| **ISV/Package Developers**  | This overview + [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) + [Exit Strategy](Strategic%20Guide%20-%20Operations.md#exit-strategy-0-license-cost)                             |
| **Reviewers / Maintainers** | The Key findings above link inline to the libraries being compared; open an issue if a claim conflicts with current upstream state                                                                                        |

---

[Architecture & Philosophy >](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md)
