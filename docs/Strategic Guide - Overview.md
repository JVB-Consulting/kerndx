---
navOrder: 10
---

# KernDX — Strategic Overview

> A self-assessment of the KernDX Salesforce framework, its design philosophy, and how it compares to alternatives in the Salesforce framework ecosystem — authored by the KernDX
> team. Where another framework covers an area more thoroughly than KernDX, this guide names the comparator and explains the trade-off.

> KernDX is one architectural approach in a maturing Salesforce framework ecosystem. It is a managed-package alternative built for enterprise delivery, managed-package development,
> and integration-heavy environments. It is not intended to replace open-source frameworks universally. This guide compares KernDX against the alternative Salesforce frameworks the
> team has surveyed, acknowledging that different team constraints lead to different optimal choices.

---

> **Document Structure:** This guide is split into focused documents for easier navigation. You can read the overview below, then dive into the section that matters most to you —
> or read them sequentially for the full picture.

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
| **[Metrics](Strategic%20Guide%20-%20Metrics.md)**                                           | Framework-internal metrics — class counts, test coverage, metadata totals                                                                                                                  |

---

## Core Tenets

Three load-bearing standards distinguish KernDX from drop-in libraries. Each is the framework's default-on position; subscribers can opt out per-call, but every opt-out emits an
audit signal.

**1. Automated Test Coverage Standard.** Every Apex class must hit 100% per-file coverage; every LWC bundle must hit 95% statements and 95% branches — and the gate runs at every
release build via `scripts/evaluate-coverage.js`. *Implication for subscriber teams:* coverage gaps cannot land in production through neglect or rushed merges. Detailed treatment
in [Risks](Strategic%20Guide%20-%20Risks.md).

**2. Default-on Data Access Governance.** Every query through `QRY_Builder` and every write through `DML_Builder` runs in `USER_MODE` by default — FLS and CRUD enforced for read
AND write, not just read. *Implication for subscriber teams:* a profile-level field hide is honored by the framework without per-class developer effort. Design rationale
in [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md).

**3. Audit-Trailed Governance Bypasses.** When a query, DML write, validation, or trigger surface bypasses a default-on governance check, the framework emits a bypass-audit event
through `TRG_Base` + `UTIL_BypassAudit`. *Implication for subscriber teams:* a security-review board can answer "where, when, and why did we bypass governance?" from a query of the
audit log instead of a code-search expedition. Audit-posture treatment in [Risks](Strategic%20Guide%20-%20Risks.md).

---

## One-Page Executive Tear Sheet

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                              KernDX                                         │
│                            Strategic Overview                               │
└─────────────────────────────────────────────────────────────────────────────┘

WHAT IS KERNDX
─────────────────────────────────────────────────────────────────────────────
An enterprise Salesforce managed-package framework. Namespace: configurable.
API: 67.0. v1.0 packaged (first validated build; testing-hardened against
100% per-file Apex coverage, 95% LWC, and an extensive subscriber e2e harness).
Zero licensing fees. Source publicly available under BSL 1.1 (relicenses to
Apache 2.0 after a four-year change date).

  • First validated build packaged; subsequent releases tracked in
    the Metrics doc (linked below)
  • Single contributor at the snapshot date
  • 100% per-file Apex coverage + 95% LWC statements + 95% LWC branches,
    enforced by scripts/evaluate-coverage.js at every release build
  • For current class counts, LWC bundle counts, commits and package
    versions, see the Metrics doc (linked below)

CAPABILITY AREAS KERNDX COVERS BROADLY
─────────────────────────────────────────────────────────────────────────────
  Production-ready, end-to-end implementations across all of these areas:
    Trigger Framework         Query Builder          DML
    Web Services — Inbound    Web Services — Outbound
    Resilience                Security               Data Masking
    LWC                       Async Patterns         Utilities
    Health & Self-Diag.       CI / Tooling

WHERE TO MIX KERNDX WITH OTHER LIBRARIES
─────────────────────────────────────────────────────────────────────────────
  Logging & Diagnostics  → KernDX ships a `LOG_Engine` for capture +
                           audit; pair with nebula-logger when you need
                           a broader logging-surface (custom dashboards,
                           per-class log levels, Pharos integration).
  Testing (mock library) → KernDX ships a `MOCK_*` family for stubbing
                           HTTP, Selectors, and DML; pair with fflib-mocks
                           when you specifically need Mockito-style
                           behaviour-verification mocking.
  Domain Patterns        → KernDX ships light on the Domain layer; pair
                           with fflib + at4dx if you need the Service /
                           Application factory pattern.

