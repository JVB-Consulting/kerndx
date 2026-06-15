# Strategic Guide — Operations

> Steady-state operating model for an installed KernDX package: distribution and packaging mechanics, exit / reversibility analysis, post-handover support tiers, performance
> characteristics, and governor-limit behaviour.

Part of the [KernDX Strategic Guide](Strategic%20Guide%20-%20Overview.md).
See
also: [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) | [Adoption](Strategic%20Guide%20-%20Adoption.md) | [Risks](Strategic%20Guide%20-%20Risks.md) | [Glossary](Strategic%20Guide%20-%20Glossary.md) | [Personas](Strategic%20Guide%20-%20Personas.md)

> **Primary reader:** Platform engineer or operations lead running the installed package — concerned with deployment footprint, upgrade cadence, exit reversibility, support model,
> and runtime performance. For the adoption *decision*, see [Adoption](Strategic%20Guide%20-%20Adoption.md). For risk classification and architecture-board questions,
> see [Risks](Strategic%20Guide%20-%20Risks.md).

---

<details><summary>Table of Contents</summary>

- [Packaging, Distribution & Exit Strategy](#packaging-distribution--exit-strategy)
    - [Distribution Models](#distribution-models)
    - [Package Lifecycle & Governance](#package-lifecycle--governance)
    - [Exit Strategy: $0 License Cost](#exit-strategy-0-license-cost)
    - [Metadata Migration Cost](#metadata-migration-cost)
    - [Exit and Reversibility Analysis](#exit-and-reversibility-analysis)
    - [Migration Checklists](#migration-checklists)
- [Post-Handover Support Model](#post-handover-support-model)
- [Performance & Governor Limits](#performance--governor-limits)
    - [Managed Package Reality](#managed-package-reality)
    - [Framework Overhead](#framework-overhead)
    - [Governor Limit Awareness](#governor-limit-awareness)
    - [Testing Philosophy Comparison](#testing-philosophy-comparison)

</details>

## Packaging, Distribution & Exit Strategy

### Distribution Models

| Aspect                   | Source-Distributed (`fflib`, Apex Fluently)                                                                                                                                                                                                                                                                                                                                                                              | Managed Package (KernDX)                                                                                                                                                                                                                                                                                                                              |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Distribution**         | Open-source, install from GitHub or source deploy                                                                                                                                                                                                                                                                                                                                                                        | Managed package (2GP) — 1 install URL                                                                                                                                                                                                                                                                                                                 |
| **Namespace**            | None (or your org's namespace)                                                                                                                                                                                                                                                                                                                                                                                           | Package namespace (or client-specific if repackaged)                                                                                                                                                                                                                                                                                                  |
| **Updates**              | Pull from GitHub per library; manage compatibility across 5-8 libraries                                                                                                                                                                                                                                                                                                                                                  | Push upgrades via single package version                                                                                                                                                                                                                                                                                                              |
| **Customisation**        | Full source access, modify freely                                                                                                                                                                                                                                                                                                                                                                                        | `global` API only (unless deployed as unlocked)                                                                                                                                                                                                                                                                                                       |
| **Isolation**            | No namespace isolation — source lives in subscriber org                                                                                                                                                                                                                                                                                                                                                                  | Namespace isolation prevents conflicts                                                                                                                                                                                                                                                                                                                |
| **Org code limit**       | Counts against 6 MB Apex code limit                                                                                                                                                                                                                                                                                                                                                                                      | Exempt from 6 MB limit                                                                                                                                                                                                                                                                                                                                |
| **Code quality in org**  | Library source becomes part of subscriber's code analysis (PMD, ApexDoc)                                                                                                                                                                                                                                                                                                                                                 | Encapsulated — subscriber never sees internal implementation                                                                                                                                                                                                                                                                                          |
| **CI/CD test execution** | Library tests become part of the subscriber's test surface. Day-to-day CI can be scoped to relevant tests, but Salesforce-enforced gates — production deploys (which run every test in the subscriber namespace) and full-suite coverage checks — cannot. Production deployment wall-clock grows materially, and headroom against platform test-execution limits (e.g. the 120-minute synchronous-test ceiling) shrinks. | Package tests run only during package version validation on the publisher's Dev Hub; subscriber CI/CD is unaffected at any gate. For KernDX specifically, the entire test suite (166 Apex test classes, ≈3,443 `@IsTest` methods, plus the LWC Jest suite) stays inside the package boundary, gated at 100% per-file Apex + 95% statement/branch LWC. |
| **DevOps velocity**      | Deploy thousands of individual source files across multiple libraries                                                                                                                                                                                                                                                                                                                                                    | Promote a single version number through DevOps pipelines                                                                                                                                                                                                                                                                                              |
| **AI context**           | 5-8 separate README files per library                                                                                                                                                                                                                                                                                                                                                                                    | 1 set of conventions (`AGENTS.md` + `docs/Code Conventions - Guide.md`) covering all modules                                                                                                                                                                                                                                                          |

### Package Lifecycle & Governance

KernDX is treated as a **stable infrastructure dependency** (like a Linux kernel). Updates are deliberate, not automatic. No forced upgrades — you control when to adopt new
versions.

| Concern                      | Approach                                                                               |
|------------------------------|----------------------------------------------------------------------------------------|
| **Version locking**          | 2GP version locking in `package.xml` during stabilisation                              |
| **Breaking changes**         | Semantic versioning (major.minor.patch); backward compatibility prioritised            |
| **Upgrade cadence**          | Quarterly maintenance window: review release notes, test in sandbox, promote           |
| **Subscriber customisation** | `ClassTypeResolver__mdt` for type resolution, selector subclassing for field extension |

### Exit Strategy: $0 License Cost

**Every subscriber owns the deployed asset completely — zero licensing fees under BSL 1.1.** Source is available, modifiable, and deployable; subscribers can self-install from the
public repository under BSL 1.1 or receive direct source delivery via a consulting engagement. After the four-year change date, the source relicenses to Apache 2.0 automatically.

**Three options for taking ownership of the framework:**

1. **Continue using the managed package** (simplest)
    - Framework maintainer continues updates
    - Subscriber receives push upgrades
    - Zero additional effort

2. **Deploy as unlocked package or direct source** (moderate effort)
    - Source acquired from the public repository, or delivered directly for consulting-engagement subscribers
    - Deploy without namespace prefix — removes the package namespace entirely
    - Full customisation freedom under BSL 1.1
    - Effort: 2-4 hours

3. **Repackage with a subscriber-owned namespace** (source delivered as `Unmanaged.zip`; subscriber owns the metadata)
    - Subscriber creates namespace (e.g., `MyOrgNS`)
    - Rebuild package in subscriber's Dev Hub
    - Automated migration: find/replace scripts handle Apex classes, LWC imports, metadata records
    - **Available to every subscriber:** Complete source code from the public repository + the repo-root `AGENTS.md` pointer + `docs/Code Conventions - Guide.md` conventions file,
      along with per-module framework reference documentation, with step-by-step repackaging instructions. Among the comparable Apex frameworks surveyed, KernDX is one of the few
      that ships a documented complete repackaging workflow (most modular OSS alternatives ship source-on-GitHub but no end-to-end recipe for namespace ownership transfer).
    - Effort: 4-8 hours (following guide)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EXIT STRATEGY DECISION TREE                              │
│                                                                             │
│                    Subscriber lifecycle: What happens next?                 │
│                              │                                              │
│                              ▼                                              │
│              ┌───────────────────────────────┐                              │
│              │  Does subscriber want to own  │                              │
│              │  the framework source code?   │                              │
│              └───────────────┬───────────────┘                              │
│                     ┌────────┴────────┐                                     │
│                     │                 │                                     │
│                     ▼                 ▼                                     │
│                   [NO]              [YES]                                   │
│                     │                 │                                     │
│                     ▼                 ▼                                     │
│    ┌─────────────────────┐   ┌────────────────────────┐                     │
│    │ OPTION 1: Continue  │   │ Does subscriber want a │                     │
│    │ using managed pkg   │   │ subscriber-owned NS?   │                     │
│    │                     │   └───────────┬────────────┘                     │
│    │ Effort: Zero        │         ┌─────┴─────┐                            │
│    │ Maintainer updates  │         │           │                            │
│    └─────────────────────┘         ▼           ▼                            │
│                                  [NO]        [YES]                          │
│                                    │           │                            │
│                                    ▼           ▼                            │
│                   ┌────────────────────┐  ┌─────────────────────────┐       │
│                   │ OPTION 2: Deploy   │  │ OPTION 3: Repackage     │       │
│                   │ as Unlocked Pkg    │  │ with subscriber NS      │       │
│                   │                    │  │                         │       │
│                   │ Effort: 2-4 hours  │  │ Effort: 4-8 hours       │       │
│                   │ Full source, no NS │  │ Complete independence   │       │
│                   └────────────────────┘  └─────────────────────────┘       │
│                                                                             │
│              See repackaging steps in this doc for per-module instructions   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Metadata Migration Cost

Source code exit is straightforward (find/replace namespace references). Metadata exit is harder. If your org has accumulated significant configuration in KernDX's custom metadata
types:

| Metadata Type                                      | What Must Migrate                                                                                   | Typical Volume                                                                                                                      | Effort         |
|----------------------------------------------------|-----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|----------------|
| `TriggerSetting__mdt` + `TriggerAction__mdt`       | Every configured trigger action and ordering                                                        | 20-100 records                                                                                                                      | Medium         |
| `FeatureFlag__mdt` + `FeatureFlagStrategy__mdt`    | All feature flag definitions                                                                        | 5-30 records                                                                                                                        | Low            |
| `ApiSetting__mdt` + `ApiCredential__mdt`           | Every outbound API configuration                                                                    | 5-20 records                                                                                                                        | High           |
| `LogSetting__c`                                    | Logging configuration (per-user / per-profile thresholds)                                           | 5-15 records                                                                                                                        | Low            |
| `MaskingRule__mdt` + `MaskingTarget__mdt`          | Data masking rules and field wirings (any SObject text field — standard, custom, or platform event) | 3 active rules + 12 default targets shipped; add one `MaskingTarget__mdt` per org-specific field or wildcard per org-specific object | Low per target |
| `ValidationRule__mdt` + `ValidationRuleGroup__mdt` | In-Apex validation rules                                                                            | 10-50 records                                                                                                                       | Medium         |

**Assessment.** *Directional estimate — based on internal scenario modelling, not benchmarked against an external subscriber exit.* For a team that has deeply adopted KernDX across
20+ objects with full API, logging, and validation configuration, the metadata migration effort depends heavily on how it is executed. A team with modern agentic AI tooling (Claude
Code, Cursor, Agentforce Vibes) loaded against the framework-context bundle (`AGENTS.md` +
`docs/Code Conventions - Guide.md` + [AI Agent Instructions](AI%20Agent%20Instructions.md), ~20K tokens) — available from the public repository, and additionally delivered at
handover for consulting-engagement subscribers — can run the migration mostly agent-driven, with scripted find/replace, custom-metadata re-authoring, deploy/iterate loops, and the
automated release-testing runbook all running inside the agent session and human review and sign-off as the primary gating factor. Directional wall-clock on this path: **~1-2 days**. A team executing the migration with human-only effort — reading documentation, re-authoring custom metadata by hand, manually iterating on deploy errors — should expect the
conventional **1-2 week** range. The source code is portable; the configuration investment is the real cost, and agentic tooling materially shrinks that cost rather than
eliminating it. Teams should factor their own tooling maturity into the estimate when scoring adoption reversibility.

> **Key Principle:** "KernDX is an Accelerator you can own, not a Product you rent."

### Exit and Reversibility Analysis

| Dimension                           | Assessment                                                                                     | Detail                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|-------------------------------------|------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Can it be removed incrementally?    | Medium                                                                                         | Utilities (`UTIL_*`, `LOG_Builder`) can be replaced independently. Trigger framework (`TRG_*`) and web services (`API_*`) require coordinated migration — all handlers for an object must move together.                                                                                                                                                                                                                                                             |
| Can services revert to native Apex? | Low complexity                                                                                 | KernDX patterns use standard Apex (selectors, builders, DTOs). Reverting to native Apex requires removing framework method calls but not paradigm changes.                                                                                                                                                                                                                                                                                                           |
| Estimated refactor cost             | ~1-2 days agent-executed / 1-2 weeks conventional (deeply adopted orgs) — see disclaimer above | Source code migration is mechanical (scripted find/replace + interface changes). Metadata migration (`TriggerAction__mdt`, `ApiSetting__mdt`, `FeatureFlag__mdt`) dominates effort under conventional human-only execution; with agentic tooling loaded against the AI-context bundle, the metadata transform collapses to hours and the wall-clock floor is set by human review, sign-off, and UAT.                                                                 |
| Structural dependency created       | Variable                                                                                       | **High** for triggers (`TRG_Dispatcher` + `TriggerAction__mdt` + `TriggerSetting__mdt`) and web services (`API_Outbound` + `ApiCall__c` + `ApiSetting__mdt`). **Low** for utilities (`UTIL_String`, `UTIL_Cache`) and test builders (`TST_Builder`).                                                                                                                                                                                                                 |
| Data dependency                     | Low to Medium                                                                                  | `LogEntry__c` records, `ApiCall__c` queue items, and `FeatureFlag__mdt` records are framework-specific. Historical data would need archival or migration.                                                                                                                                                                                                                                                                                                            |
| **Overall removal complexity**      | **Medium**                                                                                     | Utility and query layers exit cleanly. Trigger and web service layers require coordinated migration due to metadata dependencies. Exit is feasible and, for teams equipped with modern agentic AI tooling loaded against the framework's AI-context bundle, directionally absorbable inside a single sprint (~1-2 days wall-clock — directional estimate per disclaimer above). Teams without agentic tooling still face the 1-2 week conventional-execution effort. |

See [Migration Checklists](#migration-checklists) below for step-by-step recipes (KernDX → modular stack, fflib → KernDX, no-framework → KernDX).

### Migration Checklists

#### Migration Cost Calculation (Worked Example)

> **Illustrative formula — inputs are not measured from a specific deployment.** The numbers below are example values to demonstrate the formula structure. Refactor hours per
> class, hourly cost, and onboarding savings come from your team's historical delivery data, not from this framework's documentation. The formula structure is portable; the inputs
> are subscriber-supplied.

```text
Migration Cost = (Classes Using fflib × Average Refactor Hours) + (Developer Training Hours × Team Size)
Break-Even Point = Migration Cost ÷ (Quarterly Maintenance Savings + Quarterly Velocity Gain)
```

```text
Given: 50 classes using fflib, 4 developers, 10 new hires/year
─────────────────────────────────────────────────────────────
Refactor cost:    50 classes × 8 hours/class = 400 hours
Training cost:    4 developers × 40 hours = 160 hours
New hire savings: 10 hires/year × 20 hours saved/hire = 200 hours/year

Migration Cost = 400 + 160 = 560 hours ($84K at $150/hr)
Annual Saving  = 200 hours ($30K) + reduced maintenance (~$20K)
Break-Even     = $84K ÷ $50K/year = 1.7 years (migrate)
─────────────────────────────────────────────────────────────
Decision: MIGRATE (break-even < 4 quarters)
```

Adjust hours per class based on your `fflib` adoption depth (selectors only ≈ 4 hours/class; full DDD with Domain + Service + Unit of Work ≈ 16 hours/class). The example
multipliers above (8 h/class refactor, $150/hr developer cost, 20 h saved per new hire, ~$20K reduced annual maintenance) are placeholders — replace each with your team's
historical figures before treating the break-even calculation as decision-relevant.

#### Migrating from fflib to KernDX

> **Before you migrate: check the Domain / Service / Application layer.** [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) ships a Domain layer + Service /
> Application factory; KernDX does not ship either. If your codebase relies on `fflib_SObjectDomain` lifecycle hooks (`onApplyDefaults`, `onValidate`, `onBeforeInsert`) or the
`fflib_Application` factory binding `SObjectType → Selector / Domain / UnitOfWork`, you are migrating away from capabilities KernDX does not ship. Plan to rewrite domain lifecycle
> logic as trigger actions or keep `fflib` alongside KernDX (the two can coexist indefinitely).

| Step | Action                                                                                                                                                                                                                                                                  | Validation                                                          |
|------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| 1    | Install KernDX managed package in sandbox                                                                                                                                                                                                                               | All `@IsTest` methods pass                                          |
| 2    | Map `fflib` patterns to KernDX equivalents                                                                                                                                                                                                                              | Document mapping, including Domain / Service / Application gaps     |
| 3    | Create KernDX selectors for existing domain objects                                                                                                                                                                                                                     | `SEL_*` classes with `getFields()`                                  |
| 4    | Migrate the simplest selector first (fewest custom methods)                                                                                                                                                                                                             | All existing tests pass                                             |
| 5    | Replace `fflib_QueryFactory` calls with the `query` property. KernDX `QRY_Builder` defaults to FLS-enforced reads; framework-internal read paths that need system-mode opt in via `SEL_Base.systemModeRequired()`                                                       | Verify query results match and FLS behaviour is preserved           |
| 6    | Replace `fflib_SObjectUnitOfWork` with `DML_Builder`. **Gap:** KernDX has no `registerEmail()` or `IDoWork` equivalent — rewrite email registration and arbitrary work as separate steps                                                                                | Verify DML outcomes match                                           |
| 7    | Rewrite `fflib_SObjectDomain` logic as `TRG_Base` trigger actions. **This is a paradigm shift, not a rename.** Domain lifecycle hooks (`onApplyDefaults`, `onValidate`) become discrete `IF_Trigger.*` action classes; the Domain class itself has no direct equivalent | Configure `TriggerAction__mdt`; verify lifecycle ordering preserved |
| 8    | Replace `fflib_ApexMocks` with `TST_Mock` (data-driven). **Gap:** KernDX does not ship Mockito-style behaviour verification (argument captors, in-order verification). Rewrite behaviour-verification tests as data-outcome tests                                       | All tests pass with new mocks                                       |
| 9    | Add `LOG_Builder` calls to replace `System.debug()`                                                                                                                                                                                                                     | Verify log entries in `LogEntry__c`                                 |
| 10   | Remove `fflib` dependencies from `package.xml` **only if** you have replaced every Domain / Service / Application pattern. If any `fflib` Domain / Service classes remain, keep `fflib` installed — the two frameworks can coexist indefinitely                         | Full `RunLocalTests` pass                                           |

**Estimated timeline:** 2-4 weeks per domain object (selector + triggers + tests). For a 10-object org, expect 20-40 weeks for full migration. Incremental migration is
recommended — both frameworks can coexist indefinitely. If you use `fflib_Application` for registered factory bindings, expect additional cost to rewrite dependency injection;
KernDX does not ship an Application-layer equivalent.

#### Migrating from No Framework to KernDX

| Step | Action                                                         | Validation                                    |
|------|----------------------------------------------------------------|-----------------------------------------------|
| 1    | Install KernDX managed package in sandbox                      | All `@IsTest` methods pass                    |
| 2    | Start with one high-value object (most triggers, most queries) | Choose pilot object                           |
| 3    | Create trigger with `TRG_Dispatcher`                           | `TRG_ObjectName` file + `TriggerSetting__mdt` |
| 4    | Migrate inline trigger logic to `TRG_Base` action classes      | `TriggerAction__mdt` records configured       |
| 5    | Create selector extending `SEL_Base`                           | Replace inline SOQL with selector calls       |
| 6    | Add `LOG_Builder` to error handling paths                      | Remove all `System.debug()` calls             |
| 7    | Write tests using `TST_Builder` + `TST_Factory`                | 100% coverage on migrated code                |
| 8    | Repeat for next object                                         | Build momentum with team                      |

**Estimated timeline:** 1-2 weeks for first object (learning curve). 2-5 days per subsequent object. Most teams reach self-sufficiency after 3-4 objects.

#### Migrating from KernDX to a Modular Stack

If KernDX is no longer the right fit, exit paths are defined per module:

| KernDX Component                                   | Modular Replacement                                                                                                 |                                                                                                                                                                                            Migration Effort |
|----------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| `TRG_Dispatcher` + `TRG_Base`                      | [`taf`](https://github.com/mitchspano/apex-trigger-actions-framework) (Apache 2.0; declarative trigger framework)   |    Medium (metadata rename + interface change; both ship Change Data Capture dispatch and post-trigger finalizers; KernDX additionally ships bypass-audit emission `taf` lacks on its programmatic surface) |
| `QRY_Builder` + `SEL_Base`                         | [`apex-fluently-soql`](https://github.com/beyond-the-cloud-dev/soql-lib) (query-builder family)                     |                                                                                                                                  Medium (API differences; `apex-fluently-soql` defaults to user-mode reads) |
| `LOG_Builder`                                      | [`nebula-logger`](https://github.com/jongpie/NebulaLogger) (ships historical log browser + retention engine)        |                                                                                                                                Low (similar platform-event pattern; adds log browser + Big Object archival) |
| `DML_Builder`                                      | [`apex-fluently-dml`](https://github.com/beyond-the-cloud-dev/dml-lib) (DML wrapper)                                |                                                                                                                                                                                           Low (similar API) |
| `UTIL_HttpClient`                                  | Custom or [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library) `HttpClient`                      |                                                                                                                                                    Medium (`apex-libra` is independent of Beyond The Cloud) |
| `TST_Builder` + `TST_Mock`                         | ApexTestKit, [`apex-fluently-test`](https://github.com/beyond-the-cloud-dev/test-lib) (Beta), or custom             |                                                                                                                           Medium (`apex-fluently-test` carries Beta status; ApexTestKit ships a stable API) |
| `TST_Factory`                                      | Custom — no direct replacement                                                                                      |                                                                                                                                    High (metadata-factory pattern is specific to KernDX's integrated stack) |
| `UTIL_FeatureFlag`                                 | [`rflib`](https://github.com/j-fischer/rflib) Feature Switches (hierarchical Global → Profile → Group → User scope) |                                                                                                                                                                                                         Low |
| `API_Outbound` + `API_Inbound` + `API_MockFactory` | Custom implementation                                                                                               |                                                                                                    High (no comparator ships an inbound-REST + idempotency-body-hash + outbound-circuit-breaker equivalent) |
| `UTIL_AsyncChain` + `ApiStep` + Chain Monitor      | [`apex-chainable`](https://github.com/rsoesemann/apex-chainable) + custom monitoring UI                             | High (`apex-chainable` ships the chain primitive but its security posture differs — reflective `Type.forName(...).newInstance()` via auto-launched flow on a platform event without allowlist or signature) |
| `MaskingRule__mdt` + `MaskingTarget__mdt`          | Custom — no direct replacement                                                                                      |          High ([`mask-sobject`](https://github.com/tprouvot/mask-sobject) covers SObject masking with security findings; `nebula-logger` covers pre-emit log masking but not arbitrary SObject DML masking) |

**Key insight:** The web-services framework (`API_Outbound`, `API_Inbound`, `API_MockFactory`), async chain monitoring (`UTIL_AsyncChain` + Chain Monitor LWC suite), and the
data-masking framework (`MaskingRule__mdt`) are the modules with no direct comparator replacement. Plan accordingly if exit is a consideration. Conversely, the trigger, query,
logging, DML, and feature-flag modules all have comparator alternatives.

---

## Post-Handover Support Model

KernDX source is publicly available under BSL 1.1 — every subscriber, whether self-installing from the public repository or receiving direct source delivery via a consulting
engagement, can fork and self-maintain. The honest question is: *when a deep infrastructure bug surfaces eighteen months later, what does the support conversation actually look
like?* Three engagement tiers are supported, and subscribers should pick one — and document the choice as an Architecture Decision Record — before they sign a consulting
agreement (or, for self-install subscribers, before the first P1 fires).

**Tier 1 — Self-Maintenance (default, no cost).** *Self-maintenance feasibility is based on internal scenario modelling, not benchmarked against an external subscriber take-over.*
The subscriber's internal team fixes framework bugs in-place using the artefacts available from the public repository (and additionally delivered at handover for
consulting-engagement subscribers): full source under BSL 1.1, 18 guides, 15 Fast Starts, 263 API reference pages, 100% per-file Apex test coverage as a regression safety net, and
the AI-context bundle (`AGENTS.md` + `docs/Code Conventions - Guide.md` + the AI Agent Instructions framework reference — approximately 20K tokens in total) documenting
conventions, patterns, and architectural rationale. A developer new to the framework can diagnose a deep infrastructure bug with Claude Code, Cursor, Cline, or Agentforce Vibes
once those context files are loaded. Because every module is scoped to a single prefix (`TRG_*`, `QRY_*`, `DML_*`, `LOG_*`, `UTIL_*`, `API_*`, `SEL_*`) and tested at 100%, most
deep bugs are localisable to a single class and fixable without cascading rewrites.

**Tier 2 — Reach-Back Engagement (time & materials).** For bugs where the subscriber prefers to engage the original author rather than invest internal cycles, KernDX's consultancy
can be retained on a time-and-materials basis for diagnosis, patch, and test. The patch is delivered as source against the subscriber's managed-package fork or source-deployed
variant; the subscriber retains ownership of the fix. No minimum retainer is required and no SLA is implied by this tier — it is genuinely on-demand.

**Tier 3 — Advisory Retainer (optional, quarterly).** For subscribers wanting proactive health checks, upgrade guidance, and roadmap alignment, a quarterly advisory retainer covers
framework review, scanner-rule updates, and pre-emptive architecture consultations. This is **not** a break-fix SLA — it is a longer-form knowledge-transfer relationship intended
to keep the subscriber's team oriented as the framework evolves.

**Emergency path for P1 production incidents.** Every `TriggerAction__mdt` and `TriggerSetting__mdt` record ships with a `BypassExecution__c` field, and every subscriber-reachable
code path gated by a feature flag can be disabled via `FeatureFlag__mdt`. For a P1 originating in a framework module, the first-line remediation is metadata-only: disable the
handler, feature-gate the path, or deactivate a masking rule — no code deploy required. Deeper diagnostic work happens after the shield is in place, not in front of the incident.

**Day-2 governance consoles.** Beyond break-fix, KernDX ships admin consoles for the recurring ownership tasks. The **Data Masking Advisor** reviews masking
coverage across your own custom objects and exports a regulated-field inventory (CSV or JSON) plus a deployable masking-config bundle — run it before an audit
and feed the export into your [Security Governance Evidence](Security%20-%20Guide.md#security-governance-evidence). The **Streaming Event Monitor** and **Chain
Monitor** surface platform-event, Change Data Capture, and async-chain traffic with usage metrics for day-2 observability, and the Health Check reports KernDX
configuration health (cache, masking posture, scheduled jobs).

**Deep infrastructure bugs — practical notes.**

- All framework code is gated at 100% per-file Apex + 95% statement/branch LWC coverage, so a regression failing the subscriber's CI is a diagnostic signal, not a speculation
  exercise.
- `LOG_Builder` emits structured events with W3C correlation IDs, so a framework-originated exception is traceable end-to-end across Apex, outbound HTTP, and LWC interaction.
- The repo's prefix-per-module directory structure localises bugs to a single module: diagnosing a trigger-dispatch bug does not require understanding the query builder.
- Managed-package subscribers can receive a patched version (the author cuts a new 2GP version); source-deployed subscribers cherry-pick the specific patch commit from the fork.
  Either path is supported.

Subscribers should record their chosen support tier as an Architecture Decision Record at adoption time — choosing in advance is cheaper than choosing at 02:00 on a Sunday.

---

## Performance & Governor Limits

**Key Principle:** KernDX does not increase governor limits; instead it reduces CPU and boilerplate by centralising common logic.

### Managed Package Reality

**Deployment Footprint — "All-or-Nothing" Is Not What It Sounds Like:**

A common concern is that installing KernDX deploys all 183 production classes even if you only need triggers. In a source-distributed model, this would be wasteful. In a managed
package, it is not — because managed packages behave differently:

| Concern                  | Managed Package (KernDX)                                                                                                                                                                                       | Source-Distributed (modular)                              |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| **Org code size limit**  | Exempt — does not count against 6 MB Apex limit                                                                                                                                                                | Counts against 6 MB limit                                 |
| **PMD / quality scans**  | Encapsulated — unused classes invisible to subscriber scans and reports                                                                                                                                        | All source visible in subscriber quality tooling          |
| **Test coverage**        | Self-contained — 166 Apex test classes (≈3,443 `@IsTest` methods) plus the LWC Jest suite run independently, gated at 100% per-file Apex + 95% statement/branch LWC, do not affect subscriber coverage metrics | Library coverage mixes with subscriber coverage           |
| **Governor limits**      | Unused classes consume zero CPU, SOQL, DML, or heap — code that isn't called is inert                                                                                                                          | Same — unused library code is inert                       |
| **Learning requirement** | Use only what you need — `TRG_Dispatcher` works without knowing `API_Outbound` exists                                                                                                                          | Same — install `taf` without knowing `apex-fluently-soql` |

**What this means:** If you only need triggers, installing KernDX and using just `TRG_Dispatcher` + `TRG_Base` is functionally comparable to installing `taf`. The other classes sit
inert. The real costs of full package deployment are the namespace prefix on references and a single (larger) upgrade cycle — not deployed code footprint.

**Security & Compliance Posture:**

- **Internal code scanning:** The package runs 36 scanner rules (PMD + Node + ESLint) on every build, plus Salesforce Code Analyzer; current builds pass with zero critical
  findings. See the [Code Scanning Guide](Code%20Scanning%20-%20Guide.md) for the ruleset contents.
- **Security posture and code quality:** Internal code-quality scans show 0 real-issue findings under the standard ruleset; security-category suppressions all carry
  compensating-control rationale. Security posture: FLS/CRUD enforced by default on both read and write paths, data masking framework default-on at the kill-switch level, session
  encryption shipped, every bypass writes a structured audit event, and the repository ships a top-level `SECURITY.md` reporting channel. One nuance remains:
  per-SObject masking is opt-in for custom objects — the Data Masking Advisor surfaces the custom objects that need it. This is a discoverability nuance, not a
  runtime enforcement gap.
- **License:** BSL 1.1 today, Apache 2.0 after the 4-year change date. No third-party dependencies beyond the Salesforce platform.
- **Production usage:** Deployed on internal delivery engagements. KernDX is NOT AppExchange-listed and has NOT been through AppExchange security review (see note below).

**Important Note:** KernDX is a 2GP managed package that has NOT been through AppExchange security review. Only AppExchange-certified packages receive separate per-transaction
governor limits.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GOVERNOR LIMITS: WHAT'S SHARED vs EXEMPT                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ORG-LEVEL LIMITS (Package code is EXEMPT)                                 │
│   ┌─────────────────────────────────────────────────────────────┐           │
│   │  6 MB Apex Code Size Limit                                  │           │
│   │  ┌───────────────────────────────┐ ┌─────────────────────┐  │           │
│   │  │   Your Custom Code            │ │  Package Code       │  │           │
│   │  │   (counts against limit)      │ │  (DOES NOT COUNT)   │  │           │
│   │  └───────────────────────────────┘ └─────────────────────┘  │           │
│   └─────────────────────────────────────────────────────────────┘           │
│                                                                             │
│   PER-TRANSACTION LIMITS (Package code SHARES these)                        │
│   ┌─────────────────────────────────────────────────────────────┐           │
│   │                    Transaction Pool                         │           │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │           │
│   │  │  SOQL    │ │   DML    │ │   CPU    │ │   Heap   │       │           │
│   │  │  (100)   │ │  (150)   │ │ (10sec)  │ │  (6MB)   │       │           │
│   │  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │           │
│   │                                                             │           │
│   │  Your Code + Package Code = Shared consumption              │           │
│   └─────────────────────────────────────────────────────────────┘           │
│                                                                             │
│   KEY: Package code only consumes limits when YOUR code calls it.           │
│        Unused utilities = zero overhead.                                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Framework Overhead

**CPU Overhead:** Any framework that wraps trigger dispatch, query execution, and DML in structured logging and metadata-driven configuration adds CPU cost compared to hand-written
Apex. KernDX is no exception:

| Concern                | Overhead                                       | Notes                                                 |
|------------------------|------------------------------------------------|-------------------------------------------------------|
| **Trigger dispatch**   | ~1 SOQL per trigger invocation                 | Cached after first call in transaction                |
| **Query builder**      | ~1ms SOQL string assembly                      | Optional performance logging adds negligible cost     |
| **Structured logging** | Platform event publishing per log emission     | ERROR logs bypass buffer for immediate visibility     |
| **DML builder**        | Topological sort for multi-object transactions | Negligible for typical use; benchmark at 10K+ records |
| **Managed package**    | Pre-compiled code; often marginally faster     | Profile CPU in hot paths if concerned                 |
| **Namespace prefix**   | Zero runtime cost                              | IDE auto-complete handles verbosity                   |

**Recommendation:** For high-volume triggers (10K+ records), benchmark framework-managed execution against direct Apex. Overhead is typically 5-15ms per trigger invocation for
dispatch + logging in synthetic load; lower in typical production patterns. Negligible for most transactions, but measurable at scale.

> **Key Insight:** KernDX does not consume CPU, SOQL, or DML unless your code explicitly calls it. The framework sits idle in the org until invoked — there is no background
> processing or automatic resource consumption.

**Benchmarking Guidance:**

If you need to validate framework overhead for a specific use case:

```apex
// Benchmark approach: Compare framework-managed vs direct execution
@IsTest
private static void benchmarkTriggerDispatch()
{
    Integer iterations = 1000;

    // Measure framework-managed execution
    Long startFramework = System.currentTimeMillis();
    for(Integer i = 0; i < iterations; i++)
    {
        // Insert records through trigger framework
        TST_Builder.of(Foobar__c.SObjectType).build();
    }
    Long frameworkMs = System.currentTimeMillis() - startFramework;

    // Compare: frameworkMs / iterations = average ms per trigger invocation
    // Typical result: 5-15ms overhead per invocation
}
```

**When overhead matters:** Data loader operations (10K+ records), real-time integrations with sub-second SLA requirements, scheduled jobs processing millions of records. For
typical user-facing CRUD operations (1-200 records), framework overhead is imperceptible.

### Governor Limit Awareness

| Framework Component | Limit Consideration                                                                                                       |
|---------------------|---------------------------------------------------------------------------------------------------------------------------|
| `QRY_Builder`       | Bind variable parameterisation prevents SOQL injection. `.withCache()` reduces query count.                               |
| `LOG_Builder`       | Platform event publishing subject to delivery allocation (50K/24hr base, shared with CDC). Buffering reduces consumption. |
| `API_Outbound`      | Callout limits (100/transaction, 120s timeout). Circuit breaker prevents wasted callouts to failing services.             |
| `TRG_Dispatcher`    | One metadata query per transaction. Handlers share governor limits with trigger context.                                  |

### Testing Philosophy Comparison

| Aspect                   | `fflib`                      | KernDX                                                    |
|--------------------------|------------------------------|-----------------------------------------------------------|
| **Default Approach**     | Unit isolation (mocking)     | Platform integration (real database)                      |
| **Query Mocking**        | Via dependency injection     | Built-in (`QRY_Builder.setMock()`, `TST_Mock.register()`) |
| **Mock Record Creation** | Manual or custom factory     | `TST_Builder.withoutInsertion(true)` generates mock IDs   |
| **Test Speed**           | Fast (~1-5 min deployments)  | Flexible (platform tests or mocked queries)               |
| **What Tests Catch**     | Business logic correctness   | Business logic + validation + flows + sharing             |
| **Audit Compliance**     | High (proves unit isolation) | Moderate to High (supports both approaches)               |

**The Trade-off:**

- **`fflib`:** Fast feedback, audit-compliant isolation, may miss platform config issues
- **KernDX:** Choose your approach — platform tests for full coverage, or query mocking for speed

**Recommended Balance:** Platform integration tests (80%) for full coverage, query mocking (20%) for complex business logic or when deployment speed is critical. **Scaling note:**
As the subscriber's test suite grows large enough that `RunLocalTests` exceeds the team's deployment SLA, the ratio should shift toward mocked tests (`TST_Mock`,
`QRY_Builder.setMock()`) to prevent CI/CD deployment windows from compounding.

**Why Coverage Type Matters:**

- **Unit tests (`fflib`)** validate business logic in isolation but may miss configuration issues that only appear when code interacts with the Salesforce platform
- **Integration tests (KernDX)** catch validation rule conflicts, flow trigger order issues, and sharing rule misconfigurations — common sources of production incidents
- **Metadata Safety:** `fflib` mocks fail to detect breaking changes in Validation Rules, Flow triggers, and Process Builders. KernDX accepts slower execution (minutes vs seconds)
  to ensure code works with the org's active configuration

---
