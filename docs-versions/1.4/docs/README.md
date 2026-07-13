# KernDX - Developer Documentation

This page is the map to everything you can read about KernDX. It is for anyone building on the framework, whether you are a brand-new Salesforce developer looking for a quick task guide or an architect comparing design choices. Skim the [Learning Paths](#learning-paths) if you are starting out, jump to a [Fast Start](#fast-starts) when you have a specific task, or open a full [Guide](#guides) when you want the complete picture.

> **Using an AI coding assistant?** Load [`docs/AI Agent Instructions.md`](AI%20Agent%20Instructions.md)
> into it before generating KernDX code. That one file is the assistant's complete context for writing
> selectors, triggers, callouts, LWC, and tests the KernDX way. It's already in this repo and release; see
> its header for exactly how to wire it into your tool.

## Table of Contents

<details>
<summary>Expand</summary>

1. [Before You Begin](#before-you-begin)
2. [Learning Paths](#learning-paths)
3. [Fast Starts](#fast-starts)
    - [Data Access](#data-access)
    - [Triggers & Validation](#triggers--validation)
    - [Web Services](#web-services)
    - [Operations](#operations)
    - [Security](#security)
    - [User Interface](#user-interface)
    - [Code Quality](#code-quality)
    - [Testing](#testing)
4. [Guides](#guides)
    - [Core Frameworks](#core-frameworks)
    - [Data & Security](#data--security)
    - [UI](#ui)
    - [Utilities](#utilities)
    - [Code Quality](#code-quality-1)
    - [Testing](#testing-1)
5. [API Reference](#api-reference)
6. [Special Documents](#special-documents)
    - [Strategic Guide (9 documents)](#strategic-guide-9-documents)
7. [Choosing the Right Document](#choosing-the-right-document)

</details>

---

## Before You Begin

Verify these prerequisites before starting any Fast Start guide:

- [ ] **Salesforce org access**: a developer or sandbox org with admin permissions
- [ ] **Salesforce DX**: the `sf` CLI installed and authenticated to your org
- [ ] **KernDX deployed**: the KernDX managed package installed
- [ ] **API version 67.0**: org and project metadata aligned to API 67.0
- [ ] **Custom Metadata access**: permission to create and edit Custom Metadata Type records

---

## Learning Paths

Choose the path that matches your project needs:

**Data Layer Path**
> [Selectors](Fast%20Start%20-%20Selectors.md) → [DML](Fast%20Start%20-%20DML.md) → [Security](Fast%20Start%20-%20Security.md) → [Data Masking](Fast%20Start%20-%20Data%20Masking.md) → [Test Data](Fast%20Start%20-%20Test%20Data.md)

**Automation Path**
> [Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) → [Custom Validations](Fast%20Start%20-%20Custom%20Validations.md) → [Async Processing](Fast%20Start%20-%20Async%20Processing.md) → [Logging](Fast%20Start%20-%20Logging.md)

**Integration Path**
> [Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md) → [Resilience](Fast%20Start%20-%20Resilience.md) → [Inbound APIs](Fast%20Start%20-%20Inbound%20APIs.md) → [Async Chains](Fast%20Start%20-%20Async%20Processing.md) → [Feature Flags](Fast%20Start%20-%20Feature%20Flags.md) → [Logging](Fast%20Start%20-%20Logging.md)

**Testing Path**
> [Test Data](Fast%20Start%20-%20Test%20Data.md) → [E2E Testing](Fast%20Start%20-%20E2E%20Testing.md)

**Quality Path**
> [Code Scanning](Fast%20Start%20-%20Code%20Scanning.md) → [Logging](Fast%20Start%20-%20Logging.md) → [E2E Testing](Fast%20Start%20-%20E2E%20Testing.md)

**UI Path**
> [LWC](Fast%20Start%20-%20LWC.md) → [E2E Testing](Fast%20Start%20-%20E2E%20Testing.md)

---

## Fast Starts

Have a specific task in mind? These short, focused guides walk you through one job at a time so you can build it quickly.

### Data Access

| Name                                           | Description                                  | Key Reference                                                                                |
|------------------------------------------------|----------------------------------------------|--------------------------------------------------------------------------------------------|
| [Selectors](Fast%20Start%20-%20Selectors.md)   | Build object selectors and fluent queries    | [SEL_Base](reference/apex/SEL_Base.md), [QRY_Builder](reference/apex/QRY_Builder.md)       |
| [DML](Fast%20Start%20-%20DML.md)               | Insert, update, delete with Unit of Work     | [DML_Builder](reference/apex/DML_Builder.md)                                               |
| [Test Data](Fast%20Start%20-%20Test%20Data.md) | Create test data with builders and factories | [TST_Builder](reference/apex/TST_Builder.md), [TST_Factory](reference/apex/TST_Factory.md) |

### Triggers & Validation

| Name                                                             | Description                           | Key Reference                                                                                                                                |
|------------------------------------------------------------------|---------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| [Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)       | Build metadata-driven trigger actions | [TRG_Dispatcher](reference/apex/TRG_Dispatcher.md), [TRG_Base](reference/apex/TRG_Base.md), [IF_Trigger](reference/apex/IF_Trigger.md)     |
| [Custom Validations](Fast%20Start%20-%20Custom%20Validations.md) | Build formula-driven validation rules | [UTIL_ValidationRule](reference/apex/UTIL_ValidationRule.md), [FLOW_ExecuteValidationRules](reference/apex/FLOW_ExecuteValidationRules.md) |

### Web Services

| Name                                                   | Description                                | Key Reference                                                                                                                                          |
|--------------------------------------------------------|--------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md) | Call external REST APIs                    | [API_Outbound](reference/apex/API_Outbound.md), [DTO_JsonBase](reference/apex/DTO_JsonBase.md), [UTIL_HttpClient](reference/apex/UTIL_HttpClient.md) |
| [Inbound APIs](Fast%20Start%20-%20Inbound%20APIs.md)   | Expose REST endpoints for external callers | [API_Inbound](reference/apex/API_Inbound.md), [API_Dispatcher](reference/apex/API_Dispatcher.md)                                                     |
| [Resilience](Fast%20Start%20-%20Resilience.md)         | Retry, backoff, and circuit breaker for flaky callouts | [UTIL_HttpClient](reference/apex/UTIL_HttpClient.md), [UTIL_Retry](reference/apex/UTIL_Retry.md), [UTIL_CircuitBreaker](reference/apex/UTIL_CircuitBreaker.md) |

### Operations

| Name                                                         | Description                                                              | Key Reference                                                                                                                                      |
|--------------------------------------------------------------|--------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| [Async Processing](Fast%20Start%20-%20Async%20Processing.md) | Adaptive async jobs, chain orchestration with shared context, scheduling | [IF_Async](reference/apex/IF_Async.md), [UTIL_AsyncChain](reference/apex/UTIL_AsyncChain.md), [IF_Schedulable](reference/apex/IF_Schedulable.md) |
| [Logging](Fast%20Start%20-%20Logging.md)                     | Application logging and monitoring                                       | [LOG_Builder](reference/apex/LOG_Builder.md)                                                                                                     |
| [Feature Flags](Fast%20Start%20-%20Feature%20Flags.md)       | Metadata-driven feature toggles                                          | [UTIL_FeatureFlag](reference/apex/UTIL_FeatureFlag.md)                                                                                           |

### Security

| Name                                         | Description                                  | Key Reference                                                                          |
|----------------------------------------------|----------------------------------------------|--------------------------------------------------------------------------------------|
| [Security](Fast%20Start%20-%20Security.md)   | Queries and DML that run with the user's own permissions and sharing by default (USER_MODE) | [QRY_Builder](reference/apex/QRY_Builder.md), [DML_Builder](reference/apex/DML_Builder.md) |
| [Data Masking](Fast%20Start%20-%20Data%20Masking.md) | Redact cards, secrets, and PII on records before they save | [MaskingTarget__mdt](reference/metadata/MaskingTarget__mdt.md), [UTIL_FeatureFlag](reference/apex/UTIL_FeatureFlag.md) |

### User Interface

| Name                                | Description                                                         | Key Reference                       |
|-------------------------------------|---------------------------------------------------------------------|-----------------------------------|
| [LWC](Fast%20Start%20-%20LWC.md)    | Build Lightning Web Components on the ComponentBuilder base class    | [LWC - Guide](LWC%20-%20Guide.md) |

### Code Quality

| Name                                                   | Description                                                          | Key Reference |
|--------------------------------------------------------|----------------------------------------------------------------------|-------------|
| [Code Scanning](Fast%20Start%20-%20Code%20Scanning.md) | PMD and ESLint enforcement of framework conventions in IDE and CI/CD | [Code Scanning - Guide](Code%20Scanning%20-%20Guide.md)           |

### Testing

| Name                                               | Description                                             | Key Reference |
|----------------------------------------------------|---------------------------------------------------------|-------------|
| [E2E Testing](Fast%20Start%20-%20E2E%20Testing.md) | Browser-based Playwright tests for Salesforce Lightning | [E2E Testing - Guide](E2E%20Testing%20-%20Guide.md)           |

---

## Guides

In-depth reference guides. Open one of these when you want the complete picture of a framework area: what it can do, the patterns behind it, and the recommended way to use it.

### Core Frameworks

| Name                                                          | Description                                                                                                                  |
|---------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| [Selectors - Guide](Selectors%20-%20Guide.md)                 | Layered query architecture, QRY_Builder, sharing enforcement, caching, pagination                                            |
| [Triggers - Guide](Triggers%20-%20Guide.md)                   | Metadata-driven trigger actions, bypass mechanisms, entry criteria, recursion prevention                                     |
| [Validation - Guide](Validation%20-%20Guide.md)               | Formula-driven validation, bypass hierarchy, shadow mode, Flow integration                                                   |
| [DML - Guide](DML%20-%20Guide.md)                             | Unit of Work, bulk DML, sharing enforcement, CRUD/FLS, data purge                                                            |
| [Async Processing - Guide](Async%20Processing%20-%20Guide.md) | Adaptive async processing, chain orchestration with shared context, ApiStep web service bridge, Chain Monitor UI, scheduling |
| [Web Services - Guide](Web%20Services%20-%20Guide.md)         | Outbound/inbound REST, named credentials, retry logic, Flow integration                                                      |
| [Resilience - Guide](Resilience%20-%20Guide.md)               | Retry strategies, exponential/linear backoff, jitter, circuit breaker states, declarative resilience on registered handlers  |
| [Logging - Guide](Logging%20-%20Guide.md)                     | Application logging, async log publishing, log filtering, and the Log Console for browsing and diagnosing what was logged                                                         |
| [Feature Flags - Guide](Feature%20Flags%20-%20Guide.md)       | Metadata-driven flags, targeting strategies, custom strategy handlers, Apex/Flow/LWC checks                                  |

### Data & Security

| Name                                                                  | Description                                                                        |
|-----------------------------------------------------------------------|------------------------------------------------------------------------------------|
| [Data Masking - Guide](Data%20Masking%20-%20Guide.md)                 | Write-time field redaction, masking rules and targets, the Data Masking Advisor    |
| [DTOs - Guide](DTOs%20-%20Guide.md)                                   | JSON serialisation, SObject transformation, populate/transform patterns, JsonPath  |
| [Security - Guide](Security%20-%20Guide.md)                           | CRUD/FLS enforcement, sharing control, encryption                                  |
| [Objects & Metadata - Guide](Objects%20%26%20Metadata%20-%20Guide.md) | Custom objects, platform events, and custom metadata types included in the package |

### UI

| Name                                                                    | Description                                                                                                              |
|-------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| [LWC - Guide](LWC%20-%20Guide.md)                                       | ComponentBuilder pattern, utility modules, pre-built components, Jest testing                                             |
| [Administration Tools - Guide](Administration%20Tools%20-%20Guide.md)   | Kern Home and the built-in tools: API Test Harness, Streaming Event Monitor, Chain Monitor, Data Masking Advisor, Log Console |

### Utilities

| Name                                          | Description                                                                                       |
|-----------------------------------------------|---------------------------------------------------------------------------------------------------|
| [Utilities - Guide](Utilities%20-%20Guide.md) | String, date, number, collection utilities, type resolution, random data, feature flags, indexing |

### Code Quality

| Name                                                    | Description                                                                        |
|---------------------------------------------------------|------------------------------------------------------------------------------------|
| [Code Scanning - Guide](Code%20Scanning%20-%20Guide.md) | PMD rulesets, ESLint plugin, naming validators, CI/CD integration, phased adoption |

### Testing

| Name                                                | Description                                                                          |
|-----------------------------------------------------|--------------------------------------------------------------------------------------|
| [Test Data - Guide](Test%20Data%20-%20Guide.md)     | TST_Builder, TST_Mock, TST_Factory: auto-population, bulk creation, relationships, DML-free query mocking |
| [E2E Testing - Guide](E2E%20Testing%20-%20Guide.md) | Playwright E2E testing for Salesforce: authentication, helpers, page objects, CI/CD |

---

## API Reference

Auto-generated API reference documentation for all Apex classes, custom objects, platform events, and custom metadata types.

**[API Reference Index](reference/index.md)**

| Category              | Link                                  |
|-----------------------|---------------------------------------|
| Apex Classes          | [Browse](reference/apex/index.md)     |
| Custom Objects        | [Browse](reference/objects/index.md)  |
| Platform Events       | [Browse](reference/events/index.md)   |
| Custom Metadata Types | [Browse](reference/metadata/index.md) |

---

## Special Documents

| Document                                                      | Description                                                                                     |
|---------------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| [AI Agent Instructions](AI%20Agent%20Instructions.md)         | Complete framework reference for AI agents, repackaging with custom namespace, org setup |
| [Code Conventions - Guide](Code%20Conventions%20-%20Guide.md) | Canonical Apex/LWC/JS coding conventions: naming, formatting, ApexDoc, anti-patterns           |
| [Installation](Installation.md)                               | Your org configuration, post-install steps, health check verification                     |

### Strategic Guide (9 documents)

| Document                                                                                | Description                                                                                                                       |
|-----------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| [Overview](Strategic%20Guide%20-%20Overview.md)                                         | Executive tear sheet, key findings, recommendations, navigation hub                                                               |
| [Architecture & Philosophy](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md) | Design principles, capabilities, Well-Architected + Security Benchmark for Salesforce alignment                                   |
| [Adoption](Strategic%20Guide%20-%20Adoption.md)                                         | Enterprise delivery, TCO model, decision matrices, build-vs-buy economics                                                         |
| [Choosing a Framework](Strategic%20Guide%20-%20Choosing%20a%20Framework.md)             | Capability-by-capability comparison against the established Apex frameworks, pick-by-capability guidance, head-to-head trade-offs |
| [Operations](Strategic%20Guide%20-%20Operations.md)                                     | Day-2 ownership, packaging, exit strategy, observability                                                                          |
| [Risks](Strategic%20Guide%20-%20Risks.md)                                               | Risk register and mitigations for adoption decisions                                                                              |
| [Personas](Strategic%20Guide%20-%20Personas.md)                                         | Stakeholder-specific decision views (CTO, architect, developer, PM, ISV)                                                          |
| [Glossary](Strategic%20Guide%20-%20Glossary.md)                                         | Term definitions with links to relevant sections                                                                                  |
| [Metrics](Strategic%20Guide%20-%20Metrics.md)                                           | Canonical framework metrics: class counts, test coverage, metadata totals                                                        |

---

## Choosing the Right Document

| I want to...                                           | Start with                                                                                  |
|--------------------------------------------------------|---------------------------------------------------------------------------------------------|
| Learn KernDX for the first time                        | [Learning Paths](#learning-paths)                                                           |
| Build a selector or query data                         | [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md)                                   |
| Build a trigger action                                 | [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)                     |
| Build a validation rule                                | [Fast Start - Custom Validations](Fast%20Start%20-%20Custom%20Validations.md)               |
| Insert, update, or delete records                      | [Fast Start - DML](Fast%20Start%20-%20DML.md)                                               |
| Call an external API                                   | [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md)                         |
| Make a simple ad-hoc HTTP call                         | [UTIL_HttpClient](reference/apex/UTIL_HttpClient.md)                                        |
| Expose a REST endpoint                                 | [Fast Start - Inbound APIs](Fast%20Start%20-%20Inbound%20APIs.md)                           |
| Create test data                                       | [Fast Start - Test Data](Fast%20Start%20-%20Test%20Data.md)                                 |
| Process large data sets asynchronously                 | [Fast Start - Async Processing](Fast%20Start%20-%20Async%20Processing.md)                   |
| Orchestrate multi-step async workflows                 | [Async Processing - Guide](Async%20Processing%20-%20Guide.md) (Chain Orchestration section) |
| Chain outbound API calls in sequence                   | [Async Processing - Guide](Async%20Processing%20-%20Guide.md) (ApiStep section)             |
| Add logging to my code                                 | [Fast Start - Logging](Fast%20Start%20-%20Logging.md)                                       |
| Browse and diagnose production logs                    | [Logging - Guide](Logging%20-%20Guide.md#the-log-console) (The Log Console section)         |
| Monitor integrations, jobs, and logs from one place    | [Administration Tools - Guide](Administration%20Tools%20-%20Guide.md)                       |
| Toggle features on and off                             | [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md)                         |
| Make a flaky callout resilient (retry, circuit breaker) | [Fast Start - Resilience](Fast%20Start%20-%20Resilience.md)                                |
| Enforce CRUD/FLS on every read and write (USER_MODE)   | [Fast Start - Security](Fast%20Start%20-%20Security.md)                                     |
| Build my first Lightning Web Component                 | [Fast Start - LWC](Fast%20Start%20-%20LWC.md)                                               |
| Understand full query architecture                     | [Selectors - Guide](Selectors%20-%20Guide.md)                                               |
| Understand full trigger framework                      | [Triggers - Guide](Triggers%20-%20Guide.md)                                                 |
| Transform data between formats (DTOs)                  | [DTOs - Guide](DTOs%20-%20Guide.md)                                                         |
| Enforce CRUD/FLS or encrypt data                       | [Security - Guide](Security%20-%20Guide.md)                                                 |
| Control record-level sharing at runtime                | [Security - Guide](Security%20-%20Guide.md)                                                 |
| Redact sensitive data before it is stored              | [Fast Start - Data Masking](Fast%20Start%20-%20Data%20Masking.md)                           |
| Configure the data masking framework and Advisor       | [Data Masking - Guide](Data%20Masking%20-%20Guide.md)                                       |
| Build Lightning Web Components                         | [LWC - Guide](LWC%20-%20Guide.md)                                                           |
| Use string, date, number, or collection utilities      | [Utilities - Guide](Utilities%20-%20Guide.md)                                               |
| Evaluate KernDX vs fflib trade-offs                    | [Choosing a Framework](Strategic%20Guide%20-%20Choosing%20a%20Framework.md)                 |
| Set up KernDX in a subscriber org                      | [Installation](Installation.md)                                                             |
| Configure AI-assisted KernDX development               | [AI Agent Instructions](AI%20Agent%20Instructions.md)                                       |
| Write browser-based E2E tests                          | [Fast Start - E2E Testing](Fast%20Start%20-%20E2E%20Testing.md)                             |
| Enforce framework conventions in CI/CD                 | [Fast Start - Code Scanning](Fast%20Start%20-%20Code%20Scanning.md)                         |
| Build custom PMD rules or adopt scanning incrementally | [Code Scanning - Guide](Code%20Scanning%20-%20Guide.md)                                     |
| Design an E2E test strategy               | [E2E Testing - Guide](E2E%20Testing%20-%20Guide.md)                                         |
| Look up a specific class API                           | [API Reference](reference/apex/index.md)                                                    |