ONE-SENTENCE GUIDANCE
─────────────────────────────────────────────────────────────────────────────
"Adopt KernDX when you need broad coverage across Trigger, Query, DML,
Inbound REST, Resilience, Security, Data Masking, LWC, Async, Utilities,
Health, Outbound, and CI tooling in a single managed package; mix in
nebula-logger for logging-surface depth, fflib-mocks for behaviour-
verification mocking, or fflib + at4dx for the Service / Application
factory pattern."
```

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

### Executive Summary

> **The KernDX design thesis.** KernDX is built on five principles (see the [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) doc for the full
> design narrative):
>
> 1. **Every feature ships for immediate value** — not theoretical/cool-because-it-exists.
> 2. **Easy to understand** — the framework uses a consistent fluent-builder pattern across every major surface. `TST_Builder`, `QRY_Builder`, `DML_Builder`, `LOG_Builder`, `UTIL_HttpClient`, and the rest follow the same chainable-build → terminal-execute shape. Learning one means learning the others.
> 3. **Solves what 95%+ of subscribers will use** — not the long tail of niche capabilities.
> 4. **Integration is a feature, not an accident** — calls flow through the same context type so `TRG_Base`, `SEL_Base`, `DML_Builder`, and `LOG_Builder` cooperate without subscriber-side glue code.
> 5. **Shortcuts the enterprise tech-debt accumulation cycle** — the framework an enterprise would build given the budget to do so without iteration.

> **Headline finding:** KernDX covers most of the framework areas a Salesforce org needs broadly. On Trigger Framework, Query Builder, DML, Web Services — Inbound, Resilience,
> Security, Data Masking, LWC, Async Patterns, Utilities, Health & Self-Diagnostics, and CI / Tooling, KernDX ships a production-ready implementation end-to-end. On Web Services —
> Outbound, KernDX ships the broadest implementation among the comparable Apex libraries surveyed. KernDX does **not** cover three framework areas broadly: Logging & Diagnostics ([`nebula-logger`](https://github.com/jongpie/NebulaLogger) ships a broader logging surface; mix it alongside KernDX for logging depth), Testing (KernDX ships broad stubbing, but [`fflib-mocks`](https://github.com/apex-enterprise-patterns/fflib-apex-mocks) covers Mockito-style behaviour verification where KernDX has no equivalent), and Domain Patterns ([`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) ships the Application factory and [`at4dx`](https://github.com/apex-enterprise-patterns/at4dx) adds
> cross-package injection; KernDX ships light on the Domain layer). On the outbound mock-library aspect specifically, KernDX scores at the same level as [`apex-fluently-httpmock`](https://github.com/beyond-the-cloud-dev/http-mock-lib) — a single-capability HTTP-mock library.
>
> KernDX additionally ships production-ready implementations of the core capabilities a Salesforce org needs — every core capability is shipped, documented, and usable from day
> one (not stubbed or aspirational).

> **Substance and adoption are reported separately.** This guide separates what each framework does (capability scoring) from how active each framework is (commits, contributors,
> tagged releases, days since last release, third-party citations). Adoption activity is reported in its own track and never determines which framework covers more capability
> aspects. KernDX's current contributor count, commit count, tag count, and package-version count are reported in the [Metrics](Strategic%20Guide%20-%20Metrics.md) doc — that is the
> authoritative source. Comparators with longer accumulated history ([`rflib`](https://github.com/j-fischer/rflib), [`apex-fluently-soql`](https://github.com/beyond-the-cloud-dev/soql-lib), [`apex-fluently-dml`](https://github.com/beyond-the-cloud-dev/dml-lib)) have longer activity duration but
> cover fewer capability aspects than KernDX. Adopting KernDX is a different decision than adopting `rflib` or `fflib`; subscribers weighing adoption risk should weigh capability
> coverage and activity history independently — they are orthogonal by design.

> **KernDX is an accelerator you can own, not a product you rent.** Zero licensing fees, source publicly available under BSL 1.1 (relicenses to Apache 2.0 after a four-year change
> date), three documented exit paths: continue managed package, deploy as source from the public repository, or repackage under client namespace using the shipped tooling. KernDX is
> one of the few Apex frameworks that documents the complete repackaging-under-client-namespace workflow as a first-class exit path;
> see [Packaging, Distribution & Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy) for the full exit analysis.

> **How to Read This Document**
>
> If a comparative claim looks wrong or out of date relative to the linked library's current state, please open an issue in this repository.

#### What is KernDX?

KernDX is a Salesforce managed-package framework providing integrated trigger handling, data access, DML operations, web-service integration, asynchronous processing, validation,
logging, runtime field redaction (data masking), and utilities. It is designed for adoption on any brownfield or greenfield org — either in full or component by component.

**Key facts:**

|                           |                                                                                                                                                                                                                                                                                                            |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Package Type**          | Managed Package (2GP)                                                                                                                                                                                                                                                                                      |
| **API Version**           | 67.0 (`sourceApiVersion` per `sfdx-project.json`)                                                                                                                                                                                                                                                          |
| **License**               | Business Source License 1.1 — source-available, four-year clock to Apache 2.0                                                                                                                                                                                                                              |
| **Status**                | v1.0 packaged — first validated build shipped, testing-hardened (100% per-file Apex coverage gate + 95% LWC + subscriber e2e harness); publicly released under BSL 1.1 and promoted for production install, with one known external client engagement at the snapshot date and public adoption still early |
| **Coverage gate**         | 100% Apex per-file + 95% LWC statements + 95% LWC branches enforced by `scripts/evaluate-coverage.js` at every release build                                                                                                                                                                               |
| **Latest packaged build** | See [Metrics — Activity Snapshot](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) for the current build identifier                                                                                                                                                                                   |

For current Apex class counts, LWC bundle counts, commit and package-version counts, and the full framework-internal metric set (Apex method counts, Flow invocables, selectors,
surface method counts, documentation page counts), see the [Metrics](Strategic%20Guide%20-%20Metrics.md) doc — that is the authoritative source. Other guides cross-link here rather
than carrying their own snapshot counts.

KernDX source is publicly available under BSL 1.1 on the project repository (relicenses to Apache 2.0 after a four-year change date). Subscribers can continue using the managed
package, deploy as source from the public repository, or repackage under their own namespace using the shipped repackaging tooling and `Unmanaged.zip` artifact — three documented
exit paths, not just source-on-GitHub. Consulting engagements include direct source delivery and handover support.

#### Key Findings

The findings below summarize how KernDX compares against the alternative Salesforce frameworks surveyed by this guide. Where another library covers an area more thoroughly, the
library is named with its decisive feature.

1. **KernDX ships production-ready implementations of every core Salesforce capability.** Every core capability a Salesforce org needs is shipped, documented, and usable from day
   one (not stubbed or aspirational). This is broader than other Apex frameworks the team has surveyed; `rflib` and [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library) come closest. Three core capabilities are uncommon among the libraries surveyed: inbound REST routing with
   separation of routing from implementation via a `REST_*` / `API_*` two-class pattern, the LWC component framework with 5 modules and registry-dispatch activation, and LWC ↔ Apex
   DTO marshalling.

2. **KernDX covers most framework areas broadly.** On the areas listed below, KernDX ships a production-ready implementation end-to-end:
    - **Trigger Framework** — Decisive features: every bypass writes an audit log you can monitor; bypass works at four levels (per-object, per-action, per-flow, framework-wide).
    - **Query Builder** — Decisive features: extensive query API; no SOQL string concatenation needed; FLS/CRUD enforced by default, bypass per-query and audited.
    - **DML** — Decisive features: transactional batching across multiple operations; all five DML operations; FLS/CRUD enforced on writes by default, bypass per-write and audited.
    - **Web Services — Inbound** — KernDX is one of the few Apex frameworks surveyed that ships inbound REST routing. Decisive features: REST routing kept separate from business
      logic; central dispatcher; uniform error responses.
    - **Resilience** — Decisive features: feature flags via custom metadata or per-user/profile settings; read flags from Apex, Flow, and LWC; extensible strategy pattern.
    - **Security** — Decisive features: FLS-enforced reads on by default; kill-switch and per-method opt-out; audit-logged bypasses.
    - **Data Masking** — Decisive features: masks via regex, Luhn (payment-card detection), literal-string, and JSON-key matching; four masking modes; three failure actions; 18
      built-in masking rules; and a Data Masking Advisor console that scans field coverage and exports a regulated-field inventory.
    - **LWC** — Decisive features: five built-in LWC component modules with opt-in activation; clear error messages when modules aren't enabled; rejects invalid modules at
      registration.
    - **Async Patterns** — Decisive features: finalizer hooks; state passes between async transactions; emergency kill switch.
    - **Utilities** — Decisive features: 39 utility helpers; null-safe by default; masking helpers compose with the Data Masking engine.
    - **Health & Self-Diagnostics** — KernDX is one of the few Apex frameworks surveyed that ships a health-check capability. Decisive features: seven-dimension self-diagnostic with
      actionable results.
    - **CI / Tooling** — Decisive features: 25 PMD scanner rules + a 6-rule ESLint plugin + 4 Node scanners; coverage gate enforcing 100% Apex per-file and 95%
      LWC statements / 95% LWC branches; the `kerndx-pipeline` distribution renders 10 GitHub Actions workflow templates (including `sfca-quality-gate` running
      `sf code-analyzer run` against `force-app/**`, and a secret-scanning gate that blocks committed credentials) plus 2 branch-rule templates + 6 CI-tool adapters into the subscriber's repo via `kerndx init`.
    - **Web Services — Outbound** — KernDX ships the broadest implementation in this area of the Apex libraries surveyed. On the mock-library piece, KernDX scores at the same level
      as `apex-fluently-httpmock` — a single-capability HTTP-mock library. Decisive features: full Outbound coverage; built-in mock library at the same level as the dedicated
      specialty tool.

3. **Where another library covers an area more thoroughly, or matches KernDX on one piece.** Two readings — broader area coverage versus a per-piece match — are different things.

   **Where another library ships a broader implementation than KernDX:**
    - **Logging & Diagnostics** → `nebula-logger`. Decisive features: multiple log transports (event-bus + queueable + REST + synchronous), seven log levels, large surface,
      retention purge. KernDX is at: single-transport via `LogEntryEvent__e`, 4 log levels. Subscribers needing logging-surface depth mix `nebula-logger` alongside KernDX — the two
      frameworks coexist.
    - **Domain Patterns** → `fflib` (Application factory) + `at4dx` (cross-package injection). Decisive features: `fflib_Application` with UnitOfWorkFactory / ServiceFactory /
      SelectorFactory / DomainFactory inner classes; cross-package field and process injection. KernDX deliberately ships light on Domain layer scaffolding — subscribers needing
      the Service / Application factory pattern adopt `fflib` (plus `at4dx` for the DI overlay) alongside KernDX.

   **Per-piece matches from single-capability libraries inside KernDX-covered areas:**
    - **Testing — Mockito-style mocking** → `fflib-mocks`. Decisive features: 98 argument-matcher factories in `fflib_Match`, verification modes
      `times/atLeast/atMost/between/never` via `fflib_VerificationMode`. KernDX has no Mockito-style equivalent; KernDX `TST_Mock` is DML-free query interception — a structurally
      different surface. Subscribers needing behaviour-verification mocking adopt `fflib-mocks` alongside KernDX `TST_Builder`.
    - **Outbound — HTTP-callout mock library** → `apex-fluently-httpmock`. Decisive features: 4 mock-resolution strategies (exact + closest-prefix + sequential queue +
      StaticResource body source), 7 HTTP-verb coverage. KernDX scores at the same level via `API_MockFactory` and ships a broader Outbound surface than the standalone library.

4. **Where the picture is more nuanced (per-piece specifics inside areas KernDX covers broadly).**
    - **[TAF](https://github.com/mitchspano/apex-trigger-actions-framework)** (Trigger Framework specialty) — matches KernDX on the metadata-driven bypass framework piece and on
      one other Trigger piece. No pieces where TAF covers outright. The decisive KernDX point of difference is an event-bus bypass audit signal vs an SDLC-only signal in TAF.
    - **RFLIB** (Trigger Framework specialty) — covers the bypass-via-feature-switch piece outright, plus a historical log-browser UI piece where KernDX is absent. Recursion
      control is a match. KernDX covers the rest of the Trigger surface broadly.
    - **`apex-libra`** (multi-area) — covers the bypass framework, Mockito-style mocking, and functional/lambda utilities pieces outright. The Trigger Framework area is
      KernDX-covered overall, not `apex-libra`-covered. The decisive KernDX points of difference are FLS/CRUD enforced on writes by default versus no FLS/CRUD enforcement in
      `apex-libra`, and audit-logged bypasses versus no audit signal.
    - **`apex-fluently-soql`** (Query Builder specialty) — matches KernDX on 4 Query Builder pieces and 1 Domain Patterns piece. No pieces where `apex-fluently-soql` covers
      outright. The decisive KernDX point of difference is an event-bus bypass audit signal vs an SDLC-only signal in `apex-fluently-soql`.

5. **Deliberate design trade-offs (per the 95% rule).** Three surfaces where KernDX makes a different architectural choice than a top-band library:
    - **Data masking surface model** — KernDX ships per-SObject opt-in masking with a framework kill switch and custom-rule extensibility (mixed regex/Luhn/literal/JSON-key engine,
      3 failure actions, caller-scope support). `nebula-logger` applies default-on regex matching across log emissions. KernDX ships a broader runtime-masking surface; subscribers
      needing pre-emit log masking on every log call adopt `nebula-logger` for that surface.
    - **Mocking surface model** — KernDX ships DML-free query interception via `TST_Mock` using the same `of/withOverride/build` shape as `TST_Builder`. `fflib-mocks` ships
      Mockito-style behaviour verification. The two surfaces are structurally different — selector-layer mocking vs verb-style behaviour verification. Subscribers needing both
      adopt them in parallel.
    - **Subscriber-namespace adoption** — KernDX subscribers adopt by extending `TRG_Base` / `SEL_Base` / `DML_Builder` / `LOG_Builder` / `ComponentBuilder`. Drop-in libraries
      impose no class-hierarchy adoption. Framework guarantees that span layers (default-on FLS/CRUD on read AND write, shared trigger context, correlation IDs, framework-wide
      bypass audit logging) require the class hierarchy — these guarantees are why KernDX ships broad coverage across Trigger / Query / DML / Security / Async / LWC.

6. **`fflib` adoption-trajectory note.** `fflib` has 1 tagged release, 16 commits in the last 12 months, and roughly 2884 days since the last release. `fflib` remains the canonical
   implementation of the Application factory pattern. Organisations with existing `fflib` implementations needing the Application factory pattern should keep `fflib`; organisations
   with no Domain layer requirement do not need it.

> **Exit strategy:** KernDX operates on a $0 license transfer model — source is publicly available under BSL 1.1, so subscribers own access to the framework from day one. Three
> documented exit paths: continue managed package (zero effort), deploy as source from the public repository, or repackage under client namespace using the shipped tooling.
> See [Packaging, Distribution & Exit Strategy](Strategic%20Guide%20-%20Operations.md#packaging-distribution--exit-strategy) for the full exit analysis.

#### Framework Comparison

The Apex libraries surveyed by this guide span full-stack frameworks (KernDX, `fflib` + `at4dx`, `apex-libra`, `rflib`), single-capability libraries (Apex Fluently family — 8
libraries, `nebula-logger`, `taf`, [`nebula-triggers`](https://github.com/aidan-harding/nebula-core)), and single-purpose tools (`fflib-mocks`, [`mask-sobject`](https://github.com/tprouvot/mask-sobject), [`promise`](https://github.com/codefriar/promise), [`apex-chainable`](https://github.com/rsoesemann/apex-chainable), [`apex-promisify`](https://github.com/oguzalp/apex-promisify), [`apex-async-linkable`](https://github.com/scolladon/apex-async-linkable)). The per-area findings above point to the
specific comparisons. For a capability-by-capability comparison with head-to-head trade-offs and pick-by-capability guidance,
see [Choosing a Framework](Strategic%20Guide%20-%20Choosing%20a%20Framework.md).

#### Recommendations by Context

Adoption activity is reported separately from capability coverage — it informs but never determines a capability pick.

##### ISV Managed Packages

**Recommendation:** Adopt KernDX as-is. Decisive features: inbound REST routing with routing/implementation separation, uncommon among the Apex libraries surveyed; a coverage gate
enforcing 100% Apex per-file + 95% LWC per-file at every release build; metadata-driven trigger registration via custom metadata, with per-event action records. KernDX was designed
for managed-package development.

##### Enterprise Org Implementations

**Recommendation:** Adopt KernDX as-is. Decisive features: FLS-enforced reads AND writes on by default; every bypass writes an audit log you can monitor — across triggers, queries,
and DML. Subscribers wanting drop-in single-purpose libraries with longer accumulated public history should consult the per-framework comparisons for `taf`, `apex-fluently-soql`,
and `nebula-logger`.

##### Small Teams (< 5 Developers)

**Recommendation:** Adopt KernDX incrementally (start with `TRG_*` + `QRY_Builder` + `TST_Builder`). KernDX ships broad coverage across all three of these capabilities. Per-module
adoption effort is comparable to drop-in libraries; framework guarantees (shared context type, default-on FLS/CRUD, framework-wide bypass audit) accumulate as more modules are
adopted. Subscribers wanting single-purpose drop-in libraries can mix `taf` + `apex-fluently-soql` — neither ships a broader implementation in the same areas, though
`apex-fluently-soql` has a longer accumulated activity history than KernDX.

##### Integration-Heavy Projects

**Recommendation:** Adopt KernDX as-is. Decisive features: KernDX ships the broadest Outbound surface of the Apex libraries surveyed, and scores at the same level as
`apex-fluently-httpmock` on the mock-library piece. KernDX ships circuit breaker, retry with backoff, named-credential resolution, idempotency keys, and an `ApiStep`
async-chain-to-outbound bridge wired through `UTIL_AsyncChain`. Subscribers using non-`API_Outbound` HTTP paths can mix `apex-fluently-httpmock` for the mock surface; subscribers
already on KernDX get the same-level mock via `API_MockFactory`.

##### AppExchange Applications

**Recommendation:** Adopt KernDX when building a managed package. Decisive features: an enforced coverage gate, plus a production-ready implementation of every core capability,
accelerate the security-review path. Subscribers needing zero-dependency footprint for the simplest possible security review should not adopt any framework; KernDX adds framework
surface that admits a single managed-package dependency.

#### Migration Guidance

**Should you migrate off `fflib`?**

```text
Migration Cost = (Classes Using fflib × Average Refactor Hours) + (Developer Training Hours × Team Size)
Break-Even Point = Migration Cost ÷ (Quarterly Maintenance Savings + Quarterly Velocity Gain)
```

**Migrate if:** Active development (>10 commits/quarter), team composition changing, break-even <4 quarters.
**Do NOT migrate if:** Codebase in maintenance mode, break-even >6 quarters, team already proficient.
**Freeze-and-contain:** Stop expanding `fflib`; adopt modular libraries for new work; refactor opportunistically.

`fflib` activity at the snapshot date: 1 tagged release, 16 commits in the last 12 months, roughly 2884 days since the last release. `fflib` remains the canonical implementation of
the Application factory pattern. See [Migration Checklists](Strategic%20Guide%20-%20Operations.md#migration-checklists) for a worked-example migration cost calculation.

#### Document Navigation

| Reader                      | Read                                                                                                                                                                                                                      |
|-----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Executives**              | This overview + [Decision Matrix & Coexistence](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence)                                                                                                         |
| **Architects**              | [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) + [Decision Matrix](Strategic%20Guide%20-%20Adoption.md#decision-matrix--coexistence) + [Risks](Strategic%20Guide%20-%20Risks.md) |
| **Developers**              | This overview's Key Findings + [Adoption Roadmap](Strategic%20Guide%20-%20Adoption.md#adoption-roadmap)                                                                                                                   |
| **Product Managers**        | This overview + [Enterprise Delivery](Strategic%20Guide%20-%20Adoption.md#enterprise-delivery) + [Risks & Trade-offs](Strategic%20Guide%20-%20Risks.md#risks-mitigations--trade-offs)                                     |
| **ISV/Package Developers**  | This overview + [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) + [Exit Strategy](Strategic%20Guide%20-%20Operations.md#exit-strategy-0-license-cost)                             |
| **Reviewers / Maintainers** | The Key Findings above link inline to the libraries being compared; open an issue if a claim conflicts with current upstream state                                                                                        |

---

[Architecture & Philosophy >](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md)
