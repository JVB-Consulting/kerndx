---
navOrder: 34
---

# Strategic Guide — Metrics

> This is the single source of truth for the numbers that describe KernDX: how much code it contains, how many tests run, how big the public API is, and how it compares on size and activity. Every other guide links here instead of repeating a figure, so there is only one place to keep current. If you are looking up a statistic to cite, this is the page. Update this file when the codebase changes.

Part of the [KernDX Strategic Guide](Strategic%20Guide%20-%20Overview.md).

**Last verified:** 2026-06-13 (drift reconciliation against the post-Kern 1.1.0-11 dev tree)
**Source:** Counts derive from the `force-app/` source tree and from `git log` at the snapshot date. Update this file when the codebase changes.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Package Codebase](#package-codebase)
2. [Org Apex Usage (Unmanaged)](#org-apex-usage-unmanaged)
3. [Global API Surface](#global-api-surface)
4. [Extension Points (Where Your Code Connects)](#extension-points-where-your-code-connects)
5. [LWC Components](#lwc-components)
6. [Salesforce Metadata](#salesforce-metadata)
7. [Documentation](#documentation)
8. [Code Quality & Scanning](#code-quality--scanning)
9. [Release Testing](#release-testing)
10. [E2E Tests (Playwright)](#e2e-tests-playwright)
11. [Combined Test Coverage](#combined-test-coverage)
12. [Activity Snapshot](#activity-snapshot)
13. [The Other Frameworks We Compared](#the-other-frameworks-we-compared)

</details>

---

## Package Codebase

| Metric                          |                Count | Notes                                                                                                                                              |
|---------------------------------|---------------------:|----------------------------------------------------------------------------------------------------------------------------------------------------|
| Apex classes (total)            |                  363 | sum of production + test                                                                                                                           |
| Apex production classes         |                  189 | `force-app/main/default/classes/*.cls` excluding `_TEST.cls`                                                                                       |
| Apex test classes               |                  174 | `force-app/main/default/classes/*_TEST.cls`                                                                                                        |
| Apex test methods               |                3,742 | counted from `force-app/main/default/classes/*_TEST.cls` (method-level `@IsTest` annotations; class-level `@IsTest(...)` annotations are excluded) |
| Apex test coverage              |        100% per-file | enforced at every release build by `scripts/evaluate-coverage.js`                                                                                  |
| Lines of code (production Apex) |                 ~81K | counted from `force-app/main/default/classes/*.cls` excluding `_TEST.cls`                                                                          |
| Lines of code (test Apex)       |                 ~79K | counted from `force-app/main/default/classes/*_TEST.cls`                                                                                           |
| Lines of code (production LWC)  |                 ~13K | counted from `force-app/main/default/lwc/**/*.js` excluding `.test.js`                                                                             |
| Lines of code (LWC Jest tests)  |                 ~31K | counted from `force-app/main/default/lwc/**/*.test.js`                                                                                             |
| Lines of code (total)           |                ~205K | sum of the rows above                                                                                                                              |
| Source API version              |                 67.0 | visible in Setup → Installed Packages → Kern → API Version; also in `sfdx-project.json`                                                            |
| Latest packaged version         | 1.1.0-11 (released) | `sfdx-project.json` `packageAliases`                                                                                                               |

## Org Apex Usage (Unmanaged)

| Metric                 |      Value |
|------------------------|-----------:|
| Apex characters in use |      ~990K |
| Apex character limit   | 10,000,000 |
| Percent of limit used  |       ~10% |

> You can see this yourself in Setup → Apex Classes → view limit bar. The ~990K figure is approximate and was last measured against an earlier 1.0.0-x build (the current build has 363 Apex classes total). The count includes all Apex classes and triggers defined in the org, excluding comments and `@IsTest` annotated classes. Managed package code does not count toward this limit, which is why installing KernDX as a managed package leaves your org's own Apex headroom untouched.

## Global API Surface

| Metric                        | Count |
|-------------------------------|------:|
| Global classes (top-level)    |    95 |
| Global interfaces (top-level) |     4 |
| Global inner classes          |   ~94 |
| Global inner interfaces       |   ~26 |
| Global inner enums            |   ~16 |
| Global methods                |  ~546 |

## Extension Points (Where Your Code Connects)

> The points where your own code connects to the framework. The [Global API Surface](#global-api-surface) section above counts the raw symbols (classes, methods, and so on). This section is more useful day to day: it groups those connection points by *how* you use them, so you can tell at a glance whether a given extension needs configuration, Apex, or just clicks in Flow.

### Metadata-Configured (no code required)

| Metric                           | Records | Notes                                                                                                        |
|----------------------------------|--------:|--------------------------------------------------------------------------------------------------------------|
| `TriggerSetting__mdt`            |       6 |                                                                                                              |
| `TriggerAction__mdt`             |       6 |                                                                                                              |
| `FeatureFlag__mdt`               |      11 |                                                                                                              |
| `FeatureFlagStrategy__mdt`       |       2 |                                                                                                              |
| `ApiSetting__mdt`                |       4 |                                                                                                              |
| `ApiCredential__mdt`             |       3 |                                                                                                              |
| `MaskingRule__mdt`               |      18 | 3 active by default (MaskSecretKeys, MaskPaymentCard, and the legacy MaskCreditCard it replaces), 15 shipped as inactive templates |
| `MaskingTarget__mdt`             |      12 | Wildcards wiring the card and secret rules to ApiCall__c, ApiIssue__c, AsyncChainExecution__c, and LogEntryEvent__e (4 of the 12 belong to the replaced credit-card rule) |
| `ApiMock__mdt`                   |       0 | Extensibility-only: no pre-built records, you add your own                                                  |
| `ValidationRuleGroup__mdt`       |       0 | Extensibility-only: no pre-built records, you add your own                                                  |
| `ValidationRule__mdt`            |       0 | Extensibility-only: no pre-built records, you add your own                                                  |
| `ClassTypeResolver__mdt`         |       0 | Extensibility-only: no pre-built records, you add your own                                                  |
| `AsynchronousJobSetting__mdt`    |       0 | Extensibility-only: no pre-built records, you add your own                                                  |
| `FieldSetGroup__mdt`             |       0 | Extensibility-only: no pre-built records, you add your own                                                  |
| **Total pre-built CMDT records** |  **62** |                                                                                                              |

### Code-Level (extend or implement)

| Metric                        | Count | Composition                                                                                                                                                    |
|-------------------------------|------:|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Base classes to extend        |     8 | `SEL_Base`, `TRG_Base`, `API_Outbound`, `API_Inbound`, `SCHED_Base`, `DTO_JsonBase`, `UTIL_TypeResolver.BaseClassResolver`, `TST_Builder.DefaultValueProvider` |
| Top-level interfaces          |     4 | `IF_Queryable`, `IF_Schedulable`, `IF_Search`, `IF_TableDataSource`                                                                                            |
| `IF_Trigger` inner interfaces |     7 | BeforeInsert, AfterInsert, BeforeUpdate, AfterUpdate, BeforeDelete, AfterDelete, AfterUndelete                                                                 |
| `IF_Async` inner interfaces   |     2 | Processable, Finishable                                                                                                                                        |
| Other inner interfaces        |     4 | `IF_Chain.Step`, `QRY_Condition.Evaluable`, `UTIL_TypeResolver.INT_ClassTypeResolver`, `SVC_Omnistudio.OmniCallable`                                           |
| ComponentBuilder LWC modules  |     6 | `notification`, `controller`, `navigation`, `lightning-message`, `flow-navigation`, `all`                                                                      |

### Declarative (Flow Builder / Lightning App Builder)

| Metric                            |                  Count |
|-----------------------------------|-----------------------:|
| Flow invocable actions (`FLOW_*`) |                     16 |
| Exposed LWC components            |                     30 |
| LWC with Lightning page targets   |                     13 |
| — App Page                        |                      9 |
| — Home Page                       |                      7 |
| — Record Page                     |                      6 |
| — Flow Screen                     |                      5 |
| — Record Action                   |                      1 |
| Pre-built flows                   |                      5 |
| Platform events                   | 1 (`LogEntryEvent__e`) |

## LWC Components

| Metric                 |                        Count | Notes                                                             |
|------------------------|-----------------------------:|-------------------------------------------------------------------|
| LWC components (total) |                           63 | `force-app/main/default/lwc/**/`                                  |
| Jest test files        |                           65 | counted from `force-app/main/default/lwc/**/*.test.js`            |
| Jest test cases        |                       ~2,660 | counted across all Jest test files                                |
| Jest test coverage     | 100% statement / 95%+ branch | enforced at every release build by `scripts/evaluate-coverage.js` |

## Salesforce Metadata

| Metric                          |                  Count |
|---------------------------------|-----------------------:|
| Custom objects (`__c`)          |                     10 |
| Custom metadata types (`__mdt`) |                     14 |
| Platform events (`__e`)         | 1 (`LogEntryEvent__e`) |
| Pre-built CMDT records          |                     62 |

## Documentation

| Metric                                        | Count | Notes                                                                                                                       |
|-----------------------------------------------|------:|-----------------------------------------------------------------------------------------------------------------------------|
| Developer guides                              |    21 | Excluding the Strategic Guide series; counted from `docs/*%20-%20Guide.md`                                                  |
| Fast Start guides                             |    16 |                                                                                                                             |
| Strategic Guide documents                     |     9 | Overview + Architecture & Philosophy + Adoption + Operations + Risks + Glossary + Personas + Metrics + Choosing a Framework |
| API reference pages (Apex)                    |   239 |                                                                                                                             |
| API reference pages (metadata)                |    16 |                                                                                                                             |
| API reference pages (objects)                 |    11 |                                                                                                                             |
| API reference pages (events)                  |     2 |                                                                                                                             |
| API reference pages (total)                   |   268 | sum of all reference categories                                                                                             |
| Total documentation files (developer-focused) |    46 | 21 developer guides + 16 Fast Start guides + 9 Strategic Guide documents (excluding `reference/`)                           |

> The headline figure quoted in companion docs is 37 developer documents (21 guides + 16 Fast Starts) plus 263 API reference pages. The 263 figure counts the 262 categorised reference pages plus the Security Guide (which is tracked separately, at 2,027 lines).

## Code Quality & Scanning

| Metric                       | Count |
|------------------------------|------:|
| PMD rules (KernDX custom)    |    25 |
| ESLint rules (KernDX custom) |     6 |

## Release Testing

| Metric                                | Count |
|---------------------------------------|------:|
| Subscriber Apex classes (production)  |    56 |
| Subscriber test classes               |    39 |
| Subscriber test methods               |   175 |
| Anonymous Apex test sections          |    71 |
| Anonymous Apex assertions (`PASS:`)   |   350 |
| Anonymous Apex assertions (`Assert.`) |   471 |

## E2E Tests (Playwright)

| Metric              | Count |
|---------------------|------:|
| Spec files          |    10 |
| Test cases          |    57 |
| Page objects        |    12 |
| Helper modules      |     6 |
| CMDT fixture states |    15 |

## Combined Test Coverage

| Layer                       |         Tests |  Assertions |
|-----------------------------|--------------:|------------:|
| Package Apex tests          | 3,390 methods |      ~6,076 |
| Package Jest tests          |  ~2,282 cases |      ~3,591 |
| Subscriber Apex tests       |   166 methods |        ~203 |
| Subscriber anonymous Apex   |   71 sections |         350 |
| Subscriber E2E (Playwright) |      57 cases |        ~163 |
| **Total**                   |    **~5,966** | **~10,383** |

## Activity Snapshot

These figures describe how well-supported and ready-to-install the package is, measured at the snapshot date (2026-05-09). They are kept separate from the capability counts on purpose: how long a project has been active should not be confused with how much it does, so neither number skews the other. Figures derive from `sfdx-project.json` `packageAliases`.

| Metric                             |                Value | Source                                                                                  |
|------------------------------------|---------------------:|-----------------------------------------------------------------------------------------|
| Published managed-package versions |                  107 | `sfdx-project.json` `packageAliases`: `04tfj000000EtB7AAK` through `04tfj000000KesXAAS` |
| Latest packaged version            | 1.1.0-11 (released) | `sfdx-project.json` `packageAliases`                                                    |
| Primary contributors               |                    1 | single-maintainer project                                                               |

> KernDX is a single-maintainer project. Its readiness to install shows up in the 107 published managed-package versions, rather than in a long public commit history. So what this means for you: the package itself is well-exercised through repeated releases, even though it does not yet have the years-long open commit log of an older project.

## The Other Frameworks We Compared

When the guides rank or compare KernDX, they measure it against the same group of other Salesforce frameworks across the same capability areas, so every comparison is like-for-like. This page only points you to the detail rather than repeating it: the Adoption and Architecture guides walk through how each area is covered, and the Risks guide covers maintenance and the bus-factor question (what happens if the people who built it move on).

---

[Strategic Guide (Overview)](Strategic%20Guide%20-%20Overview.md)
