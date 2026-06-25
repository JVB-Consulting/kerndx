---
navOrder: 32
---

# Strategic Guide — Operations

> How an installed KernDX package behaves once it is live: how it ships and updates, how to leave it if you ever need to, who fixes a bug eighteen months from now,
> and how it performs against Salesforce's runtime limits.

Part of the [KernDX Strategic Guide](Strategic%20Guide%20-%20Overview.md).
See
also: [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) | [Adoption](Strategic%20Guide%20-%20Adoption.md) | [Risks](Strategic%20Guide%20-%20Risks.md) | [Glossary](Strategic%20Guide%20-%20Glossary.md) | [Personas](Strategic%20Guide%20-%20Personas.md)

> **Primary reader:** the platform engineer or operations lead running the installed package. If you care about deployment footprint, how often you upgrade, how hard it is to leave,
> who supports it, and how fast it runs, this guide is for you. For the adoption *decision*, see [Adoption](Strategic%20Guide%20-%20Adoption.md). For risk classification and
> architecture-board questions, see [Risks](Strategic%20Guide%20-%20Risks.md).

---

**In short:** This guide covers what life looks like after you install KernDX, a pre-built foundation layer for Salesforce orgs. It answers four practical questions: how the
package is delivered and kept up to date, how you would unwind it if your org's direction changed, who fixes a deep bug long after handover, and what the framework costs you in
Salesforce's runtime limits. Read it when you are weighing the long-term ownership and operating cost of adopting KernDX, not just its features. Architects and operations leads
will get the most from it, but delivery managers and executives can read the support-model and exit sections for the business picture without touching code.

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

How you get a framework into your org shapes how you live with it afterwards: how it updates, whether its code shows up in your scans, and whether it eats into your org's code
limit. There are two broad models. You can pull source code from GitHub and deploy it yourself, the way most open-source Apex libraries (such as `fflib` or Apex Fluently) ship. Or
you can install a managed package, which is the model KernDX uses. The table below compares the two so you can see the day-to-day consequences of each.

