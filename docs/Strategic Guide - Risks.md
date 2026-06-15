# Strategic Guide — Risks

> Risk classification for architects, governance reviewers, and architecture review boards: technical / organisational / ecosystem risks, modular-stack risks, hard questions ARBs
> will ask, scenarios where KernDX is the wrong fit, adoption gate criteria, and pre / during / post-adoption risk-mitigation strategies.

Part of the [KernDX Strategic Guide](Strategic%20Guide%20-%20Overview.md).
See
also: [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) | [Adoption](Strategic%20Guide%20-%20Adoption.md) | [Operations](Strategic%20Guide%20-%20Operations.md) | [Glossary](Strategic%20Guide%20-%20Glossary.md) | [Personas](Strategic%20Guide%20-%20Personas.md)

> **Primary reader:** Architect, governance reviewer, or executive evaluating adoption downsides — the hard questions an architecture review board will ask. For decision support
> and the roll-out plan, see [Adoption](Strategic%20Guide%20-%20Adoption.md). For runtime operating-cost and exit mechanics, see [Operations](Strategic%20Guide%20-%20Operations.md).

---

<details><summary>Table of Contents</summary>

- [When NOT to Use KernDX](#when-not-to-use-kerndx)
- [When Modular Architectures Clearly Excel](#when-modular-architectures-clearly-excel)
- [Risks, Mitigations & Trade-offs](#risks-mitigations--trade-offs)
    - [Technical Risks](#technical-risks)
    - [Organisational Risks](#organisational-risks)
    - [Ecosystem Risks](#ecosystem-risks)
    - [Enterprise Risk Dimensions](#enterprise-risk-dimensions)
    - [Potential Drawbacks](#potential-drawbacks)
    - [Modular Stack Risks](#modular-stack-risks)
    - [Bus Factor Reframe — Institutional Knowledge Survival via Documentation Depth](#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth)
    - [Community Support: Signal vs Substance](#community-support-signal-vs-substance)
    - [Governance Model](#governance-model)
    - [Versioning & API Stability](#versioning--api-stability)
    - [Adoption Gate Criteria](#adoption-gate-criteria)
    - [Hard Questions Architecture Review Boards Will Ask](#hard-questions-architecture-review-boards-will-ask)
    - [Strategic Recommendations](#strategic-recommendations)

</details>

## When NOT to Use KernDX

| Scenario                                                                                                                   | Constraint                                                                                                    | Why KernDX Is a Poor Fit                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Recommended Alternative                                                                                                                                                          |
|----------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Single concern with a feature genuinely absent from KernDX (dedicated historical log browser, default-on pre-emit masking) | Feature-specific gaps in KernDX                                                                               | `nebula-logger` ships a dedicated log browser LWC and default-on pre-emit masking. On query-layer security both `apex-fluently-soql` and KernDX `QRY_Builder` default to `USER_MODE` — equivalent on substance. (`taf` and KernDX both register Change Data Capture trigger actions and run post-trigger finalizers.) For single-concern use where these features aren't needed, KernDX is viable — unused code is inert in a managed package                                                                                              | `taf` (triggers), `nebula-logger` (logging + log browser + default-on masking), `apex-fluently-soql` (queries, no namespace, hosted docs)                                        |
| Domain-Driven Design is required                                                                                           | Complex domain model with bounded contexts                                                                    | KernDX is service-oriented, not Domain-Driven                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `fflib` or `at4dx`                                                                                                                                                               |
| OSI-approved permissive licensing required on the immediate procurement window                                             | Architecture board or policy mandate accepts only MIT/Apache-2.0/BSD on every dependency at install time      | KernDX is BSL 1.1 (source-available, public repository, relicenses to Apache 2.0 after the four-year change date); functionally close to OSI for subscriber use, but not OSI-approved during the BSL window                                                                                                                                                                                                                                                                                                                                | `taf` (Apache 2.0) + `apex-fluently-soql` (MIT) + `nebula-logger` (MIT) — all OSI-approved permissive licenses, available today                                                  |
| Existing modular stack working well                                                                                        | Coherence is already managed; migration cost exceeds benefit                                                  | Disruption risk outweighs marginal improvement                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Continue current approach                                                                                                                                                        |
| Consulting project requiring framework familiarity at handover                                                             | Client must maintain code independently post-handover                                                         | If the client team already uses a specific modular library, hand off in that library so they continue with what they know — KernDX onboarding requires per-module learning of the framework's conventions                                                                                                                                                                                                                                                                                                                                  | `taf` + `apex-fluently-soql` (or whichever libraries the client team already uses)                                                                                               |
| Multiple independent delivery partners with no shared governance                                                           | No central architectural authority to enforce conventions                                                     | KernDX's value depends on consistent usage; ungoverned adoption results in partial framework use                                                                                                                                                                                                                                                                                                                                                                                                                                           | Modular OSS stack with per-SI adoption                                                                                                                                           |
| High team turnover (>40% annual)                                                                                           | Continuous developer churn                                                                                    | Per-module onboarding times are comparable across comparable Apex frameworks (see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison)); high turnover offsets KernDX's documentation-depth advantage by repeatedly resetting the ramp curve. Pick based on the team's existing framework experience and the libraries already in your hiring pipeline                                                                                                                                             | `taf` + `apex-fluently-soql` (if the team or its replacements already use them)                                                                                                  |
| Public ecosystem credibility is a hard requirement during the immediate procurement window                                 | Architecture board requires OSI-approved licensing AND multi-contributor community validation at install time | KernDX is BSL 1.1 (source-available, published in a public repository, relicenses to Apache 2.0 after the four-year change date), single maintainer at the snapshot date. most comparable Apex frameworks are also single-maintainer (only the `fflib` family carries distributed maintainership) — modular OSS alternatives address the OSI-licence and public-repository requirement, not necessarily the contributor-count one. See [Bus Factor Reframe](#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth) | `taf` + Apex Fluently + `nebula-logger` for OSI-licence + public-repo requirements at install time; only the `fflib` family if multi-contributor maintainership is also required |
| Regulatory audit requiring multi-vendor traceability                                                                       | Compliance requires demonstrable multi-vendor supply chain                                                    | Single-vendor BSL framework complicates audit narrative                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Open-source stack with public commit history                                                                                                                                     |

## When Modular Architectures Clearly Excel

The following scenarios represent contexts where modular open-source stacks are unambiguously the right architectural choice. **One framing caveat before the table:** "modular"
here refers primarily to the license model and source-ownership story — most of the popular modular libraries are themselves single-maintainer projects (most comparable Apex
frameworks are single-maintainer; only the [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common) family has distributed maintainership). The scenarios below are
real and load-bearing, but if multi-contributor maintainership is part of the requirement, scan
the [Bus Factor Reframe](#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth) before assuming "modular = community".

| Scenario                                                                     | Why Modular Fits                                                                                                                                                                                                                                                                                                                                                                        |
|------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Highly specialised internal Salesforce teams with deep platform expertise    | Team can curate libraries individually and maintain consistency through expertise rather than framework enforcement                                                                                                                                                                                                                                                                     |
| Organisations with long-term in-house ownership and stable engineering teams | Institutional knowledge persists; framework-imposed conventions are redundant when team culture enforces them                                                                                                                                                                                                                                                                           |
| Cost-sensitive environments avoiding any centralised dependency              | Zero vendor dependency; no managed package lifecycle to manage; issue trackers are publicly visible on GitHub                                                                                                                                                                                                                                                                           |
| Platform R&D orgs experimenting with architectural patterns                  | Modular adoption allows swapping individual libraries without rearchitecting; ideal for evaluating emerging tools                                                                                                                                                                                                                                                                       |
| Organisations requiring public governance for audit or compliance            | Public GitHub repos and open commit history satisfy audit requirements that private frameworks cannot. If the audit also demands multi-contributor maintainership, only the `fflib` family genuinely qualifies (per the [Bus Factor Reframe](#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth)); most other community libraries are also single-maintainer |

In these contexts, KernDX may introduce unnecessary abstraction and operational overhead. A modular stack is the better fit for these contexts. For a capability-by-capability
comparison of KernDX against each of these libraries — including where a specialised library is the better pick —
see [Choosing a Framework](Strategic%20Guide%20-%20Choosing%20a%20Framework.md).

---

## Risks, Mitigations & Trade-offs

This section documents known risks and trade-offs for both integrated and modular approaches.

### Technical Risks

| Risk                                                                                        | Likelihood | Impact     | Mitigation Feasibility | Net Exposure | Justification                                                                                                                                                                                                                                                                                                                                                                                                                 |
|---------------------------------------------------------------------------------------------|------------|------------|------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Package overhead in CPU-intensive operations                                                | Low        | Low        | High                   | Low          | Pre-compiled managed package; benchmark hot paths                                                                                                                                                                                                                                                                                                                                                                             |
| Dependency on Salesforce platform roadmap                                                   | Medium     | Medium     | High                   | Low          | Standard Apex only; no unsupported API usage                                                                                                                                                                                                                                                                                                                                                                                  |
| Managed package namespace constraints                                                       | Low        | Low        | High                   | Low          | Three exit paths including namespace removal                                                                                                                                                                                                                                                                                                                                                                                  |
| Metadata configuration sprawl                                                               | Medium     | Medium     | High                   | Low-Medium   | Document metadata inventory; migration effort is ~1-2 days agent-executed against the AI-context bundle (or 1-2 weeks conventional human-only) for deeply adopted orgs. Mitigation Feasibility rated High because exit mechanics are now routine for an AI-equipped team — the residual risk is absorbable inside a single sprint rather than a multi-week project.                                                           |
| Over-abstraction risk                                                                       | Low        | Medium     | High                   | Low          | Incremental adoption; unused modules are inert                                                                                                                                                                                                                                                                                                                                                                                |
| Developer cognitive load                                                                    | Medium     | Low        | High                   | Low          | Per-module learning; `AGENTS.md` + `docs/Code Conventions - Guide.md` + Fast Starts reduce ramp                                                                                                                                                                                                                                                                                                                               |
| Framework updates break existing code                                                       | Low        | High       | High                   | Low          | 2GP version locking; sandbox testing before production; semantic versioning                                                                                                                                                                                                                                                                                                                                                   |
| Static methods harder to mock in tests                                                      | Low        | Low        | High                   | Low          | Built-in mocking: `QRY_Builder.setMock()`, `TST_Mock.register()`, `API_MockFactory`                                                                                                                                                                                                                                                                                                                                           |
| Data Access Governance on auxiliary read paths (framework-internal `SYSTEM_MODE` selectors) | Low        | Low-Medium | High                   | Low          | KernDX defaults `QRY_Builder` / `DML_Builder` to `USER_MODE` on read AND write. 33 framework-internal selectors opt back into `SYSTEM_MODE` via `SEL_Base.systemModeRequired()` (documented, audit-traceable, scanner-enforced). CI-blocking scanner rule prevents regression. Metadata flags remain as emergency kill-switches — flip one record, no code deploy, to revert if a subscriber hits unexpected access denials. |
| Critical bug in managed package class                                                       | Low        | High       | Medium                 | Medium       | Handler bugs: bypass via metadata. Infrastructure bugs (`QRY_Builder`, `DML_Builder`): subscriber cannot hotfix — requires vendor push upgrade or source ownership repackaging. Same constraint as Financial Services Cloud / CPQ.                                                                                                                                                                                            |

**P1 Hotfix Mitigation:** A common architecture-board concern with managed packages is: *"What if a critical bug is found inside a framework class and the vendor is unavailable?"*
KernDX's metadata-driven architecture provides multiple isolation mechanisms that do not require code deployment or a vendor push upgrade:

| Mechanism                                | Scope                      | Action                                                                           | Code Deploy Required    |
|------------------------------------------|----------------------------|----------------------------------------------------------------------------------|-------------------------|
| `TRG_Base.bypassAction(className)`       | Single trigger handler     | Programmatically skip a specific handler for the remainder of the transaction    | No (Apex API call)      |
| `TriggerSetting__mdt.BypassExecution__c` | All handlers for an object | Declaratively disable all trigger processing for an SObject type                 | No (metadata deploy)    |
| `FeatureFlag__mdt`                       | Entire feature path        | Disable a feature flag, which prevents associated trigger actions from executing | No (metadata deploy)    |
| Web service feature flags                | Specific API handler       | Disable outbound/inbound web service processing via `FeatureFlag__mdt`           | No (metadata deploy)    |
| Source ownership + repackaging           | Any framework class        | Fork the public source (BSL 1.1), fix the bug, repackage under client namespace  | Yes (the exit strategy) |

**Bypass usage is audit-logged by default.** Every bypass call writes a structured audit event via `LOG_Builder`, carrying the W3C correlation ID so every bypass — whether a
deliberate P1 mitigation or an accidental call inside a loop — is traceable across triggers, async chains, and API calls. Subscribers get auditable evidence of every emergency
bypass without writing any logging code themselves. Across comparable Apex frameworks, only KernDX and [`rflib`](https://github.com/j-fischer/rflib) ship built-in bypass-audit
emission — [`taf`](https://github.com/mitchspano/apex-trigger-actions-framework)'s programmatic bypass surface, `fflib`'s static-Boolean kill-switch, [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library)'s `disableTrigger` / `asSystemWithoutSharing`, and the Apex Fluently programmatic surfaces all emit no
observable signal on bypass.

**Two tiers of risk — with honest trade-offs:**

**Tier 1 — Pluggable handler bugs** (trigger actions, API handlers, chain steps): The bypass mechanisms above let subscribers disable the faulty handler and deploy a temporary
replacement in subscriber code. This is a real, tested mitigation — no vendor involvement needed.

**Tier 2 — Infrastructure bugs** (`QRY_Builder`, `DML_Builder`, `TRG_Dispatcher`, `LOG_Builder`): The subscriber **cannot hotfix these**. They are compiled inside the managed
package. No bypass mechanism helps because subscriber code calls *into* them. The options are: wait for a vendor push upgrade, work around the specific bug in subscriber code (e.g., write raw SOQL for the affected query pattern), or trigger the source ownership exit strategy. This is the inherent trade-off of any managed package — Salesforce's own
products (Financial Services Cloud, CPQ, Health Cloud) carry the same constraint.

**What mitigates the Tier 2 risk:** Infrastructure classes are the most stable and most tested components in the framework (166 Apex test classes ≈ 3,443 `@IsTest` methods plus the
LWC Jest suite, gated at 100% per-file Apex + 95% statement/branch LWC, enforced at every release build, validated against the subscriber-side release-testing harness — 471
anonymous-Apex assertions across 71 sections, 151 test methods across 22 subscriber test classes). They change less frequently than handler logic and are validated across every
package build (107 distinct package version IDs declared in `sfdx-project.json`). The risk is real but low-probability. Pre-adoption, enterprises should evaluate whether the
vendor's support responsiveness is acceptable for their SLA, and ensure the exit strategy documentation is maintained.

**What `ClassTypeResolver__mdt` provides:** Subscriber extension, not replacement. Subscribers inject new handlers, strategies, and chain steps into the framework's resolution
chain via custom metadata — the framework discovers them at runtime via `UTIL_System.getTypeForClassName()`. This is a dependency injection mechanism for extending the framework,
not a hotfix path for replacing package internals.

### Organisational Risks

| Risk                                 | Likelihood | Impact | Mitigation Feasibility | Net Exposure | Justification                                                                                                                                                                                                                                                                                                                  |
|--------------------------------------|------------|--------|------------------------|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Knowledge concentration (bus factor) | Medium     | High   | Medium                 | Medium       | Source ownership + AI-context files (`AGENTS.md` + `docs/Code Conventions - Guide.md` at repo root plus the [AI Agent Instructions](AI%20Agent%20Instructions.md) framework reference), 26 developer documents, 263 API reference pages, standard patterns, metadata-driven bypass for P1 isolation                            |
| No public community                  | Medium     | Low    | Medium                 | Low          | Documentation + AI context for self-service                                                                                                                                                                                                                                                                                    |
| Limited market familiarity           | Medium     | Low    | High                   | Low          | KernDX uses standard Apex patterns (selectors, triggers, DTOs); the ramp gap is per-module API familiarity, not a language or paradigm change. Per-module onboarding times are comparable across comparable Apex frameworks (see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison)) |
| Internal support dependency          | Medium     | Medium | Medium                 | Medium       | Source ownership + exit strategy                                                                                                                                                                                                                                                                                               |
| Developers misuse static utilities   | Medium     | Medium | High                   | Low          | Code review standards; limit scope to infrastructure                                                                                                                                                                                                                                                                           |
| Agentforce Vibes lock-in             | Medium     | Medium | High                   | Low          | Instruction files work with any AI tool (Claude Code, Cursor, Cline)                                                                                                                                                                                                                                                           |

### Ecosystem Risks

| Risk                                                      | Likelihood | Impact | Mitigation Feasibility | Net Exposure | Justification                                                                   |
|-----------------------------------------------------------|------------|--------|------------------------|--------------|---------------------------------------------------------------------------------|
| Salesforce deprecates platform features used by framework | Low        | High   | High                   | Low          | Standard Apex only; no unsupported APIs                                         |
| Competing frameworks improve significantly                | High       | Low    | High                   | Low          | Framework is an accelerator, not a locked dependency                            |
| AI tooling reduces framework value                        | Medium     | Medium | Medium                 | Medium       | AI tools work with conventions, not against them                                |
| Abandoned library risk (modular stacks)                   | Medium     | High   | Medium                 | Medium       | Open-source libraries depend on maintainer motivation; fork potential mitigates |

### Enterprise Risk Dimensions

Structured risk classification for architecture board evaluation:

- **Concentration Risk** (single maintainer)
    - KernDX: Amplifies — single primary developer. This matches the norm across comparable Apex frameworks: most comparable Apex frameworks are also single-maintainer (only the
      `fflib` family carries distributed maintainership).
    - Mitigation: Source publicly available under BSL 1.1 — any team can clone and self-maintain regardless of vendor status; consulting engagements include direct source delivery
      and handover support. Plus standard Apex patterns, AI-context files, 26 developer documents, and shipped repackaging-under-client-namespace tooling.
    - Audit framing: the question your audit team can answer from source — "is the framework defensible if the maintainer is unavailable?" — is enumerable from the documentation
      inventory ([Bus Factor Reframe](#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth) below), not contingent on individual availability. A Governance
      by Design baseline is documented in the repository; an Honor System dependent on the maintainer's memory is not.
- **Upgrade Risk** (API instability)
    - KernDX: Mitigates after 1.0 — semantic versioning, `global` API stability commitment
    - Mitigation: 2GP version locking, sandbox testing before production
- **Survivability Risk** (abandonment)
    - KernDX: Low — source is publicly available under BSL 1.1 (relicenses to Apache 2.0 after the four-year change date); any team can fork and self-maintain regardless of vendor
      status. KernDX is one of the few Apex frameworks that ships explicit repackaging-under-client-namespace tooling and an `Unmanaged.zip` exit artefact, so the practical exit
      path is more thorough than "source on GitHub" alone.
    - Mitigation: Public source access, standard Apex patterns, shipped repackaging tooling, documented exit strategy to modular stack.
- **Hiring & Ramp Risk** (per-framework familiarity in the hiring pipeline)
    - This guide does not measure per-framework hiring-market depth for any framework — KernDX or alternatives — so claims of "this framework is easier to hire for" are not
      load-bearing without your own data. Per-module onboarding times are comparable across comparable Apex frameworks (see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison)).
    - KernDX: Standard Apex patterns (selectors, triggers, DTOs) transferable from `fflib` / `taf` experience; the ramp gap is per-module API familiarity, not a paradigm shift.
      Adoption decisions in high-turnover environments should reference the team's own historical onboarding data, not generic hiring-market claims about any specific framework.
    - Mitigation: KernDX documentation depth (14 developer guides, 12 Fast Starts, 263 API reference pages) plus `AGENTS.md` and `docs/Code Conventions - Guide.md` reduce
      per-new-hire ramp time; measure against your team's own baseline.
- **Governance Drift Risk**
    - KernDX: Mitigates — managed package encapsulates conventions
    - Modular stacks: Amplifies — requires active architectural discipline across independent libraries
- **Vendor Lock-in Risk** (internal framework dependency)
    - KernDX: Low — managed package with three explicitly documented exit paths (namespace removal, unlocked conversion via `Unmanaged.zip`, and repackage-under-client-namespace
      using the shipped tooling). KernDX is unusual among comparable Apex frameworks in shipping a complete repackaging workflow as a first-class exit path, not just publishing
      source on GitHub.
    - Mitigation: Three documented exit strategies plus public source access under BSL 1.1.
- **Architecture Board Approval Risk** (governance review criteria)
    - KernDX: Moderate — BSL 1.1 is source-available with a four-year change date to Apache 2.0 (functionally close to OSI for subscriber use cases; the structural gap is the
      commercial-redistribution restriction during the BSL period). Single maintainer at the snapshot date; the public release brings the source into the open during the BSL
      window. Architecture boards requiring strict OSI-approved licensing on the immediate procurement window may still favour MIT/Apache alternatives; boards accepting
      source-available with a documented relicense path can adopt KernDX today.
    - Mitigation: Documented governance model, publicly available source under BSL 1.1, standard Apex patterns, time-boxed pilot.

### Potential Drawbacks

| Drawback                                                          | Context                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
|-------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| All-or-nothing installation                                       | Unused code is inert (no CPU, no governor limits). Package exempt from 6 MB limit.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Framework-internal `SYSTEM_MODE` selectors (auxiliary read paths) | `QRY_Builder` and `DML_Builder` default to `USER_MODE` on read AND write. 33 framework-internal selectors (configuration reads, Chain Monitor aggregates, etc.) opt back into `SYSTEM_MODE` via the documented `SEL_Base.systemModeRequired()` hook — declarations are auditable in source, enforced by a CI-blocking scanner rule that fails builds on undeclared access modes. Subscribers who extend `SEL_Base` inherit `USER_MODE` by default; opting out requires explicit override. Emergency rollback is a metadata flip — no code deploy.                                                                             |
| No pre-built log browser                                          | `nebula-logger` covers more aspects of the Logging family than any other Apex framework surveyed, including a dedicated historical log-browser LWC. KernDX provides real-time log monitoring via Streaming Event Monitor and persists logs to `LogEntry__c` for subscriber-built reports and dashboards. KernDX ships 21 operational UI components (Chain Monitor, Streaming Event Monitor, API Test Harness, Health Check, Org Limits) but no dedicated log search/browse interface. The gap is the UI shell — `LogEntry__c` is fully queryable + masking-applied — mitigated by a 1-day LWC against `LogEntry__c` if needed. |
| Flow-as-trigger-action — typed-collection input shape             | KernDX `TRG_InvokeFlow` ships with declarative failure-action custom metadata, deploy-time scanner, mock harness, and inherited recursion / perf / audit / feature-flag gating. `taf` covers the typed `List<SObject>` collection input shape that KernDX does not — `Invocable.Action.setInvocations` cannot pass typed collections to typed Flow inputs at API 67.0, so KernDX ships per-record dispatch.                                                                                                                                                                                                                    |
| No retryable trigger actions                                      | `rflib` supports Platform Event-based trigger retry (up to 8 retries). KernDX retry is API-level only — applied to outbound HTTP calls, not trigger handlers.                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| No Domain layer                                                   | `fflib` ships the Domain / Application factory surface; KernDX is absent on this family by deliberate design (the framework conventions document forbids `fflib` patterns). Subscribers requiring Domain-Driven Design should keep `fflib` or layer a custom domain on top of KernDX utilities.                                                                                                                                                                                                                                                                                                                                |
| Chain monitor controller selectors run in `SYSTEM_MODE`           | `CTRL_ChainMonitor` / `CTRL_EventMonitor` inherit `SEL_Base` defaults. Post-1.0 work extends the bypass audit signal to per-builder QRY/DML toggles — closes the symmetric audit gap on subscriber-write-time access-mode toggles.                                                                                                                                                                                                                                                                                                                                                                                             |
| Namespace verbosity                                               | Subscriber code requires namespace prefix. Modern IDEs auto-complete this.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |

### Modular Stack Risks

These risks apply to modular assembly (`taf` + [`apex-fluently-soql`](https://github.com/beyond-the-cloud-dev/soql-lib) + [`nebula-logger`](https://github.com/jongpie/NebulaLogger) + etc.). **Framing caveat:** the modular-stack risks below are presented at the same High-likelihood / High-impact end of
the scale that the Technical Risks, Organisational Risks, and Ecosystem Risks tables above apply to KernDX-specific risks. Both stacks carry High-exposure risks; the right choice
depends on which set of risks the team is equipped to manage and which mitigations the team can sustain.

| Risk                                           | Likelihood | Impact | Mitigation Feasibility | Net Exposure | Justification                                                                       |
|------------------------------------------------|------------|--------|------------------------|--------------|-------------------------------------------------------------------------------------|
| Integration coherence degrades over time       | High       | High   | Low                    | High         | Independent release cycles; no cross-library consistency maintainer                 |
| Convention drift across libraries              | High       | Medium | Medium                 | Medium       | 3-5 different API philosophies; no unified AI context file                          |
| Source-distributed code in subscriber analysis | Medium     | Medium | Medium                 | Medium       | Counts against 6 MB limit; appears in PMD scans and coverage reports                |
| Upgrade coordination burden                    | Medium     | High   | Medium                 | Medium       | 5+ independent release cycles; no single changelog                                  |
| No cross-boundary observability                | High       | Medium | Low                    | High         | Correlating events across independent systems requires hand-written instrumentation |
| Documentation fragmentation                    | High       | Low    | Medium                 | Medium       | No unified onboarding; must be written in-house                                     |
| Abandoned library risk                         | Medium     | High   | Medium                 | Medium       | Team inherits maintenance of unfamiliar source if maintainer stops                  |

Both approaches carry real risks. The right choice depends on which risks the team is equipped to manage.

### Bus Factor Reframe — Institutional Knowledge Survival via Documentation Depth

KernDX is single-maintainer at the snapshot date. This is acknowledged across multiple sections of this guide (Technical Risks, Organisational Risks, Enterprise Risk Dimensions)
and it is not asymmetric to the alternatives this guide compares against: most comparable Apex frameworks are also single-maintainer. Only the `fflib` family carries distributed
maintainership by the metrics enterprise procurement teams typically use.

The substantive differentiator is not maintainer count — it is **whether the maintainer's mental model is documented**. A bus-factor event is survivable to the degree that
institutional knowledge has been externalised into source-controlled documentation that a successor team can pick up cold.

**KernDX documentation inventory (verifiable against this repo):**

| Doc                                         | Purpose                                                                                                       |          Size |
|---------------------------------------------|---------------------------------------------------------------------------------------------------------------|--------------:|
| `AGENTS.md`                                 | Tool-neutral entry point for AI coding assistants — points to the canonical conventions doc                   |      46 lines |
| `docs/Code Conventions - Guide.md`          | Canonical Apex/LWC/JS conventions — naming, sharing modifiers, testing patterns, framework idioms             |     572 lines |
| `README.md`                                 | Project entry point — installation, getting started, references                                               |      70 lines |
| Strategic Guides                            | Architectural decisions, adoption decisions, persona-tailored summaries, operations, risks, metrics, glossary |   8 documents |
| `docs/Security - Guide.md`                  | Threat model, posture, mitigations, bypass governance                                                         |   2,027 lines |
| Apex reference                              | Per-class API documentation auto-generated from ApexDoc on every release build                                |     263 pages |
| **Total Markdown documentation in `docs/`** | **All `.md` files under the docs tree**                                                                       | **301 files** |

Subscribers can audit this inventory by running `find docs/ -name "*.md" -type f | wc -l` and
`wc -l AGENTS.md "docs/Code Conventions - Guide.md" README.md "docs/Security - Guide.md"` at the snapshot tag.

**What this means for a bus-factor event:** A successor team encountering KernDX cold can read `AGENTS.md` + `docs/Code Conventions - Guide.md` + the relevant Strategic Guide + the
Apex reference for the affected module and ship convention-compliant changes without prior KernDX experience. The mental model is in the repository, not in the maintainer's head.

The honest framing here is that bus-factor risk is structurally similar across most Apex frameworks today: KernDX accepts the symmetry and competes on the asymmetry that matters
operationally — whether the codebase is documented well enough to be inherited. This guide makes no claim about the depth of any specific alternative framework's documentation;
teams comparing bus-factor exposure across frameworks should audit each candidate's repository documentation inventory directly.

### Community Support: Signal vs Substance

Most Salesforce open-source frameworks do not provide SLA-backed support, are maintained by small contributor groups, and do not guarantee production assistance. This distinction
matters when evaluating risk:

| Dimension  | What Community Provides                                                                                                        | What It Does Not Provide                                                             |
|------------|--------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| Bug fixing | Shared issue visibility, community PRs                                                                                         | Contractual resolution timeline                                                      |
| Knowledge  | Public examples, Q&A, blog posts                                                                                               | Production firefighting                                                              |
| Longevity  | Fork potential, shared ownership                                                                                               | Formal roadmap control                                                               |
| Hiring     | Public maintainer-authored repos may surface in candidate portfolios, technical blogs, conference talks, and Trailhead modules | Deep expertise guarantee, or measurable hiring-pool depth for any specific framework |

- Public-maintainer-authored frameworks may provide shared issue visibility and community pull requests, but they do not guarantee shared maintenance: as covered in
  the [Bus Factor Reframe](#bus-factor-reframe--institutional-knowledge-survival-via-documentation-depth), most comparable Apex frameworks are single-maintainer regardless of
  whether the source is publicly hosted.
- Open-source visibility does not eliminate the adopting organisation's operational responsibility — production firefighting still falls on the adopter, the same way it does for
  KernDX.
- Enterprises must internalise ownership regardless of framework choice.

This applies equally to all frameworks — open-source visibility and internal operational readiness are complementary, not interchangeable.

### Governance Model

| Aspect                   | Current State                                                                                                                                                                                                       |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Roadmap ownership        | Primary developer with delivery engagement oversight                                                                                                                                                                |
| Contribution policy      | Internal — no external contributions accepted at this time                                                                                                                                                          |
| Support model            | Engagement team during active projects; documentation + AI context for self-service post-handover                                                                                                                   |
| Escalation path          | Delivery engagement lead then framework developer                                                                                                                                                                   |
| Long-term sustainability | Source publicly available under BSL 1.1 (relicenses to Apache 2.0 after the four-year change date) ensures independence from any single maintainer; standard Apex patterns ensure any senior developer can maintain |

### Versioning & API Stability

| Aspect                 | Policy                                                                                                                          |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Versioning strategy    | Semantic versioning (major.minor.patch) from 1.0 onwards                                                                        |
| Backward compatibility | `global` API stability prioritised after 1.0; breaking changes require major version bump                                       |
| Current status         | Packaged with 107 distinct package version IDs declared in `sfdx-project.json`                                                  |
| Upgrade guarantees     | Backward-compatible minor releases; breaking changes in major versions only                                                     |
| API stability          | `global` members are the stable API surface; `public` members are internal and may change                                       |
| Source delivery method | Public source repository under BSL 1.1; consulting engagements additionally include direct source delivery and handover support |

### Adoption Gate Criteria

Any framework — integrated or modular — should meet these governance gates before enterprise adoption. **Adoption should not proceed unless all PASS or CONDITIONAL gates are
satisfied, with explicit risk acceptance for any FAIL gates.**

| Gate | Requirement                       | KernDX Status                                                                                | Pass/Fail   |
|------|-----------------------------------|----------------------------------------------------------------------------------------------|-------------|
| G-1  | Semantic versioning documented    | Committed from v1.0                                                                          | PASS        |
| G-2  | Backward compatibility guarantee  | `global` API stability post-1.0                                                              | PASS        |
| G-3  | Deprecation lifecycle formalised  | Planned, not formalised                                                                      | FAIL        |
| G-4  | Defined release cadence           | Engagement-aligned, not fixed                                                                | FAIL        |
| G-5  | Named secondary maintainer        | Single primary; succession via source ownership                                              | CONDITIONAL |
| G-6  | Contribution guidelines published | `CONTRIBUTING.md` published in the source repository                                         | PASS        |
| G-7  | CI transparency                   | `.github/workflows/ci.yml` and Actions run history publicly visible on the source repository | PASS        |

**Assessment:** KernDX passes 4 of 7 gates, with 1 conditional and 2 failures. Enterprises adopting KernDX should document explicit risk acceptance for gates G-3 and G-4 and
establish contractual mitigations (source ownership, defined handover process, succession planning). The conditional G-5 gate ("succession via source ownership") is materially
stronger in practice than the conditional label alone suggests: the succession-exit path is AI-executable against the framework's public AI-context bundle, with ~1-2 days
wall-clock for a deeply adopted transition — so "succession via source ownership" is a concrete sprint-scale activity, not a multi-week project, for teams equipped with modern
agentic tooling.

**For comparison**, the same gates applied to modular frameworks:

| Gate                        | `taf`       | `apex-fluently-soql` | `nebula-logger`         | `fflib`                           |
|-----------------------------|-------------|----------------------|-------------------------|-----------------------------------|
| G-1 Semantic versioning     | PASS        | PASS                 | PASS                    | FAIL (low recent release cadence) |
| G-2 Backward compatibility  | PASS        | PASS                 | PASS                    | CONDITIONAL                       |
| G-3 Deprecation lifecycle   | CONDITIONAL | CONDITIONAL          | CONDITIONAL             | FAIL                              |
| G-4 Release cadence         | PASS        | PASS                 | PASS                    | FAIL                              |
| G-5 Secondary maintainer    | CONDITIONAL | CONDITIONAL†         | PASS (25+ contributors) | PASS (30+ contributors)           |
| G-6 Contribution guidelines | PASS        | PASS                 | PASS                    | PASS                              |
| G-7 CI transparency         | PASS        | PASS                 | PASS                    | PASS                              |

† The 8 Apex Fluently libraries share a single primary author, so a full Apex Fluently stack is effectively a single-maintainer dependency (or two if paired with a
separately-maintained logger such as `nebula-logger`), so an architecture board evaluating *the modular stack as a whole* should treat its overall G-5 gate result as CONDITIONAL
even though each individual library lists its own G-5 status.

### Hard Questions Architecture Review Boards Will Ask

| # | Question                                                    | Answer                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
|---|-------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | **What happens if the primary developer is unavailable?**   | Source is publicly available under BSL 1.1 on the project repository — any team can clone, fork, and self-maintain regardless of vendor status, with consulting engagements including direct source delivery and handover support. AI-context files document framework conventions and patterns: `AGENTS.md` (tool-neutral pointer) + `docs/Code Conventions - Guide.md` (canonical conventions) at repo root carry instruction-level guidance, and the per-module [AI Agent Instructions](AI%20Agent%20Instructions.md) doc provides a deep framework reference. Developers using AI coding tools can generate convention-compliant code and diagnose framework internals without prior KernDX experience (this narrows but does not eliminate the tribal-knowledge gap). For critical bugs, metadata-driven bypass mechanisms (`TRG_Base.bypassAction()`, `FeatureFlag__mdt`) isolate faulty handlers without code changes; the shipped repackaging-under-client-namespace tooling supports deeper fixes by forking the source under the subscriber's own namespace. See [Bus Factor Mitigation](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#bus-factor-mitigation). |
| 2 | **Can we mix modular components with KernDX later?**        | Yes. KernDX coexists with `taf`, `apex-fluently-soql`, and `nebula-logger`. See [Coexistence Playbook](Strategic%20Guide%20-%20Adoption.md#coexistence-playbook).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 3 | **What is the rollback strategy?**                          | Three exit paths: continue managed package, deploy as source, or repackage under client namespace. Estimated ~1-2 days agent-executed against the framework's AI-context bundle, or 1-2 weeks conventional human-only execution, for deeply adopted orgs. See [Exit and Reversibility Analysis](Strategic%20Guide%20-%20Operations.md#exit-and-reversibility-analysis).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| 4 | **How do we validate production-scale performance?**        | Pre-compiled managed package; benchmark hot paths in sandbox. Framework overhead is < 5 ms per trigger action in measured deployments. See [Performance & Governor Limits](Strategic%20Guide%20-%20Operations.md#performance--governor-limits).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| 5 | **How does this affect hiring flexibility?**                | KernDX uses standard Apex patterns (selectors, triggers, DTOs). The ramp gap for an incoming developer is per-module API familiarity, not a language or paradigm shift, so any senior Apex developer can ship convention-compliant code after working through the relevant Fast Start. This guide does not measure per-framework hiring-market depth for KernDX or for any alternative, so a claim that one specific framework is "easier to hire for" is not load-bearing without your own historical data. Per-module onboarding times are comparable across comparable Apex frameworks (see [Onboarding Time Comparison](Strategic%20Guide%20-%20Adoption.md#onboarding-time-comparison)).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 6 | **What governance gates must KernDX pass before adoption?** | 7 gates defined. KernDX currently passes 2 of 7, with 4 failures. Enterprises should document explicit risk acceptance for FAIL gates. See [Adoption Gate Criteria](#adoption-gate-criteria).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 7 | **What if KernDX is abandoned?**                            | Source ownership means clients can fork and maintain. Standard patterns mean the codebase is readable without framework expertise. Exit playbook in [Migration Checklists](Strategic%20Guide%20-%20Operations.md#migration-checklists).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| 8 | **How does KernDX map to a recognized security benchmark?** | KernDX maps itself control-by-control against the [Security Benchmark for Salesforce](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#security-benchmark-for-salesforce-alignment) (54 controls across 12 domains): it provides a working mechanism or audit-ready evidence for 15 controls (peer review and static analysis, source-driven builds and secret scanning, masking detection and regulated-field inventory, plus the governance-evidence and access-review feeds), and is explicit that the other 39 are org configuration and process it does not own. |

### Strategic Recommendations

Risk-mitigation strategies at different adoption stages. For organisations where most enterprise Salesforce delivery runs on SI partner teams whose engineers rotate at every
release, the recommendations below double as the operational controls that keep production integrity bounded by the build pipeline rather than by individual engineer vigilance —
the 100% per-file Apex coverage gate, default-on data-access governance, and audit-trailed bypasses act as a technical lead encoded in source-visible defaults rather than in any
single SI engineer's memory.

**Pre-Adoption:**

1. Run a time-boxed pilot (2-4 weeks) on a single non-critical object
2. Assess exit cost — review [Migration Checklists](Strategic%20Guide%20-%20Operations.md#migration-checklists) for migration effort
3. Verify team readiness — at least one developer reviewed Fast Start guides
4. Compare in sandbox — build the same feature with KernDX and a modular stack; measure time, coverage, satisfaction

**During Adoption:**

1. Start with triggers and selectors — highest value, lowest risk
2. Add web services and resilience when integration requirements arise
3. Document all custom metadata configuration
4. Maintain exit readiness

**Post-Adoption:**

1. Assign a platform engineering owner for upgrades, log monitoring, and incident response
2. Review quarterly — measure success metrics (see [Success Metrics](Strategic%20Guide%20-%20Adoption.md#success-metrics))
3. Maintain AI context files — update `docs/Code Conventions - Guide.md` when conventions evolve
4. Ensure at least two team members can troubleshoot independently

---
