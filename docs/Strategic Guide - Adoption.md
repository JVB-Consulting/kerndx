---
navOrder: 14
---

# Strategic Guide — Adoption

> **What this is:** A decision guide for the question "should we adopt KernDX, and if so, how do we roll it out?" It compares KernDX (one integrated managed package) against assembling separate open-source libraries, sets out where each approach fits, and gives you a step-by-step plan for introducing a framework into an existing org.
>
> **Why it exists:** Choosing a framework is a multi-year commitment with real costs on both sides. This guide lays out the trade-offs honestly so you can decide on evidence, not marketing.
>
> **Who should read it and when:** Engineering managers, platform leads, and architects making the build-vs-buy call, plus the delivery managers and executives who need to understand the cost and risk picture. Read it while you are evaluating frameworks or planning a rollout.

Part of the [KernDX Strategic Guide](Strategic%20Guide%20-%20Overview.md).
See
also: [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) | [Operations](Strategic%20Guide%20-%20Operations.md) | [Risks](Strategic%20Guide%20-%20Risks.md) | [Glossary](Strategic%20Guide%20-%20Glossary.md) | [Personas](Strategic%20Guide%20-%20Personas.md)

> **Primary reader:** Engineering manager or platform lead deciding *whether* to adopt KernDX and *how* to roll it out across teams. Skim, then drill into the section you need. Two related questions live in companion guides: the risks of adopting are covered in [Risks](Strategic%20Guide%20-%20Risks.md), and the steady-state cost of running it is covered in [Operations](Strategic%20Guide%20-%20Operations.md).

---

<details><summary>Table of Contents</summary>