| Aspect                   | Source-Distributed (`fflib`, Apex Fluently)                                                                                                                                                                                                                                                                                                                                                                              | Managed Package (KernDX)                                                                                                                                                                                                                                                                                                                              |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Distribution**         | Open-source, install from GitHub or source deploy                                                                                                                                                                                                                                                                                                                                                                        | Managed package (2GP): 1 install URL                                                                                                                                                                                                                                                                                                                 |
| **Namespace**            | None (or your org's namespace)                                                                                                                                                                                                                                                                                                                                                                                           | Package namespace (or client-specific if repackaged)                                                                                                                                                                                                                                                                                                  |
| **Updates**              | Pull from GitHub per library; manage compatibility across 5-8 libraries                                                                                                                                                                                                                                                                                                                                                  | Push upgrades via single package version                                                                                                                                                                                                                                                                                                              |
| **Customisation**        | Full source access, modify freely                                                                                                                                                                                                                                                                                                                                                                                        | `global` API only (unless deployed as unlocked)                                                                                                                                                                                                                                                                                                       |
| **Isolation**            | No namespace isolation: the source lives directly in your org                                                                                                                                                                                                                                                                                                                                                                  | Namespace isolation prevents conflicts                                                                                                                                                                                                                                                                                                                |
| **Org code limit**       | Counts against 6 MB Apex code limit                                                                                                                                                                                                                                                                                                                                                                                      | Exempt from 6 MB limit                                                                                                                                                                                                                                                                                                                                |
| **Code quality in org**  | Library source becomes part of your own code analysis (PMD, ApexDoc)                                                                                                                                                                                                                                                                                                                                                 | Encapsulated: you never see the internal implementation                                                                                                                                                                                                                                                                                          |
| **CI/CD test execution** | The library's tests become part of your test surface. Your day-to-day CI can be scoped to just the relevant tests, but the gates Salesforce enforces cannot: production deploys run every test in your namespace, and so do full-suite coverage checks. The result is that production deployments take materially longer, and you have less headroom against platform test-execution limits (for example, the 120-minute synchronous-test ceiling). | The package's tests run only during package version validation on the publisher's Dev Hub, so your CI/CD is unaffected at every gate. For KernDX specifically, the entire test suite (166 Apex test classes, ≈3,443 `@IsTest` methods, plus the LWC Jest suite) stays inside the package boundary, gated at 100% per-file Apex and 95% statement and branch LWC. |
| **DevOps velocity**      | Deploy thousands of individual source files across multiple libraries                                                                                                                                                                                                                                                                                                                                                    | Promote a single version number through DevOps pipelines                                                                                                                                                                                                                                                                                              |
| **AI context**           | 5-8 separate README files per library                                                                                                                                                                                                                                                                                                                                                                                    | 1 set of conventions (`AGENTS.md` + `docs/Code Conventions - Guide.md`) covering all modules                                                                                                                                                                                                                                                          |

### Package Lifecycle & Governance

You decide when to upgrade, never the framework. KernDX is meant to sit underneath your org as a **stable foundation** (the way an operating system sits under your applications):
updates are deliberate, not automatic, and nothing is ever forced on you. The benefit is that a new framework version never lands in production on someone else's schedule; you
review the release notes, test in a sandbox, and promote it when you are ready. The table below shows how each part of that lifecycle works.

| Concern                      | Approach                                                                               |
|------------------------------|----------------------------------------------------------------------------------------|
| **Version locking**          | 2GP version locking in `package.xml` during stabilisation                              |
| **Breaking changes**         | Semantic versioning (major.minor.patch); backward compatibility prioritised            |
| **Upgrade cadence**          | Quarterly maintenance window: review release notes, test in sandbox, promote           |
| **Customising it in your org** | A `ClassTypeResolver__mdt` record tells the framework which of your Apex classes to use (how it finds the classes in your namespace); you extend a selector class to add your own fields |

### Exit Strategy: $0 License Cost

A fair question before you adopt any framework is: what does it cost to leave, and who controls the code if the relationship ends? With KernDX the answer is that you own what you
deploy, and there are no licensing fees under BSL 1.1. The source is available, you can change it, and you can deploy it yourself. You can self-install from the public repository under
the BSL 1.1 license, or receive the source directly through a consulting engagement. After a four-year change date, the source automatically switches to the Apache 2.0 license, one of
the most permissive open-source licenses there is.

You have **three ways to take ownership of the framework**, from doing nothing to running it entirely under your own name:

1. **Continue using the managed package** (simplest)
    - The framework maintainer keeps shipping updates
    - You receive push upgrades
    - Zero additional effort on your side

2. **Deploy as unlocked package or direct source** (moderate effort)
    - Get the source from the public repository, or have it delivered directly if you are on a consulting engagement
    - Deploy without a namespace prefix, which removes the package namespace entirely
    - Full freedom to customise under the BSL 1.1 license
    - Effort: 2-4 hours

3. **Repackage under your own namespace** (source delivered as `Unmanaged.zip`; you own the metadata)
    - You create a namespace (for example, `MyOrgNS`)
    - You rebuild the package in your own Dev Hub
    - Find/replace scripts handle most of the work: Apex classes, LWC imports, and metadata records are rewritten for you
    - **Available to everyone:** the complete source code from the public repository, the repo-root `AGENTS.md` pointer, the `docs/Code Conventions - Guide.md` conventions file,
      and per-module reference documentation, all with step-by-step repackaging instructions. Among the comparable Apex frameworks surveyed, KernDX is one of the few
      that ships a documented, complete repackaging workflow: most modular open-source alternatives put their source on GitHub but provide no end-to-end recipe for transferring
      namespace ownership.
    - Effort: 4-8 hours (following the guide)

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

Moving the source code out is the easy part: it is mostly find/replace on namespace references. The harder part is the configuration you build up over time. KernDX is driven by
custom metadata records (the trigger settings, API configurations, feature flags, and so on that you create as you adopt it), and that configuration is the real investment to carry
across. The table below shows what you would need to migrate, roughly how much of it a heavily-adopted org tends to have, and how much effort each type takes.

| Metadata Type                                      | What Must Migrate                                                                                   | Typical Volume                                                                                                                      | Effort         |
|----------------------------------------------------|-----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|----------------|
| `TriggerSetting__mdt` + `TriggerAction__mdt`       | Every configured trigger action and ordering                                                        | 20-100 records                                                                                                                      | Medium         |
| `FeatureFlag__mdt` + `FeatureFlagStrategy__mdt`    | All feature flag definitions                                                                        | 5-30 records                                                                                                                        | Low            |
| `ApiSetting__mdt` + `ApiCredential__mdt`           | Every outbound API configuration                                                                    | 5-20 records                                                                                                                        | High           |
| `LogSetting__c`                                    | Logging configuration (per-user / per-profile thresholds)                                           | 5-15 records                                                                                                                        | Low            |
| `MaskingRule__mdt` + `MaskingTarget__mdt`          | Data masking rules and field wirings (any SObject text field, whether standard, custom, or platform event) | 3 active rules + 12 default targets shipped; add one `MaskingTarget__mdt` per org-specific field or wildcard per org-specific object | Low per target |
| `ValidationRule__mdt` + `ValidationRuleGroup__mdt` | In-Apex validation rules                                                                            | 10-50 records                                                                                                                       | Medium         |

**Assessment.** *This is a directional estimate based on internal scenario modelling. It has not been benchmarked against a real-world exit.* How long the migration takes depends
heavily on how you run it. Picture a team that has adopted KernDX deeply, across 20+ objects, with the full API, logging, and validation configuration in place.

If that team uses modern AI coding tools (such as Claude Code, Cursor, or Agentforce Vibes) and points them at the framework-context bundle (`AGENTS.md`,
`docs/Code Conventions - Guide.md`, and [AI Agent Instructions](AI%20Agent%20Instructions.md), about 20K tokens, all available from the public repository and also delivered at
handover for consulting-engagement orgs), most of the work runs inside the AI session. The scripted find/replace, the re-authoring of custom metadata, the deploy-and-iterate loops,
and the automated release-testing checks all happen there, with human review and sign-off as the main thing that paces the work. The directional wall-clock on this path is
**~1-2 days**.

If that same team does the work entirely by hand, reading the documentation, re-authoring custom metadata manually, and working through deploy errors one at a time, they should
expect the conventional **1-2 week** range.

The takeaway: the source code itself is portable, so the configuration is where the real cost sits, and AI tooling shrinks that cost substantially rather than removing it.
Factor in your own team's tooling when you weigh how reversible adoption is.

> **Key Principle:** "KernDX is an Accelerator you can own, not a Product you rent."

### Exit and Reversibility Analysis

Reversibility is about how cleanly you could undo a decision later. Some parts of KernDX come out easily; others need a coordinated migration because several pieces depend on each
other. The table below breaks the question down by dimension so you can see exactly where exit is simple and where it takes planning.

| Dimension                           | Assessment                                                                                     | Detail                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|-------------------------------------|------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Can it be removed incrementally?    | Medium                                                                                         | Utilities (`UTIL_*`, `LOG_Builder`) can be replaced one at a time. The trigger framework (`TRG_*`) and web services (`API_*`) need a coordinated migration, because all the handlers for an object have to move together.                                                                                                                                                                                                                                                             |
| Can services revert to native Apex? | Low complexity                                                                                 | KernDX patterns use standard Apex (selectors, builders, and small data-carrier classes that hold just the fields you move in and out). Reverting to native Apex requires removing framework method calls but not a change of approach.                                                                                                                                                                                                                                                                                                           |
| Estimated refactor cost             | ~1-2 days agent-executed, or 1-2 weeks conventional (deeply adopted orgs); see disclaimer above | Moving the source code is mechanical work (scripted find/replace plus interface changes). The metadata migration (`TriggerAction__mdt`, `ApiSetting__mdt`, `FeatureFlag__mdt`) is what dominates the effort when a team does it by hand. With AI tooling pointed at the context bundle, that metadata transform drops to hours, and the time floor is then set by human review, sign-off, and UAT.                                                                 |
| Structural dependency created       | Variable                                                                                       | **High** for triggers (`TRG_Dispatcher` + `TriggerAction__mdt` + `TriggerSetting__mdt`) and web services (`API_Outbound` + `ApiCall__c` + `ApiSetting__mdt`). **Low** for utilities (`UTIL_String`, `UTIL_Cache`) and test builders (`TST_Builder`).                                                                                                                                                                                                                 |
| Data dependency                     | Low to Medium                                                                                  | `LogEntry__c` records, `ApiCall__c` queue items, and `FeatureFlag__mdt` records are framework-specific. Historical data would need archival or migration.                                                                                                                                                                                                                                                                                                            |
| **Overall removal complexity**      | **Medium**                                                                                     | The utility and query layers exit cleanly. The trigger and web service layers need a coordinated migration because of their metadata dependencies. Exit is feasible. For a team using modern AI coding tools pointed at the framework's context bundle, it is directionally absorbable inside a single sprint (~1-2 days wall-clock, a directional estimate per the disclaimer above). A team without those tools still faces the 1-2 week by-hand effort. |

See [Migration Checklists](#migration-checklists) below for step-by-step recipes (KernDX → modular stack, fflib → KernDX, no-framework → KernDX).

### Migration Checklists

#### Migration Cost Calculation (Worked Example)

> **Illustrative formula: the inputs are not measured from a specific deployment.** The numbers below are example values to show the structure of the formula. Refactor hours per
> class, hourly cost, and onboarding savings come from your own team's historical delivery data, not from this framework's documentation. The formula structure is portable; you
> supply the inputs.

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

Adjust the hours-per-class figure to match how deeply you use `fflib`. If you only use its selectors, budget roughly 4 hours per class; if you use the full Domain-Driven Design
stack (Domain plus Service plus Unit of Work, where you register related records and save them together so they all commit or all roll back), budget roughly 16 hours per class.
Every multiplier in the worked example above (8 hours per class to refactor, $150/hr developer cost, 20 hours saved per new hire, ~$20K in reduced annual maintenance) is a
placeholder. Replace each one with your own team's historical figures before you treat the break-even result as a real input to a decision.

#### Migrating from fflib to KernDX

> **Before you migrate: check the Domain / Service / Application layer.** [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) ships a Domain layer and a Service /
> Application factory. KernDX ships neither. So if your code relies on `fflib_SObjectDomain` lifecycle hooks (`onApplyDefaults`, `onValidate`, `onBeforeInsert`), or on the
> `fflib_Application` factory that binds `SObjectType → Selector / Domain / UnitOfWork`, you are moving away from capabilities KernDX does not have. You have two options: rewrite that
> domain lifecycle logic as trigger actions, or keep `fflib` installed alongside KernDX. The two can coexist indefinitely.

| Step | Action                                                                                                                                                                                                                                                                  | Validation                                                          |
|------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| 1    | Install KernDX managed package in sandbox                                                                                                                                                                                                                               | All `@IsTest` methods pass                                          |
| 2    | Map `fflib` patterns to KernDX equivalents                                                                                                                                                                                                                              | Document mapping, including Domain / Service / Application gaps     |
| 3    | Create KernDX selectors for existing domain objects                                                                                                                                                                                                                     | `SEL_*` classes with `getFields()`                                  |
| 4    | Migrate the simplest selector first (fewest custom methods)                                                                                                                                                                                                             | All existing tests pass                                             |
| 5    | Replace `fflib_QueryFactory` calls with the `query` property. By default, `QRY_Builder` reads with field-level security enforced (FLS = field-level security, so a user can only read fields they have permission to see); read paths that need to skip those checks opt in via `SEL_Base.systemModeRequired()`                                                       | Verify query results match and FLS behaviour is preserved           |
| 6    | Replace `fflib_SObjectUnitOfWork` with `DML_Builder`. **Gap:** KernDX has no `registerEmail()` or `IDoWork` equivalent, so you rewrite email registration and any arbitrary work as separate steps                                                                                | Verify DML outcomes match                                           |
| 7    | Rewrite `fflib_SObjectDomain` logic as `TRG_Base` trigger actions. **This is a change of approach, not a rename.** Each domain lifecycle hook (`onApplyDefaults`, `onValidate`) becomes its own `IF_Trigger.*` action class. The Domain class itself has no direct equivalent | Configure `TriggerAction__mdt`; verify lifecycle ordering preserved |
| 8    | Replace `fflib_ApexMocks` with `TST_Mock` (data-driven). **Gap:** KernDX does not ship Mockito-style behaviour verification (argument captors, in-order verification), so you rewrite behaviour-verification tests as data-outcome tests                                       | All tests pass with new mocks                                       |
| 9    | Add `LOG_Builder` calls to replace `System.debug()`                                                                                                                                                                                                                     | Verify log entries in `LogEntry__c`                                 |
| 10   | Remove `fflib` dependencies from `package.xml` **only if** you have replaced every Domain / Service / Application pattern. If any `fflib` Domain / Service classes remain, keep `fflib` installed; the two frameworks can coexist indefinitely                         | Full `RunLocalTests` pass                                           |

**Estimated timeline:** 2-4 weeks per domain object (selector plus triggers plus tests). For a 10-object org, expect 20-40 weeks for a full migration. We recommend migrating
incrementally, since both frameworks can coexist indefinitely. If you use `fflib_Application` for registered factory bindings, budget extra time to rewrite that dependency
injection: KernDX does not ship an Application-layer equivalent.

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

**Estimated timeline:** 1-2 weeks for the first object (that includes the learning curve). 2-5 days per object after that. Most teams become self-sufficient after 3-4 objects.

#### Migrating from KernDX to a Modular Stack

If KernDX stops being the right fit, you can replace it one module at a time rather than all at once. The table below pairs each KernDX module with the specialist library you would
swap it for, and is honest about effort: some swaps are low-effort because a close equivalent exists, while a few modules have no direct replacement and are flagged as High. Where a
specialist library goes deeper on its one area than KernDX does, the table says so.

<details><summary>Module-by-module swap table (replacement library, effort, and where a specialist goes deeper)</summary>

| KernDX Component                                   | Modular Replacement                                                                                                 |                                                                                                                                                                                            Migration Effort |
|----------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| `TRG_Dispatcher` + `TRG_Base`                      | [`taf`](https://github.com/mitchspano/apex-trigger-actions-framework) (Apache 2.0; declarative trigger framework)   |    Medium (metadata rename plus an interface change). Both react to record-change events (Change Data Capture) and run follow-up work after the transaction commits (finalizers). KernDX additionally records an audit entry every time a trigger is switched off, which `taf` does not do on its programmatic surface. |
| `QRY_Builder` + `SEL_Base`                         | [`apex-fluently-soql`](https://github.com/beyond-the-cloud-dev/soql-lib) (query-builder family)                     |                                                                                                                                  Medium (some API differences). Like KernDX, `apex-fluently-soql` defaults to reads that respect the current user's permissions and sharing (user-mode). |
| `LOG_Builder`                                      | [`nebula-logger`](https://github.com/jongpie/NebulaLogger) (ships historical log browser + retention engine)        |                                                                                                                                Low (similar platform-event pattern). `nebula-logger` goes further here: it adds a log browser and Big Object archival. |
| `DML_Builder`                                      | [`apex-fluently-dml`](https://github.com/beyond-the-cloud-dev/dml-lib) (DML wrapper)                                |                                                                                                                                                                                           Low (similar API) |
| `UTIL_HttpClient`                                  | Custom or [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library) `HttpClient`                      |                                                                                                                                                    Medium (`apex-libra` is independent of Beyond The Cloud) |
| `TST_Builder` + `TST_Mock`                         | ApexTestKit, [`apex-fluently-test`](https://github.com/beyond-the-cloud-dev/test-lib) (Beta), or custom             |                                                                                                                           Medium. Note that `apex-fluently-test` carries Beta status, whereas ApexTestKit ships a stable API. |
| `TST_Factory`                                      | Custom (no direct replacement)                                                                                      |                                                                                                                                    High (the metadata-factory pattern is specific to KernDX's integrated stack) |
| `UTIL_FeatureFlag`                                 | [`rflib`](https://github.com/j-fischer/rflib) Feature Switches (hierarchical Global → Profile → Group → User scope) |                                                                                                                                                                                                         Low |
| `API_Outbound` + `API_Inbound` + `API_MockFactory` | Custom implementation                                                                                               |                                                                                                    High. None of the libraries we compared ships an equivalent that combines inbound REST, idempotency (a repeated identical request returns the first result instead of re-running), and an outbound circuit breaker (after repeated failures it stops calling a failing service for a cool-off, then resumes). |
| `UTIL_AsyncChain` + `ApiStep` + Chain Monitor      | [`apex-chainable`](https://github.com/rsoesemann/apex-chainable) + custom monitoring UI                             | High. `apex-chainable` ships the chain primitive, but it is less locked down: it looks up and runs your Apex classes by name (`Type.forName(...).newInstance()`) from an auto-launched flow triggered by a platform event, with no approved-class list or signature check. |
| `MaskingRule__mdt` + `MaskingTarget__mdt`          | Custom (no direct replacement)                                                                                      |          High. [`mask-sobject`](https://github.com/tprouvot/mask-sobject) covers SObject masking but has security findings. `nebula-logger` masks log entries before they are emitted, but not arbitrary SObject DML. |

</details>

**Key insight:** Three modules have no direct replacement among the libraries we compared, so plan for them carefully if exit is on your mind. They are the web-services framework
(`API_Outbound`, `API_Inbound`, `API_MockFactory`), the async chain monitoring (`UTIL_AsyncChain` plus the Chain Monitor LWC suite), and the data-masking framework
(`MaskingRule__mdt`). The other modules are easier to leave: the trigger, query, logging, DML, and feature-flag modules all have well-supported alternatives.

---

## Post-Handover Support Model

The KernDX source is publicly available under the BSL 1.1 license. Whether you self-install from the public repository or receive the source directly through a consulting
engagement, you can fork it and maintain it yourself. The honest question to ask before adopting is this: when a deep infrastructure bug surfaces eighteen months from now, what does
the support conversation actually look like? There are three engagement tiers, and you should choose one (and record the choice as an Architecture Decision Record) before you sign a
consulting agreement, or, if you self-installed, before your first P1 production incident fires.

**Tier 1: Self-Maintenance (default, no cost).** *How feasible self-maintenance is comes from internal scenario modelling; it has not been benchmarked against a real external
take-over.* Here, your own team fixes framework bugs in place, using the materials in the public repository (and also delivered at handover for consulting-engagement orgs). Those
materials are the full source under the BSL 1.1 license, 18 guides, 15 Fast Starts, 263 API reference pages, 100% per-file Apex test coverage that acts as a safety net against
regressions, and an AI-context bundle (`AGENTS.md`, `docs/Code Conventions - Guide.md`, and the AI Agent Instructions reference, about 20K tokens in total) that documents the
conventions, patterns, and design rationale. Once those context files are loaded, a developer new to the framework can diagnose a deep infrastructure bug using an AI coding tool
such as Claude Code, Cursor, Cline, or Agentforce Vibes. Two things make this realistic: every module lives behind a single name prefix (`TRG_*`, `QRY_*`, `DML_*`, `LOG_*`,
`UTIL_*`, `API_*`, `SEL_*`), and every module is tested at 100%. So most deep bugs can be traced to one class and fixed without rewriting the surrounding code.

**Tier 2: Reach-Back Engagement (time & materials).** When you would rather have the original author handle a bug than spend your own team's time on it, you can retain the KernDX
consultancy on a time-and-materials basis to diagnose, patch, and test it. The patch is delivered as source against your managed-package fork or source-deployed variant, and you
keep ownership of the fix. This tier needs no minimum retainer and implies no service-level agreement: it is genuinely on-demand.

**Tier 3: Advisory Retainer (optional, quarterly).** If you want proactive health checks, upgrade guidance, and roadmap alignment, a quarterly advisory retainer covers framework
review, scanner-rule updates, and architecture consultations done ahead of need. This is **not** a break-fix service-level agreement. It is a longer-running knowledge-transfer
relationship, meant to keep your team oriented as the framework evolves.

**Emergency path for P1 production incidents.** When the worst happens, you can stop a misbehaving framework module without deploying any code. Every `TriggerAction__mdt` and
`TriggerSetting__mdt` record has a `BypassExecution__c` field, and any code path behind a feature flag can be switched off through `FeatureFlag__mdt`. So for a P1 incident that
starts inside a framework module, the first response is metadata-only: disable the handler, switch off the path with its feature flag, or deactivate a masking rule. The deeper
diagnostic work then happens after the bleeding has stopped, not while the incident is still live.

**Day-2 governance consoles.** Running a framework is more than fixing bugs; it is the recurring ownership work of staying audit-ready and watching what production is actually
doing. KernDX ships admin consoles for exactly that. The **Data Masking Advisor** checks how well your own custom objects are covered by masking and exports a regulated-field
inventory (as CSV or JSON) plus a ready-to-deploy masking-config bundle. Run it before an audit and feed the export into your
[Security Governance Evidence](Security%20-%20Guide.md#security-governance-evidence). The **Streaming Event Monitor** and **Chain Monitor** show you platform-event, Change Data
Capture, and async-chain traffic with usage metrics for day-2 observability, so you can see what your code did in production rather than guess. The Health Check reports on KernDX
configuration health (cache, masking posture, and scheduled jobs).

**Deep infrastructure bugs: practical notes.**

- All framework code is gated at 100% per-file Apex coverage and 95% statement and branch LWC coverage. So when a regression fails your CI, it points you straight at the problem
  instead of leaving you guessing.
- `LOG_Builder` stamps each log with a correlation ID, a single tracking ID that follows one user action across triggers, queries, callouts, and jobs (in the standard W3C form). That
  means an exception from inside the framework is traceable end-to-end, across Apex, outbound HTTP, and what the user did in the Lightning component.
- Because every module lives in its own name-prefixed area of the codebase, a bug stays local to one module: you can diagnose a trigger-dispatch bug without understanding the query
  builder.
- If you run the managed package, you receive a patched version (the author cuts a new 2GP version). If you deployed the source, you cherry-pick the specific patch commit from
  the fork. Either path is supported.

Record your chosen support tier as an Architecture Decision Record when you adopt the framework. Deciding this in advance is far cheaper than deciding it at 02:00 on a Sunday.

---

## Performance & Governor Limits

A common worry is that a framework adds overhead and eats into Salesforce's strict per-transaction limits. Here is the short answer, with the detail in the sections below.

**Key Principle:** KernDX does not increase governor limits. Instead, it reduces CPU time and repetitive code by putting common logic in one place.

### Managed Package Reality

**Deployment Footprint: "All-or-Nothing" Is Not What It Sounds Like:**

A common concern is that installing KernDX deploys all 183 production classes even if all you need is triggers. If KernDX shipped as source code you deploy yourself, that would
indeed be wasteful. As a managed package it is not, because managed packages behave differently. The table below shows why the classes you do not use cost you nothing.

| Concern                  | Managed Package (KernDX)                                                                                                                                                                                       | Source-Distributed (modular)                              |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| **Org code size limit**  | Exempt: does not count against the 6 MB Apex limit                                                                                                                                                                | Counts against the 6 MB limit                                 |
| **PMD / quality scans**  | Encapsulated: classes you don't use are invisible to your own scans and reports                                                                                                                                        | All source is visible in your quality tooling          |
| **Test coverage**        | Self-contained: 166 Apex test classes (≈3,443 `@IsTest` methods) plus the LWC Jest suite run on their own, gated at 100% per-file Apex and 95% statement and branch LWC, and they do not affect your coverage metrics | Library coverage mixes with your coverage           |
| **Governor limits**      | Classes you don't use consume zero CPU, SOQL, DML, or heap: code that is never called is inert                                                                                                                          | Same: unused library code is inert                       |
| **Learning requirement** | Use only what you need: `TRG_Dispatcher` works without you knowing `API_Outbound` exists                                                                                                                          | Same: install `taf` without knowing `apex-fluently-soql` |

**What this means:** If all you need is triggers, installing KernDX and using just `TRG_Dispatcher` and `TRG_Base` works much like installing `taf`. The other classes simply sit
inert. The real costs of installing the full package are the namespace prefix on your references and one larger upgrade cycle, not the size of the deployed code.

**Security & Compliance Posture:**

- **Internal code scanning:** The package runs 36 scanner rules (PMD + Node + ESLint) on every build, plus Salesforce Code Analyzer; current builds pass with zero critical
  findings. See the [Code Scanning Guide](Code%20Scanning%20-%20Guide.md) for the ruleset contents.
- **Security posture and code quality:** Internal code-quality scans show 0 real-issue findings under the standard ruleset, and every security-category suppression carries a
  documented compensating-control rationale. On security posture: reads and writes both enforce the running user's permissions by default (FLS = field-level security, CRUD =
  object create/read/update/delete permissions); the data masking framework is on by default, with a single master off-switch you can flip in an incident; session encryption is
  shipped; every time a safety check is bypassed the framework writes a structured audit event; and the repository ships a top-level `SECURITY.md` reporting channel. One nuance
  remains: per-SObject masking is opt-in for custom objects, and the Data Masking Advisor surfaces the custom objects that need it. This is a matter of discoverability, not a gap
  in runtime enforcement.
- **License:** BSL 1.1 today, switching to Apache 2.0 after the 4-year change date. There are no third-party dependencies beyond the Salesforce platform itself.
- **Production usage:** Deployed on internal delivery engagements. KernDX is NOT AppExchange-listed and has NOT been through AppExchange security review (see the note below).

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

**CPU Overhead:** Be clear-eyed here. Any framework that wraps trigger dispatch, query execution, and DML with structured logging and configuration records adds some CPU cost
compared to hand-written Apex, and KernDX is no exception. The table below shows where that cost shows up and how large it is.

| Concern                | Overhead                                       | Notes                                                 |
|------------------------|------------------------------------------------|-------------------------------------------------------|
| **Trigger dispatch**   | ~1 SOQL per trigger invocation                 | Cached after first call in transaction                |
| **Query builder**      | ~1ms SOQL string assembly                      | Optional performance logging adds negligible cost     |
| **Structured logging** | Platform event publishing per log emission     | ERROR logs bypass buffer for immediate visibility     |
| **DML builder**        | Works out the right save order (parents before children) for multi-object transactions | Negligible for typical use; benchmark at 10K+ records |
| **Managed package**    | Pre-compiled code; often marginally faster     | Profile CPU in hot paths if concerned                 |
| **Namespace prefix**   | Zero runtime cost                              | IDE auto-complete handles verbosity                   |

**Recommendation:** For high-volume triggers (10K+ records), measure framework-managed execution against direct Apex for your own case. In synthetic load tests the overhead is
typically 5-15ms per trigger invocation for dispatch plus logging, and it is lower in typical production patterns. For most transactions it is negligible, but it becomes measurable
at scale.

> **Key Insight:** KernDX consumes no CPU, SOQL, or DML unless your code explicitly calls it. The framework sits idle in your org until something invokes it. There is no background
> processing and no automatic resource consumption.

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

**When overhead matters:** It matters for data-loader operations (10K+ records), real-time integrations with sub-second response targets, and scheduled jobs processing millions of
records. For everyday user-facing operations (creating, reading, updating, or deleting 1-200 records), the framework overhead is imperceptible.

### Governor Limit Awareness

Each framework component touches a different Salesforce limit, and several of them include features that actively help you stay under those limits. The table below lists what to
watch for, component by component.

| Framework Component | Limit Consideration                                                                                                       |
|---------------------|---------------------------------------------------------------------------------------------------------------------------|
| `QRY_Builder`       | Bind variable parameterisation prevents SOQL injection. `.withCache()` reduces query count.                               |
| `LOG_Builder`       | Platform event publishing subject to delivery allocation (50K/24hr base, shared with record-change events / Change Data Capture). Buffering reduces consumption. |
| `API_Outbound`      | Callout limits (100/transaction, 120s timeout). Circuit breaker prevents wasted callouts to failing services.             |
| `TRG_Dispatcher`    | One metadata query per transaction. Handlers share governor limits with trigger context.                                  |

### Testing Philosophy Comparison

There are two schools of thought on how to test Salesforce code, and `fflib` and KernDX sit on different sides of it. `fflib` leans towards fast unit tests that isolate your logic
from the database. KernDX defaults to integration tests that run against the real platform, which are slower but catch a wider class of problems. Neither is simply better; they
trade speed for realism. The table compares them so you can pick the right mix for your team.

| Aspect                   | `fflib`                      | KernDX                                                    |
|--------------------------|------------------------------|-----------------------------------------------------------|
| **Default Approach**     | Unit isolation (mocking)     | Platform integration (real database)                      |
| **Query Mocking**        | Via dependency injection     | Built-in (`QRY_Builder.setMock()`, `TST_Mock.register()`) |
| **Mock Record Creation** | Manual or custom factory     | `TST_Builder.withoutInsertion(true)` generates mock IDs   |
| **Test Speed**           | Fast (~1-5 min deployments)  | Flexible (platform tests or mocked queries)               |
| **What Tests Catch**     | Business logic correctness   | Business logic + validation + flows + sharing             |
| **Audit Compliance**     | High (proves unit isolation) | Moderate to High (supports both approaches)               |

**The Trade-off:**

- **`fflib`:** Fast feedback and audit-compliant isolation, but may miss platform config issues
- **KernDX:** Choose your approach: platform tests for full coverage, or query mocking for speed

**Recommended Balance:** Use platform integration tests (around 80%) for full coverage, and query mocking (around 20%) for complex business logic or when deployment speed matters
most. **Scaling note:** Once your test suite grows large enough that `RunLocalTests` takes longer than your team's deployment target allows, shift the ratio towards mocked tests
(`TST_Mock`, `QRY_Builder.setMock()`) so your CI/CD deployment windows do not keep growing.

**Why Coverage Type Matters:**

- **Unit tests (`fflib`)** check your business logic in isolation. The trade-off is that they can miss configuration problems that only show up when your code actually runs against
  the Salesforce platform.
- **Integration tests (KernDX)** catch validation-rule conflicts, flow trigger-order issues, and sharing-rule misconfigurations. Those are common causes of production incidents.
- **Metadata Safety:** `fflib` mocks cannot detect breaking changes in Validation Rules, Flow triggers, and Process Builders. KernDX accepts slower execution (minutes rather than
  seconds) so that tests prove your code works with the org's live configuration.

---
