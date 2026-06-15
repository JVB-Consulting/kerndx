# Kern 1.0 — Feature Reference

**Initial release:** March 2026 · **Latest release:** 1.0.0-121 (May 2026 — promoted for production install)
**API Version:** 66.0
**Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md) for white-label deployments)

> This document is the **comprehensive v1.0 feature reference** — every shipping module, what it does, and the subscriber-visible surface. For chronological per-version changes (what's new since the last build), see the [CHANGELOG](../CHANGELOG.md).

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Overview](#overview)
2. [Core Frameworks](#core-frameworks)
    - [Query Framework (QRY_Builder)](#query-framework-qry_builder)
    - [Selector Framework (SEL_Base)](#selector-framework-sel_base)
    - [DML Framework (DML_Builder, DML_Transaction)](#dml-framework-dml_builder-dml_transaction)
    - [Trigger Framework (TRG_Dispatcher, TRG_Base)](#trigger-framework-trg_dispatcher-trg_base)
    - [Web Services Framework (API_Outbound, API_Inbound)](#web-services-framework-api_outbound-api_inbound)
    - [HTTP Client (UTIL_HttpClient)](#http-client-util_httpclient)
3. [Validation Framework](#validation-framework)
4. [Feature Flags](#feature-flags)
5. [Resilience & Fault Tolerance](#resilience--fault-tolerance)
    - [Circuit Breaker (UTIL_CircuitBreaker)](#circuit-breaker-util_circuitbreaker)
    - [Retry Strategy (UTIL_Retry)](#retry-strategy-util_retry)
    - [Platform Cache (UTIL_Cache)](#platform-cache-util_cache)
6. [Logging & Observability](#logging--observability)
    - [Structured Logging (LOG_Builder)](#structured-logging-log_builder)
    - [Performance Monitoring](#performance-monitoring)
    - [LWC Client Logger](#lwc-client-logger)
    - [Flow Logger](#flow-logger)
7. [Asynchronous Processing](#asynchronous-processing)
    - [Adaptive Async (UTIL_AsynchronousJobLauncher)](#adaptive-async-util_asynchronousjoblauncher)
    - [Chain Orchestration (UTIL_AsyncChain)](#chain-orchestration-util_asyncchain)
    - [Chain Monitor (4 LWC Components)](#chain-monitor-4-lwc-components)
8. [Test Infrastructure](#test-infrastructure)
    - [TST_Builder](#tst_builder)
    - [TST_Mock.MockBuilder](#tst_mockmockbuilder)
    - [TST_Mock](#tst_mock)
    - [TST_Factory](#tst_factory)
    - [API_OutboundTestHelper](#api_outboundtesthelper)
    - [API_InboundTestHelper](#api_inboundtesthelper)
    - [API_MockFactory](#api_mockfactory)
9. [Schema & Metadata Utilities](#schema--metadata-utilities)
    - [Schema Cache (UTIL_SObjectDescribe)](#schema-cache-util_sobjectdescribe)
    - [Object Hierarchy Traversal (SEL_Hierarchy)](#object-hierarchy-traversal-sel_hierarchy)
10. [Data Masking](#data-masking)
    - [Framework Overview](#framework-overview)
    - [Default Ship Set](#default-ship-set)
    - [Shipped Rule Templates](#shipped-rule-templates)
    - [Performance](#performance)
11. [Record Sharing](#record-sharing)
    - [UTIL_Sharing](#util_sharing)
12. [Lightning Web Components](#lightning-web-components)
    - [ComponentBuilder](#componentbuilder)
    - [Components](#components)
13. [Custom Objects & Metadata](#custom-objects--metadata)
    - [Custom Objects](#custom-objects)
    - [Custom Metadata Types](#custom-metadata-types)
14. [Quality & Coverage](#quality--coverage)

</details>

---

## Overview

Kern is an enterprise Salesforce managed package framework providing production-ready implementations of common platform patterns: queries, selectors, DML, triggers, web services,
validation, feature flags, logging, and asynchronous processing.

**Key Principles:**

| Principle                 | Implementation                                                                 |
|---------------------------|--------------------------------------------------------------------------------|
| No inline SOQL            | Use `SEL_*` selectors or `QRY_Builder`                                         |
| No `System.debug`         | Use `LOG_Builder` with structured context                                      |
| Declarative configuration | Custom metadata drives triggers, validation, feature flags, and web services   |
| 100% test coverage        | Mandatory on all Apex and LWC                                                  |
| Explicit sharing          | Every class declares `with sharing`, `inherited sharing`, or `without sharing` |

**Documentation:**

| Guide                                                          | Description                                                  |
|----------------------------------------------------------------|--------------------------------------------------------------|
| [AI Agent Instructions](../docs/AI%20Agent%20Instructions.md)  | Complete framework reference and subscriber setup            |
| [Strategic Guide](../docs/Strategic%20Guide%20-%20Overview.md) | Architecture decisions and framework positioning             |
| [Documentation Hub](../docs/README.md)                         | Complete index of all guides, fast starts, and API reference |

---

## Core Frameworks

### Query Framework (QRY_Builder)

Fluent query builder covering 95% of query scenarios with automatic bind variable parameterization for injection safety.

**Guide:** [Selectors - Guide](../docs/Selectors%20-%20Guide.md) | **Fast Start:** [Selectors](../docs/Fast%20Start%20-%20Selectors.md)

**Capabilities:**

- Condition operators: `equals`, `notEquals`, `greaterThan`, `lessThan`, `isIn`, `notIn`, `isNull`, `contains`, `startsWith`, `endsWith`, `includes`, `excludes`
- Aggregate functions (SUM, AVG, MIN, MAX, COUNT) with HAVING support
- Cursor-based pagination with metadata (`.getPage(pageNumber, pageSize)`)
- Platform cache integration with configurable TTL (`.withCache(seconds)`)
- Result transformation: `.asMap()`, `.asIdSet()`, `.toList()`, `.getFirst()`
- Semi-join subqueries (`.isIn(Builder)`, `.notIn(Builder)`)
- Random results (`.getRandomItem()`, `.getRandomItems(count)`)
- Mock support for DML-free unit testing
- **Secure by default:** queries default to USER_MODE (CRUD + FLS + sharing enforced). Controlled by `FeatureFlag.UserModeQueries_Enabled` (ships `true`). Call `.withSystemMode()`
  per-query to bypass, or override `SEL_Base.systemModeRequired()` to pin a selector to SYSTEM_MODE. `AccessLevel` now propagates correctly through async DML paths (queueable,
  batch, scheduled).
- Independent security options: `.withUserMode()`, `.withSystemMode()`, `.stripInaccessible()`, `.withSharing()`, `.bypassSharing()`
- Native SObject binding — pass `List<SObject>` directly to `.isIn()` without manual Id extraction
- Field extraction from SObjects (`.isIn(contacts, Contact.Email)`)
- Strict collection conditions (`.isInStrict()`, `.notInSetStrict()`) that throw on empty collections
- Multi-field GROUP BY with ROLLUP and CUBE modes for subtotals and cross-tabulation
- `GROUPING()` function support for identifying subtotal rows in ROLLUP/CUBE results
- `WITH DATA CATEGORY` clause via `DataCategoryBuilder` — fluent filtering by data category hierarchy (AT, ABOVE, BELOW, ABOVE_OR_BELOW) for Knowledge article queries
- SOQL functions (`CALENDAR_MONTH`, `toLabel`, `FORMAT`, etc.) supported via string overloads on `.addField()`, `.groupBy()`, and `.condition()`

### Selector Framework (SEL_Base)

Object-specific query layer with default field sets, field paths, and inherited query methods.

**Guide:** [Selectors - Guide](../docs/Selectors%20-%20Guide.md) | **Fast Start:** [Selectors](../docs/Fast%20Start%20-%20Selectors.md)

**Capabilities:**

- Extend `SEL_Base`, define default fields via `getFields()`
- Inherited methods: `findById()`, `findByField()`, `findByFields()`, `findFirstByFields()`, `findByIdOrThrow()`
- Relationship traversal via `getFieldPaths()`
- Integrates with `QRY_Builder` for ad-hoc conditions

### DML Framework (DML_Builder, DML_Transaction)

Transactional DML with Unit of Work pattern.

**Guide:** [DML - Guide](../docs/DML%20-%20Guide.md) | **Fast Start:** [DML](../docs/Fast%20Start%20-%20DML.md)

**Capabilities:**

- Fluent API: `DML_Builder.newTransaction().doInsert(records).execute()`
- Partial success: `.allowPartial()`
- External ID upsert: `.doUpsert(records, externalIdField)`
- Record relationship registration for parent-child inserts
- Automatic error handling and logging
- Async DML: `.async()` with configurable `.withBatchSize()`. `AccessLevel` propagates correctly across the async boundary so the enqueued transaction honours the same user-mode
  decision as the enqueuer.
- **Secure by default:** writes default to USER_MODE (CRUD + FLS + sharing enforced). Controlled by `FeatureFlag.UserModeDml_Enabled` (ships `true`). Call `.withSystemMode()` on
  the transaction to bypass — e.g., for writes to framework-owned audit objects.
- Sharing control: `.withUserMode()`, `.withSystemMode()`, `.bypassSharing()`
- Suppression: `.suppressExceptions()`, `.suppressLogging()`

### Trigger Framework (TRG_Dispatcher, TRG_Base)

Metadata-driven trigger dispatch with ordered action execution.

**Guide:** [Triggers - Guide](../docs/Triggers%20-%20Guide.md) | **Fast Start:** [Trigger Actions](../docs/Fast%20Start%20-%20Trigger%20Actions.md)

**Capabilities:**

- One trigger per object, dispatched via `TRG_Dispatcher` (standalone — does not extend `TRG_Base`)
- Action classes extend `TRG_Base`, implement `IF_Trigger.BeforeInsert`, `IF_Trigger.AfterUpdate`, etc.
- Metadata configuration: `TriggerAction__mdt` uses `TriggerSetting__c` (which object) + `Event__c` (which trigger event)
- `TriggerSetting__mdt` uses `SObjectType__c` — MetadataRelationship to `EntityDefinition` (validated object picker, namespace-safe)
- Record naming convention: `ClassName_Event` (e.g., `SetFoobarDefaults_BeforeInsert`)
- Two-level programmatic bypass on `TRG_Base`: object-level (`bypass`/`isBypassed`/`clearBypass`) and action-level (`bypassAction`/`isActionBypassed`/`clearActionBypass`)
- Declarative bypass via `TriggerSetting__mdt.BypassExecution__c` and `TriggerAction__mdt.BypassExecution__c`
- **Bypass audit logging (always on):** every `bypass*()` / `clear*Bypass()` call emits a `LogEntryEvent__e` with category `BypassEvent` — the runtime audit trail is always on. Set
  a free-text reason for the whole transaction via `TRG_Base.setBypassReason(String)` and it attaches to every subsequent bypass emission.
- `triggerOldMap` — lazy-loaded `Map<Id, SObject>` on `TRG_Base` for field change detection in update handlers
- Feature flag integration — actions can require a feature flag or custom permission
- Recursion prevention and self-initiated trigger detection
- Performance logging with configurable thresholds

### Web Services Framework (API_Outbound, API_Inbound)

Structured HTTP callout and inbound REST framework.

**Guide:** [Web Services - Guide](../docs/Web%20Services%20-%20Guide.md)
**Fast Starts:** [Outbound APIs](../docs/Fast%20Start%20-%20Outbound%20APIs.md), [Inbound APIs](../docs/Fast%20Start%20-%20Inbound%20APIs.md)

**Capabilities:**

- Outbound: extend `API_Outbound`, configure via custom metadata, auto-mock in tests
- Inbound: extend `API_Inbound` for REST endpoint handlers
- Record-based processing via `ApiCall__c`
- Callout-safe async processing — configurable job size via `AsynchronousJobSetting__mdt` (default 20, hard cap 100), with automatic budget monitoring that defers remaining calls
  when the governor limit is reached
- Configurable retry strategies (linear, exponential backoff)
- Required input validation via `getRequiredInputs()`
- Triggering object validation via `getValidationErrors()`
- DTO pattern with `DTO_JsonBase` for request/response serialization
- Correlation ID propagation across async boundaries
- Dynamic routing — inbound request routing by path + HTTP method with wildcard support (`ApiSetting__mdt`)
- Safe Mode — dry-run execution with guaranteed DML rollback via `API_Base.enterSafeMode()`
- `API_MockFactory` — three-tier mock resolution (memory, metadata, static resource) with call verification
- Fault simulation — configurable delays and failure rates via `ApiMock__mdt`
- Programmatic invocation — framework-level API invocation without HTTP traffic, accessible via API Test Harness LWC
- W3C Distributed Tracing — `traceparent` header propagation across inbound/outbound chains
- Idempotency — framework-level duplicate detection with configurable TTL
- Dead Letter Queue — automatic dead-lettering after max retries with recovery support
- API Test Harness — LWC-based developer UI for invoking any API with Safe Mode and mocking controls

### HTTP Client (UTIL_HttpClient)

Fluent HTTP client for external service integration. Static factories, automatic retry, circuit breaker integration, and structured logging.

**Guide:** [Web Services - Guide](../docs/Web%20Services%20-%20Guide.md)

**Capabilities:**

- Static factories: `get()`, `post()`, `put()`, `del()`, `patch()` with Named Credential or `ApiCredential__mdt` support
- Request building: `.body()`, `.header()`, `.headers()`, `.queryParam()`, `.pathParam()`, `.timeout()`
- Retry strategies: `.withRetry()` (linear), `.withExponentialBackoff()` (exponential), `.retryOn()` (status codes)
- Resilience: `.withCircuitBreaker()`, `.onFailure(FailureAction)`
- Observability: `.withCorrelationId()`, `.withTriggeringRecord()`, `.skipLogging()`
- Token replacement: `.replaceRequestToken()`, `.replaceResponseToken()` for URL/body templating
- Idempotency: `.withIdempotencyKey()` for duplicate request prevention
- Terminal methods: `.send()` (raw `HttpResponse`), `.asString()`, `.asMap()`, `.deserialize(Type)`
- Delegation: `.useHandler(Type).credential().withParameter().invoke()` for framework-routed API calls

---

## Validation Framework

Formula-driven declarative validation via custom metadata, using Salesforce's `FormulaEval` namespace.

**Guide:** [Validation - Guide](../docs/Validation%20-%20Guide.md) | **Fast Start:** [Custom Validations](../docs/Fast%20Start%20-%20Custom%20Validations.md)

**Capabilities:**

- `ValidationRuleGroup__mdt` groups rules by object and trigger context
- `ValidationRule__mdt` defines individual rules with formula expressions
- Three-level bypass hierarchy: Object, Group, Rule
- Shadow mode for production testing without blocking saves
- Warning-level validations (log without blocking)
- Merge field support in error messages (`{!newRecord.FieldName}`)
- Field-level error attachment via `ErrorDisplayField__c`
- Native UX integration — trigger-based validations use standard `addError()` for page layout error display;
  `validationErrors` LWC is for Flow screens and custom Lightning pages
- Execution strategies: Accumulate (all errors) or Fail Fast (first error)
- Pre-built formula contexts for 9 standard objects (Account, Contact, Lead, Opportunity, Case, Campaign, Task, Event, User)
- Custom context support via `INT_SObjectFormulaEvaluationContext`
- Programmatic bypass: `UTIL_ValidationRule.bypassObject()`, `.bypassRule()`, `.clearBypass()`
- Feature flag integration — validation rules can require a feature flag
- Trigger integration: `TRG_ExecuteValidationRules`
- Flow integration: `FLOW_ExecuteValidationRules`
- LWC component: `validationErrors`

---

## Feature Flags

Custom metadata-driven feature toggles with pluggable evaluation strategies.

**Fast Start:** [Feature Flags](../docs/Fast%20Start%20-%20Feature%20Flags.md)

**Capabilities:**

- `UTIL_FeatureFlag.isEnabled(flagName)` for runtime feature checks
- User-context evaluation: `isEnabled(flagName, userId)` and `isEnabled(flagName, username)`
- Built-in strategies: Custom Permission, Profile, Percentage Rollout, Hierarchical Custom Setting, Custom Metadata, Public Group Membership
- Trigger action integration — actions can declare required feature flags
- Validation framework integration — rules can declare required feature flags
- API framework integration — services can be toggled via feature flags
- Flow integration: `FLOW_CheckFeatureFlag`
- Subscriber-first custom permission resolution with `core.` prefix for package permissions
- Scoped muting evaluation for Permission Set Groups

---

## Resilience & Fault Tolerance

### Circuit Breaker (UTIL_CircuitBreaker)

Three-state circuit breaker (CLOSED, OPEN, HALF_OPEN) preventing cascading failures in external service integrations.
Configurable failure threshold and timeout. Platform Cache integration for distributed state.

### Retry Strategy (UTIL_Retry)

Exponential and linear backoff strategies with configurable max retries and jitter. Prevents thundering herd problems. Integrates with the web services framework.

### Platform Cache (UTIL_Cache)

Intelligent cache management with AUTO mode. Automatic Session-to-Org cache fallback. Bulk operations (`getAll`, `putAll`).
User-scoped keys. Automatic compression for payloads exceeding 4KB.

---

## Logging & Observability

**Guide:** [Logging - Guide](../docs/Logging%20-%20Guide.md) | **Fast Start:** [Logging](../docs/Fast%20Start%20-%20Logging.md)

### Structured Logging (LOG_Builder)

Async logging via `LogEntryEvent__e` platform events with levels: DEBUG, INFO, WARN, ERROR.

**Capabilities:**

- Fluent API: `LOG_Builder.build().error(e).emitAt('Class.method')`
- Transaction correlation IDs linking logs across async boundaries
- Context serialization/hydration for async job transfer
- Global context key-value pairs with auto-serialization to JSON
- Log buffering to reduce platform event consumption (auto-flush at 500 logs per transaction)
- ERROR logs bypass buffer for immediate visibility
- Configurable log level thresholds via `LogSetting__c` to control event volume in high-throughput contexts

### Performance Monitoring

- Automatic timing with configurable thresholds
- Query execution time and row count tracking
- Trigger action performance logging with 3-tier hierarchy
- Data masking commit-time attribution via `UTIL_MaskerPerformanceTimer` — aggregate `LogEntryEvent__e` per masked trigger batch when the subscriber opts in with
  `LogSetting__c.EnableMaskerPerformanceLogging__c = true`. Default off so subscribers pay zero log volume by default. Threshold configured via
  `LogSetting__c.MaskerPerformanceThresholdMs__c` (default 100 ms). The emitted entry's `ClassMethod__c` carries the target SObject name (e.g.,
  `UTIL_MaskerPerformanceTimer/ApiCall__c`) for per-object aggregation.
- Configuration via `LogSetting__c` (hierarchy custom setting)

### LWC Client Logger

- JavaScript logging module (`utilityLogger`)
- Client-to-server correlation tracking
- Performance timers, log buffering, batch persistence via `CTRL_Logger`

### Flow Logger

- `FLOW_LoggerStart`, `FLOW_LoggerLog`, `FLOW_LoggerEnd`
- Bookend pattern for Flow logging with correlation

---

## Asynchronous Processing

**Guide:** [Async Processing - Guide](../docs/Async%20Processing%20-%20Guide.md) | **Fast Start:** [Async Processing](../docs/Fast%20Start%20-%20Async%20Processing.md)

### Adaptive Async (UTIL_AsynchronousJobLauncher)

Adaptive async processing with automatic strategy selection.

**Capabilities:**

- Execution strategies: AUTO (adaptive), QUEUEABLE, BATCH, SYNCHRONOUS
- Automatic strategy selection based on data volume and governor limits
- Automatic chunking of large datasets
- Finisher support via `IF_Async.Finishable`
- Delayed dispatch: `.withDelayMinutes(minutes)` for scheduled execution
- Automatic chaining for delays exceeding 10 minutes
- **Timezone-aware scheduling** — `ScheduledJob__c.Timezone__c` stores the authoring user's IANA timezone; the
  framework automatically adjusts cron hours at scheduling time so jobs fire at the intended absolute time regardless
  of which user activates them. Supports half-hour timezones (e.g., India UTC+5:30), day-of-week/month rollover, and
  boundary guards

### Chain Orchestration (UTIL_AsyncChain)

Multi-step async orchestration framework with shared context, execution tracking, and real-time monitoring.

**Capabilities:**

- Fluent builder API: `UTIL_AsyncChain.newChain('name').then(step).execute()`
- Shared `ChainContext` — typed key-value store persisted across Queueable transactions
- Per-step `continueOnError` — chain continues despite individual step failures
- Error and completion handler steps with transaction isolation (separate Queueable)
- Finalizer crash recovery — prevents zombie chains stuck in Running status
- Persistent execution record (`AsyncChainExecution__c`) with field history tracking
- Step log — JSON array of step definitions enriched at runtime with status, duration, and messages
- Correlation ID propagation via `LOG_Builder` across all chain transactions
- Feature flag kill switch (`FeatureFlag.AsyncChain`) — when inactive, new chains are immediately aborted
- Configurable max steps (default 50) and max context size (default 32K)
- `AsyncOptions` support for delayed enqueue

### Chain Monitor (4 LWC Components)

Real-time operational dashboard for async chain execution monitoring.

**Components:**

- `chainMonitor` — full-page split-panel layout (list + detail) with real-time streaming updates via `empApi` subscription to `LogEntryEvent__e`
- `chainMonitorList` — paginated datatable with status filter bar (Running, Completed, Failed, Aborted, Stalled), chain name search, multi-column sorting, and clickable record
  links
- `chainMonitorDetail` — execution detail with expandable accordion sections (Steps, Timing, Error), progress bar, and copyable correlation ID for log tracing
- `chainStepTimeline` — step-by-step visualization with status icons and hover popovers showing class name, status, duration, and continueOnError flag

Users reach the Chain Monitor from the Kern Home page — the Administration Tools section renders an `Open` card that navigates to the dedicated tab.

**Supporting infrastructure:**

- `CTRL_ChainMonitor` — Apex controller with paginated, filtered, sorted chain queries and DTOs
- `SEL_AsyncChainExecution` — selector with `findFiltered()` for multi-criteria queries
- FlexiPages for Chain Monitor app page and `AsyncChainExecution__c` record page
- Tab, permission set, and compact layout metadata

---

## Test Infrastructure

**Fast Start:** [Test Data](../docs/Fast%20Start%20-%20Test%20Data.md)

### TST_Builder

Fluent builder pattern for test data creation with automatic required field population.

- `.of(SObjectType)` — start building
- `.withOverride(field, value)` / `.withOverrides(Map)` — field overrides
- `.withCount(n).buildList()` — bulk creation
- `.withoutInsertion()` — in-memory only (no DML)
- `.withoutInsertion(true)` — in-memory with mock IDs

### TST_Mock.MockBuilder

Fluent mock builder (inner class of `TST_Mock`) that wraps `TST_Builder` and auto-registers results with `TST_Mock` for DML-free query interception.

### TST_Mock

Central registry for mock SObjects. Wraps `QRY_Builder.setMock()` with lifecycle management.

### TST_Factory

Factory methods for trigger settings, trigger actions, validation rules, feature flags, and web service queue items.

### API_OutboundTestHelper

Global test assertion helpers for outbound API calls: `assertCallSuccessful()`, `assertCallFailed()`, `assertCallAborted()` with overloads for service name, record ID, and
parameters.

### API_InboundTestHelper

Global test assertion helpers for inbound API calls: `setupRestContext()`, `assertCallSuccessful()`, `assertCallFailed()`, `assertCallAborted()` with overloads for DTOs and
headers.

### API_MockFactory

Three-tier mock resolution (memory, metadata, static resource) with fluent mock builder: `API_MockFactory.forService().body().statusCode().register()`. Subscriber-accessible for
integration testing.

---

## Schema & Metadata Utilities

**Guide:** [Utilities - Guide](../docs/Utilities%20-%20Guide.md)

### Schema Cache (UTIL_SObjectDescribe)

Unified schema cache with single-iteration population of all derived caches.

- `getCachedFieldDescribe(SObjectField)` — cached `DescribeFieldResult`
- `getCachedFieldName(SObjectField)` — field API name from cache
- `FieldsMap` and `GlobalDescribeMap` with `containsKey()`, `size()`, `keySet()`, `get()`, `values()`
- Two-phase lazy loading: lightweight `FieldMetadata` first, full `DescribeFieldResult` on demand
- O(1) cache hits after first access (~26ms first call, <1ms subsequent)

### Object Hierarchy Traversal (SEL_Hierarchy)

- Find ultimate parent, all ancestors with configurable depth
- Bulk operations for multiple starting records
- Cycle detection to prevent infinite loops

---

## Data Masking

**Guide:** [Logging - Guide](../docs/Logging%20-%20Guide.md) | [Web Services - Guide](../docs/Web%20Services%20-%20Guide.md#maskingrule__mdt--maskingtarget__mdt)

### Framework Overview

One metadata-driven framework redacts sensitive content across every package-owned object that persists caller payloads — `ApiCall__c`, `ApiIssue__c`, `AsyncChainExecution__c`, and
`LogEntryEvent__e` / `LogEntry__c`. Redaction runs as a before-insert / before-update pre-step on the trigger dispatcher, gated on `TriggerSetting__mdt.ApplyMasking__c` (default
`true`, per-object opt-out), so the persisted record never holds the raw sensitive value.

**Split across two CMDTs** so one rule can be reused against many fields on many objects without pattern duplication:

- `MaskingRule__mdt` — the reusable *what to find* definition. `Mode__c` picklist values:
    - `Regex` — standard regex with optional case-insensitivity and `$n` back-references.
    - `JsonKey` — parses the field as JSON and redacts values under any key matching the pattern. Handles nested objects and arrays. Falls back to a regex key-scan if the payload
      isn't valid JSON.
    - `ExactMatch` — literal string replacement.
    - `CreditCard` — regex + Luhn (mod-10) validation via `UTIL_String.isValidCardNumber`. Each regex match is Luhn-checked per ISO/IEC 7812 before substitution, so transaction
      IDs, order numbers, and other long digit runs that happen to match the pattern but fail Luhn are preserved. The algorithm is industry-standard for payment cards, not a
      Kern-specific check.
- `MaskingRule__mdt` optional short-circuit fields:
    - `MinInputLength__c` — numeric gate: skip the rule entirely for values shorter than this length. Zero per-record cost on short fields (URLs, phone numbers, IDs) where a
      multi-digit card pattern couldn't match anyway.
    - `ApplicableFieldTypes__c` — semicolon-delimited list of `System.DisplayType.name()` values (e.g., `STRING;TEXTAREA;ENCRYPTEDSTRING`). Blank applies to every text-shaped
      field. Filter is evaluated at batch-plan construction — zero per-record cost.
- `MaskingTarget__mdt` — the wiring layer. Points a `MaskingRule__mdt` at a specific `SObjectType__c` + `Field__c` (or leaves `Field__c` blank to wildcard every text field on the
  object), with optional `CallerClass__c` scoping so a rule can fire only when a specific service class invokes masking.

**Failure handling** — each rule's `FailureAction__c` controls what happens when its pattern throws: `LogAndContinue` (default) leaves the value unchanged and logs a warning,
`WriteFailureMarker` substitutes `[MASKING_FAILURE]`, `BlockDml` throws `MaskingBlockedException` so the surrounding DML aborts.

**Kill switch** — `FeatureFlag.MaskingFramework_Enabled` (default `true`) — disables the entire framework globally in a break-glass scenario. Evaluated once per transaction.

### Default Ship Set

Two rules are active out of the box, each wildcarded onto all four logged objects (8 wildcard `MaskingTarget__mdt` records):

| Rule             | Mode         | What it redacts                                                                                                                                                                                                                                                                                                      | Rationale                                                                                                                                                                                                                                                                                                                              |
|------------------|--------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `MaskSecretKeys` | `JsonKey`    | JSON values under keys named `password`, `token`, `apiKey`, `authorization`, `bearer`, `client_secret`, `private_key`, `access_token`, `refresh_token`, and common variants                                                                                                                                          | Salesforce auth belongs in Named Credentials and External Credentials, but this is a bad-design guard for developers who accidentally log a credential.                                                                                                                                                                                |
| `MaskCreditCard` | `CreditCard` | Luhn-validated 13–19 digit sequences matching Visa / Mastercard / Amex / Discover / Diners Club / JCB / UnionPay issuer prefixes. `MinInputLength__c = 15` skips the pattern on short fields; `ApplicableFieldTypes__c = 'STRING;TEXTAREA;ENCRYPTEDSTRING'` restricts to free-text fields (not URL / EMAIL / PHONE). | Universal PCI concern — any org processing payments risks card numbers appearing in API traces. Luhn + issuer-prefix checks together filter out transaction IDs, order numbers, and other long digit runs that would otherwise false-positive. `BlockDml` failure action so a misconfigured rule cannot silently leak cardholder data. |

### Shipped Rule Templates

Twelve additional rules ship as **inactive templates** (`IsActive__c = false`). Subscribers enable them by flipping the flag and adding a `MaskingTarget__mdt` wiring — either in
their own unmanaged project or as a subscriber override:

| Rule                        | Mode    | Typical use                                                                       |
|-----------------------------|---------|-----------------------------------------------------------------------------------|
| `MaskSsn`                   | Regex   | US Social Security Numbers (3-2-4 with optional dashes)                           |
| `MaskEmail`                 | Regex   | Email addresses — opt-in because many business payloads legitimately contain them |
| `MaskPhoneUS`               | Regex   | US phone numbers; bounded to prevent false matches inside record IDs              |
| `MaskIban`                  | Regex   | EU bank account numbers                                                           |
| `MaskSwiftBic`              | Regex   | SWIFT / BIC codes                                                                 |
| `MaskMedicareBeneficiaryId` | Regex   | US Medicare Beneficiary IDs (HIPAA-relevant)                                      |
| `MaskHealthKeywords`        | JsonKey | Common health/clinical JSON keys (diagnosis, procedure, icd10, etc.)              |
| `MaskJwt`                   | Regex   | JWT tokens (`eyJ…` three-part base64url)                                          |
| `MaskAuthHeader`            | Regex   | HTTP `Authorization:` header contents                                             |
| `MaskUrlBasicAuth`          | Regex   | HTTP basic-auth credentials in URLs (`https://user:pwd@host`)                     |
| `MaskAwsAccessKey`          | Regex   | AWS access key IDs (`AKIA…`)                                                      |
| `MaskIpv4Private`           | Regex   | Private-range IPv4 addresses — opt-in only due to higher false-positive rate      |

### Performance

Optimised in the April 2026 masking-performance cycle — worst-case masking overhead dropped roughly 11× (~1,008 ms → ~90 ms on a 200-record `insert` on `ApiCall__c` with the
default ship set active) through three changes:

1. `MinInputLength__c` + `ApplicableFieldTypes__c` short-circuits on `MaskingRule__mdt` — evaluated once at batch-plan build time, zero per-record cost when the rule can't possibly
   match.
2. `UTIL_String.isValidCardNumber` (Luhn mod-10 per ISO/IEC 7812) replaces per-match regex recompilation inside the `CreditCard` mode, with a cached `Pattern` keyed on the rule
   definition.
3. Opt-in performance telemetry via `UTIL_MaskerPerformanceTimer` — gated on `LogSetting__c.EnableMaskerPerformanceLogging__c` (default `false`, zero overhead when off). Aggregates
   a single `LogEntryEvent__e` per masked trigger batch exceeding `LogSetting__c.MaskerPerformanceThresholdMs__c` (default 100 ms).

A per-transaction plan cache keyed on `(SObjectType, callerClassName)` ensures target resolution, field discovery, and rule mode-splitting run exactly once per batch — not once per
record. Zero additional SOQL per record.

Bulk-import contexts (1 k+ record batches) should still bypass the pre-step via `TriggerSetting__mdt.ApplyMasking__c = false` during the migration and re-enable afterward.

---

## Record Sharing

**Guide:** [Security - Guide](../docs/Security%20-%20Guide.md)

### UTIL_Sharing

Programmatic record sharing with temporary grant support.

- `.grant(objects, groupId, accessLevel)` — permanent sharing
- `.grantTemporary(objects, groupId, accessLevel, minutes)` — time-bound sharing with automatic revocation

---

## Lightning Web Components

**Guide:** [LWC - Guide](../docs/LWC%20-%20Guide.md)

### ComponentBuilder

Base class for LWC with composable modules: `notification` (toasts), `navigation` (record pages), `controller` (Apex calls),
`flow-navigation` (Flow events), `lightning-message` (LMS).

Cross-namespace subscriber imports supported — ComponentBuilder and 11 dependency modules are `isExposed=true` for use in subscriber LWC via `kern/componentBuilder`.
`notification.showErrorToast` auto-normalises Apex / UI API error objects through `c/utilitySystem.reduceErrors`, so subscribers can pass a raw error from a `.catch()` chain and
get a sensible toast string.

### Components

**Kern Home:**

- `kernHome` — composite "Control Room" home page component that wraps the health check banner and renders three launch cards (API Test Harness, Streaming Event Monitor, Chain
  Monitor) inside an outer "Administration Tools" card. Tool-card icons match their corresponding tab motifs (`custom:custom63`, `custom:custom30`, `custom:custom57`) for visual
  cohesion.
- `healthCheck` — post-install diagnostics across five checks (Organisation Cache, Session Cache, Trusted Site, Class Type Resolver, Data Retention). Renders as a slim green scoped
  notification when every check passes, or a two-section card otherwise — *Action required* (fail items, red heading) above *Review recommended* (warn items, neutral heading),
  sorted by priority within each section. Data Retention offers one-click *Apply Recommended Retention* (creates all four purge jobs in a confirmation modal) and *Customize each
  job →* (expands into per-object sub-rows, each with a *Set up* button opening `scheduledJobEditorModal` prefilled with defaults and a read-only Class Name). Namespace-agnostic —
  the UX works identically in managed-package and rebranded builds.
- `classTypeResolverSetupModal` — guided `LightningModal` with a numbered Setup Steps callout, scoped tabset for generated Resolver Class + Test Class code blocks, and Copy +
  Download actions. Live-binds the resolver class name into step 3. Opens inline from the health check Setup action.

**Monitoring & Diagnostics:**

- Chain Monitor (4 components) — real-time async chain execution monitoring with streaming updates, status filtering, step timeline, and error detail (see [Chain Monitor](#chain-monitor-4-lwc-components))
- Streaming Event Monitor (10 components) — real-time Platform Event, CDC, and PushTopic visualization with D3.js timeline, table/timeline views, filtering, sidebar navigation, and
  usage metrics
- `orgLimits` — org governor limit usage display

**Scheduling:**

- `cronExpressionEditor` — reusable cron expression editor with preset, advanced, and custom modes; crontab.guru-style human-readable preview
- `scheduledJobEditor` / `scheduledJobEditorModal` — unified record page editor for `ScheduledJob__c` with embedded cron editor, dynamic parameter forms, timezone-aware scheduling,
  and view/edit modes
- `scheduledJobDetail` — read-only record page component displaying job configuration with human-readable cron descriptions and timezone labels

**Development & Validation:**

- `apiTestHarnessForm` — full-page two-column developer workspace for invoking inbound and outbound APIs with Safe Mode and mocking controls. Renders on a dedicated
  `ApiTestHarness` tab with a dynamic key-value parameter grid, a 4-state Execution Settings safety bar (Safe Mode / Full Sandbox / Live DML · Mocked callouts / LIVE), a
  destructive Execute variant when Safe Mode is off, Reset controls, a sticky config column, and a response panel with status badge, timing metrics, and tabbed Request / Response /
  Errors viewers. The persisted API Call Id hyperlinks to the `ApiCall__c` record when Safe Mode was disabled on execution.
- `retryApiIssue` — headless quick action to retry failed API issues from record page
- `validationErrors` — display validation framework errors and warnings

---

## Custom Objects & Metadata

**Guide:** [Objects & Metadata - Guide](../docs/Objects%20%26%20Metadata%20-%20Guide.md)

### Custom Objects

| Object                   | Purpose                                                                                                |
|--------------------------|--------------------------------------------------------------------------------------------------------|
| `AsyncChainExecution__c` | Async chain execution tracking with step log, context data, correlation ID, and timing                 |
| `ApiIssue__c`            | API issue tracking and diagnostics                                                                     |
| `ApiCall__c`             | API call tracking and orchestration                                                                    |
| `ApiRuntimeSwitch__c`    | Hierarchy custom setting — org/profile/user-level API runtime kill switches                            |
| `Foobar__c`              | Package-controlled test data object                                                                    |
| `ScheduledJob__c`        | Declarative job scheduling                                                                             |
| `LogEntry__c`            | Application log storage                                                                                |
| `LogSetting__c`          | Hierarchy custom setting — log level thresholds, performance logging toggles, context data size limits |
| `LoginFrequency__c`      | User login frequency tracking                                                                          |
| `ScheduleSetting__c`     | Schedule configuration                                                                                 |

### Custom Metadata Types

| Metadata                      | Purpose                                                                                                            |
|-------------------------------|--------------------------------------------------------------------------------------------------------------------|
| `ApiCredential__mdt`          | API authentication credentials                                                                                     |
| `ApiMock__mdt`                | Mock response scenarios for API services                                                                           |
| `ApiSetting__mdt`             | Web service configuration                                                                                          |
| `AsynchronousJobSetting__mdt` | Async job execution configuration                                                                                  |
| `ClassTypeResolver__mdt`      | Dynamic class type resolution                                                                                      |
| `FeatureFlag__mdt`            | Feature flag definitions                                                                                           |
| `FeatureFlagStrategy__mdt`    | Feature flag evaluation strategies                                                                                 |
| `FieldSetGroup__mdt`          | Field set grouping for dynamic field selection                                                                     |
| `MaskingRule__mdt`            | Reusable data masking rule definitions (regex, JSON-key, literal, credit card) — see [Data Masking](#data-masking) |
| `MaskingTarget__mdt`          | Wires a `MaskingRule__mdt` to specific fields on specific objects, optionally scoped by caller class               |
| `TriggerAction__mdt`          | Individual trigger action registration                                                                             |
| `TriggerSetting__mdt`         | Object-level trigger configuration; `ApplyMasking__c` checkbox opts an object in or out of the masking pre-step    |
| `ValidationRule__mdt`         | Individual validation rule definitions                                                                             |
| `ValidationRuleGroup__mdt`    | Validation rule grouping by object                                                                                 |

---

## Quality & Coverage

- 351 Apex classes (183 production, 168 test) with ~3,352 unit tests at 100% coverage
- 53 LWC components with ~2,283 Jest cases at 100% coverage
- 24 PMD rules + 6 ESLint rules enforce framework conventions in IDE and CI/CD — see [Code Scanning - Guide](../docs/Code%20Scanning%20-%20Guide.md)
- Secure-by-default: USER_MODE is the default `AccessLevel` on `QRY_Builder` / `SEL_Base` / `DML_Builder`; bypass audit logging records every programmatic bypass
- Subscriber release testing: 171 subscriber Apex tests / 21 Playwright end-to-end cases at 100% pass rate on the released build (1.0.0-121)
- No inline SOQL, no `System.debug`, no hardcoded IDs in production code