- [Enterprise Delivery](#enterprise-delivery)
    - [The Multi-SI Challenge](#the-multi-si-challenge)
    - [Onboarding Time Comparison](#onboarding-time-comparison)
    - [Core Pattern Comparison](#core-pattern-comparison)
    - [Enterprise Utilities Beyond Core Patterns](#enterprise-utilities-beyond-core-patterns)
    - [Framework Selection by Org Archetype](#framework-selection-by-org-archetype)
    - [Build vs Buy: Hidden Costs](#build-vs-buy-hidden-costs)
    - [Build vs Buy: Cost Considerations](#build-vs-buy-cost-considerations)
    - [Coherence Costs of Modular Stacks](#coherence-costs-of-modular-stacks)
    - [Code Drift in Multi-Team Environments](#code-drift-in-multi-team-environments)
- [AI & Modern Platform](#ai--modern-platform)
    - [AI Development Landscape](#ai-development-landscape)
    - [AI Context Files](#ai-context-files)
    - [Agentforce Implications](#agentforce-implications)
    - [Practical AI Development Patterns](#practical-ai-development-patterns)
    - [Modern Platform Features](#modern-platform-features)
- [Decision Matrix & Coexistence](#decision-matrix--coexistence)
    - [Quick Decision Guide](#quick-decision-guide)
    - [Decision Criteria](#decision-criteria)
    - [Capability Comparison](#capability-comparison)
    - [Coexistence Playbook](#coexistence-playbook)
- [Adoption Roadmap](#adoption-roadmap)
    - [Adoption Patterns](#adoption-patterns)
    - [Standalone Adoption — Logging as a No-Migration Wedge](#standalone-adoption--logging-as-a-no-migration-wedge)
    - [Starting from Existing Org (Brownfield)](#starting-from-existing-org-brownfield)
    - [Migration Narratives](#migration-narratives)
    - [Organisational Readiness](#organisational-readiness)
    - [Adoption Governance Model](#adoption-governance-model)
    - [Operational Ownership Model](#operational-ownership-model)
    - [Success Metrics](#success-metrics)
- [Conclusion](#conclusion)
    - [Which approach to choose](#which-approach-to-choose)
    - [What Comes Next](#what-comes-next)
    - [Decision Framework](#decision-framework)
    - [Decision Summary Matrix](#decision-summary-matrix)

</details>

## Enterprise Delivery

### The Multi-SI Challenge

If your org uses more than one delivery partner, framework choice quickly becomes a consistency problem. Large enterprises usually engage several System Integrators (SIs), the outside consultancies that build and deliver Salesforce work, across different regions, business units, or project types. Each SI brings its own preferred frameworks, coding standards, trained staff, in-house accelerators, and partner relationships. So what? Left unmanaged, every new partner can pull your codebase in a different direction.

This sets up a recurring tension between keeping things consistent and using each SI's existing expertise:

1. You pick Framework A for the first project, it succeeds, and it becomes the "standard".
2. A second SI proposes Framework B (the one they know). Now you face a choice: make the SI learn Framework A (which adds timeline risk) or accept Framework B (which fragments the codebase).
3. The same choice repeats with every new SI.

**The reality on the ground:**

- **Fortune 500 enterprises** often run 3-5 different frameworks across business units.
- **Global 2000 enterprises** may have 10+ framework variations across regions.
- **From the SI's side**, training 50-100 developers on an unfamiliar framework is a 6-12 month investment.
- **From your side**, running multiple frameworks means higher support costs, slower collaboration between teams, and harder hiring.

**Multi-SI Environment Risk Analysis:**

| Risk Dimension               | KernDX                                                                                                                                                                                                                                                                              | Modular OSS Stack                                                                                                                                                                                                                                      |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Hand-off complexity**      | Higher if the incoming SI is new to KernDX: they must learn the framework's conventions, how its configuration records are laid out and relate, and the managed-package constraints                                                                                                                                 | Comparable. Incoming SIs that already use one of `taf` / `apex-fluently-soql` / `nebula-logger` get a head start on that library; SIs new to those libraries face an equivalent ramp                                                                     |
| **Convention fragmentation** | Lower if governance exists: the managed package enforces a single convention set                                                                                                                                                                                                       | Higher: each SI may adopt different libraries, or use them inconsistently, unless the central architecture team enforces a standard                                                                                                                   |
| **Contractual boundaries**   | More complex: the framework dependency should be addressed in SI contracts, and source ownership and maintenance responsibility need explicit terms. This is mitigated by public source availability under BSL 1.1: the framework source is published on the public KernDX repository, so any team can clone and self-maintain it without a handover | Simpler: open-source libraries carry no contractual implications                                                                                                                                                                                      |
| **Knowledge silo risk**      | Higher: KernDX expertise is concentrated in the original SI, so handover requires deliberate knowledge transfer                                                                                                                                                                          | Comparable in practice. Modular libraries have public READMEs and (in some cases) hosted docs, but most are single-maintainer projects without large issue-tracker communities, so the "Stack Overflow will save us" framing is weaker than it sounds |
| **Overall multi-SI risk**    | **Higher risk** without strong central governance to enforce consistent usage across SIs; **manageable** with central authority                                                                                                                                                     | **Comparable risk** to KernDX. Multi-SI fragmentation is governance-driven, not framework-driven. Modular stacks fragment differently (library divergence) than integrated stacks (partial adoption), but both fragment without governance             |

*Recommendation: In multi-SI environments, the deciding variable is the strength of your governance, not which framework you pick. Either approach fragments without a central architectural authority enforcing consistency across all delivery partners; either works with one.
See [Code Drift in Multi-Team Environments](#code-drift-in-multi-team-environments) for how that gradual drift toward inconsistent code sets in.*

### Onboarding Time Comparison

How long does it take a developer to become productive? The fair way to compare is **per-module learning time**, because no developer learns an entire framework in one sitting, whichever approach you choose.

**Per-module onboarding time (mid-level developer):**

Each KernDX module has a dedicated **Fast Start guide** that walks through three stages: see it work, build your own, then apply production patterns. The times below are for completing the Fast Start, which is enough to build a working implementation and understand the patterns. When developers need to go deeper, full-depth **Developer Guides** cover each module.

| Module                  | KernDX (Fast Start time)                    | `taf`               | `apex-fluently-soql` | `nebula-logger`                       |
|-------------------------|---------------------------------------------|---------------------|----------------------|---------------------------------------|
| Selectors               | `SEL_Base`: ~30 min                         | N/A                 | ~2-5 hours*          | N/A                                   |
| Triggers                | `TRG_*`: ~20 min                            | ~2-4 hours          | N/A                  | N/A                                   |
| DML                     | `DML_Builder`: ~30 min                      | N/A                 | N/A                  | N/A                                   |
| Logging                 | `LOG_Builder`: ~30 min                      | N/A                 | N/A                  | ~1-2 hours (basic), ~3-4 hours (full) |
| Test data               | `TST_Builder`: ~30 min                      | N/A                 | N/A                  | N/A                                   |
| Feature flags           | `UTIL_FeatureFlag`: ~25 min                 | N/A                 | N/A                  | N/A                                   |
| Validations             | `ValidationRule__mdt`: ~25 min              | N/A                 | N/A                  | N/A                                   |
| Outbound APIs           | `API_Outbound`: ~30 min                     | N/A                 | N/A                  | N/A                                   |
| Inbound APIs            | `API_Inbound`: ~30 min                      | N/A                 | N/A                  | N/A                                   |
| Async processing        | `UTIL_AsyncChain`: ~30 min                  | N/A                 | N/A                  | N/A                                   |
| Code scanning           | PMD + ESLint: ~20 min                       | N/A                 | N/A                  | N/A                                   |
| E2E testing             | Playwright: ~25 min                         | N/A                 | N/A                  | N/A                                   |
| **Full stack (all 12)** | **~5.5 hours of Fast Starts to productive** | N/A (triggers only) | N/A (queries only)   | N/A (logging only)                    |

**Competitor onboarding times** are based on each library's documentation as observed across the libraries we compared against:

- **[`taf`](https://github.com/mitchspano/apex-trigger-actions-framework):** The README is 30 lines linking to the maintainer's docs site, which has about 4,400 words across 9 focused
  pages. Strong ApexDoc (the API documentation shown in the IDE) on all core classes. A developer reads the getting-started page and creates a trigger plus a custom metadata record, an action class, and a test in about 2-4 hours. There is no structured learning path; the docs are reference-style, not guided.
- **[`apex-fluently-soql`](https://github.com/beyond-the-cloud-dev/soql-lib):** The README links to the maintainer's hosted docs site, which has 49 pages: broad in coverage and
  well-structured. The library intentionally suppresses all ApexDoc (per the project README), so developers must leave their IDE to learn the API. The first query is trivial (about 10
  minutes), but the missing in-IDE documentation means constant switching between IDE and browser while learning. Developers who read the docs first take about 2-3 hours; developers
  who learn by doing (the majority) take about 4-5 hours because of the IDE-to-browser round trips on every new method. Without ApexDoc, autocomplete shows many overloads with no descriptions.
  One security note: `apex-fluently-soql` defaults to `USER_MODE` (it runs queries with the current user's read permissions and record sharing enforced), so field-level security (FLS) and object create/read/update/delete permissions (CRUD) are enforced by construction. KernDX `QRY_Builder` also defaults to `USER_MODE`, so this is the same security default, not a difference.
- **[`nebula-logger`](https://github.com/jongpie/NebulaLogger):** The README ships quick starts for Apex, LWC, Flow, and OmniStudio, with strong ApexDoc on core classes. The first log entry
  takes about 10 minutes (`Logger.info('msg'); Logger.saveLog();`). Full setup with retention, tags, and the log browser takes about 3-4 hours. A wiki migration is in progress, so the docs are currently split between the repo
  and the GitHub Wiki.

**Key insight:** KernDX's onboarding advantage is not faster per-module learning. Competitors cover their individual modules in comparable time. The advantage is structural: 12
timed, tiered Fast Start guides with consistent conventions, full ApexDoc in the IDE, and a single documentation site covering the entire stack. Competitors have no cross-module
learning path, and their documentation quality varies.

**Key Factors:**

- **Documentation depth:** KernDX ships 21 developer guides, 16 Fast Start guides, 269 API reference pages, a detailed Security Guide and a top-level `SECURITY.md`, a release-testing runbook (561
  anonymous-Apex assertions across 74 sections), drift-audit cycle, `AGENTS.md` + `docs/Code Conventions - Guide.md` at repo root
  plus [AI Agent Instructions](AI%20Agent%20Instructions.md) for AI tooling. `taf`: 9 docs pages + ApexDoc. `apex-fluently-soql`: 49 docs pages but zero ApexDoc per repo-level
  exclusion. `nebula-logger`: README + GitHub Wiki (migration in progress) + ApexDoc. Across the comparable Apex frameworks surveyed, most ship no SECURITY.md at all; the 4
  Beyond-The-Cloud libraries ([`apex-fluently-dml`](https://github.com/beyond-the-cloud-dev/dml-lib), `apex-fluently-soql`, [`apex-fluently-consts`](https://github.com/beyond-the-cloud-dev/apex-consts), [`apex-fluently-httpmock`](https://github.com/beyond-the-cloud-dev/http-mock-lib)) ship the same
  Beyond-The-Cloud project-template SECURITY.md verbatim.
- **In-IDE experience:** KernDX and `taf` both have full ApexDoc, so developers learn without leaving their IDE. `apex-fluently-soql` has none, so developers must consult the external docs
  site for every method. This is the biggest single difference in onboarding friction.
- **Structured learning path:** KernDX Fast Starts follow three stages (see it work, build it, extend it), each guide self-contained at about 30 minutes. No comparator offers
  a structured learning path across modules.
- **Convention consistency:** One naming system is faster to learn than 5 or more. New developers absorb the `QRY_*`, `TRG_*`, and `SEL_*` patterns that apply everywhere.
- **AI tooling:** Frameworks with a unified `AGENTS.md` (or similar tool-neutral context file) plus a canonical conventions doc cut ramp time, because they let AI tools generate
  convention-compliant code from day one.
- **Code similarity to native Apex:** Both KernDX and the Apex Fluently libraries use standard Apex patterns (selectors, builders, and DTOs, the small classes that move data in and out as JSON). Neither requires a paradigm shift like
  the [fflib](https://github.com/apex-enterprise-patterns/fflib-apex-common) Domain-Driven Design patterns.

**Reality check:** These are best-case numbers, assuming good documentation, senior-developer mentorship, and dedicated learning time. Real-world onboarding often takes 50-100%
longer because of production pressure, incomplete documentation, and learning by debugging existing code.

### Core Pattern Comparison

| Pattern             | `fflib`                   | `at4dx`          | KernDX                                              | `taf`                 | `apex-fluently-soql`      |
|---------------------|---------------------------|------------------|-----------------------------------------------------|-----------------------|---------------------------|
| **Triggers**        | Custom base               | Custom base      | Metadata-driven (`TRG_Base` + `TriggerAction__mdt`) | Metadata-driven       | N/A                       |
| **Queries**         | `fflib_QueryFactory`      | `Query` builder  | `QRY_Builder` + `SEL_*` selectors                   | N/A                   | `SOQL` builder            |
| **DML**             | `fflib_SObjectUnitOfWork` | Unit of Work     | `DML_Builder`                                       | N/A                   | N/A                       |
| **Service Layer**   | `fflib_SObjectDomain`     | Domain classes   | Service-specific (`API_*`, `SVC_*`, `FLOW_*`)       | N/A                   | N/A                       |
| **Selector**        | Abstract factory          | Inheritance      | Inheritance (`SEL_Base`)                            | N/A                   | Direct `SOQL` calls       |
| **Mocking**         | `fflib_ApexMocks`         | ApexMocks        | `TST_Mock` + `QRY_Builder.setMock()`                | Standard Apex mocking | Standard Apex mocking     |
| **Test Data**       | Custom factories          | Custom factories | `TST_Builder` + `TST_Factory`                       | N/A                   | Standard test setup       |
| **Logging**         | Custom                    | Custom           | `LOG_Builder` (Platform Events)                     | N/A                   | Integrate `nebula-logger` |
| **Feature Flags**   | Custom                    | Custom           | `UTIL_FeatureFlag`                                  | N/A                   | Custom or 3rd party       |
| **Caching**         | Custom                    | Custom           | `UTIL_Cache` (Platform Cache)                       | N/A                   | Custom                    |
| **API Integration** | Custom                    | Custom           | `API_Outbound` + `API_Inbound`                      | N/A                   | Custom                    |
| **LWC**             | N/A                       | Limited          | `ComponentBuilder` + modules                        | N/A                   | N/A                       |

**Key Observations:**

- **`fflib` / [`at4dx`](https://github.com/apex-enterprise-patterns/at4dx):** broad scope, but they require a significant training investment. `fflib` has had 1 tag and about 16 commits in the
  last 12 months (the latest tagged release is roughly 2,884 days old), and installation is source deploy, not an unlocked or managed package. `at4dx` extends `fflib` with dependency-injection
  patterns and inherits `fflib`'s posture on CRUD/FLS enforcement (opt-in at the query and DML layer); plan for an architecture review of the `at4dx` dependency-injection module before
  adoption. KernDX coexists with both, for teams that want an infrastructure layer alongside Domain-Driven Design.
- **KernDX:** one managed package covering all layers. FLS (field-level security) and CRUD (object create/read/update/delete) are enforced by default on both read and write paths. The data masking framework covers the broadest scope
  surveyed (any SObject), with per-SObject opt-in via `MaskingTarget__mdt` plus `TriggerSetting.ApplyMasking__c = true`. It includes a framework-wide kill-switch (a master off-switch you can flip in an incident without a deployment) for emergency rollback, and a Data Masking Advisor console that scans coverage and exports a regulated-field inventory.
  Session encryption is shipped, and every bypass writes a structured audit event. Framework-internal selectors opt into `SYSTEM_MODE` (which skips those permission and sharing checks) via the documented `SEL_Base.systemModeRequired()`
  hook; the metadata kill-switches double as emergency rollback.
- **`taf` / `apex-fluently-soql`:** focused, modular, with fast onboarding. Both ship `USER_MODE` defaults on their read paths and have an established adoption signal (`apex-fluently-soql` at 147 commits and 36 tagged releases in 12 months, plus a hosted docs site; `taf` at 33 published versions). KernDX matches them on substance and adds an integrated
  expansion path; the choice between them is depth on a single specialty surface versus framework-wide cohesion.
- **Mix-and-match:** teams commonly combine `taf` (triggers) plus `apex-fluently-soql` (queries) plus `nebula-logger` (logging). These three core libraries require no integration work:
  they are standalone and independent of each other. [`rflib`](https://github.com/j-fischer/rflib)'s adoption of `apex-fluently-soql` in v9.1.0 confirms how easily they compose.

### Enterprise Utilities Beyond Core Patterns

Real-world teams need more than the core patterns for triggers, queries, and DML. They also need the supporting utilities below. This table shows who ships each one built in versus where you would build it yourself or pull in a third-party library:

| Capability                 | `fflib`         | `at4dx`          | KernDX                                                                     | Build or Integrate 3rd Party                                |
|----------------------------|-----------------|------------------|----------------------------------------------------------------------------|-------------------------------------------------------------|
| **Logging**                | Custom required | Custom required  | Built-in (`LOG_Builder`)                                                   | `nebula-logger` (most established adoption signal surveyed) |
| **Feature Flags**          | Custom required | Custom required  | Built-in (`UTIL_FeatureFlag`)                                              | LaunchDarkly, custom metadata                               |
| **Circuit Breaker**        | Custom required | Custom required  | Built-in (`UTIL_CircuitBreaker`)                                           | Custom implementation                                       |
| **Retry Logic**            | Custom required | Custom required  | Built-in (`UTIL_Retry`)                                                    | Custom implementation                                       |
| **Caching**                | Custom required | Custom required  | Built-in (`UTIL_Cache`)                                                    | Custom Platform Cache wrapper                               |
| **String/Date/Collection** | Custom required | Limited          | 39 utility helpers across string, date, collection, set/list/map, security | Custom implementation                                       |
| **Test Builders**          | Custom required | Custom factories | Built-in (`TST_Builder`, `TST_Factory`)                                    | Custom factories                                            |
| **API Framework**          | Custom required | Custom required  | Built-in (`API_Outbound`, `API_Inbound`)                                   | Custom implementation                                       |
| **LWC Base**               | N/A             | N/A              | Built-in (`ComponentBuilder`)                                              | Custom base components                                      |
| **DTO Framework**          | Custom required | Custom required  | Built-in (`DTO_JsonBase`)                                                  | Custom implementation                                       |

**Reality check:** 80% of enterprises eventually build custom utilities regardless of framework choice. Logging is most commonly replaced first (usually with `nebula-logger`), followed by
test builders, then integration frameworks.

### Framework Selection by Org Archetype

What you need from a framework depends heavily on the kind of org you are. A small startup and a large enterprise have very different needs. The table below matches common org types to a realistic starting point under both the KernDX and the modular approach:

| Org Archetype              | Realistic Needs                             | KernDX Approach                                                                                                                                                                                                                                               | Modular Approach                                                                                                                                                                                                                                                                                          |
|----------------------------|---------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Startup (< 20 users)**   | Triggers + queries + tests (minimum)        | Install KernDX, use `TRG_*` + `QRY_Builder` + `TST_Builder`                                                                                                                                                                                                   | `taf` + `apex-fluently-soql` + custom test setup                                                                                                                                                                                                                                                          |
| **SMB (20-200 users)**     | + logging + validation                      | Add `LOG_Builder`, validation rules                                                                                                                                                                                                                           | + `nebula-logger` + custom validation                                                                                                                                                                                                                                                                     |
| **Mid-Market (200-1000)**  | + web services + resilience                 | Full KernDX adoption                                                                                                                                                                                                                                          | `taf` + `apex-fluently-soql` + `nebula-logger` + `apex-fluently-dml` + `apex-fluently-httpmock` + custom resilience                                                                                                                                                                                       |
| **Enterprise (1000+)**     | Full stack + governance                     | Full KernDX, where metadata enforces conventions                                                                                                                                                                                                                   | `taf` + Apex Fluently libraries (`apex-fluently-soql`, `apex-fluently-dml`, `apex-fluently-async`, `apex-fluently-httpmock`, `apex-fluently-cache`, `apex-fluently-test`, `apex-fluently-lwc`, `apex-fluently-consts`, each installed independently) + `nebula-logger`, where discipline enforces conventions |
| **ISV (AppExchange)**      | Package quality + namespace isolation       | KernDX (designed for managed packages)                                                                                                                                                                                                                        | `taf` + zero-dep (or Apex Fluently source)                                                                                                                                                                                                                                                                |
| **Integration-heavy**      | Retry, circuit breaker, outbox, idempotency | KernDX: built-in outbound retry, circuit breaker, transactional outbox, idempotency keys, dead-letter queues. KernDX covers more aspects of the Outbound family than any other Apex framework surveyed; `rflib` is competitive on the safe-mode surface | Build custom resilience patterns. Note that `apex-chainable` ships a dispatcher that resolves classes by name at runtime (reflection), unsuitable for managed-package distribution                                                                                                                                                             |
| **Government / regulated** | Compliance + audit logging                  | KernDX (any-SObject masking, pre-emit log masking, session encryption, payload signing, Log Console for browsing past entries) + `nebula-logger` if per-record retention overrides are required                                                                                                              | `taf` + `apex-fluently-soql` + `nebula-logger` (`USER_MODE` default on the query path; no integrated session encryption or signing)                                                                                                                                                                       |
| **Domain-complex**         | Business logic isolation                    | KernDX + custom domain layer (KernDX does not ship a Domain layer by design; `fflib` covers more aspects of the Domain Patterns family than any other Apex framework surveyed)                                                                                | `fflib` or `at4dx` (Domain / Service / Unit-of-Work patterns; `fflib` ships as source deploy with one tag in the last 12 months)                                                                                                                                                                          |

**Decision principle:** Even the smallest team needs trigger handling, query organisation, and test data. So the question is not *whether* to adopt a framework. It is which
approach (integrated or modular) best fits your team's size, priorities, and maintenance capacity. Over-engineering a small org is costly, but so is having no framework once the
codebase reaches 20 or more classes and technical debt starts compounding (Besker et al.: 23% of development time wasted on tech debt; McKinsey: 10-20% of new-product budget diverted to
debt resolution).

### Build vs Buy: Hidden Costs

The obvious costs of a framework are licensing and training. The costs that surprise teams are the ongoing ones below: the upkeep that every dependency quietly adds. They matter because they recur for the life of the org, and they multiply with every extra library you take on:

| Hidden Cost                       | Description                                                                                                  | Impact                                         |
|-----------------------------------|--------------------------------------------------------------------------------------------------------------|------------------------------------------------|
| **Framework upgrade testing**     | Each framework version requires sandbox testing before production promotion                                  | 2-4 hours per upgrade per framework            |
| **Cross-framework debugging**     | When bugs span multiple libraries, debugging requires expertise in each one                                  | 4-8 hours per cross-framework incident         |
| **Documentation maintenance**     | Internal coding standards, onboarding guides, and migration playbooks require updates when frameworks change | 8-16 hours per major version                   |
| **CI/CD pipeline maintenance**    | Test configurations, deployment scripts, and quality gates for each framework                                | 4-8 hours per framework per quarter            |
| **Vendor risk monitoring**        | Tracking GitHub activity, release cadence, and community health for each dependency                          | 1-2 hours per framework per quarter            |
| **Framework conflict resolution** | Namespace conflicts, dependency version mismatches, governor limit interactions                              | Rare but high-impact (8-24 hours per incident) |

**Key insight:** The modular approach (`taf` + `apex-fluently-soql` + `nebula-logger`) has lower costs per framework, but you pay them across 3 or more frameworks. KernDX has higher
costs per framework, but only one dependency to manage. The break-even point is typically at 3-4 independent libraries: beyond that, an integrated framework may have lower total
hidden costs.

### Build vs Buy: Cost Considerations

This guide does **not** publish a modelled 3-Year total-cost-of-ownership (TCO) comparison of Native Apex / `fflib` / KernDX / a modular OSS stack in specific dollar figures. Here is why. A fair
per-framework dollar comparison rests on soft-cost multipliers ("framework-enforced quality standards reduce production bugs by Nx", "convention consistency reduces technical debt
accumulation by Ny"). The relevant industry research (IBM/NIST, DORA, Besker et al., McKinsey) supports those as *qualitative ranges* but does not convert them into per-framework dollar
deltas. Publishing specific dollar figures would give the comparison a precision it does not have. The honest framing is that the dollar difference depends on your team's pre-framework
baseline, so what follows is a directional comparison built on the qualitative research findings, not a fabricated point estimate.

**What the research does support, qualitatively:**

- Production bugs cost 10-100x more than development-phase bugs (IBM/NIST/NASA). Frameworks with enforced coverage gates, ApexDoc requirements, and scanner enforcement reduce
  production-defect rates relative to a no-framework or unenforced-standards baseline. KernDX's 100% per-file Apex coverage gate and [35 scanner checks](Strategic%20Guide%20-%20Metrics.md#code-quality--scanning) (25 PMD rules, 6 ESLint rules, 4 Node scanners) are concrete enforcement
  mechanisms that move this metric in your direction.
- Developers waste roughly 23% of their time on technical debt (Besker, Martini & Bosch 2018, IEEE, replicated 2019); McKinsey 2020 found 10-20% of new-product budget is diverted
  to debt resolution. Framework-enforced conventions reduce the inconsistent-pattern flavour of debt, but they do not eliminate it.
- Quality documentation strengthens the lift from technical practices (DORA 2022 *Accelerate State of DevOps* report). KernDX's documentation depth (21 developer guides, 16 Fast
  Starts, 269 API reference pages, `AGENTS.md` + `docs/Code Conventions - Guide.md` AI context, the detailed Security Guide, the release-testing runbook) materially reduces the
  per-new-hire ramp curve, a metric you can measure directly against your team's own historical baseline.

**What the research does not support:** a specific dollar comparison of "KernDX costs $X over 3 years vs Modular at $Y" without measuring against your team's actual delivery data.
Run the comparison on your team's own pre-framework baseline (defects per release, P1 incident MTTR, onboarding ramp time, code review cycle time) and remeasure after the pilot.
See [Success Metrics](#success-metrics) for the metric set most enterprises track.

**Cost considerations that do not need a model:**

- **Licensing.** Native Apex, KernDX, `fflib`, `taf`, `apex-fluently-*`, `nebula-logger`, `rflib`, and [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library) all
  carry zero recurring licence fees.
- **Initial adoption ramp.** `fflib` requires internalising Domain-Driven Design, which is a paradigm shift, not just an API change, so it is a meaningful ramp investment. KernDX and modular
  stacks have comparable per-module learning time (see [Onboarding Time Comparison](#onboarding-time-comparison)). The total framework footprint differs: KernDX covers more
  capability areas, while a modular stack covers fewer but is layered in incrementally.
- **Maintenance and upgrades.** One managed package with one upgrade cycle (KernDX) versus five-to-eight independent libraries with five-to-eight independent release cadences (a modular
  stack) is a real difference, but the dollar magnitude depends on your team's release-engineering maturity.
- **Multi-SI fragmentation.** In environments with multiple SIs and weak central governance, both stacks fragment. With strong central governance, either is viable. The mechanism is
  described in [Code Drift in Multi-Team Environments](#code-drift-in-multi-team-environments).

**Sensitivity analysis (how the picture shifts by scenario):**

| Scenario                                                | Impact on KernDX TCO                                                                                                                              | Impact on Modular TCO                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Favours                                                          |
|---------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| **High turnover team (40%+ annual)**                    | Training costs increase with churn; KernDX documentation depth and AI context files reduce per-new-hire ramp time                                 | Training costs increase with churn similarly; per-module onboarding times are comparable (see [Onboarding Time Comparison](#onboarding-time-comparison))                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Either: pick based on your team's existing framework experience |
| **Stable senior team (< 10% turnover)**                 | Training costs minimal; coherence and maintenance savings dominate                                                                                | Training costs minimal; coherence discipline easier with stable team                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | KernDX (marginal)                                                |
| **Heavy Flow org (>50% logic in Flows)**                | Framework value reduced: most logic bypasses the Apex framework                                                                                      | Framework value reduced equally                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Neutral (both disadvantaged)                                     |
| **Pure Apex org (>90% logic in Apex)**                  | Maximum framework value: all logic flows through framework patterns                                                                              | Maximum framework value: all logic benefits from library standards                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | KernDX (marginal)                                                |
| **Bus factor event (maintainer unavailable 6+ months)** | **High impact per component:** single maintainer; source publicly available under BSL 1.1 lets the team self-maintain from the public repository | **Portfolio-distributed risk, component-level concentration is comparable.** A 5-library modular stack spreads bus-factor events across 5 solo maintainers (a single event affects ~20% of the stack, not 100%), but individual components are themselves single-maintainer in most cases. Across comparable Apex frameworks, most comparable Apex frameworks are also single-maintainer. Only the `fflib` family has distributed maintainership. Fork potential applies equally to KernDX (source publicly available under BSL 1.1). See [Bus Factor Mitigation](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#bus-factor-mitigation). | Modular (portfolio spread), otherwise equivalent                 |

*The risk of gradual drift toward inconsistent code (see [Code Drift in Multi-Team Environments](#code-drift-in-multi-team-environments)) is worth treating
as an additional TCO variable. In multi-SI, weakly governed environments, the cost of that drift in a modular stack can exceed the coherence savings of an integrated framework. In
centrally governed environments, the reverse holds: an integrated framework reduces the cost of drift.*

**Adoption Cost Dimensions (Relative Ratings):**

| Dimension                 | KernDX                                                                                                                                                                                                      | Modular Stack                                                                                                                                                                                   | `fflib`                                                                  | Native Apex                                                       |
|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|-------------------------------------------------------------------|
| Initial Adoption Effort   | ★★ Medium: 1 framework, 1 convention set, 1 doc site                                                                                                                                                       | ★★ Medium: comparable per-module learning time, but 5-8 APIs, 5-8 convention sets, and integration glue between libraries. Lower if adopting fewer modules, but equivalent at full-stack level | ★★★★ High: paradigm shift to Domain-Driven Design, steep learning curve | ★ Low: no framework overhead (costs surface in maintenance/debt) |
| Ongoing Maintenance       | ★ Low: single upgrade cycle, encapsulated internals                                                                                                                                                        | ★★★ Medium-High: multiple upgrade cycles, cross-library testing                                                                                                                                | ★★★ Medium: community maintenance, low recent release cadence           | ★★★★ High: no standards enforcement, technical debt compounds    |
| Architectural Flexibility | Low: centralised metadata and naming conventions enforced via the managed package; your code follows framework prefixes (`TRG_*` / `SEL_*` / `DML_*` / `LOG_*` / `API_*`) and patterns by construction | High: swap libraries independently, full source control                                                                                                                                        | Low: pervasive Domain-Driven Design patterns, high migration cost       | High: no framework constraints                                   |
| Test Coverage Guarantee   | 100% per-file Apex + 95% LWC statement/branch, enforced by the managed package requirement                                                                                                                     | Varies per library: `apex-fluently-soql` 98%+, others vary, and custom code is your responsibility                                                                                                 | Not publicly documented                                                  | Whatever your team enforces                                       |
| Resilience / Web Services | Built-in: retry, circuit breaker, outbox, idempotency, distributed tracing                                                                                                                                 | Must build custom: no modular equivalent for this combined feature set                                                                                                                         | Must build custom                                                        | Must build custom                                                 |

*Directional ratings (★ Low through ★★★★ Very High for cost rows; Low / Medium / High for strategic dimensions). For the cost discussion these ratings summarise, see [Build vs Buy: Cost Considerations](#build-vs-buy-cost-considerations) above; this guide presents directional, not dollar, comparisons.*

**TCO Sensitivity Factors:**

| Factor                        | Impact on TCO                                                                                                                                                    |
|-------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **SI turnover rate**          | Higher turnover = training and onboarding costs dominate = favour well-documented frameworks (KernDX) or simple standards (modular)                              |
| **Greenfield vs brownfield**  | Brownfield = favour modular adoption (per-library incremental) over full framework migration                                                                     |
| **Team Apex maturity**        | Junior-heavy teams = higher code quality costs without standards = favour frameworks with strict enforcement                                                     |
| **Multi-SI strategy**         | Multiple SIs = favour managed-package enforcement (KernDX) or modular stacks with strong central governance (without central governance, either stack fragments) |
| **Integration volume**        | High integration count = favour KernDX (built-in resilience) over custom patterns                                                                                |
| **Code quality requirements** | Regulated / ISV = favour 100% coverage + ApexDoc frameworks (KernDX, `taf`)                                                                                      |

See the [Decision Summary Matrix](#decision-summary-matrix) for situation-specific recommendations, and [Decision Matrix & Coexistence](#decision-matrix--coexistence) for detailed
evaluation criteria.

### Coherence Costs of Modular Stacks

When you assemble separate libraries, someone has to keep them working together consistently. That ongoing effort is the hidden cost of a modular stack: an integrated framework does it for you automatically. The table below shows the concrete tasks involved. One term it uses is the correlation ID: a single tracking ID that follows one user action across triggers, queries, callouts, and jobs, so you can trace what happened end to end. For the conceptual argument,
see [Integrated Stack](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#integrated-stack). For the operating model perspective,
see [Code Drift in Multi-Team Environments](#code-drift-in-multi-team-environments).

| Concern                    | Modular Stack Cost                                                                     | Integrated Framework                                                                                             |
|----------------------------|----------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| **Error handling**         | Manual `Logger.error()` in every catch block with hand-assembled context               | Automatic structured logging with trigger context and correlation ID                                             |
| **Log correlation**        | Build custom correlation ID system across trigger / API / async boundaries             | Correlation ID propagates automatically across all layers                                                        |
| **Testing**                | 3+ mock systems (query mocks, `HttpCalloutMock`, logger test setup) with separate APIs | Unified `TST_Mock` + `QRY_Builder.setMock()` + `API_MockFactory`                                                 |
| **Feature flags**          | Manually disable each component (trigger bypass, query check, API check)               | One feature flag record disables an entire feature path                                                          |
| **Upgrade coordination**   | 5-8 independent release cycles with manual compatibility testing                       | 1 managed package upgrade with internally tested compatibility                                                   |
| **Convention enforcement** | 5+ library APIs with different naming, error handling, and test patterns               | 1 prefix system and 1 set of conventions (`AGENTS.md` + `docs/Code Conventions - Guide.md`) covering all modules |
| **Environment quality**    | Source-distributed code appears in your own PMD scans and coverage reports         | The managed package keeps the framework's code out of your code-analysis tools                                                       |

These costs are manageable with strong technical guidance. Teams with dedicated architects who enforce cross-library consistency can maintain a coherent modular stack. Teams
without that discipline will see these costs compound over time.

### Code Drift in Multi-Team Environments

#### What drives long-term maintainability

Here is the central point of this section: in large Salesforce implementations, whether your code stays maintainable over the years depends far more on how you organise delivery than on whether your framework is open source or integrated.

Enterprise orgs most commonly degrade because of:

- Multiple system integrators contributing concurrently
- Inconsistent architectural enforcement
- Divergent coding patterns
- Uneven adoption of shared utilities
- Fragmented logging and error handling approaches
- Variable CI/CD enforcement discipline
- Team turnover across vendors

Maintainability challenges in these environments are typically behavioural and structural, not related to whether components are open source or integrated.

#### Open Source Does Not Guarantee Maintainability

The presence of an open-source framework does not inherently enforce:

- Naming conventions
- Consistent abstraction layering
- Cross-cutting concerns (logging, retry, resilience)
- Transaction boundary discipline
- Test strategy alignment
- Dependency management hygiene

Open-source modularity gives you building blocks. It does not enforce organisational consistency. Lasting maintainability depends on governance, enforcement, and architectural
authority.

#### Drift Risk in Modular Architectures

In multi-SI or loosely governed environments, modular stacks can introduce additional degrees of freedom. Common failure patterns include:

- Selective framework adoption by different teams
- Local utility duplication
- Forked implementations of shared libraries
- Inconsistent trigger orchestration approaches
- Divergent logging frameworks
- Incompatible error handling standards
- Variable mocking and test patterns

These conditions feed the gradual drift toward inconsistent code as different teams pick different patterns: inconsistency and unpredictability grow across the codebase over time. The more that drift sets in, the longer onboarding takes, the slower incident triage gets, the more friction appears between teams, and the less confident anyone is about refactoring.

This risk is independent of open-source licensing. It is a result of your operating model.

#### Degradation Sequence in Multi-SI Environments

In distributed delivery environments, the drift compounds in a predictable order:

1. **SI A adopts framework X:** it establishes the initial patterns and conventions.
2. **SI B introduces different patterns:** it uses alternative libraries or custom utilities for the same concerns.
3. **SI C bypasses both for delivery speed:** it writes inline solutions under sprint pressure.
4. **Utility duplication emerges:** three string utility classes, two date helpers, and no shared awareness of any of them.
5. **Logging fragments:** each SI instruments differently, so cross-team incident triage means reading three logging styles.
6. **Testing conventions diverge:** mock strategies, assertion patterns, and data-setup approaches differ across teams.
7. **You end up with a composite codebase and no shared model:** no single developer or team can reason about the full system with confidence.

This is not a failure of any framework. It is what naturally happens when modular freedom meets distributed ownership.

#### How an Integrated Framework Limits Drift

An integrated framework narrows the number of ways to do the same thing. It centralises trigger orchestration, logging standards, query construction, error handling, resilience patterns, and test scaffolding, which reduces the number of architectural decisions each team has to make on its own.

Fewer choices can slow that drift toward inconsistency in environments where governance is patchy, multiple vendors contribute, architectural enforcement is uneven, or knowledge transfer between teams is weak.

This does not eliminate the drift. It shrinks the room for teams to diverge.

#### Trade-Off: Coherence vs Coupling

Centralised integration introduces countervailing risks:

- Increased dependency on core maintainers
- Tighter coupling between framework components
- Higher impact radius of framework defects
- Greater importance of release discipline
- More structured onboarding requirements

| Approach                   | Strengths                                                 | Risks                                  |
|----------------------------|-----------------------------------------------------------|----------------------------------------|
| **Distributed Modularity** | Greater flexibility; lower central dependency             | More room for inconsistency to creep in without governance |
| **Integrated Coherence**   | Fewer divergent decisions; less room for code to drift apart | Higher central governance dependency   |

Each approach has trade-offs; which one suits you depends on how mature your operating model is.

#### Maintainability Comparison

| Dimension                  | Modular Stack                    | Integrated Stack                 |
|----------------------------|----------------------------------|----------------------------------|
| Code readability           | Depends on governance            | Depends on governance            |
| Long-term sustainability   | Depends on maintainer continuity | Depends on maintainer continuity |
| Upgrade path               | Component-specific               | Release-aligned                  |
| Risk of code drifting apart | Higher in distributed ownership  | Lower if enforced                |
| Vendor lock-in             | Low                              | Medium                           |

Maintainability is not determined by open-source status. It is determined by consistency, enforcement, and cultural discipline. The key difference is how much structural
guard-rail the architecture gives you when discipline slips.

#### Drift Risk by Environment

| Delivery Environment               | Modular Stack Drift Risk | Integrated Framework Drift Risk |
|------------------------------------|:--------------------------:|:---------------------------------:|
| Single cohesive team               |            Low             |                Low                |
| Two coordinated teams              |           Medium           |                Low                |
| Multi-team, shared governance      |           Medium           |                Low                |
| Multi-SI, weak central enforcement |            High            |              Medium               |
| High turnover, distributed vendors |            High            |              Medium               |

*This table assumes governance strength as the primary variable.*

#### Governance Readiness and Framework Suitability

Framework suitability correlates with the adopting organisation's governance readiness:

**Level 1, the tactical delivery org:** Multiple vendors, no architectural board, and sprint velocity prioritised over consistency. The risk of a modular stack drifting apart is high here because no central
authority forces everyone toward the same patterns. Integrated frameworks reduce divergent decisions but still need a minimum governance investment (naming conventions, code-review standards, and upgrade
ownership).

**Level 2, the controlled enterprise:** A central architecture function exists, and framework standards are enforced through pull-request reviews and CI pipelines. KernDX ships a
ready-to-use [Framework Compliance Scanner](Code%20Scanning%20-%20Guide.md): [35 checks](Strategic%20Guide%20-%20Metrics.md#code-quality--scanning) (25 PMD rules, 6 ESLint rules, 4 Node scanners) that enforce use of the framework's abstractions (no inline SOQL, no direct
DML, no `System.debug()`, and so on). Upload the rulesets to your CI/CD tool (Gearset, Copado, AutoRABIT, CodeScan) and enforcement is automatic. Mixed modular stacks are viable at this
level because the governance mechanisms catch divergence before it compounds, but teams have to build their own linting rules. Integrated frameworks with built-in scanners add
guard-rails with zero custom tooling.

**Level 3, the platform-as-product org:** A strong internal platform team, CI enforcement with automated linting and convention validation, and dedicated framework maintainers. KernDX's
scanner provides the linting baseline, and platform teams extend it with org-specific naming rules. Here a modular stack is sustainable long-term, because the platform team actively manages
coherence across the libraries. An integrated framework offers diminishing returns at this maturity level.

| Governance Level     | Modular Stack Viability |  Integrated Framework Value  |
|----------------------|:-----------------------:|:----------------------------:|
| Level 1 (Tactical)   |    High drift risk    |  Reduces divergent decisions   |
| Level 2 (Controlled) | Viable with enforcement |    Additional guard-rails    |
| Level 3 (Platform)   |  Sustainable long-term  | Diminishing marginal returns |

KernDX reduces dependency on Level 2/3 governance readiness but does not eliminate the need for it.

#### Key Framing Principle

Maintainability comes from governance authority, enforcement mechanisms, pattern discipline, review rigour, and cultural alignment, not from the licensing model. So your architectural choice
should match your organisation's ability to enforce standards across delivery partners.

---

## AI & Modern Platform

### AI Development Landscape

If your team uses AI coding assistants, framework choice affects how well they work. These tools have moved from simple code completion to full-context development agents that read your project's conventions and generate code to match. The table below compares the common ones:

| Tool                 | Model Access                             | Context Handling                     | Salesforce Integration                   |
|----------------------|------------------------------------------|--------------------------------------|------------------------------------------|
| **Agentforce Vibes** | Claude (Cline fork)                      | `AGENTS.md` support                  | Native (VS Code extension, org-aware)    |
| **Claude Code**      | Claude                                   | `AGENTS.md` native support           | Generic (requires manual context setup)  |
| **Cursor**           | Claude, GPT, custom                      | `.cursorrules` project context       | Generic (requires custom rules)          |
| **Cline**            | Any API (Claude, OpenAI, Gemini, Ollama) | Custom instructions, project context | Generic (community SFDC prompts)         |
| **Copado AI**        | Claude (partnership)                     | Salesforce metadata-aware            | Native (deployment history, test impact) |

**Key observations:**

- Tools that read project-specific context files (`AGENTS.md`, `.cursorrules`) produce more convention-compliant code.
- Salesforce metadata awareness (Agentforce Vibes, Copado AI) reduces deployment errors by about 30%.
- Base subscription costs are converging ($10-20/month); the real cost driver is API usage for multi-turn conversations.

### AI Context Files

KernDX maintains three AI context files:

| File                                                                                    | Tokens | Location  | Purpose                                                                                                                                                                     |
|-----------------------------------------------------------------------------------------|--------|-----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `AGENTS.md`                                                                             | ~3K    | repo root | Tool-neutral entry point for AI coding assistants; points to the canonical conventions (the `AGENTS.md` convention recognised by Claude Code, Cursor, Cline, Agentforce Vibes) |
| `docs/Code Conventions - Guide.md`                                                      | ~12K   | `docs/`   | Canonical framework conventions, code patterns, critical rules for AI code generation                                                                                       |
| `AI Agent Instructions` ([docs/AI Agent Instructions.md](AI%20Agent%20Instructions.md)) | ~10K   | `docs/`   | Complete per-module framework reference for deep AI-assisted development: architecture, module inventory, conventions, examples                                            |

Prompt caching (available from major LLM providers) helps most when a framework ships standardised instruction files, because it reduces repeated input token costs by about 90%.

### Agentforce Implications

Salesforce's Atlas Reasoning Engine (Agentforce GA October 2024) lets autonomous agents run multi-step workflows. That has a few implications for framework choice:

1. **Lean code is preferred:** agents reason about simple code more effectively.
2. **Declarative config is preferred:** metadata-driven frameworks line up with how agents execute.
3. **Test coverage is critical:** agents validate their changes by running unit tests.
4. **Idempotency is essential:** agents may retry an action, so the framework's duplicate detection (idempotency: if the same request arrives twice, the first result is returned again rather than re-run) prevents double-processing.

### Practical AI Development Patterns

**Pattern 1: Framework-Aware Code Generation**

With a well-structured `docs/Code Conventions - Guide.md`, AI assistants generate convention-compliant code:

```apex
// Prompt: "Create a trigger action that sets Account.Description to 'Enterprise' when Industry is 'Technology'"

// Without conventions — AI generates vanilla Apex with System.debug, inline SOQL, raw DML
// With AGENTS.md + docs/Code Conventions - Guide.md — AI generates:
//   - TRG_SetAccountDescription extending TRG_Base
//   - Implements IF_Trigger.BeforeInsert
//   - Uses LOG_Builder instead of System.debug
//   - Includes TST_Factory setup in test class
//   - Follows Allman bracing, tab indentation, ApexDoc conventions
```

**Pattern 2: AI-Assisted Test Generation**

When a framework has structured test patterns, AI generates better tests, because there is a clear pattern to copy:

| Without Framework          | With KernDX                                   |
|----------------------------|-----------------------------------------------|
| AI writes `insert record`  | AI uses `TST_Builder.of(SObjectType).build()` |
| AI writes `[SELECT ...]`   | AI uses `QRY_Builder` or `SEL_*`              |
| AI writes `System.debug()` | AI uses `LOG_Builder`                         |
| AI guesses test setup      | AI uses `TST_Factory.newTriggerAction()`      |
| AI forgets mock setup      | AI uses `TST_Mock` for DML-free tests         |

### Modern Platform Features

Spring '26 introduces features that affect framework selection:

| Feature                     | Impact                                          | KernDX Integration                             |
|-----------------------------|-------------------------------------------------|------------------------------------------------|
| **Apex Cursors (GA)**       | Process up to 50M rows in controllable chunks   | `.toCursor()` on `QRY_Builder`                 |
| **RunRelevantTests (Beta)** | AI-driven test selection for faster deployments | Declare dependencies via `testFor` parameter   |
| **Named Query API (GA)**    | REST endpoints without custom Apex              | Reduces need for simple query-only API classes |

---

## Decision Matrix & Coexistence

> Scenarios where KernDX is *not* the right fit (including "When NOT to Use KernDX" and "When Modular Architectures Clearly Excel") live in the
> companion [Risks](Strategic%20Guide%20-%20Risks.md) doc.

### Quick Decision Guide

Find the row that matches what you need; the Rationale column gives the honest "why", including where a specialist library wins.

<details><summary>Full quick-decision table (need → recommended choice → why)</summary>

| If You Need...                         | Choose                                               | Rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
|----------------------------------------|------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Only trigger framework                 | `taf` or KernDX (triggers only)                      | KernDX covers every aspect in the Trigger family (turn each handler on or off per event from configuration; logs every failure, times each action, and records every time a safety check is switched off; plus reacts to record-change events and runs follow-up work after the transaction commits), and `taf` wins on none of them. Choose KernDX unless you already run `taf` and want triggers only                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Only query builder                     | `apex-fluently-soql` or KernDX (queries only)        | Both default to `USER_MODE` on the read path. `apex-fluently-soql` covers the query specialty surface (semi-join, cursor pagination, ROLLUP/CUBE aggregates); KernDX matches on substance and adds integrated selector infrastructure (`SEL_Base` with 12+ inherited methods). Choose `apex-fluently-soql` for syntax breadth on a single specialty surface; choose KernDX for integrated selector infrastructure and a coherent expansion path                                                                                                                                                                                                                                                                                                                                                      |
| Only logging                           | `nebula-logger`                                      | `nebula-logger` covers more aspects of the Logging family than any other Apex framework surveyed, with log retention purge, 7 log levels, four save-method strategies, and log analytics dashboards. KernDX matches on Apex / async / LWC logging plus W3C distributed tracing and cross-trigger correlation IDs, and ships the Log Console for browsing, filtering, and searching past entries, but has four levels on a single transport and no retention overrides or dashboards.                                                                                                                                                                                                                                                                                                                                                 |
| Triggers + queries (no full framework) | `taf` + `apex-fluently-soql` or KernDX (partial)     | Both modular libraries default to `USER_MODE` on the read path. Modular: 2 installs, no namespace. KernDX: 1 install, use 2 modules, rest is inert, integrated when you expand. Choose based on whether you value independent installs (no namespace, mix-and-match) or integrated expansion path                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Modular open-source full stack         | Apex Fluently libraries + `nebula-logger`            | Assemble from 8 independently-installable MIT libraries (`apex-fluently-soql`, `apex-fluently-dml`, `apex-fluently-async`, `apex-fluently-httpmock`, `apex-fluently-cache`, `apex-fluently-consts`, `apex-fluently-test` (Beta), and `apex-fluently-lwc`, each in its own repo) plus `nebula-logger`. Per-module learning is comparable to KernDX; the trade-off is flexibility versus coherence costs (see [Coherence Costs of Modular Stacks](#coherence-costs-of-modular-stacks)). Note: the 8 Apex Fluently libraries share a single primary author, so this stack is effectively 2 maintainers (the Apex Fluently author plus the `nebula-logger` maintainer), not 9. For portfolio-level maintainer spread, pair independently-maintained libraries (`taf` + `apex-fluently-soql` + `nebula-logger`) for 3 distinct maintainers |
| Full integrated infrastructure         | KernDX                                               | Integrated triggers, queries, logging, web services, resilience, LWC, inbound REST routing, masking, and async chain. KernDX ships production-ready implementations of every core Salesforce capability, broader than the comparable Apex frameworks the team has surveyed. Per-module learning is comparable to modular; the advantage is pre-integrated coherence, a single upgrade cycle, and cross-cutting framework guarantees (see [Coherence Costs of Modular Stacks](#coherence-costs-of-modular-stacks))                                                                                                                                                                                                                                                                                                           |
| Complex domain modelling               | `fflib`                                              | `fflib` covers more aspects of the Domain / Service / Application-factory surface than any other Apex framework surveyed; KernDX is absent on this capability by design. `fflib` distribution is source deploy (~16 commits and 1 tag in the last 12 months), so plan for in-org source maintenance.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Web services + resilience              | KernDX                                               | KernDX covers every aspect in the Outbound family: an outbound HTTP client with retry, a circuit breaker (after repeated failures it stops calling a failing system for a cool-off, then resumes), a transactional outbox, idempotency keys, and dead-letter queues (messages that fail after all retries are set aside for inspection, not silently lost). KernDX is also the only Apex framework surveyed shipping inbound REST routing with body-hash idempotency that returns HTTP 409 on replay divergence. `rflib` is competitive on the safe-mode surface.                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Agentforce integration                 | KernDX + `nebula-logger`                             | Idempotent actions, platform event diagnostics, web service capabilities                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Team < 5 developers                    | KernDX (incremental) or `taf` + `apex-fluently-soql` | Both viable: per-module learning time is equivalent. Adopt one module at a time, not all at once                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Team > 20 developers                   | KernDX or `taf` + Apex Fluently + `nebula-logger`    | Standardisation at scale, architectural governance                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Existing `fflib` org                   | KernDX utilities + `fflib` domains                   | Reuse existing domain logic, add infrastructure modules (HTTP client, retry / circuit breaker, structured logging, masking, async chain orchestration) that `fflib` does not ship                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Managed package development            | KernDX                                               | Designed for managed packages: 2GP, namespace isolation, 100% per-file Apex coverage                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

</details>

### Decision Criteria

Use this table to work out which approach best fits your constraints. Each column has its strengths; the right choice depends on your team's priorities:

| Criterion                             | Favours Integrated (KernDX)                                                                                                                                                               | Favours Modular (`taf` + Apex Fluently + `nebula-logger`)                                                                               |
|---------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Team size > 20 developers             | Convention enforcement via managed package                                                                                                                                                | Modular libraries with team-supplied conventions (architectural discipline required to keep multiple libraries consistent)              |
| Governance readiness is low           | Managed package encapsulates standards                                                                                                                                                    | Requires architectural discipline to maintain consistency                                                                               |
| Integration volume > 5 APIs           | Built-in retry, circuit breaker, transactional outbox                                                                                                                                     | Build custom resilience or adopt `apex-libra`                                                                                           |
| Package encapsulation needed          | 2GP managed, exempt from 6 MB limit                                                                                                                                                       | Source-distributed, counts against limit                                                                                                |
| Open-source community required        | Not a fit. The source is public under BSL 1.1, but BSL is not OSI-approved until the Apache 2.0 conversion, and the contribution model is single-maintainer / issues-only                    | MIT-licensed, public GitHub repos                                                                                                       |
| Existing `fflib` investment           | Complement with utilities, don't replace                                                                                                                                                  | Complement with utilities, don't replace                                                                                                |
| Domain-Driven Design required         | Not a fit (service-oriented)                                                                                                                                                              | `fflib` or `at4dx`                                                                                                                      |
| Rapid prototyping                     | Strong default conventions speed delivery                                                                                                                                                 | Lighter initial setup                                                                                                                   |
| AI-assisted development               | `AGENTS.md` + `docs/Code Conventions - Guide.md` at repo root plus [AI Agent Instructions](AI%20Agent%20Instructions.md) per-module framework reference, optimised for AI code generation | Per-library README quality varies; `apex-fluently-soql` and `nebula-logger` ship maintainer-authored docs sites                         |
| Consulting delivery with handover     | Source is public under BSL 1.1; consulting delivery adds direct source delivery and handover support, and the client owns and can self-maintain the framework                             | Client may already know one or more of the libraries; if not, the per-library ramp is comparable to learning KernDX                     |
| Risk of code drifting apart (multi-team) | Less room for code to drift apart (see [Code Drift](#code-drift-in-multi-team-environments))                                                           | Higher drift risk without governance (see [Code Drift](#code-drift-in-multi-team-environments)) |

### Capability Comparison

See [Choosing a Framework](Strategic%20Guide%20-%20Choosing%20a%20Framework.md) for the full capability-by-capability comparison and head-to-head trade-offs across all frameworks.

### Coexistence Playbook

Modern Salesforce implementations rarely use a single framework. Salesforce frameworks are increasingly modular and interoperable: `taf` handles triggers, `apex-fluently-soql`
handles queries, and `nebula-logger` handles logging, with no architectural conflicts between them.

**Example Combinations:**

| Combination                                      | When to Use                                                                                                               | Trade-offs                                                                                                                                                                                      |
|--------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `taf` + KernDX utilities                         | Need `taf`'s declarative trigger surface + KernDX web services / resilience / async / inbound REST                        | Learn two frameworks. Bypass KernDX's `TRG_Dispatcher`.                                                                                                                                         |
| `apex-fluently-soql` + `nebula-logger`           | Specialty query surface + logging depth (retention, dashboards)                                                                           | No integrated trigger or DML framework                                                                                                                                                          |
| `taf` + `apex-fluently-soql` + `nebula-logger`   | Full open-source stack: `taf` on triggers, `apex-fluently-soql` on query depth, `nebula-logger` on logging depth + masking | Requires managing three separately-versioned dependencies                                                                                                                                       |
| KernDX + `fflib` domains                         | KernDX infrastructure + `fflib` Domain layer (KernDX absent on this family by design)                                     | Requires understanding both paradigms. `fflib` distribution is source deploy (~16 commits / 1 tag in the last 12 months).                                                                       |
| KernDX + `apex-fluently-soql` (query-layer swap) | When you specifically need `apex-fluently-soql`'s specialty (semi-join, cursor pagination, ROLLUP/CUBE aggregates) | Two query builders in the same codebase: pick one per class by convention, and lint to prevent drift. Both default to `USER_MODE` on read AND write, so they are equivalent on substance, not a reason to swap. |

#### Practical Coexistence Examples

**`fflib` Domain with KernDX Query Builder:**

```apex
public inherited sharing class Accounts extends fflib_SObjects
{
    public Accounts(List<Account> records)
    {
        super(records, Account.SObjectType);
    }

    public void applyDefaults()
    {
        Set<Id> ownerIds = new Set<Id>();
        for(Account account : (List<Account>)getRecords())
        {
            ownerIds.add(account.OwnerId);
        }

        Map<Id, User> ownerMap = (Map<Id, User>)QRY_Builder.selectFrom(User.SObjectType)
            .fields(new List<SObjectField>{User.Id, User.Department})
            .condition(User.Id).isIn(ownerIds)
            .asMap();

        for(Account account : (List<Account>)getRecords())
        {
            User owner = ownerMap.get(account.OwnerId);
            if(owner != null && String.isBlank(account.Department__c))
            {
                account.Department__c = owner.Department;
            }
        }
    }
}
```

#### Invoking Flows from KernDX Trigger Actions

KernDX's trigger framework ships native Flow-as-trigger-action via `TRG_InvokeFlow` and a `FlowName__c` field on `TriggerAction__mdt`. Set `FlowName__c`, leave `ApexClassName__c`
blank, and the framework dispatches via its built-in flow runner with declarative `LogAndContinue` / `BlockDml` failure strategies and a deploy-time scanner. For programmatic Flow
invocation outside the trigger framework (for example, calling a Flow from a non-trigger context), the pattern below applies:

```apex
public without sharing class TRG_InvokeAccountFlow extends TRG_Base implements IF_Trigger.AfterInsert
{
    private static final String FLOW_NAME = 'Account_PostProcessing';

    public void afterInsert(List<SObject> newRecords)
    {
        for(SObject record : newRecords)
        {
            Map<String, Object> inputs = new Map<String, Object>{ 'recordId' => record.Id };
            Flow.Interview flow = Flow.Interview.createInterview(FLOW_NAME, inputs);
            flow.start();
        }
    }
}
```

> **Note:** This pattern invokes Flows programmatically from arbitrary Apex. KernDX's native Flow-as-trigger-action surface (`TRG_InvokeFlow` + `FlowName__c` on
`TriggerAction__mdt`) handles declarative trigger-time dispatch without writing this Apex.

#### Adoption Principle

Adopt incrementally: start with one module (triggers or queries), expand when the team is comfortable, add resilience patterns when integration requirements arise. Specific
timelines depend on team size, existing codebase complexity, and available training time.

#### Testing Hybrid Implementations

**Isolation Principles:**

- Each framework's test patterns remain valid within their scope
- `taf` trigger actions test independently using standard Apex test patterns
- `apex-fluently-soql` queries test using direct assertions on returned data
- KernDX web services test using `API_OutboundTestHelper` assertions
- `nebula-logger` tests verify log entries using its `Logger.getBufferedLogEntries()` API

**Integration Testing:** When components from multiple frameworks interact, write integration tests that verify the handoff points:

```apex
@IsTest
private class Integration_TriggerToWebService_TEST
{
    @IsTest
    private static void shouldQueueApiCallFromTrigger()
    {
        // TAF trigger fires and queues KernDX API call
        Case record = (Case)TST_Builder.of(Case.SObjectType)
            .withOverrides(new Map<SObjectField, Object>{
                Case.Subject => 'Test', Case.Priority => 'High'
            }).build();

        // Assert: KernDX API queue item created
        List<ApiCall__c> items = QRY_Builder.selectFrom(ApiCall__c.SObjectType)
            .condition(ApiCall__c.TriggeringRecordId__c).equals(record.Id)
            .toList();
        Assert.areEqual(1, items.size(), 'Should create one API queue item');
    }
}
```

#### When NOT to Combine Frameworks

**Avoid Redundant Capabilities:**

- Don't install both `taf` and KernDX `TRG_*` for triggers (choose one)
- Don't install both `apex-fluently-soql` and KernDX `QRY_Builder` for queries (choose one)
- Don't install both `nebula-logger` and KernDX `LOG_Builder` for logging (choose one)

**Organisational Complexity:**

- If your release cadence is less than quarterly, avoid managing multiple framework upgrade streams in parallel; pick one integrated stack or one modular stack and let it run
- If central architectural authority is not yet established, don't introduce competing patterns; pick one approach and ratify it before mixing
- If on-call coverage cannot sustain debugging across 5+ independent libraries' release notes, prefer a single integrated framework's release cycle

---

## Adoption Roadmap

### Adoption Patterns

There are three common ways teams bring KernDX in. Find the one closest to your situation:

**1. Internal Accelerator Model**

- Used within a single enterprise to standardise delivery
- Governance centralised under platform engineering
- Ownership formalised with dedicated framework maintainer
- Best fit: large enterprise orgs with multiple Salesforce teams

**2. Managed Package Platform Model**

- The primary fit: KernDX was designed for managed package development
- Requires version discipline (semantic versioning, `global` API stability)
- Namespace isolation gives a clean boundary between framework code and your own code
- Best fit: ISVs, AppExchange publishers, multi-tenant product teams

**3. Ecosystem Alternative Model**

- Positions KernDX as one option alongside modular open-source stacks
- Requires demonstrating value over `taf` + Apex Fluently + `nebula-logger` combination
- Community growth strategy needed for long-term market adoption
- Best fit: teams evaluating integrated vs modular approaches

### Standalone Adoption — Logging as a No-Migration Wedge

If you want to try KernDX without committing to the full framework, start by adopting the logging capability on its own. `LOG_Builder` runs alongside your existing
automation without requiring you to migrate any triggers, queries, or DML.

**Why this works as a low-risk first step:**

- `TRG_LogEntryEvent` fires only on the `LogEntryEvent__e` Platform Event, so your own SObject triggers are not touched
- `TRG_Base` + `TRG_Dispatcher` stay inert until a `TriggerAction__mdt` record registers a handler, so an existing trigger framework of yours continues unchanged
- `UTIL_FrameworkMasker` short-circuits at runtime when masking is not enabled
- `UTIL_BypassAudit` short-circuits in test mode

**Install footprint (the honest caveat, auditable against the artifact list):**

- **Apex classes (~25):** `LOG_Builder`, `LOG_Engine`, `TRG_PersistLogEntry`, `TRG_Base`, `TRG_Dispatcher`, `IF_Trigger`, `DML_Builder`, `UTIL_String`, `UTIL_Random`, `UTIL_List`,
  `UTIL_SObjectDescribe`, `UTIL_Limits`, `UTIL_AsynchronousJobLauncher` (+ `UTIL_AdaptiveAsynchronousProcessor` + `DTO_AsynchronousJobRequest` + `DTO_ProcessSettings` +
  `IF_Async` + `IF_Queryable`), `UTIL_FrameworkMasker` (+ `SEL_MaskingRule` + `SEL_MaskingTarget` + `SEL_Base` + `QRY_Builder` + `UTIL_FeatureFlag` + `UTIL_AsyncChain` +
  `UTIL_Exceptions`), `UTIL_BypassAudit` (+ `SEL_LogEntry` + `UTIL_ValidationRule`).
- **Apex trigger:** `TRG_LogEntryEvent` (after-insert on Platform Event)
- **Custom SObjects:** `LogEntry__c` (~18 fields), `LogSetting__c` (Custom Setting hierarchy)
- **Platform Events:** `LogEntryEvent__e` (~14 fields)
- **CMDT types:** `TriggerAction__mdt` + `TriggerSetting__mdt` (+ `Event__c` picklist + `SObjectType__c` → `EntityDefinition` lookup), plus `FeatureFlag__mdt` +
  `MaskingRule__mdt` + `MaskingTarget__mdt` (records can be empty if masking stays disabled)
- **CMDT registration records (required):** `TriggerSetting.LogEntryEvent`, `TriggerAction.PersistLogEntry_AfterInsert`

**What this gives you:** structured Apex logging via `LOG_Builder.build().info('...').emitAt('Class.method')`, async event-bus delivery via `LogEntryEvent__e`, persistent
`LogEntry__c` records, transaction correlation, optional pre-emit regex / Luhn masking, and a chance to evaluate the framework's discipline by adopting one capability without migrating
any of your existing code.

**What this is NOT:**

- NOT a minimal install. The package deploys all [190 production Apex classes, 175 test classes](Strategic%20Guide%20-%20Metrics.md#package-codebase), and [67 LWC bundles](Strategic%20Guide%20-%20Metrics.md#lwc-components). Unused classes are inert (no governor impact, exempt from the 6 MB
  managed package limit), but the namespace prefix and single upgrade cycle still apply.
- NOT a way to adopt logging without the framework's broader posture. The `with sharing` defaults and the `USER_MODE` defaults on `QRY_Builder` / `DML_Builder`, and so on, all apply to the
  installed classes whether or not you actively use them.

### Starting from Existing Org (Brownfield)

| Weeks | Activity                                                                                                                                                                                                     | Effort        | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|-------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1-2   | **Adopt trigger framework.** Choose `taf` or KernDX `TRG_*`. Select highest-value trigger (most defects, most business rules, most frequently changed). Migrate to framework pattern. Achieve 100% coverage. | 3-5 dev-days  | `taf`: configure `TriggerAction__mdt`. KernDX: configure `TriggerAction__mdt` + `TriggerSetting__mdt`. Comparison summary: `taf` is the most-established of the frameworks we compared on declarative trigger registration, handler ordering, and Flow-as-trigger-action; KernDX matches on dispatcher substance and adds a stable action order (actions that share an order value always run in the same sequence, across deployments and org clones), bypass audit emission (every bypass writes a structured event), performance monitoring with metadata-driven thresholds, and W3C distributed tracing. |
| 3-4   | **Standardise trigger pattern.** Migrate 2-3 additional triggers. Establish coding standards (bypass mechanisms, recursion handling, test patterns). Document migration playbook.                            | 5-10 dev-days | Train team on metadata-driven configuration                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 5-6   | **Adopt query framework.** Choose `apex-fluently-soql` or KernDX `QRY_Builder`. Refactor 5-10 high-complexity queries. Focus on queries with multiple filters, dynamic conditions, or caching needs.         | 3-5 dev-days  | Measure query performance before/after. Both `apex-fluently-soql` and KernDX `QRY_Builder` default to `USER_MODE` on the read path. Document any framework-internal `SYSTEM_MODE` opt-outs via `SEL_Base.systemModeRequired()` (KernDX) or `.systemMode()` call sites (`apex-fluently-soql`) for code review.                                                                                                                                               |
| 7-8   | **Standardise query pattern.** Build reusable query methods for common patterns. Establish coding standards (security modes, caching policies). Document migration playbook.                                 | 5-8 dev-days  | Explore complementary libraries (`apex-fluently-dml`, `apex-fluently-async`; each Apex Fluently library installs independently from its own GitHub repo)                                                                                                                                                                                                                                                                                                   |
| 9-10  | **Adopt logging framework.** Choose `nebula-logger` or KernDX `LOG_Builder`. Replace `System.debug()` in async processes. Configure log retention and monitoring dashboards.                                 | 2-3 dev-days  | Trade-off: `nebula-logger` leads on log retention purge and analytics dashboards; both ship a screen for browsing past log entries. Both ship default-on, CMDT-extensible pre-emit masking. Nebula's rules scrub its log payload; KernDX's universally-relevant rules (payment-card numbers, secrets/keys) redact its log events, API calls, async chains, and issues, and can target any SObject. KernDX matches on Apex / async / LWC logging plus W3C distributed tracing, ships 15 more tested rules (covering both US and international identifiers) that enable on any object or field, and extends masking to your own SObjects. The default set targets what nearly every org handles; jurisdiction-specific and exhaustive rules are tested opt-in templates.        |
| 11-12 | **Retrospective.** Measure success metrics (code coverage, defect rates, developer velocity). Identify remaining migration candidates. Plan next quarter's framework adoption.                               | 2-3 dev-days  | Refine coding standards and CI/CD gates                                                                                                                                                                                                                                                                                                                                                                                                                     |

*Effort estimates assume a team of 5-10 developers and scale with codebase size, trigger complexity, and team familiarity with framework patterns. A smaller codebase (< 50 Apex
classes) will trend toward the lower bound; a larger codebase (200+ classes) or teams new to metadata-driven patterns will trend toward the upper bound.*

### Migration Narratives

Moving from one framework to another is rarely a gear-for-gear swap: you keep some things, give up others, and gain new ones. The summary below sets out the honest trade for five common migration paths, grounded in a
per-framework analysis, so you can see exactly what each move costs and buys.

**From `taf` to KernDX**

- **Low-friction port.** KernDX's `TRG_*` trigger framework is a direct evolution of `taf`: the Apex headers of the dispatcher and base classes retain `taf` attribution under
  Apache 2.0. The mental model is the same: a metadata-driven dispatcher, one trigger-action class per concern, context interfaces (`BeforeInsert` / `AfterUpdate` / etc.), and
  declarative bypass. A `taf` developer reads a KernDX trigger action and recognises it immediately; the hardest part of the port is the metadata-record schema change, not the Apex
  code.
- **Keep:** The class-per-concern discipline, the context-interface pattern, and the declarative bypass posture. `IF_Trigger.BeforeInsert` is the direct analogue of
  `TriggerAction.BeforeInsert`. Developers do not need re-training on the architectural model.
- **Give up:** The 627-star / 7-contributor community footprint and the architecture-board-signalling value of a framework maintained by Salesforce's Apex product lead.
- **Gain:** Flow-as-trigger-action via `FlowName__c` on `TriggerAction__mdt` (leave `ApexClassName__c` blank, and the framework dispatches via its built-in flow runner) with
  declarative `LogAndContinue` / `BlockDml` error strategies, a deploy-time flow-name + variable-contract scanner, and a mock harness for orchestration tests. `triggerOldMap` as a
  lazy-loaded `Map<Id, SObject>` for keyed lookups (`taf` provides list-only); performance monitoring with metadata-driven thresholds plus an auto-emitted audit event when a slow-action
  budget is exceeded (KernDX-only surveyed); W3C distributed tracing (traceparent/tracestate propagate across triggers, async chains, and API calls); feature-flag gating via
  `FeatureFlag__mdt`; and a **bypass audit trail**, where every bypass call writes a structured audit event with a W3C correlation ID. Across comparable Apex frameworks, only KernDX and `rflib`
  ship built-in bypass-audit emission. `EntityDefinition`-validated object binding instead of `taf`'s free-text field (typo-proof).
- **Schema migration:** `taf`'s `sObject_Trigger_Setting__mdt` + `Trigger_Action__mdt` (7 per-context MetadataRelationship fields) maps to KernDX's `TriggerSetting__mdt` +
  `TriggerAction__mdt` (single event picklist + single setting lookup). Record-by-record migration is mechanical, so most teams script it once and replay. Flow-action records drop
  the `ApexClassName__c = 'TriggerActionFlow'` indirection (KernDX dispatches via its built-in flow runner whenever `FlowName__c` is populated and `ApexClassName__c` is blank) and
  add `FailureAction__c = 'BlockDml'` (validation flows) or `'LogAndContinue'` (orchestration flows).
- **Coexistence option:** If a team already runs `taf` on specific objects and isn't ready to migrate, keep `taf` there and adopt KernDX on new objects. Both frameworks leave
  system Apex triggers alone; they coexist by object.

**From `fflib` to KernDX**

- **Keep:** the selector pattern (both frameworks ship a selector inheritance model); parent-child DML; and `fflib-mocks` for behaviour verification. KernDX does not replace
  `fflib_ApexMocks` behaviour verification (98 matcher factories in `fflib_Match`, in-order sequence verification, and post-hoc argument capture); KernDX is absent on this surface by
  design.
- **Give up:** the `fflib` Domain layer and `fflib_Application` registry (KernDX is absent here by design, because the framework conventions document explicitly forbids `fflib` patterns);
  `registerEmail()` / `IDoWork` on `fflib_SObjectUnitOfWork`; and domain lifecycle hooks (`onValidate`, `onApplyDefaults`). If you need Domain-Driven Design, keep
  `fflib` in place or pair KernDX with a custom domain layer.
- **Gain:** Metadata-driven triggers with bypass audit; per-action performance monitoring (KernDX-only); W3C distributed tracing; feature flags; circuit breaker (KernDX-only);
  inbound REST routing with body-hash idempotency (KernDX-only); any-SObject masking (four rule modes: regex, JSON-key, exact-match, credit-card-with-Luhn; enabling on a given
  SObject still requires `TriggerSetting.ApplyMasking__c = true`); pre-emit log masking; automatic save-order sorting (parents saved before children) with `.allowPartial()`; async chain orchestration.
- **Install note:** `fflib` distribution is source deploy ([`apex-enterprise-patterns/fflib-apex-common`](https://github.com/apex-enterprise-patterns/fflib-apex-common)), with ~16
  commits and 1 tag in the last 12 months, so plan for in-org source maintenance.
- **Net gain on query security:** `fflib`'s `newQueryFactory().setCondition(String)` accepts arbitrary WHERE strings, `fflib` has no `USER_MODE` default, and the static-Boolean
  off-switch consulted at every check method is silent. So `fflib`'s query and DML layers don't make the safe behaviour the default; you have to opt in to it. KernDX `QRY_Builder` and `DML_Builder` default
  to `USER_MODE` on read AND write, with the toggle methods explicit and any write-time toggles audit-traceable. Migrating the query / DML layer off `fflib` is one of the
  larger security gains this path delivers.

**From `nebula-logger` to KernDX `LOG_Builder`**

- **Keep:** If logging is your primary need, **do not migrate**. `nebula-logger` covers more aspects of the Logging family than any other Apex framework surveyed, with log
  retention purge, real-time event monitoring, and the depth of its logging surface (mixed transport modes, 7 log levels, four save-method
  strategies). KernDX matches on the core surface (Apex / async / LWC logging plus W3C distributed tracing) and ships its own screen for browsing past entries (the Log Console),
  but the dedicated dashboard surface rests with `nebula-logger`.
- **Give up:** Big Object archival; plugin framework (Slack, Big Object, async plugins); 7 log levels (vs 4 in KernDX); four
  save-method strategies; log analytics dashboards and a related-log-entries record-page component (KernDX's Log Console covers browsing, grouping, search, and drilldown, not
  dashboards or the record page).
- **Gain:** W3C `traceparent` / `tracestate` header propagation across async chains and outbound API calls; automatic instrumentation of every KernDX trigger, query, DML, and API
  call; auto-publish (no forgotten `Logger.saveLog()`); ERROR bypass buffering; typed async context serialisation. KernDX is the only Apex framework surveyed covering logging woven
  into trigger bypass auditing, DML failure handling, outbound HTTP correlation, and inbound idempotency tracking via shared correlation IDs.
- **A clear gain on masking:** both frameworks mask by default, and both let you add rules via custom metadata. But `nebula-logger`'s rules only ever scrub its own log payload
  (message + serialised record JSON), whereas KernDX masks the universally-relevant data (payment-card numbers and secrets/keys) across its log events, API calls, async chains,
  and issues out of the box, and can point a rule at any field on any SObject of yours. KernDX ships 15 more tested rules spanning US (SSN, Medicare) and international (IBAN,
  SWIFT/BIC, international phone) identifiers that activate on any object or field, and extends to your own SObjects via `MaskingTarget__mdt`. The default set is what
  nearly every org needs; jurisdiction-specific and exhaustive rules are tested opt-in templates. So the migration keeps default-on masking and gains reach far beyond the log payload.
- **Coexistence option:** Run both. KernDX `LOG_Builder` for framework infrastructure logging with W3C tracing + bypass audit emission; `nebula-logger` for business audit trails
  with Big Object archival + analytics dashboards + default-on regex masking. Cost: two log storage tables, and each framework's viewer shows only its own entries.

**From `rflib` to KernDX**

- **Keep:** `rflib`'s v9.1.0 adopted `apex-fluently-soql`. If you rely on `rflib_DefaultLogger` and the 4-level feature-switch hierarchy, they remain functional in an org that
  also installs KernDX. Before migrating, note that `rflib_DefaultLogger` is declared `without sharing` with masking off by default, an operational point worth reviewing. On
  Feature Switch specifically, `rflib` has a longer established adoption history; KernDX matches on substance with the `UTIL_FeatureFlag` strategy resolution.
- **Give up:** Platform-event-based trigger retry up to 8 retries (`rflib`'s only feature with no KernDX equivalent at the trigger layer); Big Object log archival; the fixed
  4-level feature-switch hierarchy if your admin UX depends on it; and the "Ops Center" visibility habits tied to `rflib`'s dashboards.
- **Gain:** an outbound HTTP framework (KernDX covers every aspect in the family); circuit breaker (KernDX-only); selector pattern (both ship one); inbound REST routing with body-hash
  idempotency (KernDX-only); W3C distributed tracing; and any-SObject masking (KernDX-only between these two). KernDX matches `rflib` on bypass audit emission: these are the only two frameworks
  surveyed with built-in bypass-audit emission.
- **Not a pure gain on logging:** Across the comparable Apex frameworks surveyed, `rflib` and `nebula-logger` carry the established adoption signal on the Logging family; KernDX
  matches them on the substantive logging surface. On Logging-family adoption signal, `rflib` and `nebula-logger` (and `apex-libra`) carry the strongest independent uptake.

**From Apex Fluently (multi-library) to KernDX**

> **Maintainer note (relevant if multi-contributor maintainership matters to your team):** The 8 Apex Fluently libraries share a single primary author, so a full Apex Fluently
> stack is effectively a single-maintainer dependency (or two maintainers if a separately-maintained logger such as `nebula-logger` is paired alongside). This is the norm rather than
> the exception: most comparable Apex frameworks are also single-maintainer; only the `fflib` family has genuinely distributed maintainership.
> See [Architecture & Philosophy: Bus Factor Mitigation](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#bus-factor-mitigation) for the per-framework breakdown.

- **Keep:** Apex Fluently is 8 independently-shipped MIT
  libraries ([apex-fluently-soql](https://github.com/beyond-the-cloud-dev/soql-lib), [apex-fluently-dml](https://github.com/beyond-the-cloud-dev/dml-lib), [apex-fluently-async](https://github.com/beyond-the-cloud-dev/async-lib), [apex-fluently-httpmock](https://github.com/beyond-the-cloud-dev/http-mock-lib), [apex-fluently-cache](https://github.com/beyond-the-cloud-dev/cache-manager), [apex-fluently-consts](https://github.com/beyond-the-cloud-dev/apex-consts), [apex-fluently-test](https://github.com/beyond-the-cloud-dev/test-lib) (Beta), [apex-fluently-lwc](https://github.com/beyond-the-cloud-dev/lwc-utils)). "Migrating to KernDX" is really a set of per-library swap decisions, not one decision. Each
  library can remain in place if the corresponding KernDX module does not improve on it for your use case.
- **Give up:** the specialty query surface in `apex-fluently-soql` (semi-join, cursor pagination, ROLLUP / CUBE aggregates, `conditionLogic('1 OR (2 AND 3)')` string expressions,
  `toLabel()`, `ignoreWhen()`, named mock IDs, with KernDX matching on substance for aggregates via `.toAggregateList()` / `.rollup()` / `.cube()` / `.grouping(field)`);
  the `apex-fluently-async` chain surface (KernDX matches on substance); and the larger public community on each library. Security-default parity holds on the read path: both default to
  `USER_MODE`, so they are equivalent on substance.
- **Gain:** logging (none in Apex Fluently; `LOG_Builder` ships the full logging surface); an outbound HTTP framework with circuit breaker (KernDX-only); an inbound REST framework (KernDX-only); resilience primitives (feature flag, utilities, async chain); security modules (session encryption and payload signing are KernDX-only; data masking is absent in Apex Fluently); an LWC framework (KernDX-only); CI tooling (KernDX-only); health diagnostics; and integration coherence (a single set of conventions in `docs/Code Conventions - Guide.md` versus 8
  READMEs).
- **Install note:** You don't have to pick one or the other. Most Apex Fluently libraries can be kept alongside KernDX; the cost is two sets of conventions and two maintenance
  calendars per library you keep. [`apex-fluently-async`](https://github.com/beyond-the-cloud-dev/async-lib) and `UTIL_AsyncChain` overlap in scope, so pick one for chain
  orchestration. [`apex-chainable`](https://github.com/rsoesemann/apex-chainable) should not be added to a KernDX-plus-`apex-fluently-async` stack, because its dispatcher resolves
  classes by name at runtime (reflection).

### Organisational Readiness

Framework adoption is a team activity, not just a tooling decision. Even the best framework fails without buy-in. Start with a pilot team of 2-3 developers who are willing to learn and
give feedback. Measure concrete metrics during the pilot (code-review cycle time, production defect rate, and new-developer onboarding time) so you can build a data-driven case for
broader rollout. See [Personas](Strategic%20Guide%20-%20Personas.md) for stakeholder-specific guidance on building alignment.

### Adoption Governance Model

The following governance structure applies to any framework adoption, whether integrated or modular:

```text
┌─────────────────────────────────────────────────────────────┐
│                ADOPTION GOVERNANCE MODEL                    │
│                                                             │
│   ┌──────────────────────────┐                              │
│   │  Architecture Authority  │  Selects framework(s),       │
│   │  (ARB / Platform Lead)   │  defines adoption gates,     │
│   │                          │  approves exceptions         │
│   └────────────┬─────────────┘                              │
│                │                                            │
│                ▼                                            │
│   ┌──────────────────────────┐                              │
│   │  Core Maintainers        │  Manages upgrades,           │
│   │  (Platform Engineering)  │  documentation, AI context,  │
│   │                          │  version compatibility       │
│   └────────────┬─────────────┘                              │
│                │                                            │
│                ▼                                            │
│   ┌──────────────────────────┐                              │
│   │  Contributing Teams      │  Builds features using       │
│   │  (Delivery / SI Teams)   │  framework patterns,         │
│   │                          │  follows conventions         │
│   └────────────┬─────────────┘                              │
│                │                                            │
│                ▼                                            │
│   ┌──────────────────────────┐                              │
│   │  Release Approval Gate   │  CI/CD, code review,         │
│   │  (Automated + Manual)    │  PMD, coverage, convention   │
│   │                          │  compliance verification     │
│   └──────────────────────────┘                              │
└─────────────────────────────────────────────────────────────┘
```

### Operational Ownership Model

Framework adoption requires clear ownership after initial implementation:

| Responsibility                                                    | Owner                 | Cadence              |
|-------------------------------------------------------------------|-----------------------|----------------------|
| Framework version upgrades                                        | Platform Engineering  | Per release cycle    |
| Error log review and trending                                     | Platform Engineering  | Weekly               |
| Agent action monitoring (if applicable)                           | Product + Engineering | Weekly               |
| `docs/Code Conventions - Guide.md` / instruction file maintenance | Engineering           | When patterns change |
| Cost monitoring (token/credit usage, if applicable)               | Product + Finance     | Monthly              |
| Incident response (framework issues)                              | Engineering           | As needed            |
| Change management (adoption rollout)                              | Product + Engineering | Per adoption phase   |

This model applies regardless of framework choice (`taf`, `apex-fluently-soql`, KernDX, or a combination).

### Success Metrics

Measure framework adoption impact with concrete, team-agnostic metrics:

| Metric                        |     Baseline (Pre-Framework)     |            Target (Post-Framework)            | How to Measure                               |
|-------------------------------|:--------------------------------:|:---------------------------------------------:|----------------------------------------------|
| **Code coverage**             |              75-85%              | 100% per-file Apex + 95% statement/branch LWC | `sf apex run test --code-coverage`           |
| **New developer onboarding**  | 4-8 weeks to first production PR |                   1-2 weeks                   | Track time from team join to first merged PR |
| **Production defect rate**    |              Varies              |               30-50% reduction                | Track defects per sprint/release             |
| **Code review cycle time**    |             2-5 days             |                   1-2 days                    | PR open then approved duration               |
| **Deployment frequency**      |             Monthly              |              Weekly or bi-weekly              | Successful production deployments per month  |
| **`System.debug` statements** |       Present in codebase        |                     Zero                      | `grep -r "System.debug" force-app/`          |
| **Inline SOQL statements**    |       Present in codebase        |                     Zero                      | `grep -rn "\[SELECT" force-app/`             |
| **Test execution time**       |              Varies              |          < 15 minutes for full suite          | `sf apex run test` duration                  |

**Leading indicators** (measure early, predict success):

- Developer satisfaction survey (quarterly, anonymous)
- Framework pattern adoption rate (% of new classes following conventions)
- AI code generation accuracy (% of AI-generated code passing review without changes)

**Lagging indicators** (measure later, confirm value):

- Production incident rate reduction
- Total cost of ownership vs pre-framework baseline
- Cross-team collaboration velocity (time to contribute to unfamiliar module)

---

## Conclusion

### Which approach to choose

The Salesforce framework ecosystem now has two viable full-stack approaches: **Apex Fluently** (modular open-source, 8 independent MIT libraries, each installed from its own
GitHub repo) and **KernDX** (one integrated managed package). Both cover triggers (the announced Apex Fluently Trigger Lib is not yet released, so teams use `taf` today), queries, DML,
caching, async, HTTP mocking, and test data. Both default to `USER_MODE` on the query layer, so they are equivalent on read-path security. Apex Fluently does not ship logging, web services,
resilience, masking, encryption / signing, inbound REST routing, an LWC framework, or CI tooling; a KernDX-equivalent modular stack pairs Apex Fluently with `nebula-logger` plus
custom resilience / security code. KernDX ships production-ready implementations of every core Salesforce capability, broader than the comparable Apex frameworks the team has
surveyed. The choice between them depends on whether your team prioritises **established adoption history and specialty depth on individual surfaces** (modular stack) or **framework-wide cohesion, broad capability coverage, default-on `USER_MODE` on read AND write, and bypass audit emission** (KernDX).

**KernDX provides an integrated alternative to modular assembly.** It comes with trade-offs that matter:

| Strength                                                                                                                                                                                                                                                                   | Corresponding Weakness                                                                                                                                                                                                                                                                                                                                                                        |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Integrated stack covering every core Salesforce capability (broader than the comparable Apex frameworks surveyed)                                                                                                                                                          | Full package deployment (unused code is inert: exempt from 6 MB, invisible to your code-quality tools, and zero governor impact, but the namespace prefix and single upgrade cycle still apply)                                                                                                                                                                                                          |
| You can see what your code actually did in production (a searchable, kept record) across triggers and API calls, with related entries tied together by a shared tracking ID; only KernDX and `rflib` ship built-in bypass-audit emission across comparable Apex frameworks                                                                                       | Single vendor dependency                                                                                                                                                                                                                                                                                                                                                                      |
| 100% per-file Apex coverage gate + 95% statement/branch LWC, enforced at every release build; full ApexDoc; zero real-issue scanner findings                                                                                                                               | Higher initial development cost                                                                                                                                                                                                                                                                                                                                                               |
| Five-tier documentation architecture ([21 guides + 16 Fast Starts + 269 reference pages](Strategic%20Guide%20-%20Metrics.md#documentation) + 2,326-line Security Guide + AI-context bundle)                                                                                                                                    | Single developer authored it                                                                                                                                                                                                                                                                                                                                                                  |
| Managed package (1 install, 1 upgrade, exempt from 6 MB); [120 distinct package version IDs](Strategic%20Guide%20-%20Metrics.md#activity-snapshot) in `sfdx-project.json`                                                                                                                                                          | Cannot modify managed source directly                                                                                                                                                                                                                                                                                                                                                         |
| Zero licensing fees; source publicly available under BSL 1.1 (relicenses to Apache 2.0 after the four-year change date); broader capability coverage than the comparable Apex frameworks surveyed (see [Overview § Headline Finding](Strategic%20Guide%20-%20Overview.md)) | Newly public framework: at least one known external client engagement at the snapshot date and a short public production track record so far. Broader production references will accumulate as more teams install the public release. If you weight accumulated activity history as a primary criterion, weigh that against KernDX's framework-wide capability footprint |
| Designed around what you receive: a [release-testing harness](Strategic%20Guide%20-%20Metrics.md#release-testing) with 561 anonymous-Apex assertions across 74 sections, 190 test methods across 41 subscriber test classes; a load-testing suite; rolling perf-history baselines; a release runbook; and a drift-audit cycle                        | No public community yet, so discoverability remains low                                                                                                                                                                                                                                                                                                                                       |

KernDX's trigger framework was adapted from `taf`. `UTIL_Security` originally descended from `fflib` but was replaced by platform-native `QRY_Builder.withUserMode()` and
`.stripInaccessible()`. `rflib` adopted `apex-fluently-soql`. Frameworks learn from each other, so choose based on your actual constraints.

### What Comes Next

| Milestone                    | Status                  | Impact                                |
|------------------------------|-------------------------|---------------------------------------|
| **1.0 package release**      | Released                | First GA version                      |
| **Open-source publishing**   | Shipped                 | Community access, external validation |
| **AppExchange listing**      | Planned                 | Enterprise distribution channel       |
| **Apex Cursors integration** | Shipped                 | 50M-row processing capability         |
| **Named Query API support**  | Evaluating              | REST exposure without custom Apex     |

### Decision Framework

| Condition                                       | Integrated Approach (KernDX)                                                                                                                                                                                                                                                                                      | Modular Approach (`taf` + Apex Fluently + `nebula-logger`)                                                                                                                                                                                                                                                                                                                                  |
|-------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Building a managed package                      | Strong fit: designed for the 2GP lifecycle                                                                                                                                                                                                                                                                           | Viable: source distribution, no namespace isolation                                                                                                                                                                                                                                                                                                                                        |
| Coordinated resilience patterns needed          | Strong fit: retry, circuit breaker, and outbox built in                                                                                                                                                                                                                                                              | Requires custom engineering per pattern                                                                                                                                                                                                                                                                                                                                                     |
| Centralised governance exists                   | Strong fit: the framework encapsulates conventions                                                                                                                                                                                                                                                                   | Strong fit: architectural discipline enforces standards                                                                                                                                                                                                                                                                                                                                    |
| OSI-approved licensing required at install time | Weaker fit: BSL 1.1 with a four-year change date to Apache 2.0, and single-maintainer (this is the norm; most comparable Apex frameworks are also single-maintainer; see [Risks: Bus Factor Reframe](Strategic%20Guide%20-%20Risks.md#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth)) | Strong fit on licence: MIT-licensed, public GitHub repos. Multi-contributor maintainership lives mostly in the `fflib` family.                                                                                                                                                                                                                                                             |
| Incremental per-library adoption preferred      | Moderate fit: per-module adoption is possible                                                                                                                                                                                                                                                                       | Strong fit: install only what you need                                                                                                                                                                                                                                                                                                                                                     |
| Architecture board requires public governance   | Weaker fit: private CI, internal contribution model, BSL 1.1 license                                                                                                                                                                                                                                             | Strong fit on CI visibility: public GitHub Actions. Most modular alternatives are still single-maintainer projects, so "community governance" is largely "one maintainer plus public CI" rather than a multi-contributor governance model; see [Risks: Bus Factor Reframe](Strategic%20Guide%20-%20Risks.md#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth) |

### Decision Summary Matrix

| Scenario                                                     | Recommended Posture                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|--------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Greenfield managed package, single SI                        | Evaluate KernDX. See [Decision Criteria](#decision-criteria) for the per-factor rationale                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Greenfield org, multiple SIs                                 | Depends on governance strength, not framework choice. See [Multi-SI Challenge](#the-multi-si-challenge). Without a central architectural authority, both integrated and modular stacks fragment under multi-SI delivery. With central authority, either is viable.                                                                                                                                                                                                                                            |
| Brownfield with `fflib`                                      | Freeze and contain; adopt modular libraries for new work. See [Migration Narratives](#migration-narratives) for the `fflib` coexistence guidance                                                                                                                                                                                                                                                                                                                                                              |
| Integration-heavy, single governance                         | Evaluate KernDX for the web services layer. See [Core Pattern Comparison](#core-pattern-comparison) for the inbound / outbound mechanism inventory                                                                                                                                                                                                                                                                                                                                                                |
| Open-source mandate                                          | Modular OSS stack only. See [Architecture & Philosophy: Licensing Considerations](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#licensing-considerations)                                                                                                                                                                                                                                                                                                                                       |
| Architecture board requires multi-contributor maintainership | The `fflib` family is the only modular alternative with genuinely distributed maintainership. Most other modular libraries (including the full Apex Fluently stack, which is effectively two maintainers: a single primary author across the 8 Apex Fluently libraries, plus the `nebula-logger` maintainer if it's included) are still single-maintainer projects. See [Architecture & Philosophy: Bus Factor Mitigation](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#bus-factor-mitigation) |
| Small team (< 5), greenfield                                 | Either is fine: KernDX (incremental) or `taf` + `apex-fluently-soql`. See [Onboarding Time Comparison](#onboarding-time-comparison) for the per-module timing                                                                                                                                                                                                                                                                                                                                                         |
| Enterprise (1000+ users), weak governance                    | Evaluate KernDX for convention enforcement; accept single-maintainer risk. (This risk applies to most alternatives too: most comparable Apex frameworks are also single-maintainer. See [Risks: Bus Factor Reframe](Strategic%20Guide%20-%20Risks.md#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth).)                                                                                                                                                                         |

| High team turnover (>40% annual) | Either stack is viable: per-module onboarding times are comparable across the comparable Apex frameworks (see [Onboarding Time Comparison](#onboarding-time-comparison)). Pick based on your team's existing framework experience and the libraries already in your hiring pipeline, not on a
generic "hiring liquidity" claim about any specific framework. |
| Consulting handover to client team | Either stack is viable. If the client team already uses a specific modular library, hand off in that library so they continue with what they
know. Otherwise, hand off in KernDX: source is publicly available under BSL 1.1 from day one (consulting engagements include direct source delivery and handover support), so the
client owns the framework. |

---
