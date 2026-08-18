---
navOrder: 34
---

# Strategic Guide — Metrics

> This is the single source of truth for the numbers that describe KernDX: how much code it contains, how many tests run, how big the public API is, and how it compares on size and activity. Every other guide links here instead of repeating a figure, so there is only one place to keep current. If you are looking up a statistic to cite, this is the page. Update this file when the codebase changes.

Part of the [KernDX Strategic Guide](Strategic%20Guide%20-%20Overview.md).

**Last verified:** 2026-08-17 (1.7.0 release reconciliation); counts recomputed from the source tree, including 73 Jest suites and 3,275 Jest test cases
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
| Apex classes (total)            |                  374 | sum of production + test                                                                                                                           |
| Apex production classes         |                  193 | `force-app/main/default/classes/*.cls` excluding `_TEST.cls`                                                                                       |
| Apex test classes               |                  181 | `force-app/main/default/classes/*_TEST.cls`                                                                                                        |
| Apex test methods               |                4,341 | counted from `force-app/main/default/classes/*_TEST.cls` (method-level `@IsTest` annotations; class-level `@IsTest(...)` annotations are excluded) |
| Apex test coverage              |        100% per-file | enforced at every release build by `scripts/evaluate-coverage.js`                                                                                  |
| Lines of code (production Apex) |                ~105K | counted from `force-app/main/default/classes/*.cls` excluding `_TEST.cls`                                                                          |
| Lines of code (test Apex)       |                ~114K | counted from `force-app/main/default/classes/*_TEST.cls`                                                                                           |
| Lines of code (production LWC)  |                 ~27K | counted from `force-app/main/default/lwc/**/*.js` excluding `.test.js`                                                                             |
| Lines of code (LWC Jest tests)  |                 ~49K | counted from `force-app/main/default/lwc/**/*.test.js`                                                                                             |
| Lines of code (total)           |                ~294K | the rows above are rounded; exact total 294,036                                                                                                    |
| Source API version              |                 67.0 | visible in Setup → Installed Packages → Kern → API Version; also in `sfdx-project.json`                                                            |
| Latest packaged version         | 1.7.0-8 (candidate) | `sfdx-project.json` `packageAliases`                                                                                                               |

## Org Apex Usage (Unmanaged)

| Metric                 |      Value |
|------------------------|-----------:|
| Apex characters in use |  1,209,561 |
| Apex character limit   | 10,000,000 |
| Percent of limit used  |     12.10% |

> You can see this figure yourself in Setup → System Overview. The count includes every Apex class and trigger defined in the org, excluding comments and test classes (those annotated `@IsTest`). Managed package code does not count towards this limit, which is why installing KernDX as a managed package leaves your org's own Apex headroom untouched.

## Global API Surface

| Metric                        | Count |
|-------------------------------|------:|
| Global classes (top-level)    |   106 |
| Global interfaces (top-level) |     4 |
| Global inner classes          |   ~94 |
| Global inner interfaces       |   ~26 |
| Global inner enums            |   ~16 |
| Global methods                |  ~556 |

## Extension Points (Where Your Code Connects)

> The points where your own code connects to the framework. The [Global API Surface](#global-api-surface) section above counts the raw symbols (classes, methods, and so on). This section is more useful day to day: it groups those connection points by *how* you use them, so you can tell at a glance whether a given extension needs configuration, Apex, or just clicks in Flow.

### Metadata-Configured (no code required)

| Metric                           | Records | Notes                                                                                                        |
|----------------------------------|--------:|--------------------------------------------------------------------------------------------------------------|
| `TriggerSetting__mdt`            |       6 |                                                                                                              |
| `TriggerAction__mdt`             |       6 |                                                                                                              |
| `FeatureFlag__mdt`               |      13 | excluding the `TestFeatureFlag` fixture record                                                               |
| `FeatureFlagStrategy__mdt`       |       5 | excluding the `TestFeatureFlagStrategy` fixture record                                                       |
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
| `PostTriggerAction__mdt`         |       0 | Extensibility-only: no pre-built records, you add your own                                                  |
| **Total pre-built CMDT records** |  **67** | excluding the two `Test*` fixture records                                                                    |

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
| Exposed LWC components            |                     33 |
| LWC with Lightning page targets   |                     15 |
| — App Page                        |                     11 |
| — Home Page                       |                      7 |
| — Record Page                     |                      6 |
| — Flow Screen                     |                      5 |
| — Tab                             |                      1 |
| — Record Action                   |                      1 |
| Pre-built flows                   |                      5 |
| Platform events                   | 1 (`LogEntryEvent__e`) |

## LWC Components

| Metric                 |                        Count | Notes                                                             |
|------------------------|-----------------------------:|-------------------------------------------------------------------|
| LWC components (total) |                           72 | `force-app/main/default/lwc/**/`                                  |
| Jest test files        |                           73 | counted from `force-app/main/default/lwc/**/*.test.js`            |
| Jest test cases        |                        3,275 | counted across all Jest test files                                |
| Jest test coverage     | 95%+ statement / 95%+ branch | enforced at every release build by `scripts/evaluate-coverage.js` |

## Salesforce Metadata

| Metric                          | Count |
|---------------------------------|------:|
| Custom objects (`__c`)          |    11 |
| Custom metadata types (`__mdt`) |    15 |
| Platform events (`__e`)         |     1 |
| Custom fields (total)           |   278 |
| — on custom objects             |   139 |
| — on custom metadata types      |   122 |
| — on platform events            |    17 |
| Pre-built CMDT records          |    67 |

## Documentation

| Metric                                        | Count | Notes                                                                                                                       |
|-----------------------------------------------|------:|-----------------------------------------------------------------------------------------------------------------------------|
| Developer guides                              |    21 | Excluding the Strategic Guide series; counted from `docs/*%20-%20Guide.md`                                                  |
| Fast Start guides                             |    16 |                                                                                                                             |
| Strategic Guide documents                     |     9 | Overview + Architecture & Philosophy + Adoption + Operations + Risks + Glossary + Personas + Metrics + Choosing a Framework |
| API reference pages (Apex)                    |   241 |                                                                                                                             |
| API reference pages (metadata)                |    16 |                                                                                                                             |
| API reference pages (objects)                 |    12 |                                                                                                                             |
| API reference pages (events)                  |     2 |                                                                                                                             |
| API reference pages (total)                   |   271 | sum of all reference categories                                                                                             |
| Total documentation files (developer-focused) |    46 | 21 developer guides + 16 Fast Start guides + 9 Strategic Guide documents (excluding `reference/`)                           |
| Security Guide (lines)                        | 2,326 | bespoke threat-model guide; counted from `docs/Security - Guide.md`                                                         |

> The headline figure quoted in companion docs is 37 developer documents (21 guides + 16 Fast Starts) plus 271 API reference pages, matching the per-category totals above.

## Code Quality & Scanning

| Metric                       | Count |
|------------------------------|------:|
| PMD rules (KernDX custom)    |    26 |
| ESLint rules (KernDX custom) |     7 |
| Node validators              |     4 |
| Total scanner checks         |    37 |

## Release Testing

| Metric                                | Count |
|---------------------------------------|------:|
| Subscriber Apex classes (production)  |    65 |
| Subscriber test classes               |    46 |
| Subscriber test methods               |   205 |
| Anonymous Apex test sections          |    76 |
| Anonymous Apex assertions (`PASS:`)   |   417 |
| Anonymous Apex assertions (`Assert.`) |   561 |

## E2E Tests (Playwright)

| Metric              | Count |
|---------------------|------:|
| Spec files          |    13 |
| Test cases          |   103 |
| Page objects        |    14 |
| Helper modules      |     8 |
| CMDT fixture states |    24 |

> The Test cases row counts the functional release-verification specs (parts 1 to 10). Three further spec files sit outside that count: two capture the documentation screenshots (15 cases between them) and one checks the Log Console's shipped screens against the agreed design (2 cases). The Spec files row counts all 13 files.

## Combined Test Coverage

| Layer                       |         Tests |  Assertions |
|-----------------------------|--------------:|------------:|
| Package Apex tests          | 4,341 methods |      ~7,729 |
| Package Jest tests          |   3,275 cases |      ~5,054 |
| Subscriber Apex tests       |   205 methods |        ~349 |
| Subscriber anonymous Apex   |   76 sections |         417 |
| Subscriber E2E (Playwright) |     103 cases |        ~342 |
| **Total**                   |     **8,000** | **~13,885** |

> The Tests column is recounted from source every release. The Assertions column carries forward from the 1.6 reconciliation and was not recounted this release.

## Activity Snapshot

These figures describe how well-supported and ready-to-install the package is, measured at the snapshot date (2026-08-17). They are kept separate from the capability counts on purpose: how long a project has been active should not be confused with how much it does, so neither number skews the other. Figures derive from `sfdx-project.json` `packageAliases`.

| Metric                             |                Value | Source                                                                                  |
|------------------------------------|---------------------:|-----------------------------------------------------------------------------------------|
| Published managed-package versions |                  136 | `sfdx-project.json` `packageAliases`: `04tfj000000EtB7AAK` through `04tfj000000ScTlAAK` |
| Latest packaged version            | 1.7.0-8 (candidate) | `sfdx-project.json` `packageAliases`                                                    |
| Primary contributors               |                    1 | single-maintainer project                                                               |

> KernDX is a single-maintainer project. Its readiness to install shows up in the 136 published managed-package versions, rather than in a long public commit history. So what this means for you: the package itself is well-exercised through repeated releases, even though it does not yet have the years-long open commit log of an older project.

## The Other Frameworks We Compared

When the guides rank or compare KernDX, they measure it against the same group of other Salesforce frameworks across the same capability areas, so every comparison is like-for-like. This page only points you to the detail rather than repeating it: the Adoption and Architecture guides walk through how each area is covered, and the Risks guide covers maintenance and the bus-factor question (what happens if the people who built it move on).

---

[Strategic Guide (Overview)](Strategic%20Guide%20-%20Overview.md)
