# Web Services - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Building inbound and outbound REST integrations with automatic logging and retry mechanisms
- **Architects** - Designing API integration patterns with DTO serialization, mock testing, and orchestration
- **Business Analysts** - Understanding API capabilities, configuration options, error handling, and monitoring

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
    - [What is the Web Services Framework?](#what-is-the-web-services-framework)
    - [Key Benefits](#key-benefits)
    - [UTIL_HttpClient (Fluent HTTP Client)](#util_httpclient-fluent-http-client)
    - [KernDX vs OOTB: Web Services Comparison](#kerndx-vs-ootb-web-services-comparison)
        - [Salesforce Out-of-the-Box Alternatives](#salesforce-out-of-the-box-alternatives)
        - [Pros & Cons Comparison](#pros--cons-comparison)
        - [When to Use KernDX Web Services Framework](#when-to-use-kerndx-web-services-framework)
        - [When to Use OOTB HttpRequest/Response](#when-to-use-ootb-httprequestresponse)
        - [When to Use External Services](#when-to-use-external-services)
    - [Framework Orchestration Pattern](#framework-orchestration-pattern)
3. [Quick Start](#quick-start)
4. [Architecture](#architecture)
    - [Architecture Diagram](#architecture-diagram)
    - [Class Hierarchy](#class-hierarchy)
    - [Key Design Patterns](#key-design-patterns)
    - [The Orchestration Pattern Explained](#the-orchestration-pattern-explained)
5. [Core Components](#core-components)
    - [ApiCall__c (Custom Object)](#apicall__c-custom-object)
    - [ApiSetting__mdt (Custom Metadata Type)](#apisetting__mdt-custom-metadata-type)
    - [MaskingRule__mdt + MaskingTarget__mdt](#maskingrule__mdt--maskingtarget__mdt)
    - [ApiRuntimeSwitch__c (Hierarchy Custom Setting)](#apiruntimeswitch__c-hierarchy-custom-setting)
    - [Named Credentials](#named-credentials)
6. [Working with a Managed Package](#working-with-a-managed-package)
    - [CRITICAL Requirements for Managed Package Usage](#critical-requirements-for-managed-package-usage)
        - [Complete Example with Namespace](#complete-example-with-namespace)
    - [Calling Framework Methods](#calling-framework-methods)
    - [API Dispatcher Usage](#api-dispatcher-usage)
7. [Building Outbound APIs](#building-outbound-apis)
    - [Step 1: Choose Your Base Class](#step-1-choose-your-base-class)
    - [Step 2: Override Virtual Methods](#step-2-override-virtual-methods)
        - [Minimal Implementation](#minimal-implementation)
    - [Complete Real-World Example: REST GET with Parameters](#complete-real-world-example-rest-get-with-parameters)
    - [Complete Real-World Example: REST POST with DML](#complete-real-world-example-rest-post-with-dml)
    - [Step 3: Create ApiSetting__mdt Record](#step-3-create-apisetting__mdt-record)
    - [Step 4: Execute Your API](#step-4-execute-your-api)
8. [Building Inbound APIs](#building-inbound-apis)
    - [Architecture Overview](#architecture-overview)
    - [Minimal Inbound Example](#minimal-inbound-example)
    - [Advanced Example: Multiple Operations on One URL](#advanced-example-multiple-operations-on-one-url)
    - [Multi-method routing](#multi-method-routing)
    - [Naming Conventions for Inbound APIs](#naming-conventions-for-inbound-apis)
9. [Intra-Org API Calls](#intra-org-api-calls)
    - [Overview](#overview-1)
    - [Key Features](#key-features)
    - [When to Use](#when-to-use)
    - [Basic Usage](#basic-usage)
    - [How It Works](#how-it-works)
    - [Configuration](#configuration)
10. [Virtual Methods Reference](#virtual-methods-reference)
    - [Common Base Methods (API_Base)](#common-base-methods-api_base)
        - [getValidationErrors()](#getvalidationerrors)
        - [getBody()](#getbody)
        - [getServiceName()](#getservicename)
        - [onSuccess()](#onsuccess)
        - [setUnitOfWorksObjectTypes()](#setunitofworksobjecttypes)
    - [Outbound-Specific Methods (API_Outbound)](#outbound-specific-methods-api_outbound)
        - [getAuthorisationToken()](#getauthorisationtoken)
        - [getHttpMethod()](#gethttpmethod)
        - [getQueryParameters()](#getqueryparameters)
        - [getRequiredInputs()](#getrequiredinputs)
        - [getResponseBody()](#getresponsebody)
        - [getResponseReplacementTokens()](#getresponsereplacementtokens)
        - [getTimeout()](#gettimeout)
        - [getWebServiceEndPoint()](#getwebserviceendpoint)
        - [prepareRequest()](#preparerequest)
        - [setHeaders()](#setheaders)
        - [requiresTriggeringRecord](#requirestriggeringrecord)
    - [Inbound-Specific Methods (API_Inbound)](#inbound-specific-methods-api_inbound)
        - [processRequest()](#processrequest)
        - [updateCallResult()](#updatecallresult)
        - [updateResponseDTO()](#updateresponsedto)
        - [writeResponse()](#writeresponse)
11. [Advanced Features](#advanced-features)
    - [Automatic Retries](#automatic-retries)
        - [Custom Retry Strategies](#custom-retry-strategies)
    - [Circuit Breaker Pattern](#circuit-breaker-pattern)
        - [How It Works in the Framework](#how-it-works-in-the-framework)
        - [State Transitions Example](#state-transitions-example)
        - [Circuit State Persistence](#circuit-state-persistence)
        - [Default Behavior (No Configuration)](#default-behavior-no-configuration)
        - [Best Practices](#best-practices)
        - [Advanced: Custom Circuit Breaker Configuration](#advanced-custom-circuit-breaker-configuration)
        - [Troubleshooting](#troubleshooting)
    - [Data Masking](#data-masking)
    - [Mock Mode and API_MockFactory](#mock-mode-and-api_mockfactory)
        - [defaultMockBody (Handler-Level Mocking)](#defaultmockbody-handler-level-mocking)
        - [API_MockFactory (Programmatic Mocking)](#api_mockfactory-programmatic-mocking)
        - [Call Verification](#call-verification)
        - [Response Interpolation](#response-interpolation)
        - [Fault Injection](#fault-injection)
        - [Declarative Mock Mode](#declarative-mock-mode)
    - [Disabling APIs](#disabling-apis)
    - [Performance Monitoring](#performance-monitoring)
    - [Batched Outbound Calls](#batched-outbound-calls)
    - [Safe Mode](#safe-mode)
        - [Framework usage (reference)](#framework-usage-reference)
        - [Behavior](#behavior)
        - [Use Cases](#use-cases)
    - [API Test Harness (LWC + Tab)](#api-test-harness-lwc--tab)
        - [Features](#features)
        - [Deployment](#deployment)
    - [Idempotency (Inbound APIs)](#idempotency-inbound-apis)
        - [What gets stored](#what-gets-stored)
        - [Replay behaviour](#replay-behaviour)
        - [Handling 409 in callers](#handling-409-in-callers)
        - [Backward compatibility](#backward-compatibility)
12. [Integration with Flows](#integration-with-flows)
    - [Understanding Synchronous vs Asynchronous Callouts](#understanding-synchronous-vs-asynchronous-callouts)
        - [When to Use Synchronous Callouts](#when-to-use-synchronous-callouts)
        - [When to Use Asynchronous Callouts](#when-to-use-asynchronous-callouts)
    - [Synchronous Callouts from Screen Flows](#synchronous-callouts-from-screen-flows)
        - [Use Case: External API Call from Screen Flow](#use-case-external-api-call-from-screen-flow)
    - [Asynchronous Callouts from Record-Triggered Flows](#asynchronous-callouts-from-record-triggered-flows)
        - [Use Case: Notify External System When Account is Created](#use-case-notify-external-system-when-account-is-created)
    - [Comparison Matrix: Sync vs Async Callouts](#comparison-matrix-sync-vs-async-callouts)
    - [Best Practices for Flow Integration](#best-practices-for-flow-integration)
    - [Testing Flow Callouts](#testing-flow-callouts)
        - [Test Synchronous Flow Callout](#test-synchronous-flow-callout)
        - [Test Asynchronous Flow Callout](#test-asynchronous-flow-callout)
13. [Logging and Monitoring](#logging-and-monitoring)
    - [Where Things Are Logged](#where-things-are-logged)
    - [Automatic Web Service Context](#automatic-web-service-context)
    - [Monitoring API Health](#monitoring-api-health)
    - [Accessing Large Payloads](#accessing-large-payloads)
14. [Testing](#testing)
    - [Overview of Test Helper Classes](#overview-of-test-helper-classes)
    - [Testing Outbound APIs](#testing-outbound-apis)
        - [Using API_OutboundTestHelper](#using-api_outboundtesthelper)
        - [Complete Outbound Test Example](#complete-outbound-test-example)
        - [Using TST_Factory for Queue Items](#using-tst_factory-for-queue-items)
    - [Testing Inbound APIs](#testing-inbound-apis)
        - [Using API_InboundTestHelper](#using-api_inboundtesthelper)
        - [Complete Inbound Test Example](#complete-inbound-test-example)
        - [Using SEL_ApiCall for Assertions](#using-sel_apicall-for-assertions)
    - [Testing Best Practices](#testing-best-practices)
    - [Common Test Patterns](#common-test-patterns)
15. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
16. [Anti-Patterns](#anti-patterns)
17. [Best Practices](#best-practices-1)
    - [Code Standards](#code-standards)
    - [Naming Conventions](#naming-conventions)
    - [Override Only What You Need](#override-only-what-you-need)
    - [Error Handling](#error-handling)
    - [Logging Best Practices](#logging-best-practices)
    - [Inbound API Architecture](#inbound-api-architecture)
    - [Security Considerations](#security-considerations)
    - [Performance Optimization](#performance-optimization)
    - [Understanding the Orchestration](#understanding-the-orchestration)
18. [Troubleshooting](#troubleshooting-1)
    - [Common Issues](#common-issues)
19. [Support and Resources](#support-and-resources)
    - [Code Examples in Framework](#code-examples-in-framework)
    - [Getting Help](#getting-help)
20. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                | Go to...                                             |
|---------------|-----------------------------|------------------------------------------------------|
| **Architect** | Understand API architecture | [Architecture](#architecture)                        |
| **Architect** | Review advanced features    | [Advanced Features](#advanced-features)              |
| **Developer** | Build my first API          | [Quick Start](#quick-start)                          |
| **Developer** | Build outbound APIs         | [Building Outbound APIs](#building-outbound-apis)    |
| **Developer** | Build inbound APIs          | [Building Inbound APIs](#building-inbound-apis)      |
| **Analyst**   | Configure API settings      | [Capability Matrix](#capability-matrix-for-analysts) |
| **Analyst**   | Monitor API health          | [Logging and Monitoring](#logging-and-monitoring)    |

---

## Overview

### What is the Web Services Framework?

The Salesforce Web Services Framework is a comprehensive, enterprise-grade solution for managing both **inbound** (receiving) and **outbound** (sending) API integrations within
Salesforce. It provides:

- **Standardized patterns** for REST web services
- **Automatic logging** of all API calls to [`ApiCall__c`](reference/objects/ApiCall__c.md)
- **Built-in retry mechanisms** with configurable strategies (linear, exponential, custom)
- **Data masking** for sensitive information
- **Mock support** for testing and development
- **Flow integration** for low-code/no-code API calls
- **Error handling** and failure tracking
- **Performance monitoring** with timing metrics
- **Managed package distribution** for reusable architecture
- **Intra-org API support** for calling Salesforce APIs from within the same org

> **Web Services Framework Scope:** 16 `API_*` classes (4 extending `API_Outbound`), 10 `DTO_*` classes, 2 named credentials,
> and full lifecycle tracking via `ApiCall__c` and `ApiIssue__c`. Includes `UTIL_HttpClient` for zero-boilerplate callouts with automatic retry,
> circuit breaker, and failure logging.

> **Responsibilities:** The Web Services framework handles HTTP callout orchestration (request building, execution, response parsing, logging,
> and retry). It does not contain business logic -- that belongs in the calling code or trigger actions. DTOs transport data; API classes
> orchestrate the call lifecycle.

> **When NOT to use this pattern:**
> - Simple one-off callouts in anonymous Apex or data migration scripts
> - Salesforce-to-Salesforce integrations where External Services or Named Credentials alone suffice
> - Outbound messages that a Workflow Rule or Platform Event can handle declaratively

### Key Benefits

- **Consistency**: All APIs follow the same patterns and conventions
- **Traceability**: Every API call is logged with request/response details
- **Resilience**: Automatic retries with configurable backoff periods
- **Security**: Built-in data masking for sensitive fields
- **Testability**: Mock frameworks for unit testing
- **Monitoring**: Performance metrics and error tracking
- **Low-Code Integration**: Direct Flow/Process Builder support
- **Callout Safety**: Orchestration pattern ensures callouts complete before DML operations

---

### UTIL_HttpClient (Fluent HTTP Client)

[`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md) is the simplest way to make HTTP calls in KernDX. It provides a zero-boilerplate fluent API that wraps the
[`API_Outbound`](reference/apex/API_Outbound.md) pipeline, giving you automatic retry, circuit breaker, failure logging, performance timing, and data masking
without writing a dedicated API class.

**When to use UTIL_HttpClient vs API_Outbound:**

| Scenario                                                     | Recommended Approach                                                       |
|--------------------------------------------------------------|----------------------------------------------------------------------------|
| Simple ad-hoc HTTP calls (GET, POST, PUT, DELETE, PATCH)     | [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md)                     |
| Complex integrations with DTOs, validation, or orchestration | [`API_Outbound`](reference/apex/API_Outbound.md)                           |
| Quick prototypes or one-off calls that still need logging    | [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md)                     |
| Subscriber handlers with custom processing logic             | [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md) with `useHandler()` |

**Ad-hoc mode** -- direct calls with a Named Credential (or [`ApiCredential__mdt`](reference/metadata/ApiCredential__mdt.md) DeveloperName) and URL path:

```apex
// Simple GET
HttpResponse response = UTIL_HttpClient.get('CRM', '/accounts/{id}')
	.pathParam('id', accountId)
	.send();

// POST with retry
HttpResponse response = UTIL_HttpClient.post('PaymentGateway', '/charges')
	.body(chargeRequest)
	.withRetry(3)
	.send();

// DELETE
HttpResponse response = UTIL_HttpClient.del('CRM', '/contacts/{id}')
	.pathParam('id', contactId)
	.send();
```

**Delegation mode** -- route processing through a subscriber handler via `useHandler()`:

```apex
API_Outbound handler = UTIL_HttpClient.useHandler(API_SendEmail.class)
	.credential('PaymentGateway')
	.withParameter(API_SendEmail.PARAM_RECIPIENT, email)
	.withTriggeringRecord(recordId)
	.invoke();
```

Caller-provided settings override the handler's [`ApiSetting__mdt`](reference/metadata/ApiSetting__mdt.md) defaults. Unspecified settings fall back to the
handler's CMDT values:

| Builder method            | Overrides                                     |
|---------------------------|-----------------------------------------------|
| `.credential(name)`       | Named Credential                              |
| `.path(urlPath)`          | `EndpointPath__c`                             |
| `.withRetry(n)`           | `MaxRetryCount__c`                            |
| `.withRetry(n, backoff)`  | `MaxRetryCount__c` + `RetryBackoffSeconds__c` |
| `.withCircuitBreaker()`   | `CircuitBreakerEnabled__c`                    |
| `.onFailure(LOG_FAILURE)` | `LogIssues__c`                                |

For full API details, see the [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md) reference.

---

### KernDX vs OOTB: Web Services Comparison

#### Salesforce Out-of-the-Box Alternatives

Salesforce provides several native web service capabilities:

1. **[HttpRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httprequest.htm) / [HttpResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httpresponse.htm)** - Manual HTTP callout classes for custom integrations
2. **Http.send()** - Send HTTP requests directly
3. **[RestContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restcontext.htm)** - Handle inbound REST requests (@RestResource
   annotation)
4. **[External Services](https://developer.salesforce.com/docs/atlas.en-us.api_action.meta/api_action/external_services.htm)** - Import OpenAPI 2.0/3.0 schemas, auto-generate
   invocable actions (no code required)

#### Pros & Cons Comparison

| Feature                       | KernDX Web Services Framework                                                                                                                                      | OOTB HttpRequest/Response      | OOTB External Services             |
|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------|------------------------------------|
| **Code Required**             | ⚠️ Apex class extending base class                                                                                                                                 | ⚠️ Full Apex implementation    | ✅ No code (OpenAPI import only)    |
| **Request/Response Logging**  | ✅ Automatic to [`ApiCall__c`](reference/objects/ApiCall__c.md)                                                                                                     | ❌ Manual implementation        | ⚠️ Limited via Debug Logs only     |
| **Retry Logic**               | ✅ Built-in linear/exponential/custom strategies                                                                                                                    | ❌ Manual implementation        | ❌ No built-in retry                |
| **Data Masking**              | ✅ Regex/JSON-key/literal rules via [`MaskingRule__mdt`](reference/metadata/MaskingRule__mdt.md) + [`MaskingTarget__mdt`](reference/metadata/MaskingTarget__mdt.md) | ❌ Manual implementation        | ❌ No data masking                  |
| **Mock Testing**              | ✅ Framework mock pattern                                                                                                                                           | ✅ `HttpCalloutMock` interface  | ⚠️ Cannot mock in unit tests       |
| **Performance Metrics**       | ✅ Automatic timing (callout, processing, total)                                                                                                                    | ❌ Manual tracking              | ❌ No built-in metrics              |
| **Error Tracking**            | ✅ [`ApiIssue__c`](reference/objects/ApiIssue__c.md) for retry management                                                                                           | ❌ Manual implementation        | ⚠️ Error captured in debug logs    |
| **Callout/DML Orchestration** | ✅ [`API_Dispatcher`](reference/apex/API_Dispatcher.md) pattern                                                                                                     | ❌ Manual code structure        | ⚠️ Flow handles sequencing         |
| **DTO Pattern**               | ✅ [`DTO_JsonBase`](reference/apex/DTO_JsonBase.md)                                                                                                                 | ❌ Manual DTO creation          | ✅ Auto-generated from OpenAPI      |
| **Named Credentials**         | ✅ Via [`ApiCredential__mdt`](reference/metadata/ApiCredential__mdt.md)                                                                                             | ✅ `callout:` syntax            | ✅ Direct integration               |
| **Flow Integration**          | ✅ Built-in invocable methods                                                                                                                                       | ❌ Must create invocables       | ✅ Auto-generated invocable actions |
| **Metadata Configuration**    | ✅ [`ApiSetting__mdt`](reference/metadata/ApiSetting__mdt.md)                                                                                                       | ❌ Hardcoded or Custom Settings | ✅ External Service registration    |
| **Circuit Breaker**           | ✅ [`UTIL_CircuitBreaker`](reference/apex/UTIL_CircuitBreaker.md) integration                                                                                       | ❌ Manual implementation        | ❌ No circuit breaker               |
| **OpenAPI Support**           | ⚠️ Manual DTO creation                                                                                                                                             | ❌ No OpenAPI support           | ✅ OpenAPI 2.0/3.0 import           |
| **Setup Complexity**          | ⚠️ Base class + metadata config                                                                                                                                    | ✅ Direct Apex coding           | ✅ UI-based OpenAPI import          |
| **Flexibility**               | ✅ Full control over logic                                                                                                                                          | ✅ Full control                 | ⚠️ Limited to OpenAPI operations   |
| **Performance**               | ⚠️ Framework overhead                                                                                                                                              | ✅ Minimal overhead             | ✅ Platform-optimized               |

#### When to Use KernDX Web Services Framework

- ✅ **Enterprise integrations** requiring comprehensive logging and monitoring
- ✅ **Production systems** needing automatic retry and error handling
- ✅ **Compliance requirements** for API audit trails
- ✅ **Multiple developers** working on different API integrations
- ✅ **Sensitive data** requiring automated masking
- ✅ **Complex error handling** with retry logic
- ✅ **Flow-based integrations** for low-code API calls
- ✅ **Trigger-based callouts** needing orchestration

#### When to Use OOTB HttpRequest/Response

- ✅ **Simple integrations** with minimal logging needs
- ✅ **One-time data loads** or scripts
- ✅ **Maximum performance** is critical (no framework overhead)
- ✅ **Quick prototypes** or POCs
- ✅ **Custom integration logic** not fitting standard patterns

#### When to Use External Services

- ✅ **OpenAPI-compliant APIs** (REST APIs with OpenAPI 2.0/3.0 specs)
- ✅ **No-code/low-code** integrations for admins
- ✅ **Flow-first** integrations (invocable actions)
- ✅ **Simple CRUD operations** against external systems
- ✅ **Rapid prototyping** from existing API specs
- ✅ **APIs that don't require** retry logic, masking, or detailed logging

---

### Framework Orchestration Pattern

The framework uses a sophisticated orchestration pattern in [`API_Dispatcher`](reference/apex/API_Dispatcher.md) that ensures:

1. **All HTTP callouts are executed first** (avoiding uncommitted work issues)
2. **All DML operations are committed after** callouts complete
3. **Errors are handled gracefully** at each stage

This pattern prevents the dreaded "Callout from triggers with uncommitted work pending is not allowed" error by separating callout execution from database commits.
> **Namespace Note:** Code examples in this guide omit the namespace prefix for readability. In subscriber orgs, prefix framework class references with your namespace (e.g.,
`ClientNS.API_Outbound`). See the Subscriber Context section for details.

---

## Quick Start

Extend `API_Outbound` or `API_Inbound` to build integrations with automatic logging, retries, and error tracking.

> **Step-by-step walkthroughs:** [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md) and
> [Fast Start - Inbound APIs](Fast%20Start%20-%20Inbound%20APIs.md) cover implementation, testing, and common pitfalls.

```apex
public inherited sharing class API_GetWeather extends API_Outbound
{
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"temperature": 72, "conditions": "Sunny"}';
	}
}
```

For deeper coverage, continue reading the sections below.

---

## Architecture

### Architecture Diagram

```text
+---------------------------------------------------------------------------+
|                      WEB SERVICES FRAMEWORK ARCHITECTURE                  |
+---------------------------------------------------------------------------+
|                                                                           |
|  OUTBOUND FLOW (Salesforce -> External System)                            |
|  =============================================                            |
|                                                                           |
|  Your Code / Flow / Trigger                                               |
|        |                                                                  |
|        v                                                                  |
|  +-----------------------------+     +-----------------------------+      |
|  |     UTIL_HttpClient         |     |      API_Outbound          |      |
|  |  (Fluent HTTP Client)       |     |  (Full Lifecycle Handler)  |      |
|  |  .post().body().send()      |     |  configure/validate/send   |      |
|  +-------------+---------------+     +-------------+---------------+      |
|                |                                   |                      |
|                +-----------------------------------+                      |
|                                |                                          |
|                                v                                          |
|                  +-----------------------------+                          |
|                  |       API_Dispatcher         |                         |
|                  |  Phase 1: HTTP Callout       |                         |
|                  |  Phase 2: Commit DML         |                         |
|                  +-------------+---------------+                          |
|                                |                                          |
|          +---------------------+---------------------+                    |
|          v                     v                     v                    |
|  +---------------+   +----------------+   +------------------+           |
|  | ApiCall__c    |   | UTIL_Retry     |   | UTIL_Circuit     |           |
|  | (Audit Log)   |   | (Retry Logic)  |   | Breaker          |           |
|  +---------------+   +----------------+   +------------------+           |
|                                                                           |
+---------------------------------------------------------------------------+
|                                                                           |
|  INBOUND FLOW (External System -> Salesforce)                             |
|  =============================================                            |
|                                                                           |
|  HTTP Request                                                             |
|        |                                                                  |
|        v                                                                  |
|  +-----------------------------+     +-----------------------------+      |
|  |  REST_* (@RestResource)     |---->|       API_Dispatcher        |      |
|  |  REST routing only          |     |  processInboundService()    |      |
|  +-----------------------------+     +-------------+---------------+      |
|                                                    |                      |
|                                                    v                      |
|                                      +-----------------------------+      |
|                                      |       API_Inbound           |      |
|                                      |  validate -> onSuccess ->   |      |
|                                      |  updateResponseDTO          |      |
|                                      +-----------------------------+      |
|                                                                           |
+---------------------------------------------------------------------------+
|                                                                           |
|  CONFIGURATION (Custom Metadata)                                          |
|  ===============================                                          |
|  ApiSetting__mdt    - Endpoint, retry, circuit breaker                    |
|                       (outbound: HTTP method via getHttpMethod() override)|
|  ApiCredential__mdt - Named Credential references                         |
|  MaskingRule__mdt   - Shared redaction rules (regex, JSON key, literal)    |
|  MaskingTarget__mdt - Wires rules to specific fields or wildcards          |
|  ApiRuntimeSwitch__c - Emergency kill switch for all APIs                 |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Class Hierarchy

```text
API_Base (Abstract Base)
├── API_Outbound
│   ├── API_CallCurrentOrg (for intra-org calls)
│   └── Your Outbound REST APIs (e.g., API_PostExample, API_GetPwndPasswords)
└── API_Inbound
    └── Your Inbound REST APIs (e.g., API_Echo)
```

### Key Design Patterns

1. **Template Method Pattern**: Base classes define the flow; child classes override specific steps
2. **Unit of Work Pattern**: Database changes are batched and committed together
3. **Data Transfer Object (DTO) Pattern**: Separate objects for request/response serialization
4. **Factory Pattern**: Mock objects and API handlers created via factories
5. **Strategy Pattern**: Different behaviors for inbound vs outbound
6. **Orchestration Pattern**: Callouts execute before DML commits (see [`API_Dispatcher`](reference/apex/API_Dispatcher.md))

### The Orchestration Pattern Explained

The `API_Dispatcher.execute()` method implements a critical orchestration pattern:

**Phase 1: Process (Execute HTTP Callouts)**

```apex
for(ApiCall__c queueRecord : queueRecords)
{
	API_Base apiHandler = getHandler(queueRecord.ServiceName__c);
	apiHandler.process(queueRecord);  // Performs HTTP callout
	handlersToCommit.add(apiHandler);
}
```

**Phase 2: Commit (Persist DML Operations)**

```apex
for(API_Base handlerToCommit : handlersToCommit)
{
	handlerToCommit.commitWork();  // Commits DML operations
}
```

This two-phase approach ensures:

- All HTTP callouts complete before any DML
- No "uncommitted work" errors
- Transactional integrity across multiple APIs

---

## Core Components

### [ApiCall__c](reference/objects/ApiCall__c.md) (Custom Object)

This custom object logs every API interaction. Key fields:

| Field                   | Description                                                                |
|-------------------------|----------------------------------------------------------------------------|
| `ServiceName__c`        | API class name (e.g., `API_PostExample`)                                   |
| `Direction__c`          | `Inbound` or `Outbound`                                                    |
| `Status__c`             | `Queued`, `Completed`, `Failed`, `Aborted`, `Retry`, `Retrying`, `Batched` |
| `TriggeringRecordId__c` | Record that triggered the API call                                         |
| `Request__c`            | Request body (auto-truncated if too large)                                 |
| `Response__c`           | Response body (auto-truncated if too large)                                |
| `RequestParameters__c`  | JSON serialized parameters                                                 |
| `URL__c`                | Endpoint URL                                                               |
| `StatusCode__c`         | HTTP status code                                                           |
| `ErrorMessages__c`      | Error messages if call failed                                              |
| `NextRetry__c`          | Scheduled retry datetime (populated when retry is needed)                  |
| `Retries__c`            | Number of retry attempts made                                              |
| `IsMockedResponse__c`   | Indicates if response was mocked                                           |
| `CalloutDurationMs__c`  | Time spent in HTTP callout (milliseconds)                                  |
| `HandlerDurationMs__c`  | Time spent in handler logic                                                |
| `CommitDurationMs__c`   | Time spent committing DML                                                  |
| `TotalDurationMs__c`    | Total end-to-end time                                                      |
| `LoggerContext__c`      | Serialized logger context for transaction correlation                      |

**Scope — what `ApiCall__c` does and does not log.** `ApiCall__c` records callouts that flow through the KernDX Web Services framework: outbound calls via
`API_Outbound` / `UTIL_HttpClient` / `API_Dispatcher`, and inbound calls handled by `API_Inbound`. It is **not** an org-wide API-usage log — direct
`Http` / `HttpRequest` callouts, managed-package callouts, and platform API consumption never reach it. For org-wide API, login, and limit monitoring, use
Salesforce Event Monitoring rather than `ApiCall__c`.

**Large Content Handling**: If request/response bodies exceed field limits, they're stored as **ContentVersion** files linked to the queue item.

**Automatic Transaction Correlation**: The `LoggerContext__c` field enables automatic correlation of logs across async boundaries. When queue items are created via
`TST_Factory.newOutboundApiCall()` or `newInboundApiCall()`, the current logger context (correlation ID, transaction ID, global context) is automatically captured.

When `API_Dispatcher.execute()` processes the queue item asynchronously, it hydrates this context, ensuring all logs in the async transaction share the same correlation ID as the
originating transaction. This requires **zero code changes** in subscriber orgs.

### [ApiSetting__mdt](reference/metadata/ApiSetting__mdt.md) (Custom Metadata Type)

Stores configuration per API service:

| Field                               | Description                                                                               |
|-------------------------------------|-------------------------------------------------------------------------------------------|
| `ClassName__c`                      | API class name (must match exactly)                                                       |
| `EndpointPath__c`                   | API endpoint path (appended to Named Credential)                                          |
| `ApiCredential__c`                  | Lookup to credentials metadata                                                            |
| `IsActive__c`                       | Whether the API service is active (default: true). Inactive services abort with an error. |
| `RequiredFeatureFlag__c`            | MetadataRelationship lookup to `FeatureFlag__mdt` — required for the service to execute   |
| `BypassFeatureFlag__c`              | MetadataRelationship lookup to `FeatureFlag__mdt` — bypasses the service when enabled     |
| `MaxRetryCount__c`                  | Maximum retry attempts (e.g., 3)                                                          |
| `RetryBackoffSeconds__c`            | Seconds to wait before first retry (e.g., 30)                                             |
| `CircuitBreakerFailureThreshold__c` | Number of consecutive failures before circuit opens (e.g., 5)                             |
| `CircuitBreakerTimeout__c`          | Seconds to keep circuit open before testing recovery (e.g., 60)                           |
| `CircuitBreakerSuccessThreshold__c` | Number of consecutive successes in half-open state to close the circuit (e.g., 2)         |
| `LogIssues__c`                      | Create `ApiIssue__c` records                                                              |
| `ResolveIssues__c`                  | Auto-resolve failures on success                                                          |

**Centralized Validation:** `API_Base.performValidation()` automatically checks these three fields before any API handler executes:

1. **`IsActive__c`** — If `false`, the service aborts with error: *"API service is inactive"*
2. **`RequiredFeatureFlag__c`** — If the Feature Flag is not enabled for the running user, the service aborts with error: *"Required feature flag is not enabled"*
3. **`BypassFeatureFlag__c`** — If the Feature Flag is enabled for the running user, the service aborts with error: *"API service is bypassed by feature flag"*

These checks run in both inbound and outbound flows, before `getValidationErrors()` is called.

### [MaskingRule__mdt](reference/metadata/MaskingRule__mdt.md) + [MaskingTarget__mdt](reference/metadata/MaskingTarget__mdt.md)

Redaction is split across two metadata types so a single rule can be reused against many fields on many objects without duplicating the pattern.

**[`MaskingRule__mdt`](reference/metadata/MaskingRule__mdt.md)** — the reusable *what to find* definition:

| Field                     | Description                                                                                                                                                                                    |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Mode__c`                 | `Regex`, `JsonKey` (picklist label "JSON by Key"), `ExactMatch`, or `CreditCard` (the pattern match plus a Luhn checksum)                                                                      |
| `Pattern__c`              | Regex pattern, JSON key regex, or literal string (depending on Mode)                                                                                                                           |
| `Replacement__c`          | Replacement text (e.g., `[CARD_REDACTED]`)                                                                                                                                                     |
| `CaseSensitive__c`        | Toggle case-insensitive matching                                                                                                                                                               |
| `FailureAction__c`        | `LogAndContinue`, `WriteFailureMarker`, or `BlockDml` when a pattern throws                                                                                                                    |
| `IsActive__c`             | Enable/disable rule globally                                                                                                                                                                   |
| `MinInputLength__c`       | Optional minimum input length — rule skipped for values shorter than this (zero-cost short-circuit for short fields like URLs)                                                                 |
| `ApplicableFieldTypes__c` | Optional semicolon-delimited `System.DisplayType.name()` list (e.g., `STRING;TEXTAREA;ENCRYPTEDSTRING`) restricting the rule to specific field types; blank applies to every text-shaped field |

**[`MaskingTarget__mdt`](reference/metadata/MaskingTarget__mdt.md)** — the wiring from rules to fields:

| Field            | Description                                                          |
|------------------|----------------------------------------------------------------------|
| `Rule__c`        | The `MaskingRule__mdt` to apply                                      |
| `SObjectType__c` | Target SObject (e.g., `ApiCall__c`)                                  |
| `Field__c`       | Specific field path, or blank for a wildcard across every text field |
| `CallerClass__c` | Optional scope: only fire when the caller class name matches         |
| `IsActive__c`    | Enable/disable this wiring without touching the rule                 |

**Default ship set (3 rules active, 12 targets):** `MaskSecretKeys` (JSON key redaction for password/token/apiKey/authorization/bearer and similar, scoped to `STRING;TEXTAREA` since
JSON payloads only live in free-text fields) and `MaskPaymentCard` (`CreditCard` mode: 13-19 digit sequences passing the Luhn checksum, spaces or hyphens allowed,
`MinInputLength = 13`, restricted to `STRING;TEXTAREA;ENCRYPTEDSTRING` field types), each wildcarded onto `ApiCall__c`, `ApiIssue__c`,
`AsyncChainExecution__c`, and `LogEntryEvent__e`. `MaskPaymentCard` replaces the original `MaskCreditCard` rule, which still ships active — with its own four targets — for
compatibility with configurations that reference it; where both rules are wired to the same object the payment-card rule does the work. Fifteen other rules (SSN, IBAN, SWIFT/BIC, MBI, health keywords, email, US phone, JWT, AWS access key, URL basic auth,
authorization header, private IPv4, postal address, free text, and international phone) ship as inactive templates — flip `IsActive__c = true` and add a `MaskingTarget__mdt` when
your org's data profile calls for them.

**Rule-level filters override explicit target wiring.** If a `MaskingTarget__mdt` wires a rule to a specific `Field__c` (non-wildcard) whose `DisplayType` is excluded by the rule's
`ApplicableFieldTypes__c`, the rule will **not** fire on that field — rule-level filters take precedence over per-target wiring. The framework emits a one-time `warn`-level
`LogEntry__c` with `ClassMethod__c = 'UTIL_FrameworkMasker.filterTargetsByFieldType'` to surface the misconfiguration. Either widen the rule's `ApplicableFieldTypes__c` to include
the field's type or remove the target. `MinInputLength__c` behaves similarly but is a value-length check at mask time — it does not warn, and a rule whose minimum exceeds the
field's schema max length will silently never fire.

### [ApiRuntimeSwitch__c](reference/objects/ApiRuntimeSwitch__c.md) (Hierarchy Custom Setting)

Emergency kill switch for all APIs at the org, profile, or user level:

| Field               | Description                             |
|---------------------|-----------------------------------------|
| `DisableAllApis__c` | Disable all APIs (inbound and outbound) |

For granular per-service control, use `ApiSetting__mdt.IsActive__c`. For feature-flag-driven disable/mock, use `UTIL_FeatureFlag` with the `DisableAllAPIs` or `MockAllInboundAPIs`
feature flags.

### [Named Credentials](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts_named_credentials.htm)

Stores authentication details securely
via [External Credentials](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/external_credentials.htm). Referenced by `ApiSetting__mdt`.

**The two named credentials KernDX ships.** Both back the framework's outbound examples and call public, unauthenticated endpoints, so they store no secrets:

| Named Credential     | Label           | Endpoint                              | Authentication   | Used by                                       |
|----------------------|-----------------|---------------------------------------|------------------|-----------------------------------------------|
| `API_ExampleRestApi` | Example REST API | `https://jsonplaceholder.typicode.com` | Anonymous (none) | The outbound REST example `API_PostExample`   |
| `API_PwndPasswords`  | Pwnd Passwords  | `https://api.pwnedpasswords.com`      | Anonymous (none) | The breach-check example `API_GetPwndPasswords` |

Replace or remove these when you wire up your own integrations — they are demonstrations, not production endpoints. Keeping an inventory of *your org's*
named credentials and their criticality is org configuration: use native Setup or a posture tool such as AppOmni. A managed package does not catalogue your
credentials for you.

---

## Working with a Managed Package

### CRITICAL Requirements for Managed Package Usage

When using KernDX as a managed package, subscriber orgs **MUST** follow these critical requirements to avoid runtime failures:

#### [@JsonAccess](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_JsonAccess.htm) Annotation (MANDATORY)

**⚠️ ALL DTOs extending managed package classes MUST include `@JsonAccess` annotation:**

```apex
// ✅ CORRECT - @JsonAccess grants managed package permission to serialize/deserialize
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_Request extends DTO_JsonBase
{
	public String customerId;
	public String orderNumber;
}

// ❌ WRONG - Will fail at runtime with "Type cannot be serialized as it is not globally visible"
public class DTO_Request extends DTO_JsonBase
{
	public String customerId;
}
```

**When to use each setting:**

- `Serializable='always'` - Required when managed package calls `serialize()` on your DTO (outbound requests)
- `Deserializable='always'` - Required when managed package calls `deserialize()` on your DTO (inbound responses)
- Use **both** for bidirectional scenarios (most common)

#### Type Resolution (MANDATORY)

**⚠️ You MUST implement type resolution using ONE of these three approaches:**

**Option A: Make DTOs Global (simple but exposes classes)**

```apex
@JsonAccess(Serializable='always' Deserializable='always')
global class DTO_Request extends DTO_JsonBase
{
	public String data;
}
```

**Option B: Implement getObjectType() in Every DTO (repetitive but explicit)**

```apex
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_Request extends DTO_JsonBase
{
	public String data;

	protected override Type getObjectType()
	{
		return DTO_Request.class;
	}
}
```

**Option C: Register Type Resolver (RECOMMENDED - flexible and maintainable)**

1. Create resolver class:

```apex
/**
 * @description Custom type resolver for subscriber org classes
 *
 * @see UTIL_TypeResolver
 */
global with sharing class CustomTypeResolver extends kern.UTIL_TypeResolver.BaseClassResolver
{
	/**
	 * @description Resolves a Type object from a class name
	 *
	 * @param className The name of the class to resolve
	 *
	 * @return Type The resolved Type object or null if not found
	 */
	public override Type resolveType(String className)
	{
		return getTypeForClassName(className) ?? (Type)nextResolver?.resolveType(className);
	}

	/**
	 * @description Resolves the Type for a given class name, handling namespaces and nested classes
	 *
	 * @param className The class name to resolve
	 *
	 * @return The resolved Type object, or null if not found
	 */
	private static Type getTypeForClassName(String className)
	{
		Type classType;

		if(String.isNotBlank(className))
		{
			String namespace = kern.UTIL_System.getNamespacePrefix(
				kern.UTIL_System.getClassNamespace(className),
				'.'
			);

			classType = Type.forName(namespace, className);
			// Retry without namespace for nested classes (e.g., MyParentClass.MyChildClass)
			classType = classType == null && String.isNotBlank(namespace)
				? Type.forName('', className)
				: classType;
		}

		return classType;
	}
}
```

2. Register in `ClassTypeResolver__mdt`:
    - **Label:** Custom Type Resolver
    - **DeveloperName:** CustomTypeResolver
    - **ClassName__c:** CustomTypeResolver

3. No need to implement `getObjectType()` in any DTO!

**Without type resolution, you will encounter:**

```text
System.JSONException: Type cannot be deserialized as it is not globally visible - DTO_Request
```

#### Complete Example with Namespace

```apex
/**
 * @description Example outbound API demonstrating subscriber namespace usage.
 * Demonstrates proper namespace usage and coding standards.
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date January 2026
 */
public inherited sharing class MyAPI_SendEmail extends API_Outbound
{
	/**
	 * @description Initializes the API handler with required DTOs and mock class.
	 * This method is called by the framework before processing begins.
	 */
	public override void configure()
	{
		super.configure();

		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"success": true, "messageId": "12345"}';
		requiresTriggeringRecord = false;
	}

	/**
	 * @description Sets HTTP headers required for the API call.
	 * Adds a custom correlation header for request tracking.
	 */
	public override void setHeaders()
	{
		super.setHeaders();
		request.setHeader('X-Correlation-Id', UTIL_Random.randomUUID());
	}

	/**
	 * @description Registers database changes to be committed after the API call succeeds.
	 * API_Base extends DML_Transaction, so doInsert/doUpdate/doDelete are inherited directly.
	 */
	public override void onSuccess()
	{
		super.onSuccess();

		Task newTask = new Task(Subject = 'Email sent', Status = 'Completed');
		doInsert(newTask);  // Inherited from DML_Transaction
	}

	/**
	 * @description Data Transfer Object for the API request payload.
	 */
	@JsonAccess(Serializable='always')
	public class DTO_Request extends DTO_JsonBase
	{
		public String recipient;
		public String subject;
		public String body;
	}

	/**
	 * @description Data Transfer Object for the API response payload.
	 */
	@JsonAccess(Deserializable='always')
	public class DTO_Response extends DTO_JsonBase
	{
		public Boolean success;
		public String messageId;

		/**
		 * @description Returns the type of this DTO for proper deserialization.
		 *
		 * @return The DTO_Response class type
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}

}
```

### Calling Framework Methods

In subscriber orgs, prefix framework classes and utilities with the package namespace:

```apex
// ❌ WRONG — missing namespace prefix
String abbreviated = UTIL_String.abbreviate(input, 100);
Id recordId = UTIL_SObject.validateId(stringId);

// ✅ CORRECT — use kern namespace prefix
String abbreviated = kern.UTIL_String.abbreviate(input, 100);
Id recordId = kern.UTIL_SObject.validateId(stringId);
```

### API Dispatcher Usage

```apex
// Create queue item
ApiCall__c queueItem = TST_Factory.newOutboundApiCall(
	'MyAPI_SendEmail',
	null,
	new Map<String, String>{ 'recipient' => 'test@example.com' }
);

// Execute via factory
List<API_Base> handlers = API_Dispatcher.execute(
	new List<ApiCall__c>{ queueItem }
);

// Access results
MyAPI_SendEmail handler = (MyAPI_SendEmail)handlers[0];

if(handler.result.isSuccess)
{
	// Process success - e.g., update UI, return result to caller
}
```

---

## Building Outbound APIs

Outbound APIs **send** HTTP requests to external systems.

### Step 1: Choose Your Base Class

- **REST API**: Extend [`API_Outbound`](reference/apex/API_Outbound.md)
- **Intra-Org REST API**: Extend [`API_CallCurrentOrg`](reference/apex/API_CallCurrentOrg.md) (for calling Salesforce APIs from same org)

### Step 2: Override Virtual Methods

**You only need to override methods where defaults aren't sufficient.** The framework provides sensible defaults for most scenarios. See
the [Virtual Methods Reference](#virtual-methods-reference) section for detailed explanations of each method.

#### Minimal Implementation

```apex
/**
 * @description Minimal outbound API implementation showing required overrides only.
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date January 2025
 */
public inherited sharing class API_MinimalExample extends API_Outbound
{
	/**
	 * @description Initializes the API handler with response DTO.
	 * The framework will auto-serialize requests and deserialize responses.
	 */
	public override void configure()
	{
		super.configure();
		responsePayload = new DTO_Response();
	}

	/**
	 * @description Data Transfer Object for API response.
	 */
	@JsonAccess(Deserializable='always')
	public class DTO_Response extends DTO_JsonBase
	{
		public String result;

		/**
		 * @description Returns the type of this DTO for proper deserialization.
		 *
		 * @return The DTO_Response class type
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}
}
```

### Complete Real-World Example: REST GET with Parameters

See `API_GetPwndPasswords` in the framework source for a complete working example of a GET API with URL parameter encoding, custom headers, and required parameter validation.

### Complete Real-World Example: REST POST with DML

```apex
/**
 * @description Sends email via external service API and logs activity as Task.
 * Demonstrates POST requests, parameter validation, and database operations.
 *
 * @see API_SendMail_TEST
 *
 * @author your.name@company.com
 *
 * @group Communications
 *
 * @date January 2025
 */
public inherited sharing class API_SendMail extends API_Outbound
{
	/**
	 * @description The required parameter name for send mail request JSON.
	 */
	public static final String REQUIRED_PARAMETER_REQUEST_JSON = 'sendMailRequests';

	/**
	 * @description Initializes the API handler with request/response DTOs and mock.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"results": [{"success": true}]}';
		requiresTriggeringRecord = false;
	}

	/**
	 * @description Specifies required request parameters for validation.
	 *
	 * @return Set containing required parameter names
	 */
	public override Set<String> getRequiredInputs()
	{
		Set<String> requiredParameters = super.getRequiredInputs();
		requiredParameters.add(REQUIRED_PARAMETER_REQUEST_JSON);
		return requiredParameters;
	}

	/**
	 * @description Adds custom correlation header for request tracking.
	 */
	public override void setHeaders()
	{
		super.setHeaders();
		request.setHeader('X-Correlation-Id', UTIL_Random.randomUUID());
	}

	/**
	 * @description Bypasses sharing rules for this API to allow system-wide email operations.
	 */
	public override void commitWork()
	{
		commitWork(false);
	}

	/**
	 * @description Validates and deserializes the send mail request parameter.
	 *
	 * @return List of validation error messages
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		DTO_Request dtoRequest = (DTO_Request)requestPayload;

		try
		{
			dtoRequest.dtoSendMailRequests =
				(List<DTO_SendMailRequest>)JSON.deserialize(
					inputs.get(REQUIRED_PARAMETER_REQUEST_JSON),
					List<DTO_SendMailRequest>.class
				);

			if(dtoRequest.dtoSendMailRequests == null || dtoRequest.dtoSendMailRequests.isEmpty())
			{
				errors.add('No send mail requests provided');
			}
		}
		catch(Exception error)
		{
			errors.add('Invalid JSON: ' + error.getMessage());
		}

		return errors;
	}

	/**
	 * @description Creates Task records for each successfully sent email.
	 * DML operations are committed after all callouts complete.
	 */
	public override void onSuccess()
	{
		super.onSuccess();

		DTO_Response dtoResponse = (DTO_Response)responsePayload;

		for(Integer i = 0; i < dtoResponse.results.size(); i++)
		{
			if(dtoResponse.results[i].success)
			{
				Task newTask = new Task
				(
					Subject = 'Email sent',
					Status = 'Completed',
					Type = 'Email'
				);
				doInsert(newTask);
			}
		}
	}

	/**
	 * @description Data Transfer Object for send mail request.
	 */
	@JsonAccess(Serializable='always')
	private class DTO_Request extends DTO_JsonBase
	{
		private List<DTO_Mail> messages = new List<DTO_Mail>();
		private transient List<DTO_SendMailRequest> dtoSendMailRequests;

		/**
		 * @description Populates the mail messages from the request list.
		 *
		 * @param recordId The record that triggered this API call (unused in this implementation)
		 */
		public override void populate(Id recordId)
		{
			super.populate(recordId);

			for(DTO_SendMailRequest request : dtoSendMailRequests)
			{
				DTO_Mail mail = new DTO_Mail();
				mail.toAddress = request.toAddress;
				mail.subject = request.subject;
				mail.body = request.body;
				messages.add(mail);
			}
		}
	}

	/**
	 * @description Data Transfer Object for individual mail message.
	 */
	@JsonAccess(Serializable='always')
	private class DTO_Mail
	{
		public String toAddress;
		public String subject;
		public String body;
	}

	/**
	 * @description Data Transfer Object for API response.
	 */
	@JsonAccess(Deserializable='always')
	private class DTO_Response extends DTO_JsonBase
	{
		public List<DTO_SendMessageOutcome> results;

		/**
		 * @description Returns the type of this DTO for proper deserialization.
		 *
		 * @return The DTO_Response class type
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}

	/**
	 * @description Data Transfer Object for individual send outcome.
	 */
	public class DTO_SendMessageOutcome
	{
		public Boolean success;
		public List<String> errors;
	}

	/**
	 * @description Data Transfer Object for send mail request parameters.
	 */
	public class DTO_SendMailRequest
	{
		public String toAddress;
		public String subject;
		public String body;
	}

}
```

### Step 3: Create ApiSetting__mdt Record

Create a custom metadata record:

| Field                  | Value                  |
|------------------------|------------------------|
| Label                  | `API Send Mail`        |
| ClassName__c           | `API_SendMail`         |
| EndpointPath__c        | `/api/v1/send`         |
| ApiCredential__c       | (Lookup to credential) |
| MaxRetryCount__c       | `3`                    |
| RetryBackoffSeconds__c | `30`                   |
| LogIssues__c           | `true`                 |
| ResolveIssues__c       | `true`                 |

### Step 4: Execute Your API

```apex
// Create queue item
ApiCall__c queueItem = TST_Factory.newOutboundApiCall(
	'API_SendMail',
	null,
	new Map<String, String>
	{
		'sendMailRequests' => JSON.serialize(new List<API_SendMail.DTO_SendMailRequest>
		{
			new API_SendMail.DTO_SendMailRequest()
		})
	}
);

// Execute synchronously
List<API_Base> handlers = API_Dispatcher.execute(
	new List<ApiCall__c>{ queueItem }
);

API_SendMail handler = (API_SendMail)handlers[0];

if(handler.result.isSuccess)
{
	// Process success - e.g., update UI, return result to caller
}
```

---

## Building Inbound APIs

Inbound APIs **receive** HTTP requests from external systems.

**IMPORTANT**: The framework uses a **two-class architecture** that separates URL routing from business logic. This pattern provides better maintainability, flexibility, and
reusability.

### Architecture Overview

Inbound REST APIs use two separate classes:

1. **REST Routing Class** (`REST_*` prefix): Contains `@RestResource` annotation and routes HTTP methods
2. **API Implementation Class** (`API_*` prefix): Contains business logic and extends [`API_Inbound`](reference/apex/API_Inbound.md)

**Benefits of this pattern:**

- ✅ **Separation of Concerns**: REST routing is separate from business logic
- ✅ **Multiple Operations**: One REST endpoint can handle multiple HTTP methods
- ✅ **Reusability**: Same API implementation can be exposed at different endpoints
- ✅ **Maintainability**: Changes to URL structure don't affect business logic
- ✅ **Flexibility**: Each HTTP method can delegate to a different API implementation

### Minimal Inbound Example

**Step 1: Create the REST Routing Class**

```apex
/**
 * @description REST Endpoint wrapper class for the inbound echo test service.
 * This class serves as a RESTFUL endpoint that listens for POST requests to the `/echo/*` URL mapping.
 *
 * @see API_Echo
 * @see API_Echo_TEST
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date January 2025
 */
@RestResource(UrlMapping='/echo/*')
global inherited sharing class REST_Echo
{
	/**
	 * @description Handles the POST method for the echo service (inbound).
	 * Delegates processing to the API_Echo implementation class via the framework factory.
	 *
	 * @example
	 * POST /services/apexrest/echo
	 * Body: {"message": "Hello, Echo!"}
	 */
	@HttpPost
	global static void echo()
	{
		API_Dispatcher.processInboundService(API_Echo.class.getName());
	}
}
```

**Key Points for REST Routing Classes:**

- Use [`@RestResource`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_rest_intro.htm) annotation with `UrlMapping`
- Methods must be `global static` with HTTP method annotations (`@HttpPost`, `@HttpGet`, etc.)
- Delegate to `API_Dispatcher.processInboundService()` with the API class name
- Use `global` access modifier (required for @RestResource)
- Keep logic minimal - only routing, no business logic

**Step 2: Create the API Implementation Class**

```apex
/**
 * @description An example Inbound API call that will echo exactly what was sent.
 * Contains the business logic for processing echo requests.
 *
 * @see REST_Echo
 * @see API_Echo_TEST
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date January 2025
 */
public inherited sharing class API_Echo extends API_Inbound
{
	@TestVisible
	private static final String ERROR_NO_BODY_RECEIVED = 'No request body received';

	/**
	 * @description Validates that a request body was provided.
	 *
	 * @return List of validation error messages
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();

		if(String.isEmpty(requestBody))
		{
			errors.add(ERROR_NO_BODY_RECEIVED);
		}

		return errors;
	}

	/**
	 * @description Sets the response to echo back the request body.
	 */
	public override void updateCallResult()
	{
		super.updateCallResult();
		result.responseBody = requestBody;  // Echo back exactly what was sent
	}
}
```

**Key Points for API Implementation Classes:**

- Extend [`API_Inbound`](reference/apex/API_Inbound.md) (or a custom base class)
- Do NOT use `@RestResource` annotation (that's on the URL routing class)
- Use `public` access modifier (not global)
- Override virtual methods to customize behavior
- Contains all business logic and data processing

### Advanced Example: Multiple Operations on One URL

This example demonstrates how **one REST routing class** can handle **multiple HTTP methods** by delegating to different API implementation classes.

**Step 1: Create the REST Routing Class**

```apex
/**
 * @description REST API endpoint for managing person profile details.
 * Supports GET (retrieve) and PATCH (update) operations on the same URL endpoint.
 *
 * @see API_PersonRetrieve
 * @see API_PersonUpdate
 *
 * @author your.name@company.com
 *
 * @group Person APIs
 *
 * @date January 2025
 */
@RestResource(UrlMapping='/v1/identity/persons/*')
global inherited sharing class REST_Person
{
	/**
	 * @description Handles HTTP GET requests to retrieve person profile details.
	 * Extracts identityId from URL path and delegates to API_PersonRetrieve.
	 *
	 * @example
	 * GET /services/apexrest/v1/identity/persons/f47ac10b-58cc-4372-a567-0e02b2c3d479
	 *
	 * Response (200 OK):
	 * {
	 *   "identityId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
	 *   "firstName": "John",
	 *   "lastName": "Doe",
	 *   "email": "john.doe@company.com"
	 * }
	 */
	@HttpGet
	global static void getPerson()
	{
		API_Dispatcher.processInboundService(API_PersonRetrieve.class.getName());
	}

	/**
	 * @description Handles HTTP PATCH requests to update person profile details.
	 * Delegates to API_PersonUpdate for processing.
	 *
	 * @example
	 * PATCH /services/apexrest/v1/identity/persons/
	 * Body:
	 * {
	 *   "identityId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
	 *   "firstName": "John",
	 *   "lastName": "Smith"
	 * }
	 */
	@HttpPatch
	global static void editPerson()
	{
		API_Dispatcher.processInboundService(API_PersonUpdate.class.getName());
	}
}
```

**Step 2: Create API Implementation for GET Operation**

```apex
/**
 * @description Processes person profile retrieval.
 * Retrieves person details based on identityId provided in URL path.
 *
 * @see REST_Person
 * @see API_PersonRetrieve_TEST
 *
 * @author your.name@company.com
 *
 * @group Person APIs
 *
 * @date January 2025
 */
public inherited sharing class API_PersonRetrieve extends API_Inbound
{
	/**
	 * @description The Contact record found based on the provided identity ID.
	 */
	protected Contact foundPerson;

	/**
	 * @description Initializes the response DTO.
	 */
	public override void configure()
	{
		super.configure();
		responsePayload = new DTO_Response();
	}

	/**
	 * @description Validates the identity ID and retrieves person data.
	 *
	 * @return List of validation error messages
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		String identityId = request.requestURI.substringAfterLast('/');

		if(String.isBlank(identityId))
		{
			errors.add('Identity Id not provided');
		}
		else
		{
			foundPerson = SEL_Contact.findByExternalReference(identityId);

			if(foundPerson == null)
			{
				errors.add('No person found with the provided details');
			}
			else
			{
				DTO_Response dtoResponse = (DTO_Response)responsePayload;
				dtoResponse.identityId = foundPerson.CMN_ExternalReference__c;
				dtoResponse.birthdate = foundPerson.Birthdate;
				dtoResponse.email = foundPerson.Email;
				dtoResponse.firstName = foundPerson.FirstName;
				dtoResponse.lastName = foundPerson.LastName;
				dtoResponse.mobile = foundPerson.MobilePhone;
			}
		}

		return errors;
	}

	/**
	 * @description Data Transfer Object for person response.
	 */
	@JsonAccess(Serializable='always')
	public class DTO_Response extends DTO_JsonBase
	{
		public String identityId;
		public Date birthdate;
		public String email;
		public String firstName;
		public String lastName;
		public String mobile;
	}
}
```

**Step 3: Create API Implementation for PATCH Operation**

```apex
/**
 * @description Processes person profile updates.
 * Updates person details and commits changes to database.
 *
 * @see REST_Person
 * @see API_PersonUpdate_TEST
 *
 * @author your.name@company.com
 *
 * @group Person APIs
 *
 * @date January 2025
 */
public inherited sharing class API_PersonUpdate extends API_Inbound
{
	/**
	 * @description The Contact record to be updated.
	 */
	protected Contact upsertContact;

	/**
	 * @description Initializes the request and response DTOs.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
	}

	/**
	 * @description Validates the request and finds the Contact to update.
	 *
	 * @return List of validation error messages
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		DTO_Request dtoRequest = (DTO_Request)requestPayload;

		if(String.isBlank(dtoRequest.identityId))
		{
			errors.add('Identity Id not provided');
		}
		else
		{
			upsertContact = SEL_Contact.findByExternalReference(dtoRequest.identityId);

			if(upsertContact == null)
			{
				errors.add('No Person found for the identityId provided');
			}
		}

		return errors;
	}

	/**
	 * @description Updates the Contact record with data from the request.
	 * API_Base inherits DML methods from DML_Transaction, so doUpdate is called directly.
	 */
	public override void onSuccess()
	{
		super.onSuccess();

		DTO_Request dtoRequest = (DTO_Request)requestPayload;

		upsertContact.FirstName = dtoRequest.firstName;
		upsertContact.LastName = dtoRequest.lastName;
		upsertContact.Email = dtoRequest.email;

		doUpdate(upsertContact);
	}

	/**
	 * @description Updates the response DTO with committed data.
	 * This method is called after database commit completes.
	 */
	public override void updateResponseDTO()
	{
		super.updateResponseDTO();

		DTO_Response dtoResponse = (DTO_Response)responsePayload;
		dtoResponse.message = 'Person updated successfully';
		dtoResponse.identityId = upsertContact.CMN_ExternalReference__c;
	}

	/**
	 * @description Data Transfer Object for person update request.
	 */
	@JsonAccess(Deserializable='always')
	public class DTO_Request extends DTO_JsonBase
	{
		public String identityId;
		public String firstName;
		public String lastName;
		public String email;
	}

	/**
	 * @description Data Transfer Object for update response.
	 */
	@JsonAccess(Serializable='always')
	public class DTO_Response extends DTO_JsonBase
	{
		public String message;
		public String identityId;
	}
}
```

### Multi-method routing

When one URL responds to multiple HTTP verbs (the `REST_Person` example above handles both GET and PATCH), each verb routes to a different inbound handler class. Salesforce REST
plumbing dispatches by verb based on the `@HttpGet`/`@HttpPost`/`@HttpPut`/`@HttpPatch`/`@HttpDelete` annotation on each method of the `REST_*` routing class. Each annotated method
delegates to a different `API_*` handler by passing that handler's class name to `processInboundService()`:

| Custom Metadata Record  | `ClassName__c`       | Routing Method            |
|-------------------------|----------------------|---------------------------|
| `ApiSetting.GetPerson`  | `API_PersonRetrieve` | `@HttpGet getPerson()`    |
| `ApiSetting.EditPerson` | `API_PersonUpdate`   | `@HttpPatch editPerson()` |

One `ApiSetting__mdt` record per handler — `ClassName__c` ties the metadata to the implementation. When a request arrives, Salesforce's `@Http*` dispatch selects the routing
method, which calls `API_Dispatcher.processInboundService(API_PersonRetrieve.class.getName())` (or the corresponding handler) to run the framework's pre-validation, authorisation,
and `onSuccess()` pipeline.

### Naming Conventions for Inbound APIs

**REST Routing Classes:**

- **Pattern**: `REST_*`
- **Examples**:
    - `REST_Echo` - Simple routing class
    - `REST_Person` - Resource routing class
    - `REST_Invoices` - Domain-specific routing class

**API Implementation Classes:**

- **Pattern**: `API_*` or `[Domain]_API_[Operation][Resource]`
- **Examples**:
    - `API_Echo` - Simple implementation
    - `API_PersonRetrieve` - Domain + Operation + Resource
    - `API_PersonUpdate` - Domain + Operation + Resource
    - `DOMAIN_API_CreateCase` - Domain + Operation + Resource

---

## Intra-Org API Calls

### Overview

The [`API_CallCurrentOrg`](reference/apex/API_CallCurrentOrg.md) class is a specialized base class for making API calls **back into the same Salesforce org**. This is useful when
you need to call standard Salesforce REST APIs (like Composite API, Tooling API, or custom REST services) from within your org using the current user's session.

### Key Features

- **Dynamic URL Resolution**: Resolves the org base URL at runtime via `URL.getOrgDomainURL()` — no Named Credential required
- **Automatic Session ID Management**: Automatically uses the current user's session ID for authentication
- **Bearer Token Authentication**: Sets the Authorization header with the proper Bearer token format
- **Inherits All Outbound Features**: Logging, retries, mocking, and error handling

### When to Use

Use [`API_CallCurrentOrg`](reference/apex/API_CallCurrentOrg.md) when you need to:

- Call Salesforce REST APIs from within the same org
- Use the Composite API to perform multiple operations in a single call
- Access Tooling API endpoints
- Call custom REST endpoints within your org with user context

### Basic Usage

```apex
/**
 * @description Calls Salesforce Composite API to perform multiple DML operations in a single call.
 * Demonstrates intra-org API usage with automatic session management.
 *
 * @see API_CompositeExample_TEST
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date January 2025
 */
public inherited sharing class API_CompositeExample extends API_CallCurrentOrg
{
	/**
	 * @description Initializes the API handler with request and response DTOs.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"compositeResponse": [{"httpStatusCode": 201, "referenceId": "ref1", "body": {"id": "001000000000001"}}]}';
		requiresTriggeringRecord = false;
	}

	/**
	 * @description Data Transfer Object for Composite API request.
	 */
	@JsonAccess(Serializable='always')
	public class DTO_Request extends DTO_JsonBase
	{
		public Boolean allOrNone = true;
		public List<CompositeSubRequest> compositeRequest;
	}

	/**
	 * @description Data Transfer Object for individual composite sub-request.
	 */
	@JsonAccess(Serializable='always')
	public class CompositeSubRequest
	{
		public String method;
		public String url;
		public String referenceId;
		public Map<String, Object> body;
	}

	/**
	 * @description Data Transfer Object for Composite API response.
	 */
	@JsonAccess(Deserializable='always')
	public class DTO_Response extends DTO_JsonBase
	{
		public List<CompositeSubResponse> compositeResponse;

		/**
		 * @description Returns the type of this DTO for proper deserialization.
		 *
		 * @return The DTO_Response class type
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}

	/**
	 * @description Data Transfer Object for individual composite sub-response.
	 */
	@JsonAccess(Deserializable='always')
	public class CompositeSubResponse
	{
		public Integer httpStatusCode;
		public String referenceId;
		public Map<String, Object> body;
	}

}
```

### How It Works

The [`API_CallCurrentOrg`](reference/apex/API_CallCurrentOrg.md) class overrides three key methods to provide dynamic URL resolution and session-based authentication:

```apex
// 1. configure() — sets baseUrl to the current org domain
global protected virtual override void configure()
{
	super.configure();
	baseUrl = Url.getOrgDomainUrl().toExternalForm();
}

// 2. getAuthorisationToken() — returns Bearer token with session ID
global protected virtual override String getAuthorisationToken()
{
	return HTTP_AUTH_TOKEN_BEARER + UTIL_System.getApiEnabledSessionId();
}

// 3. getWebServiceEndPoint() — combines org domain URL with endpoint path
global protected virtual override String getWebServiceEndPoint()
{
	String orgBaseUrl = Url.getOrgDomainUrl().toExternalForm();
	String endpointPath = setting?.EndpointPath__c;

	return orgBaseUrl + (String.isNotBlank(endpointPath) ? endpointPath : UTIL_String.EMPTY);
}
```

### Configuration

In your `ApiSetting__mdt` record:

| Field            | Value                                   |
|------------------|-----------------------------------------|
| ClassName__c     | `API_CompositeExample`                  |
| EndpointPath__c  | `/services/data/v67.0/composite`        |
| ApiCredential__c | (Leave blank - session ID handles auth) |

**Note**: You do not need a Named Credential for intra-org calls since authentication is handled via the session ID. The org base URL is resolved dynamically at runtime via
`URL.getOrgDomainURL()`.

> **Subscriber Setup**: Add a [Remote Site Setting](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts_remote_site_settings.htm) for your My
> Domain URL (Setup > Remote Site Settings > New). Without this, callouts to the current org will fail with a `System.CalloutException`.

---

## Virtual Methods Reference

This section provides detailed explanations of all virtual methods available for override in the framework. Each method includes its purpose, default behavior, when to override,
and examples.

### Common Base Methods ([API_Base](reference/apex/API_Base.md))

These methods are available in both inbound and outbound APIs.

---

#### getValidationErrors()

**Purpose**: Returns validation error messages that determine whether the API request should be aborted before processing.

**Signature**: `global protected virtual List<String> getValidationErrors()`

**Default Behavior**: Returns an empty list (no validation errors). Framework-level checks (disabled APIs, feature flags, runtime switches) are handled internally by
`performValidation()` -- no `super` call needed.

**When to Override**:

- Validating required parameters
- Checking user permissions
- Validating request payload structure
- Querying and validating related data

**Return Value**: List of error message strings. An empty list means validation passed; non-empty aborts the request.

**Example**:

```apex
/**
 * @description Validates required parameters before proceeding with API call.
 *
 * @return List of validation error messages, empty if validation passed
 */
public override List<String> getValidationErrors()
{
	List<String> errors = new List<String>();

	String userId = inputs.get('userId');
	if(String.isBlank(userId))
	{
		errors.add('userId parameter is required');
	}

	return errors;
}
```

---

#### getBody()

**Purpose**: Returns the request body to be sent in the HTTP request.

**Signature**: `global protected virtual String getBody()`

**Default Behavior**: Serializes `requestPayload` to JSON or XML.

**When to Override**:

- Custom body formatting (multi-part form data, binary content)
- Non-standard serialization
- Custom XML structure

**Return Value**: String containing the request body

**Note**: Rarely needs to be overridden.

---

#### getServiceName()

**Purpose**: Returns the name of the service for logging and configuration lookup.

**Signature**: `protected virtual String getServiceName()`

**Default Behavior**: Uses the class name.

**When to Override**: Only if the configuration name differs from the class name (rare).

**Return Value**: String containing the service name

---

#### onSuccess()

**Purpose**: Registers DML operations to be committed after HTTP callout completes.

**Signature**: `global protected virtual void onSuccess()`

**Default Behavior**: No operations registered (empty method).

**When to Override**:

- Creating records from API responses
- Updating records based on API results
- Logging activity (Tasks, Events, etc.)
- Managing relationships

**Important**: `API_Base` extends `DML_Transaction`, so DML methods (`doInsert()`, `doUpdate()`, `doDelete()`, `doUpsert()`) are inherited directly. Call them within `onSuccess()`
to register DML operations that will be committed after all callouts complete. **Never call DML statements (insert/update/delete) directly**.

**Example**:

```apex
/**
 * @description Creates Account and updates Contact based on API response.
 */
public override void onSuccess()
{
	super.onSuccess();

	DTO_Response response = (DTO_Response)responsePayload;

	// Create Account from API response
	Account newAccount = new Account
	(
		Name = response.companyName,
		Industry = response.industry,
		ExternalId__c = response.externalId
	);
	doInsert(newAccount);

	// Update existing Contact
	Contact existingContact = queryContact();
	existingContact.Email = response.email;
	doUpdate(existingContact);
}
```

---

#### setUnitOfWorksObjectTypes()

**Purpose**: Hook method called during `configure()` for subclass initialization. Override only if your API handler needs to perform setup before processing begins.

**Signature**: `protected virtual void setUnitOfWorksObjectTypes()`

**Default Behavior**: Empty method (no-op).

**When to Override**: Rarely needed. DML operations are registered directly via inherited `doInsert()`, `doUpdate()`, `doDelete()`, `doUpsert()` methods in `onSuccess()`. The
framework resolves SObject type ordering automatically during `commitWork()`.

---

### Outbound-Specific Methods ([API_Outbound](reference/apex/API_Outbound.md))

These methods are only available in outbound APIs.

---

#### getAuthorisationToken()

**Purpose**: Returns the authorization token for the API call.

**Signature**: `global protected virtual String getAuthorisationToken()`

**Default Behavior**: Returns empty string (authentication handled by Named Credential).

**When to Override**:

- Custom authentication (OAuth, API keys, session-based)
- Dynamic token management
- Custom auth schemes

**Return Value**: Authorization header value (e.g., `Bearer {token}`)

**Example**:

```apex
/**
 * @description Provides OAuth token for API authentication.
 *
 * @return Bearer token for authorization
 */
public override String getAuthorisationToken()
{
	// Custom OAuth token logic
	return 'Bearer ' + getOAuthToken();
}
```

---

#### getHttpMethod()

**Purpose**: Specifies the HTTP method for the request.

**Signature**: `global protected override virtual HttpMethod getHttpMethod()`

**Default Behavior**: Returns `HttpMethod.POST`.

**When to Override**: When using GET, PUT, PATCH, or DELETE methods.

**Return Value**: `HttpMethod` enum value (`HttpMethod.GET`, `HttpMethod.POST`, `HttpMethod.PUT`, `HttpMethod.PATCH`, `HttpMethod.DELETE`)

**Example**:

```apex
/**
 * @description Specifies GET method for this API.
 *
 * @return GET HTTP method
 */
public override HttpMethod getHttpMethod()
{
	return HttpMethod.GET;
}
```

---

#### getQueryParameters()

**Purpose**: Returns query parameters to append to the endpoint URL.

**Signature**: `global protected virtual String getQueryParameters()`

**Default Behavior**: Returns empty string.

**When to Override**: When adding URL query parameters.

**Return Value**: Query string (without leading `?`)

**Example**:

```apex
/**
 * @description Builds query parameters for the API call.
 *
 * @return Query string with format and version
 */
public override String getQueryParameters()
{
	List<String> params = new List<String>();
	params.add('format=json');
	params.add('version=2');
	return String.join(params, '&');
}
```

---

#### getRequiredInputs()

**Purpose**: Specifies which request parameters are mandatory.

**Signature**: `global protected virtual Set<String> getRequiredInputs()`

**Default Behavior**: Returns empty set.

**When to Override**: When your API requires specific parameters.

**Return Value**: Set of required parameter names

**Example**:

```apex
/**
 * @description Defines required parameters for validation.
 *
 * @return Set of required parameter names
 */
public override Set<String> getRequiredInputs()
{
	Set<String> required = super.getRequiredInputs();
	required.add('userId');
	required.add('accountId');
	return required;
}
```

---

#### getResponseBody()

**Purpose**: Extracts the response body from the HTTP response.

**Signature**: `global protected virtual String getResponseBody()`

**Default Behavior**: Returns `response.getBody()`.

**When to Override**:

- Unwrapping nested response structure
- Decoding encoded content

**Return Value**: Response body string

---

#### getResponseReplacementTokens()

**Purpose**: Defines token replacements for response JSON before deserialization.

**Signature**: `global protected virtual void getResponseReplacementTokens(List<String> searchTokens, List<String> replaceTokens)`

**Default Behavior**: No replacements.

**When to Override**: When response contains:

- Reserved Apex keywords (`class`, `type`)
- Hyphens in JSON keys (`user-id` → `userId`)
- Special characters incompatible with Apex

**Parameters**:

- `searchTokens` - List to populate with strings to find
- `replaceTokens` - List to populate with replacement strings

**Example**:

```apex
/**
 * @description Replaces reserved keywords and hyphens in response JSON.
 *
 * @param searchTokens List to populate with tokens to find
 * @param replaceTokens List to populate with replacement tokens
 */
public override void getResponseReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
{
	super.getResponseReplacementTokens(searchTokens, replaceTokens);
	searchTokens.add('"user-id"');
	replaceTokens.add('"userId"');
	searchTokens.add('"class"');
	replaceTokens.add('"className"');
}
```

---

#### getTimeout()

**Purpose**: Returns the HTTP request timeout in milliseconds.

**Signature**: `global protected virtual Integer getTimeout()`

**Default Behavior**: Returns 120000 milliseconds (2 minutes).

**When to Override**: When a different timeout is needed.

**Return Value**: Timeout in milliseconds (max 120000)

**Example**:

```apex
/**
 * @description Sets timeout to 1 minute.
 *
 * @return Timeout in milliseconds
 */
public override Integer getTimeout()
{
	return 60000; // 1 minute
}
```

---

#### getWebServiceEndPoint()

**Purpose**: Returns the full endpoint URL for the API call.

**Signature**: `global protected virtual String getWebServiceEndPoint()`

**Default Behavior**: Combines Named Credential URL with path from `ApiSetting__mdt.EndpointPath__c`.

**When to Override**:

- Dynamic URL construction
- URL parameter substitution
- Path variables
- Custom routing logic

**Return Value**: Complete endpoint URL

**Example**:

```apex
/**
 * @description Builds endpoint URL with userId path parameter.
 *
 * @return Complete endpoint URL
 */
public override String getWebServiceEndPoint()
{
	String userId = inputs.get('userId');
	String basePath = super.getWebServiceEndPoint();
	return String.format(basePath, new List<String>{ userId });
}
```

---

#### prepareRequest()

**Purpose**: Populates the request DTO with data for the API call.

**Signature**: `global protected virtual void prepareRequest()`

**Default Behavior**: Calls `requestPayload.populate(recordId, inputs)`.

**When to Override**:

- Complex data transformations
- Querying related data
- Combining multiple data sources
- Parameter processing

**Example**:

```apex
/**
 * @description Populates request with timestamp and user info.
 */
public override void prepareRequest()
{
	super.prepareRequest();

	DTO_Request request = (DTO_Request)requestPayload;
	request.timestamp = Datetime.now();
	request.username = UserInfo.getUserName();
}
```

---

#### setHeaders()

**Purpose**: Sets HTTP headers on the request.

**Signature**: `global protected virtual void setHeaders()`

**Default Behavior**: Sets `Content-Type` and `Accept` headers to JSON.

**When to Override**:

- Custom headers (API keys, tokens, correlation IDs)
- Different content types
- Additional authentication headers

**Example**:

```apex
/**
 * @description Adds custom headers for API call.
 */
public override void setHeaders()
{
	super.setHeaders();
	request.setHeader('X-API-Key', getClientId());
	request.setHeader('X-Correlation-ID', UTIL_Random.randomUUID());
	request.setHeader('X-Client-Version', '2.0');
}
```

---

#### requiresTriggeringRecord

**Purpose**: Indicates whether a triggering object ID is required.

**Signature**: `global protected Boolean requiresTriggeringRecord`

**Default Behavior**: `true`.

**When to Set to `false`**:

- API doesn't need a specific record context (GET requests)
- Uses only parameters
- Operates on multiple records
- Utility/system operation

**Example**:

```apex
public override void configure()
{
	super.configure();
	requestPayload = new DTO_Request();
	responsePayload = new DTO_Response();
	requiresTriggeringRecord = false;
}
```

---

### Inbound-Specific Methods ([API_Inbound](reference/apex/API_Inbound.md))

These methods are only available in inbound APIs.

---

#### processRequest()

**Purpose**: Processes the incoming HTTP request.

**Signature**: `global protected virtual void processRequest()`

**Default Behavior**: No-op (does nothing).

**When to Override**:

- Parse request body
- Query Salesforce data
- Perform business logic
- Validate complex rules

**Example**:

```apex
/**
 * @description Processes incoming request and queries related data.
 */
public override void processRequest()
{
	super.processRequest();

	// Parse request
	DTO_Request request = (DTO_Request)requestPayload;

	// Query related data
	Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Id, Account.Name})
		.condition(Account.ExternalId__c).equals(request.accountId)
		.getFirst();

	// Perform business logic
	if(account != null)
	{
		// Process account
	}
}
```

---

#### updateCallResult()

**Purpose**: Updates the call result with response data.

**Signature**: `global protected virtual void updateCallResult()`

**Default Behavior**: Sets `result.responseBody` from `responsePayload`.

**When to Override**: When custom response formatting is needed.

**Example**:

```apex
/**
 * @description Formats response as pretty-printed JSON.
 */
public override void updateCallResult()
{
	super.updateCallResult();

	DTO_Response response = (DTO_Response)responsePayload;
	result.responseBody = JSON.serializePretty(response, true);
}
```

---

#### updateResponseDTO()

**Purpose**: Updates the response DTO after database commit completes.

**Signature**: `global protected virtual void updateResponseDTO()`

**Default Behavior**: No-op (does nothing).

**When to Override**:

- Include committed record IDs in response
- Add calculated fields from committed data
- Include related data from database

**Example**:

```apex
/**
 * @description Updates response with committed Account ID.
 */
public override void updateResponseDTO()
{
	super.updateResponseDTO();

	DTO_Response response = (DTO_Response)responsePayload;
	response.accountId = committedAccount.Id;
	response.timestamp = Datetime.now();
}
```

---

#### writeResponse()

**Purpose**: Writes the HTTP response back to the caller.

**Signature**: `global protected virtual void writeResponse()`

**Default Behavior**: Serializes `responsePayload` to JSON or writes errors.

**When to Override**:

- Custom response formatting
- Different content types
- Custom error structures
- Response headers

**Example**:

```apex
/**
 * @description Writes response with custom headers.
 */
public override void writeResponse()
{
	super.writeResponse();

	// Add custom response headers
	response.setHeader('X-API-Version', '2.0');
	response.setHeader('X-Request-ID', result.Id);
}
```

---

## Advanced Features

### Automatic Retries

> The retry *strategies* themselves — backoff shapes, jitter, and exception filters — are documented in depth in the **[Resilience - Guide](Resilience%20-%20Guide.md)**. This section covers how the web services framework applies retry to outbound calls via `ApiSetting__mdt`.

The framework automatically handles retries for failed outbound API calls when configured in `ApiSetting__mdt`.

**How It Works**:

When an API call fails, the framework:

1. Checks if `MaxRetryCount__c` is configured and not exceeded
2. Calculates the next retry time using linear backoff (default strategy):
    - Each retry uses `RetryBackoffSeconds__c` seconds as the delay
    - Example: With `RetryBackoffSeconds__c = 30`, all retries wait 30 seconds
3. Sets `NextRetry__c` datetime field
4. Sets `Status__c` to `'Retry'`
5. Increments `Retries__c` counter

**Configuration**:

In `ApiSetting__mdt`:

- **MaxRetryCount__c**: Maximum number of retry attempts (e.g., `3`)
- **RetryBackoffSeconds__c**: Backoff in seconds between retries (e.g., `30`)

**Example Retry Schedule** (with `RetryBackoffSeconds__c = 30`):

- Original call fails at 10:00:00
- First retry scheduled for 10:00:30 (30 seconds later)
- If first retry fails, second retry scheduled for 10:01:00 (30 seconds later)
- If second retry fails, third retry scheduled for 10:01:30 (30 seconds later)

**Automatic Retry Processing**:

The framework ships with a built-in record-triggered flow (`RetryOutboundApiCall`) that automatically processes retries. When an API call fails and the framework sets
`Status__c = 'Retry'` with a `NextRetry__c` datetime, the flow uses a time-based scheduled path to wait until the scheduled time, then invokes `FLOW_CallApiAsync` to re-execute the
callout and sets `Status__c` to `'Retrying'` to prevent re-triggering.

No custom scheduled jobs or platform events are needed — retry processing is fully automated out of the box.

---

#### Custom Retry Strategies

By default, [`API_Outbound`](reference/apex/API_Outbound.md) retries with a linear backoff built from `RetryBackoffSeconds__c` and `MaxRetryCount__c`. To use a different strategy on a handler, override `createRetryStrategy()` to return any [`UTIL_Retry.Strategy`](reference/apex/UTIL_Retry.md):

```apex
public inherited sharing class API_SendGridEmail extends API_Outbound
{
	global override UTIL_Retry.Strategy createRetryStrategy()
	{
		// Exponential backoff with jitter for a rate-limited API
		return UTIL_Retry.exponential()
			.withBaseBackoff(10)
			.withMaximumBackoff(300)
			.withMaxRetries(5)
			.withJitter(true);
	}
}
```

The full retry API — exponential vs linear backoff, jitter, exception allowlists and denylists, and writing a custom `UTIL_Retry.Strategy` (for example, HTTP-status-aware backoff) — is documented in the **[Resilience - Guide](Resilience%20-%20Guide.md)**.

---

### Circuit Breaker Pattern

The framework automatically applies a circuit breaker to every outbound API call, so a failing dependency trips the circuit and later calls fail fast instead of piling up timeouts. The breaker moves through CLOSED → OPEN → HALF_OPEN and recovers on its own.

> The circuit breaker concept — the three states and their transitions, the `execute()` helpers, metrics, and Platform Cache persistence — is covered in depth in the **[Resilience - Guide](Resilience%20-%20Guide.md)**. This section covers how the web services framework wires it onto outbound calls via `ApiSetting__mdt`.

---

#### How It Works in the Framework

**Automatic Activation**: Every outbound API automatically gets circuit breaker protection when you configure `ApiSetting__mdt`.

**Configuration** via `ApiSetting__mdt`:

| Field                               | Description                                               | Example |
|-------------------------------------|-----------------------------------------------------------|---------|
| `CircuitBreakerFailureThreshold__c` | Consecutive failures before opening circuit               | `5`     |
| `CircuitBreakerTimeout__c`          | Seconds to keep circuit open before testing recovery      | `60`    |
| `CircuitBreakerSuccessThreshold__c` | Consecutive successes in half-open state to close circuit | `2`     |

**Example Configuration**:

```text
DeveloperName: SendGrid_Email_API
ClassName__c: API_SendGridEmail
CircuitBreakerFailureThreshold__c: 5
CircuitBreakerTimeout__c: 60
CircuitBreakerSuccessThreshold__c: 2
```

**Behavior**:

1. After **5 consecutive failures**, circuit opens
2. For the next **60 seconds**, all calls immediately fail with `CircuitOpenException`
3. After 60 seconds, circuit enters half-open state
4. Test requests are allowed to verify recovery
5. After **2 consecutive successes**, circuit closes (normal operation)
6. If a test fails → circuit re-opens for another 60 seconds

---

#### State Transitions Example

**Scenario**: External email API experiencing issues

```text
Time    Event                           Circuit State    Action
------  ------------------------------  ---------------  ----------------------------------
10:00   Call fails (timeout)            CLOSED           Failure count: 1
10:01   Call fails (503 error)          CLOSED           Failure count: 2
10:02   Call fails (timeout)            CLOSED           Failure count: 3
10:03   Call fails (503 error)          CLOSED           Failure count: 4
10:04   Call fails (timeout)            CLOSED → OPEN    Failure count: 5 (threshold reached)
10:05   Call attempted                  OPEN             Immediately rejected (CircuitOpenException)
10:06   Call attempted                  OPEN             Immediately rejected
10:07   Call attempted                  OPEN             Immediately rejected
...
11:04   Call attempted                  OPEN → HALF_OPEN Timeout expired, allow test requests
11:04   Test call 1 succeeds            HALF_OPEN        Test 1/2 passed
11:05   Test call 2 succeeds            HALF_OPEN → CLOSED  Test 2/2 passed, circuit closes
11:06   Call succeeds                   CLOSED           Normal operation resumed
```

---

#### Circuit State Persistence

Circuit state is persisted in **Platform Cache** (org-wide), ensuring:

- State maintained across transaction boundaries
- All users see the same circuit state
- Protection applies org-wide (not per-user)

**Example**:

```apex
// User A makes call at 10:04, circuit opens
API_SendGridEmail api = new API_SendGridEmail();
api.run(); // 5th failure, circuit opens

// User B makes call at 10:05 (different transaction, different user)
API_SendGridEmail api2 = new API_SendGridEmail();
api2.run(); // Immediately fails with CircuitOpenException (state loaded from cache)
```

---

#### Default Behavior (No Configuration)

If circuit breaker fields are **not configured** in `ApiSetting__mdt`:

- **Default Threshold**: 3 consecutive failures
- **Default Timeout**: 60 seconds
- **Default Half-Open Requests**: 1

The framework uses sensible defaults, so circuit breaker protection is always active.

---

#### Best Practices

**1. Choose Appropriate Thresholds by Service Type**

| Service Type              | Threshold | Timeout      | Rationale                     |
|---------------------------|-----------|--------------|-------------------------------|
| **Critical Payment APIs** | 2-3       | 300s (5 min) | Low tolerance, long recovery  |
| **Email/Notification**    | 5-10      | 60s (1 min)  | Higher tolerance, quick retry |
| **Internal Salesforce**   | 3-5       | 30s          | Fast recovery expected        |
| **Rate-Limited APIs**     | 5         | 60s          | Match rate limit window       |

**2. Combine Circuit Breakers with Retry Strategies**

Circuit breakers and retry strategies work together:

- **Retry Strategy**: Handles transient failures (1-3 attempts for network blips)
- **Circuit Breaker**: Handles sustained failures (service is down)

```apex
public inherited sharing class API_SendGridEmail extends API_Outbound
{
	// Retry handles transient errors (network timeouts, 429 rate limits)
	global override UTIL_Retry.Strategy createRetryStrategy()
	{
		return UTIL_Retry.exponential()
			.withMaxRetries(3)
			.withBaseBackoff(10);
	}

	// Circuit breaker handles sustained failures (service outage)
	// Configuration loaded from ApiSetting__mdt automatically
}
```

**Request Flow**:

1. Circuit breaker checks state (CLOSED = proceed, OPEN = reject immediately)
2. If CLOSED, retry strategy attempts call (up to 3 times with backoff)
3. If all retries fail, circuit breaker increments failure count
4. When threshold reached, circuit opens

**3. Monitor Circuit State**

Check `ApiCall__c` for circuit-related failures:

```soql
SELECT Id, ServiceName__c, Status__c, ErrorMessages__c, CreatedDate
FROM ApiCall__c
WHERE ErrorMessages__c LIKE '%Circuit breaker is OPEN%'
  AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
```

**4. Environment-Specific Configuration**

Use different thresholds per environment:

**Development/Sandbox** (more tolerant for testing):

```text
CircuitBreakerFailureThreshold__c: 10
CircuitBreakerTimeout__c: 30
```

**Production** (stricter for reliability):

```text
CircuitBreakerFailureThreshold__c: 3
CircuitBreakerTimeout__c: 300
```

**5. Handle Circuit Open Exceptions Gracefully**

When circuit is open, the framework sets `Status__c = 'Aborted'` and logs the error. Implement fallback logic:

```apex
// In your calling code
ApiCall__c queueItem = TST_Factory.newOutboundApiCall('API_SendGridEmail', emailId);
DML_Builder.newTransaction().doInsert(queueItem).execute();

// Check result after processing
queueItem = (ApiCall__c)QRY_Builder.selectFrom(ApiCall__c.SObjectType)
	.addFields(new List<SObjectField>{ApiCall__c.Status__c, ApiCall__c.ErrorMessages__c})
	.condition(ApiCall__c.Id).equals(queueItem.Id)
	.getFirst();

if(queueItem.Status__c == 'Aborted' && queueItem.ErrorMessages__c.contains('Circuit breaker is OPEN'))
{
	// Circuit is open - use alternative approach
	// Option 1: Queue for later retry
	// Option 2: Use backup email service
	// Option 3: Store in offline queue
}
```

---

#### Advanced: Custom Circuit Breaker Configuration

Circuit breaker behavior is configured per service via `ApiSetting__mdt`. For standalone use outside the web services framework, use the `UTIL_CircuitBreaker` API directly:

```apex
// Standalone circuit breaker with custom thresholds
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('MyExternalService')
	.withFailureThreshold(10)       // More tolerant
	.withTimeout(600)                // Longer recovery (10 minutes)
	.withHalfOpenMaxAttempts(5);     // More confident recovery test

breaker.execute(new MyProtectedAction());
```

**When to use standalone circuit breakers**:

- Custom non-API callout scenarios
- Programmatic circuit control based on runtime conditions
- Protecting non-HTTP operations (e.g., platform event publishing)

---

#### Troubleshooting

**Problem**: Circuit opens too frequently

**Solution**: Increase `CircuitBreakerFailureThreshold__c` (e.g., from 3 to 5 or 10)

**Problem**: Circuit stays open too long

**Solution**: Decrease `CircuitBreakerTimeout__c` (e.g., from 300s to 60s)

**Problem**: Circuit closes prematurely after recovery

**Solution**: Increase `CircuitBreakerSuccessThreshold__c` (e.g., from 1 to 3) to require more successful tests

**Problem**: All calls showing "Circuit breaker is OPEN"

**Cause**: Service is genuinely down or experiencing issues

**Solution**:

1. Check external service status
2. Wait for timeout period to expire
3. Circuit will automatically test recovery
4. If needed, manually clear circuit state (see Utilities guide)

---

### Data Masking

Protect sensitive data written to `ApiCall__c` and `ApiIssue__c` using the shared [data masking framework](#maskingrule__mdt--maskingtarget__mdt). Payload fields (`Request__c`,
`Response__c`, `URL__c`, `RequestParameters__c`, `ErrorMessages__c`) are redacted on the trigger dispatcher's before-insert / before-update pre-step, so the persisted row never
holds the raw sensitive value.

**Default coverage out of the box:** `MaskSecretKeys` redacts JSON keys named `password`, `token`, `apiKey`, `authorization`, `bearer`, `client_secret`, `private_key`,
`access_token`, `refresh_token` (and common variants). `MaskPaymentCard` redacts 13–19 digit sequences that pass the Luhn checksum (all major card brands; spaces or hyphens
allowed). No admin work required for those.

**Example: activate US-SSN masking on API payloads**

Add a `MaskingTarget__mdt` wiring the shipped-but-inactive `MaskSsn` rule onto `ApiCall__c`. First flip `MaskingRule.MaskSsn.IsActive__c = true`, then create the target:

| Field            | Value                                      |
|------------------|--------------------------------------------|
| `Rule__c`        | `MaskSsn`                                  |
| `SObjectType__c` | `ApiCall__c`                               |
| `Field__c`       | *blank (wildcard across every text field)* |
| `IsActive__c`    | `true`                                     |

**Example: scope a rule to one service**

Use `CallerClass__c` on a `MaskingTarget__mdt` to fire a rule only when a specific API class is invoking the mask — useful when one rule (e.g., a credit-card format your processor
uses) should only apply to payment-service payloads and not bleed into unrelated callouts.

**How it works:** the framework reads the populated text fields of the record, caches the resolved rule-to-field plan for `(SObjectType, callerClassName)` once per transaction,
then applies each rule in rule-order with JSON-key rules batched into a single deserialize/serialize pass. The actual HTTP request/response going over the wire is unaffected — only
the logged copy is redacted.

---

### Mock Mode and API_MockFactory

The framework provides a three-tier mock resolution system for testing and sandbox environments:

1. **Memory mocks** — [`API_MockFactory.forService()`](reference/apex/API_MockFactory.md) / `API_MockFactory.registerErrorMock()` (highest priority)
2. **Metadata mocks** — `ApiMock__mdt` custom metadata records
3. **`defaultMockBody`** — JSON string set on the handler class in `configure()`

#### defaultMockBody (Handler-Level Mocking)

Set `defaultMockBody` in `configure()` for automatic test mocking without additional setup:

```apex
public override void configure()
{
	super.configure();
	requestPayload = new DTO_Request();
	responsePayload = new DTO_Response();
	defaultMockBody = '{"success": true, "messageId": "msg-12345"}';
}
```

In tests, the framework automatically returns this JSON as the mock HTTP response (200 OK) when no higher-priority mock is registered.

#### API_MockFactory (Programmatic Mocking)

[`API_MockFactory`](reference/apex/API_MockFactory.md) provides fluent mock registration for advanced test scenarios:

```apex
// Register a custom mock response
API_MockFactory.forService(API_SendEmail.class.getName())
	.body('{"messageId":"msg-123"}')
	.statusCode(200)
	.register();

// Register a 500 error mock
API_MockFactory.registerErrorMock(API_SendEmail.class.getName());

// Register a parse-fail mock (200 OK with unparseable body)
API_MockFactory.registerParseFailMock(API_SendEmail.class.getName());

// Clear all registered mocks
API_MockFactory.clearMocks();
```

**MockBuilder methods** (all return `MockBuilder` for chaining):

| Method                              | Description                                                |
|-------------------------------------|------------------------------------------------------------|
| `.body(String)`                     | Response body (supports `{{request.field}}` interpolation) |
| `.statusCode(Integer)`              | HTTP status code                                           |
| `.status(String)`                   | HTTP status text                                           |
| `.withHeader(String, String)`       | Add a response header                                      |
| `.withHeaders(Map<String, String>)` | Add multiple response headers                              |
| `.fromResponse(HttpResponse)`       | Populate from an existing HttpResponse                     |
| `.withFailureRate(Integer)`         | Percentage of requests to fail randomly (0-100)            |
| `.register()`                       | Register the mock in the factory                           |

#### Call Verification

Verify that mocks were called with expected data (Mockito-style assertions):

```apex
// Check if a service was called
Assert.isTrue(API_MockFactory.wasCalled(API_SendEmail.class.getName()), 'Service should be called');

// Verify the service was never called
Assert.isTrue(API_MockFactory.wasNeverCalled(API_SendEmail.class.getName()), 'Should not be called');

// Verify last request contained specific data
Assert.isTrue(
	API_MockFactory.lastRequestContains(API_SendEmail.class.getName(), '"recipient"'),
	'Request should contain recipient'
);
```

#### Response Interpolation

Echo request data back in mock responses using `{{request.field}}` placeholders:

```apex
API_MockFactory.forService(API_EchoService.class.getName())
	.body('{"echoId":"{{request.id}}","echoName":"{{request.data.name}}"}')
	.statusCode(200)
	.register();

// When request contains {"id":"12345","data":{"name":"Acme"}}
// Response becomes: {"echoId":"12345","echoName":"Acme"}
```

**Supported patterns:**

- `{{request.fieldName}}` — Top-level field
- `{{request.nested.field}}` — Nested field access via dot notation

#### Fault Injection

Test error handling with simulated failures:

```apex
// 50% of requests fail randomly with 500
API_MockFactory.forService(API_UnreliableService.class.getName())
	.body('{"success":true}')
	.statusCode(200)
	.withFailureRate(50)
	.register();
```

#### Declarative Mock Mode

**Enable Mock Mode** without changing code:

**Via Feature Flag**: Enable the `MockAllInboundAPIs` feature flag to force mock mode for all inbound APIs.

**Per-Service**: Set `MockingEnabled__c = true` on the service's `ApiSetting__mdt` record.

**Metadata Mocks** (via `ApiMock__mdt`):

Configure mock responses in custom metadata for sandbox and demo environments without deploying code changes. `ApiMock__mdt` records support response bodies, status codes, headers,
request matching patterns, delay simulation, and failure rates.

---

### Disabling APIs

**Disable APIs** without code deployment:

**All APIs** (hierarchy): `ApiRuntimeSwitch__c.DisableAllApis__c = true` (per user/profile/org)

**All APIs** (feature flag): Enable the `DisableAllAPIs` feature flag

**Per-Service**: Set `IsActive__c = false` on the service's `ApiSetting__mdt` record

**Per-Service** (feature flag): Set `BypassFeatureFlag__c` on `ApiSetting__mdt` to a feature flag name — when enabled, the service is bypassed

---

### Performance Monitoring

Every API call tracks timing metrics:

| Field                  | Description                               |
|------------------------|-------------------------------------------|
| `CalloutDurationMs__c` | Time spent in HTTP callout (milliseconds) |
| `HandlerDurationMs__c` | Time spent in handler logic               |
| `CommitDurationMs__c`  | Database commit time                      |
| `TotalDurationMs__c`   | Total end-to-end time                     |

Access in code:

```apex
Long calloutTime = handler.calloutProcessingTime.getTime();
Long handlerTime = handler.serviceProcessingTime.getTime();
Long commitTime = handler.commitProcessingTime.getTime();
Long totalTime = handler.fullProcessingTime.getTime();
```

---

### Batched Outbound Calls

For scenarios where you want to queue multiple API calls and process them asynchronously:

**Scheduled Processing**:

The framework includes [`SCHED_PerformBatchedCallouts`](reference/apex/SCHED_PerformBatchedCallouts.md) for processing queued API calls:

```apex
// Schedule batched callout processing.
System.schedule
(
	'Process Batched API Calls',
	'0 */5 * * * ?',
	new SCHED_PerformBatchedCallouts()
);
```

**How It Works**:

1. Create queue items with status `'Batched'`
2. Scheduled job changes status to `'Queued'`
3. Platform event or async processor picks up queued items
4. Factory manager executes the calls

---

### Safe Mode

Safe Mode enables dry-run execution of API handlers where all DML is rolled back after completion. The framework uses it internally for testing, debugging, and validating API
behaviour without persisting changes.

> **Framework-internal API.** `API_Base.enterSafeMode()`, `API_Base.isSafeModeActive()`, and `API_Base.SafeModeContext` are declared `public` (not `global`) and are not callable
> from subscriber Apex. Subscribers who want dry-run testing of an inbound API should use `@IsTest` methods with `Test.startTest()` / `Test.stopTest()` and let the test-mode rollback
> do the work — or mock the outbound callout via `kern.API_MockFactory.forService(serviceName).body(json).register()`.

#### Framework usage (reference)

```apex
// Internal framework pattern — shown for documentation only.
API_Base.SafeModeContext safeMode = API_Base.enterSafeMode();
try
{
	API_Dispatcher.processInboundService('API_MyHandler');
}
finally
{
	safeMode.close();
}
```

**Framework-internal methods:**

| Method                        | Visibility | Description                                                  |
|-------------------------------|-----------:|--------------------------------------------------------------|
| `API_Base.enterSafeMode()`    |   `public` | Returns a `SafeModeContext` — must be closed via try/finally |
| `API_Base.isSafeModeActive()` |   `public` | Check if any Safe Mode scope is currently active             |
| `safeMode.close()`            |   `public` | Close the scope (idempotent — safe to call multiple times)   |

#### Behavior

| Aspect            | Behavior                          |
|-------------------|-----------------------------------|
| DML Operations    | Executed then rolled back         |
| Triggers          | Fire normally                     |
| Validation Rules  | Execute and can block             |
| Workflows/Flows   | Execute but rolled back           |
| HTTP Callouts     | Blocked with mock response        |
| Emails            | NOT rolled back                   |
| Platform Events   | Rolled back (deferred publishing) |
| Governor Limits   | Consumed as normal                |
| `ApiCall__c` logs | Rolled back (not persisted)       |

#### Use Cases

- **Debugging failed APIs** — replay a request with Safe Mode to inspect behavior without side effects
- **Validating new API handlers** — test end-to-end flow before enabling in production
- **Demo environments** — execute APIs without creating real records
- **Test Harness** — the `apiTestHarnessForm` LWC uses Safe Mode by default

---

### API Test Harness (LWC + Tab)

The `apiTestHarnessForm` Lightning Web Component provides an interactive, full-page workspace for testing inbound and outbound APIs. It ships with a dedicated `ApiTestHarness`
FlexiPage + Custom Tab so you reach it from the Kern Home page (or any nav menu) without App Builder configuration.

#### Features

- **Two-column page layout** — configuration on the left, response preview on the right
- **Service discovery** — auto-populates available services from `ApiSetting__mdt` filtered by direction
- **Direction toggle** — switch between inbound and outbound APIs, reloads the service list automatically
- **Key-value parameter grid** — dynamic rows for outbound parameters (add/remove/replacement-row), serialised to the Apex controller as a structured `List<DTO_NameValue>` inside a
  single JSON request payload (avoids the comma/equals footgun of delimited strings)
- **Execution Settings safety bar** — 4-state combined indicator for Safe Mode and Mocking:
    - **Safe Mode** (blue info): DML rolled back, real callouts
    - **Full Sandbox** (green success): DML rolled back AND responses mocked
    - **Live DML · Mocked callouts** (amber warning): persistent DML but mocked external calls
    - **LIVE** (red error + SLDS alert-texture stripes): fully persistent, maximum risk
- **Destructive Execute variant** — when Safe Mode is off, the Execute button turns red with a `utility:warning` icon and "Execute (Live)" label
- **Reset button** — clears direction, service, parameters, toggles, and result in one click
- **Response preview** — status badge (dynamically themed by `isSuccess` / `isAborted` / HTTP 4xx-5xx), metrics grid, Request/Response/Errors tabs with JSON viewers
- **API Call Id hyperlink** — when Safe Mode was off on execution, the persisted `ApiCall__c` record Id renders as a clickable link that navigates to the record page; when Safe
  Mode was on (no persisted record), the Id is plain text
- **Sticky config column** — on wide viewports, the left-side configuration panel stays pinned while the user scrolls the response preview, so Execute and Reset stay visible
- **Capped scroll regions** — inner JSON viewers and header tables scroll internally rather than stretching the whole page, so very large responses stay manageable

#### Deployment

Ships as part of Kern with three metadata artifacts — no App Builder wiring required:

- `ApiTestHarness.flexipage-meta.xml` — the App Page that hosts the form
- `ApiTestHarness.tab-meta.xml` — the Custom Tab referencing the FlexiPage
- `Administrator.permissionset-meta.xml` — grants tab visibility via `<tabSettings>`

Users navigate to `/lightning/n/ApiTestHarness` or click the **API Test Harness** tool card on Kern Home to open it. The `apiTestHarnessForm` LWC is also exposed to
`lightning__AppPage` and `lightning__HomePage` if subscribers want to embed it elsewhere.

---

### Idempotency (Inbound APIs)

Idempotency keys let inbound API callers retry a request safely after a network failure or timeout, without risking duplicate processing. Enable it per-service with
`kern__ApiSetting__mdt.IdempotencyEnabled__c = true`. Once enabled, callers send a unique `Idempotency-Key` HTTP header on each request and the framework deduplicates against
`kern__ApiCall__c.IdempotencyKey__c`.

#### What gets stored

When idempotency is enabled and a caller sends an `Idempotency-Key` header, the framework stores three fields on `ApiCall__c` after first-call processing:

- **`IdempotencyKey__c`** — the raw header value, indexed as an external ID for fast replay lookup
- **`IdempotencyKeyBodyHash__c`** — a SHA-256 hex digest of the request body, used to detect key reuse with a divergent body (see "Replay behaviour" below)
- **`IsIdempotencyHit__c`** — `true` if the response was returned from a prior call's record without re-running the handler; `false` for first calls

The body hash is computed once per call. Outbound calls leave the field blank (idempotency keys on outbound are subscriber-driven via `UTIL_HttpClient`'s `withCorrelationId()`, not
framework-managed).

#### Replay behaviour

The framework's replay decision is a three-way branch on the inbound request:

| Replay scenario                                               | Stored hash on existing record | New request body hash | Framework response                                                             |
|---------------------------------------------------------------|--------------------------------|-----------------------|--------------------------------------------------------------------------------|
| **Same key, same body** (network retry, idempotent replay)    | matches                        | matches               | HTTP 200 + cached response from `Response__c`                                  |
| **Same key, different body** (caller bug or stale-edit retry) | populated                      | differs               | **HTTP 409** with JSON body referencing the original `ApiCall.Id`              |
| **Same key, legacy record** (created before A5 shipped)       | null                           | any                   | HTTP 200 + cached response (legacy passthrough — see "Backward compatibility") |

The HTTP 409 response body shape:

```json
{
  "error": "Idempotency-Key reused with different request body",
  "originalApiCallId": "a01ABC0000xyz123"
}
```

Callers can parse `originalApiCallId` and query the original `ApiCall__c` record to reconcile what their first request actually committed.

#### Handling 409 in callers

When a caller receives HTTP 409 from an inbound endpoint, the framework is signalling that the same `Idempotency-Key` was previously used to commit a *different* request body.
Three reasonable client-side responses:

1. **Investigate the divergence** — fetch the original record via `kern__ApiCall__c.Id = :originalApiCallId` and compare the stored `Request__c` against the new payload. Most often
   the caller has buggy retry logic that mutates the request body before retrying.
2. **Use a new key for the new payload** — if the caller legitimately wants to send a different request, generate a fresh `Idempotency-Key`. Reusing the same key with a different
   body is a contract violation per the IETF idempotency-key draft.
3. **Surface the conflict to the caller's user** — for human-driven workflows (e.g. a form submission), present the original response so the user knows their first attempt
   succeeded and the second was a duplicate.

Note: HTTP 409 is only returned when both bodies hash differently. Same-body replays continue to return HTTP 200 with the cached response — this is the standard idempotent-replay
path and is unchanged.

#### Backward compatibility

`ApiCall__c` records created before the body-hash field shipped have `IdempotencyKeyBodyHash__c = null`. The framework cannot detect divergence on these records, so it falls
through to the cached-response path (HTTP 200) regardless of whether the new request body matches the original. This preserves pre-existing behaviour for legacy data.

Forward-going records (created after the body-hash check shipped) get the full 409 detection. There is no migration to backfill the hash on legacy records — the field stays null
and those records are treated as legacy passthroughs forever.

To audit which records have the hash populated:

```apex
// Records with body-hash detection enabled
List<kern__ApiCall__c> withHash = [
    SELECT Id, kern__ServiceName__c, kern__IdempotencyKey__c
    FROM kern__ApiCall__c
    WHERE kern__IdempotencyKey__c != null
    AND kern__IdempotencyKeyBodyHash__c != null
    AND kern__Direction__c = 'Inbound'
];

// Legacy records (pre-A5) — replay behaviour falls through to cached response
List<kern__ApiCall__c> legacyRecords = [
    SELECT Id, kern__ServiceName__c, kern__IdempotencyKey__c
    FROM kern__ApiCall__c
    WHERE kern__IdempotencyKey__c != null
    AND kern__IdempotencyKeyBodyHash__c = null
    AND kern__Direction__c = 'Inbound'
];
```

---

## Integration with Flows

The framework provides two invocable methods for calling APIs from Salesforce Flows, enabling both **synchronous** (immediate response) and **asynchronous** (background processing)
callout patterns.

### Understanding Synchronous vs Asynchronous Callouts

#### When to Use Synchronous Callouts

**Use synchronous callouts when:**

- ✅ You need an immediate API response to display to the user
- ✅ The API call is fast (typically < 5 seconds)
- ✅ The flow needs the API response to make decisions
- ✅ Running from a **Screen Flow** where the user is waiting
- ✅ The flow is invoked manually (not from a record trigger)

**Example Scenarios:**

- Data enrichment in a screen flow
- Credit card verification during checkout
- Real-time inventory check
- Currency conversion for display

**⚠️ Important Limitations:**

- Synchronous callouts **block** the flow execution until the API responds
- Maximum callout time: 120 seconds (Salesforce limit)
- Cannot be used in **before-save** record-triggered flows
- Counts against synchronous transaction limits

#### When to Use Asynchronous Callouts

**Use asynchronous callouts when:**

- ✅ The API response is not needed immediately
- ✅ Running from a **Record-Triggered Flow** (after-save)
- ✅ The API call might be slow or unreliable
- ✅ You want to prevent blocking user interactions
- ✅ Processing large volumes of API calls

**Example Scenarios:**

- Notifying external systems of record changes
- Syncing data to external databases
- Sending emails or notifications via third-party services
- Background data enrichment

**✅ Benefits:**

- Does not block user interface or flow execution
- Automatic retry and error handling
- Better for unreliable or slow APIs
- Can handle higher volumes via batch processing

---

### Synchronous Callouts from Screen Flows

#### Use Case: External API Call from Screen Flow

A screen flow where users provide input and need immediate API response feedback before proceeding.

**Flow Type:** Screen Flow
**Invocable Action:** `Invoke Callout Synchronously`
**Framework Class:** [`FLOW_CallApi`](reference/apex/FLOW_CallApi.md)

**Flow Configuration:**

1. **Create Screen** - Collect user input
   ```
   Screen: Enter Details
   - Text Input: Title → {!title}
   ```

2. **Add Action Element** - Invoke API Synchronously
   ```
   Action: Call External API
   Type: Invoke Callout Synchronously

   Inputs:
   - webServiceClassName: "API_PostExample"
   - recordId: {!recordId}
   - parameters: "foo={!title}"
   - inputDelimiter: "," (default)
   - extractPath: (optional - to extract specific JSON element)

   Store Outputs:
   - success → {!apiSuccess}
   - responseBody → {!apiResponse}
   - queueItemId → {!queueId}
   - extractedValue → {!extractedValue}
   ```

3. **Add Decision Element** - Check API Result
   ```
   Decision: API Succeeded?
   Outcome 1: Success
     Condition: {!apiSuccess} Equals {!$GlobalConstant.True}
     → Go to next screen

   Outcome 2: Failed
     Condition: {!apiSuccess} Equals {!$GlobalConstant.False}
     → Show error screen
   ```

4. **Screen: Success** - Display result
   ```
   Display Text:
   "API Response: {!apiResponse}"
   ```

5. **Screen: Error** - Display error message
   ```
   Display Text:
   "API call failed: {!apiResponse}"
   ```

**Complete Example Flow Metadata:**

See `FLOW_ApiTestHarness` (`force-app/main/default/flows/FLOW_ApiTestHarness.flow-meta.xml`) for a complete working example of synchronous API calls from a screen flow with
response handling.

**Input Parameters:**

| Parameter             | Type   | Required | Description                             | Example                |
|-----------------------|--------|----------|-----------------------------------------|------------------------|
| `webServiceClassName` | String | ✅        | API class name                          | `API_PostExample`      |
| `recordId`            | String | ❌        | Record ID (if API needs record context) | `{!recordId}` or blank |
| `parameters`          | String | ❌        | Comma-separated name=value pairs        | `foo=Test Title`       |
| `inputDelimiter`      | String | ❌        | Delimiter for parameters (default: `,`) | `,` or `;`             |
| `extractPath`         | String | ❌        | JSON path to extract specific element   | `title`                |

**Output Variables:**

| Output           | Type    | Description                                        | Example Value                                                          |
|------------------|---------|----------------------------------------------------|------------------------------------------------------------------------|
| `success`        | Boolean | Whether API call succeeded                         | `true` or `false`                                                      |
| `responseBody`   | String  | Full API response or error message                 | `{"body":"Some Random Body","id":101,"title":"Test Title","userId":9}` |
| `queueItemId`    | String  | ID of logged `ApiCall__c` record                   | `a0X5g000000AbCD`                                                      |
| `extractedValue` | String  | Extracted JSON element (if `extractPath` provided) | `Test Title`                                                           |

---

### Asynchronous Callouts from Record-Triggered Flows

#### Use Case: Notify External System When Account is Created

A record-triggered flow that calls an external API when a new Account is created, without blocking the save operation.

**Flow Type:** Record-Triggered Flow (After Save)
**Trigger:** Account Created

**How It Works:**

The framework ships with two built-in record-triggered flows on `ApiCall__c`:

| Flow                    | Trigger     | Purpose                                                                                                  |
|-------------------------|-------------|----------------------------------------------------------------------------------------------------------|
| `ResetOutboundApiCall`  | Before Save | Clears execution output fields (zero DML) when an `ApiCall__c` is set to `Queued`                        |
| `InvokeOutboundApiCall` | After Save  | Invokes [`FLOW_CallApiAsync`](reference/apex/FLOW_CallApiAsync.md) to process the callout asynchronously |

Your flow only needs to **create the `ApiCall__c` record** with `Status__c = 'Queued'` — the framework handles the rest.

**Why Asynchronous?**

- The `InvokeOutboundApiCall` flow calls `FLOW_CallApiAsync`, which enqueues a Queueable job
- Job size is configurable via `AsynchronousJobSetting__mdt` (default: 20, hard cap: 100 per the callout governor limit)
- Callout budget is monitored at runtime — remaining items are deferred if the limit is reached
- Automatic retry if external system is temporarily unavailable
- Better error handling and logging

**Flow Configuration:**

1. **Flow Properties**
   ```
   Object: Account
   Trigger: A record is created
   Entry Conditions: All Conditions Are Met (Boolean) AND
     - Account Type Equals "Customer"
   Optimize the Flow For: Actions and Related Records
   ```

2. **Create Records Element** - Build API Queue Item
   ```
   Create Records: Build API Queue Item
   How Many Records: One
   Object: ApiCall__c

   Set Field Values:
   - ServiceName__c: "API_NotifyAccountCreated"
   - TriggeringRecordId__c: {!$Record.Id}
   - Direction__c: "Outbound"
   - Status__c: "Queued"
   ```

That's it. No action element needed — the framework's `InvokeOutboundApiCall` flow triggers automatically when the `ApiCall__c` record is created with `Status__c = 'Queued'` and
`Direction__c = 'Outbound'`.

**Important Notes:**

- The flow completes immediately after creating the queue item
- The API call executes asynchronously in the background via a Queueable job
- Check `ApiCall__c.Status__c` to monitor progress
- Framework automatically retries failed calls based on `ApiSetting__mdt` configuration
- Cannot use the API response in the same flow (it happens later)

---

### Comparison Matrix: Sync vs Async Callouts

| Aspect                 | Synchronous                             | Asynchronous                                         |
|------------------------|-----------------------------------------|------------------------------------------------------|
| **Execution**          | Blocks until complete                   | Returns immediately                                  |
| **Use From**           | Screen Flows, Manual Invocation         | Record-Triggered Flows (after-save), Scheduled Flows |
| **Response Available** | Yes, immediately                        | No (logged to `ApiCall__c`)                          |
| **Max Duration**       | 120 seconds                             | No practical limit (runs in Queueable/Batch)         |
| **Error Handling**     | Must handle in flow                     | Automatic retry via framework                        |
| **User Experience**    | User waits for response                 | User not blocked                                     |
| **Governor Limits**    | Counts against transaction limits       | Separate async limits                                |
| **Best For**           | Real-time validation, Interactive forms | Background sync, Notifications, Data enrichment      |
| **Retry Support**      | Manual only                             | Automatic via framework                              |

---

### Best Practices for Flow Integration

#### **Always Check Success Flag**

```text
Decision: API Call Successful?
Outcome 1: Success
  - Condition: {!apiSuccess} Equals true
  - Action: Proceed with success path
Outcome 2: Failure
  - Condition: {!apiSuccess} Equals false
  - Action: Display error message: {!apiResponse}
```

#### **Provide User Feedback**

**For Synchronous Calls:**

- Show spinner/progress indicator during API call
- Display success or error message based on response
- Allow user to retry on failure

**For Asynchronous Calls:**

- Inform user the action will complete in background
- Provide reference number (`queueItemId`) for tracking
- Set up email notifications for completion/errors

#### **Handle Timeouts**

```text
Add Fault Path to Action Element:
- Store Error Message: {!$Flow.FaultMessage}
- Show Error Screen: "The API request timed out. Please try again."
```

#### **Use Meaningful Parameter Names**

```text
✅ GOOD: parameters = "accountId={!recordId},accountName={!accountName}"
❌ BAD:  parameters = "id={!recordId},name={!accountName}"
```

#### **Log Queue Item IDs**

Store the `queueItemId` in a custom field for later tracking:

```text
Update Record: Update Account
- WebserviceQueueId__c = {!queueItemId}
```

---

### Testing Flow Callouts

#### Test Synchronous Flow Callout

```apex
@IsTest
private static void testSynchronousFlowCallout()
{
	Test.startTest();

	Map<String, Object> flowInputs = new Map<String, Object>
	{
		'webServiceClassName' => 'API_PostExample',
		'parameters' => 'foo=Test Title'
	};

	Flow.Interview flow = Flow.Interview.createInterview('YourFlowAPIName', flowInputs);
	flow.start();

	Boolean success = (Boolean)flow.getVariableValue('apiSuccess');
	String payload = (String)flow.getVariableValue('apiResponse');

	Test.stopTest();

	Assert.isTrue(success, 'API call should succeed');
	Assert.isNotNull(payload, 'Response payload should not be null');
}
```

#### Test Asynchronous Flow Callout

```apex
@IsTest
private static void testAsynchronousFlowCallout()
{
	Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Test Account')
		.build();

	Test.startTest();

	ApiCall__c queueItem = TST_Factory.newOutboundApiCall(
		'API_NotifyAccountCreated',
		testAccount.Id,
		new Map<String, String>()
	);
	FLOW_CallApiAsync.invokeApiCallAsynchronously(
		new List<ApiCall__c>{ queueItem }
	);

	Test.stopTest();

	SEL_ApiCall.assertServiceCompleted('API_NotifyAccountCreated');
}
```

---

## Logging and Monitoring

### Where Things Are Logged

| Component            | Location                          | Details                                                       |
|----------------------|-----------------------------------|---------------------------------------------------------------|
| **All API Calls**    | `ApiCall__c`                      | Request, response, status, timing                             |
| **Large Payloads**   | `ContentVersion`                  | Files linked to queue item                                    |
| **Errors**           | `ApiCall__c.ErrorMessages__c`     | Error messages and stack traces                               |
| **Failures**         | `ApiIssue__c`                     | Persistent failure records (if enabled)                       |
| **Application Logs** | `LogEntryEvent__e` Platform Event | Via [`LOG_Builder`](reference/apex/LOG_Builder.md) fluent API |

### Automatic Web Service Context

The framework automatically injects web service context into all [`LOG_Builder`](reference/apex/LOG_Builder.md) calls during API execution. This context appears in the
`ContextData__c` field of `LogEntry__c` records.

**Automatic Context Fields:**

| Field               | When Set      | Description                                      |
|---------------------|---------------|--------------------------------------------------|
| `serviceName`       | `configure()` | The API handler class name                       |
| `endpoint`          | `configure()` | The endpoint URL being called                    |
| `httpMethod`        | `configure()` | The HTTP method (GET, POST, etc.)                |
| `statusCode`        | After callout | HTTP response status code (outbound only)        |
| `calloutDurationMs` | After callout | Callout duration in milliseconds (outbound only) |

**How It Works:**

When you call any [`LOG_Builder`](reference/apex/LOG_Builder.md) method during API processing, the framework automatically includes the web service context:

```apex
public inherited sharing class API_CustomerSync extends API_Outbound
{
	public override void onSuccess()
	{
		super.onSuccess();

		// This log entry automatically includes web service context
		LOG_Builder.build().info('Processing customer sync').emitAt('API_CustomerSync.onSuccess');
		// ContextData__c includes: serviceName, endpoint, httpMethod, statusCode, calloutDurationMs
	}
}
```

**Correlation with Other Logs:**

Web service calls can use transaction correlation to link all related logs:

```apex
// Before calling the API
LOG_Builder.startCorrelation();
LOG_Builder.build().info('Initiating customer sync').emitAt('MyService.syncCustomer');

// Execute API - context is automatically maintained
API_Dispatcher.execute(queueItems);

// All logs share the same correlationId for easy debugging
```

**Context Cleanup:**

The framework automatically clears the web service context when API processing completes, ensuring subsequent logs don't incorrectly inherit API context.

### Monitoring API Health

**List View: Recent API Calls**

```soql
SELECT Name, ServiceName__c, Status__c, StatusCode__c, CreatedDate, ErrorMessages__c
FROM ApiCall__c
WHERE CreatedDate = LAST_N_DAYS:7
ORDER BY CreatedDate DESC
```

**Dashboard Metrics**:

- Success rate by service
- Average response time
- Failed calls requiring retry
- Most common error messages

### Accessing Large Payloads

When request/response exceeds field limits:

```apex
// Get related files
List<ContentDocumentLink> links = QRY_Builder.selectFrom(ContentDocumentLink.SObjectType)
	.fields(new List<String>{'ContentDocumentId', 'ContentDocument.LatestPublishedVersionId'})
	.condition(ContentDocumentLink.LinkedEntityId).equals(queueItem.Id)
	.toList();

Set<Id> versionIds = new Set<Id>();
for(ContentDocumentLink link : links)
{
	versionIds.add((Id)link.ContentDocument.get('LatestPublishedVersionId'));
}

List<ContentVersion> versions = QRY_Builder.selectFrom(ContentVersion.SObjectType)
	.fields(new List<SObjectField>{ContentVersion.VersionData, ContentVersion.Title})
	.condition(ContentVersion.Id).isIn(versionIds)
	.toList();

for(ContentVersion version : versions)
{
	if(version.Title.contains('RequestBody'))
	{
		String fullRequest = version.VersionData.toString();
	}
}
```

---

## Testing

### Overview of Test Helper Classes

The framework provides comprehensive test helper classes that simplify web service testing and eliminate boilerplate code:

| Helper Class                                                         | Purpose                  | Used For                                                      |
|----------------------------------------------------------------------|--------------------------|---------------------------------------------------------------|
| [`API_OutboundTestHelper`](reference/apex/API_OutboundTestHelper.md) | Test outbound REST APIs  | Successful calls, failed calls, aborted calls, parse failures |
| [`API_InboundTestHelper`](reference/apex/API_InboundTestHelper.md)   | Test inbound REST APIs   | Setting up REST context, validating aborted calls             |
| [`SEL_ApiCall`](reference/apex/SEL_ApiCall.md)                       | Assert queue item status | Verifying service completion, abortion, or failure            |
| [`TST_Factory`](reference/apex/TST_Factory.md)                       | Create test data         | Generating `ApiCall__c` records for testing                   |
| [`TST_Builder`](reference/apex/TST_Builder.md)                       | Build test records       | Creating test data with proper relationships                  |

**Key Benefits:**

- ✅ Reduce test code by 60-80%
- ✅ Consistent testing patterns across all APIs
- ✅ Automatic queue item creation and assertion
- ✅ Built-in validation of framework behavior
- ✅ Cleaner, more maintainable tests

---

### Testing Outbound APIs

#### Using API_OutboundTestHelper

The [`API_OutboundTestHelper`](reference/apex/API_OutboundTestHelper.md) class provides methods to test outbound API calls without writing boilerplate code.

**Key Methods:**

| Method                                                                                | Purpose                        | Returns              |
|---------------------------------------------------------------------------------------|--------------------------------|----------------------|
| `assertCallSuccessful(serviceName, recordId)`                                         | Test successful API execution  | API handler instance |
| `assertCallSuccessful(serviceName, recordId, parameters)`                             | Test with custom parameters    | API handler instance |
| `assertCallSuccessfulWithTransformation(serviceName, recordId, transformerClassName)` | Test with response transformer | API handler instance |
| `assertCallFailed(queueItems)`                                                        | Test failed API calls          | List of API handlers |
| `assertCallAborted(serviceName, recordId)`                                            | Test aborted calls             | API handler instance |

**What These Methods Do Automatically:**

1. Create [`ApiCall__c`](reference/objects/ApiCall__c.md) queue item using [`TST_Factory`](reference/apex/TST_Factory.md)
2. Execute the API via [`API_Dispatcher`](reference/apex/API_Dispatcher.md)
3. Assert the expected status (completed, failed, aborted)
4. Return the handler for additional assertions

#### Complete Outbound Test Example

```apex
/**
 * @description Unit tests for API_PostExample outbound API.
 *
 * @see API_PostExample
 */
@IsTest(SeeAllData=false IsParallel=true)
private class API_PostExample_TEST
{
	/**
	 * @description Validates successful API call with parameters
	 */
	@IsTest
	private static void successfulCallReturnsResponse()
	{
		API_Base handler = API_OutboundTestHelper.assertCallSuccessful(API_PostExample.class.getName(), UserInfo.getUserId());

		Assert.isNotNull(handler, 'Handler should not be null');

		// Verify queue item was created and marked as completed
		List<ApiCall__c> queueItems = SEL_ApiCall.assertServiceCompleted(API_PostExample.class.getName());
		Assert.areEqual(1, queueItems.size(), 'Should have one queue item');
		Assert.isNotNull(queueItems[0].Response__c, 'Response should be logged');
	}

	/**
	 * @description Validates API call with triggering Account record
	 */
	@IsTest
	private static void apiCallWithTriggeringObjectReferencesRecord()
	{
		Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Test Company')
			.build();

		API_Base handler = API_OutboundTestHelper.assertCallSuccessful
		(
			API_PostExample.class.getName(),
			testAccount.Id
		);

		List<ApiCall__c> queueItems = new SEL_ApiCall().findByServiceName
		(
			API_PostExample.class.getName()
		);
		Assert.areEqual(testAccount.Id, queueItems[0].TriggeringRecordId__c, 'Should reference account');
	}

	/**
	 * @description Validates API abortion when all outbound calls are disabled
	 */
	@IsTest
	private static void disabledApiAbortsWithError()
	{
		TST_Factory.newFeatureFlag('DisableAllAPIs');

		API_Base handler = API_OutboundTestHelper.assertCallAborted
		(
			API_PostExample.class.getName(),
			null
		);

		Assert.isTrue(handler.result.isAborted, 'Call should be aborted');
		Assert.isFalse(handler.result.errors.isEmpty(), 'Should have error messages');

		// Verify queue item shows aborted status
		List<ApiCall__c> queueItems = SEL_ApiCall.assertServiceAborted
		(
			API_PostExample.class.getName(),
			'API has been disabled'
		);
		Assert.areEqual(1, queueItems.size());
	}

	/**
	 * @description Validates bulk processing of multiple API calls
	 */
	@IsTest
	private static void bulkApiCallsProcessAllRecords()
	{
		List<ApiCall__c> queueItems = new List<ApiCall__c>();
		for(Integer i = 0; i < 5; i++)
		{
			queueItems.add
			(
				TST_Factory.newOutboundApiCall
				(
					API_PostExample.class.getName(),
					UserInfo.getUserId()
				)
			);
		}

		Test.startTest();
		List<API_Base> handlers = API_Dispatcher.execute(queueItems);
		Test.stopTest();

		Assert.areEqual(5, handlers.size(), 'Should process all 5 API calls');

		List<ApiCall__c> completedItems = SEL_ApiCall.assertServiceCompleted
		(
			API_PostExample.class.getName()
		);
		Assert.areEqual(5, completedItems.size(), 'All calls should complete successfully');
	}
}
```

#### Using TST_Factory for Queue Items

When you need more control over queue item creation:

```apex
/**
 * @description Creates outbound queue item with basic service name
 */
ApiCall__c queueItem1 = TST_Factory.newOutboundApiCall(
	'API_PostExample'
);

/**
 * @description Creates queue item with triggering object
 */
ApiCall__c queueItem2 = TST_Factory.newOutboundApiCall(
	'API_PostExample',
	accountId
);

/**
 * @description Creates queue item with parameters map
 */
ApiCall__c queueItem3 = TST_Factory.newOutboundApiCall(
	'API_PostExample',
	accountId,
	new Map<String, String>{ 'foo' => 'Test Title' }
);

/**
 * @description Creates queue item with single parameter
 */
ApiCall__c queueItem4 = TST_Factory.newOutboundApiCall(
	'API_PostExample',
	accountId,
	'foo',
	'Test Title'
);
```

---

### Testing Inbound APIs

#### Using API_InboundTestHelper

The [`API_InboundTestHelper`](reference/apex/API_InboundTestHelper.md) class simplifies setup of REST context for inbound API testing.

**Key Methods:**

| Method                                                         | Purpose                                                                          |
|----------------------------------------------------------------|----------------------------------------------------------------------------------|
| `setupRestContext()`                                           | Initializes `RestContext.request` and `RestContext.response` with default values |
| `setupRestContext(DTO_Base dtoRequest)`                        | Sets up context and populates request body with serialized DTO                   |
| `assertCallAborted(serviceName)`                               | Executes API and asserts it was aborted                                          |
| `assertCallAborted(serviceName, exceptionMessage)`             | Asserts abortion with specific error message                                     |
| `assertCallAborted(serviceName, dtoRequest, exceptionMessage)` | Full setup with DTO and error validation                                         |

**What setupRestContext() Does:**

1. Creates new `RestRequest` and `RestResponse` objects
2. Sets `Content-Type` header to `application/json`
3. Sets HTTP method to `POST`
4. Sets default request URI to `https://example.com/test`
5. Assigns to `RestContext.request` and `RestContext.response`

#### Complete Inbound Test Example

```apex
/**
 * @description Unit tests for API_PersonRetrieve inbound API.
 *
 * @see API_PersonRetrieve
 * @see REST_Person
 */
@IsTest(SeeAllData=false IsParallel=true)
private class API_PersonRetrieve_TEST
{
	/**
	 * @description Creates test Contact record for use in tests
	 */
	@TestSetup
	private static void setupTestData()
	{
		TST_Builder.of(Contact.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
			Contact.LastName => 'Test Person',
			Contact.FirstName => 'John',
			Contact.Email => 'john.test@example.com',
			Contact.MobilePhone => '555-0100',
			Contact.CMN_ExternalReference__c => 'test-guid-12345'
		}).build();
	}

	/**
	 * @description Validates successful person retrieval with valid identity ID
	 */
	@IsTest
	private static void successfulRetrievalReturnsPersonData()
	{
		Contact testContact = (Contact)QRY_Builder.selectFrom(Contact.SObjectType)
			.addFields(new List<SObjectField>{Contact.Id, Contact.CMN_ExternalReference__c})
			.withLimit(1)
			.getFirst();

		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestURI = RestContext.request.requestURI + '/' + testContact.CMN_ExternalReference__c;

		Test.startTest();
		System.runAs(TST_Factory.newUser(SEL_Profile.API_ONLY_USER))
		{
			REST_Person.getPerson();
		}
		Test.stopTest();
		String responseBody = RestContext.response.responseBody.toString();
		Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);

		Assert.areEqual('Test Person', responseMap.get('lastName'), 'Should return lastName');
		Assert.areEqual('John', responseMap.get('firstName'), 'Should return firstName');
		Assert.areEqual('john.test@example.com', responseMap.get('email'), 'Should return email');
		Assert.areEqual(200, RestContext.response.statusCode, 'Should return 200 OK');

		// Verify queue item was logged with completed status
		SEL_ApiCall.assertServiceCompleted(API_PersonRetrieve.class.getName());
	}

	/**
	 * @description Validates error handling when person is not found
	 */
	@IsTest
	private static void personNotFoundReturnsErrorResponse()
	{
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestURI = RestContext.request.requestURI + '/invalid-guid-99999';

		Test.startTest();
		System.runAs(TST_Factory.newUser(SEL_Profile.API_ONLY_USER))
		{
			REST_Person.getPerson();
		}
		Test.stopTest();

		Assert.areEqual(400, RestContext.response.statusCode, 'Should return 400 Bad Request');
		String responseBody = RestContext.response.responseBody.toString();
		Assert.isTrue(responseBody.contains('No person found'), 'Should contain error message');

		// Verify queue item was logged with aborted status
		SEL_ApiCall.assertServiceAborted(API_PersonRetrieve.class.getName(), 'No person found');
	}

	/**
	 * @description Validates missing identity ID returns validation error
	 */
	@IsTest
	private static void missingIdentityIdReturnsValidationError()
	{
		API_InboundTestHelper.setupRestContext();

		Test.startTest();
		REST_Person.getPerson();
		Test.stopTest();

		SEL_ApiCall.assertServiceAborted(API_PersonRetrieve.class.getName(), 'Identity Id not provided');
	}

	/**
	 * @description Validates update person with DTO modifies contact record
	 */
	@IsTest
	private static void updatePersonWithDtoModifiesContactRecord()
	{
		Contact testContact = (Contact)QRY_Builder.selectFrom(Contact.SObjectType)
			.addFields(new List<SObjectField>{Contact.Id, Contact.CMN_ExternalReference__c})
			.withLimit(1)
			.getFirst();

		API_PersonUpdate.DTO_Request updateRequest = new API_PersonUpdate.DTO_Request();
		updateRequest.identityId = testContact.CMN_ExternalReference__c;
		updateRequest.firstName = 'Jane';
		updateRequest.lastName = 'Updated';
		updateRequest.email = 'jane.updated@example.com';

		API_InboundTestHelper.setupRestContext(updateRequest);

		Test.startTest();
		REST_Person.editPerson();
		Test.stopTest();

		Contact updatedContact = (Contact)QRY_Builder.selectFrom(Contact.SObjectType)
			.addFields(new List<SObjectField>{Contact.Id, Contact.FirstName, Contact.LastName, Contact.Email})
			.condition(Contact.Id).equals(testContact.Id)
			.getFirst();
		Assert.areEqual('Jane', updatedContact.FirstName, 'FirstName should be updated');
		Assert.areEqual('Updated', updatedContact.LastName, 'LastName should be updated');
		Assert.areEqual('jane.updated@example.com', updatedContact.Email, 'Email should be updated');

		// Verify queue item shows successful completion
		SEL_ApiCall.assertServiceCompleted(API_PersonUpdate.class.getName());
	}

	/**
	 * @description Validates assertCallAborted helper detects missing required fields
	 */
	@IsTest
	private static void assertCallAbortedHelperDetectsMissingFields()
	{
		API_PersonUpdate.DTO_Request invalidRequest = new API_PersonUpdate.DTO_Request();

		Test.startTest();
		API_Base handler = API_InboundTestHelper.assertCallAborted(API_PersonUpdate.class.getName(), invalidRequest, 'Identity Id not provided');
		Test.stopTest();

		Assert.isTrue(handler.result.isAborted, 'Should be aborted');
		Assert.isTrue(handler.result.errors.contains('Identity Id not provided'), 'Should have validation error');
	}
}
```

#### Using SEL_ApiCall for Assertions

The [`SEL_ApiCall`](reference/apex/SEL_ApiCall.md) class provides assertion methods to verify API execution status.

**Key Assertion Methods:**

```apex
/**
 * @description Asserts API completed successfully
 */
List<ApiCall__c> completedItems = SEL_ApiCall.assertServiceCompleted(
	'API_PersonRetrieve'
);

/**
 * @description Asserts API was aborted
 */
List<ApiCall__c> abortedItems = SEL_ApiCall.assertServiceAborted(
	'API_PersonRetrieve'
);

/**
 * @description Asserts API was aborted with specific error message
 */
List<ApiCall__c> abortedItems = SEL_ApiCall.assertServiceAborted(
	'API_PersonRetrieve',
	'No person found'
);

/**
 * @description Asserts API failed
 */
List<ApiCall__c> failedItems = SEL_ApiCall.assertServiceFailed(
	'API_PersonRetrieve'
);

/**
 * @description Asserts API failed with specific error phrase
 */
List<ApiCall__c> failedItems = SEL_ApiCall.assertServiceFailed(
	'API_PersonRetrieve',
	'Timeout'
);
```

**What These Methods Do:**

1. Query `ApiCall__c` for the specified service name
2. Assert that at least one queue item exists
3. Assert that all queue items have the expected status
4. Optionally assert error message contains the specified phrase
5. Return the queue items for additional assertions

**Query Methods:**

```apex
/**
 * @description Retrieves all queue items for a service
 */
List<ApiCall__c> items = new SEL_ApiCall().findByServiceName(
	'API_PersonRetrieve'
);

/**
 * @description Retrieves batched outbound queue items
 */
List<ApiCall__c> batchedItems = new SEL_ApiCall().findByBatchedOutbound();
```

---

### Testing Best Practices

1. **Always use test helper classes** - [`API_OutboundTestHelper`](reference/apex/API_OutboundTestHelper.md) and [`API_InboundTestHelper`](reference/apex/API_InboundTestHelper.md)
   eliminate boilerplate
2. **Use [`TST_Builder`](reference/apex/TST_Builder.md) for test data** - Cleaner than manual record creation
3. **Test bulk scenarios** - Create and process multiple queue items
4. **Use assertion methods** - `assertServiceCompleted()`, `assertServiceAborted()`, `assertServiceFailed()`
5. **Verify queue items** - Always check that `ApiCall__c` records were created correctly
6. **Test error scenarios** - Missing parameters, invalid data, disabled APIs
7. **Use @TestSetup** - Create common test data once for multiple test methods
8. **Test with different users** - Use `System.runAs()` to test with API users
9. **Enable logging when needed** - Set `LOG_Builder.ignoreTestMode = true` for log testing
10. **Test mock responses** - Verify that mock classes return expected data

### Common Test Patterns

**Pattern 1: Simple Successful Outbound Call**

```apex
@IsTest
private static void successfulOutboundCallCompletesWithResponse()
{
	Test.startTest();
	API_Base handler = API_OutboundTestHelper.assertCallSuccessful(API_MyService.class.getName(), recordId);
	Test.stopTest();

	// Additional assertions on handler.result or handler.responsePayload
}
```

**Pattern 2: Outbound Call with Parameters**

```apex
@IsTest
private static void outboundCallWithParametersExecutesCorrectly()
{
	Map<String, String> params = new Map<String, String>{ 'key' => 'value' };

	Test.startTest();
	API_Base handler = API_OutboundTestHelper.assertCallSuccessful(API_MyService.class.getName(), null, params);
	Test.stopTest();
}
```

**Pattern 3: Inbound Call Setup**

```apex
@IsTest
private static void inboundCallProcessesRequestSuccessfully()
{
	API_InboundTestHelper.setupRestContext();
	RestContext.request.requestURI = RestContext.request.requestURI + '/someId';

	Test.startTest();
	REST_MyAPI.httpMethodName();
	Test.stopTest();

	SEL_ApiCall.assertServiceCompleted(API_MyImplementation.class.getName());
}
```

**Pattern 4: Inbound Call with DTO**

```apex
@IsTest
private static void inboundCallWithDtoProcessesRequest()
{
	API_MyService.DTO_Request request = new API_MyService.DTO_Request();
	request.fieldName = 'value';

	API_InboundTestHelper.setupRestContext(request);

	Test.startTest();
	REST_MyAPI.httpMethodName();
	Test.stopTest();

	SEL_ApiCall.assertServiceCompleted(API_MyService.class.getName());
}
```

**Pattern 5: Testing Abortion**

```apex
@IsTest
private static void abortedCallLogsErrorMessage()
{
	Test.startTest();
	API_Base handler = API_OutboundTestHelper.assertCallAborted(API_MyService.class.getName(), null);
	Test.stopTest();

	SEL_ApiCall.assertServiceAborted(API_MyService.class.getName(), 'Expected error message');
}
```

---

## Capability Matrix (for Analysts)

| Capability                            | Custom Metadata                           | Field/Class                                                                                                                           | Notes                                                                                                                     |
|---------------------------------------|-------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| API endpoint configuration (inbound)  | `ApiSetting__mdt`                         | `EndpointPath__c`                                                                                                                     | Declarative endpoint configuration for inbound REST handlers                                                              |
| API endpoint configuration (outbound) | `ApiSetting__mdt`                         | `EndpointPath__c` (HTTP method via handler's `getHttpMethod()` override)                                                              | Declarative endpoint; HTTP verb is set in the handler class, not the metadata record                                      |
| Credential management                 | `ApiCredential__mdt`                      | Named Credential reference                                                                                                            | Secure credential storage and rotation                                                                                    |
| Data masking                          | `MaskingRule__mdt` + `MaskingTarget__mdt` | `Mode__c` (Regex / JsonKey / ExactMatch / CreditCard), `Pattern__c`, `Replacement__c`, `MinInputLength__c`, `ApplicableFieldTypes__c` | Shared redaction framework — ships with secrets + credit-card rules active; subscribers opt additional rules in per field |
| Mock mode                             | `ApiSetting__mdt`                         | `MockingEnabled__c`                                                                                                                   | Enable mock responses without callouts                                                                                    |
| API disable switch                    | `ApiRuntimeSwitch__c`                     | `DisableAllApis__c`                                                                                                                   | Emergency kill switch for all API calls (hierarchy)                                                                       |
| Retry strategy                        | `ApiSetting__mdt`                         | `MaxRetryCount__c`, `RetryBackoffSeconds__c`                                                                                          | Configurable retry with linear or exponential backoff                                                                     |
| Circuit breaker                       | `ApiSetting__mdt`                         | `CircuitBreakerEnabled__c`                                                                                                            | Automatic circuit breaker protection                                                                                      |
| Performance logging                   | Automatic                                 | `ApiCall__c.TotalDurationMs__c`                                                                                                       | All API calls are automatically timed and logged                                                                          |
| Batched callouts                      | `ScheduledJob__c`                         | `SCHED_PerformBatchedCallouts`                                                                                                        | Process queued API calls in scheduled batches                                                                             |

---

## Anti-Patterns

| Anti-Pattern                                           | Why It's Wrong                                                                  | Instead                                                                                                          |
|--------------------------------------------------------|---------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| Raw `HttpRequest`/`HttpResponse` without the framework | No logging, no retry, no data masking, no mock support                          | Extend `API_Outbound` or `API_Inbound` and let the orchestrator handle the lifecycle                             |
| DML before callout in the same transaction             | Salesforce throws `CalloutException` -- you cannot make callouts after DML      | Use the framework's orchestration pattern: callout first, then `onSuccess()` for DML registration                |
| Hardcoding endpoints or credentials in Apex            | Cannot change per environment, fails security review, blocks testing            | Use `ApiSetting__mdt` + Named Credentials; override `getWebServiceEndPoint()` only when dynamic                  |
| Overriding every virtual method                        | Makes the class brittle and harder to maintain when the framework evolves       | Override only what differs from the defaults (see [Override Only What You Need](#override-only-what-you-need)) |
| Skipping `@JsonAccess` on DTOs in subscriber orgs      | Serialization fails at runtime with a security error in managed package context | Always add `@JsonAccess(Serializable='always' Deserializable='always')` to every DTO                             |

---

## Best Practices

### Code Standards

**Always follow the project coding standards**:

- Use **tabs for indentation** (indent size: 3, tab size: 3)
- Braces on new lines (Allman style)
- No space before control structure parentheses
- Keywords (`else`, `while`, `catch`) on new lines
- ApexDoc for all public/global methods and classes
- Meaningful variable names in camelCase

### Naming Conventions

**Outbound APIs:**

- **REST**: `API_Get*`, `API_Post*`, `API_Put*`, `API_Patch*`, `API_Delete*`
- **Intra-Org**: `API_*` (extends [`API_CallCurrentOrg`](reference/apex/API_CallCurrentOrg.md))
- **Mocks**: `API_*Mock`

**Inbound APIs (Two-Class Pattern):**

- **REST Routing Classes**: `REST_*`
    - Examples: `REST_Echo`, `REST_Person`, `REST_Invoices`
- **API Implementation Classes**: `API_*`
    - Examples: `API_Echo`, `API_PersonRetrieve`, `API_PersonUpdate`

**Common:**

- **DTOs**: `DTO_Request`, `DTO_Response`, `DTO_*` (nested)

### Override Only What You Need

**Don't override methods unnecessarily.** The framework provides good defaults:

```apex
// ❌ BAD - Unnecessary overrides
public override String getEncoding()
{
	return HTTP_ENCODING_JSON;  // Already the default!
}

public override HttpMethod getHttpMethod()
{
	return HttpMethod.POST;  // Already the default!
}

// ✅ GOOD - Only override when changing defaults
public override HttpMethod getHttpMethod()
{
	return HttpMethod.GET;  // Different from default
}
```

### Error Handling

```apex
/**
 * @description Handles errors with custom notification logic.
 *
 * @param error The exception that occurred
 */
public override void handleError(Exception error)
{
	super.handleError(error);

	// Send notification to administrators
	// Log to external system
	// Create case for follow-up
}
```

### Logging Best Practices

- **Always use LOG_Builder fluent API** for application errors:
  ```apex
  LOG_Builder.build().error(error).emitAt('API_PostExample.prepareRequest');
  ```

- **Don't log sensitive data** - use data masks instead

- **Use appropriate log levels**:
    - `LOG_Builder.build().error().emitAt()` - Errors requiring attention
    - `LOG_Builder.build().warn().emitAt()` - Potential issues
    - `LOG_Builder.build().info().emitAt()` - Informational messages
    - `LOG_Builder.build().debug().emitAt()` - Detailed debugging (disabled in prod)

### Inbound API Architecture

**Always use the two-class URL prefix pattern for inbound APIs:**

✅ **DO:**

- Separate REST routing (REST_* classes) from business logic (API_* classes)
- Use `@RestResource` only on REST routing classes
- Delegate to `API_Dispatcher.processInboundService()`
- Keep REST routing classes minimal (only routing, no business logic)
- One REST class can handle multiple HTTP methods (GET, POST, PATCH, etc.)

❌ **DON'T:**

- Put `@RestResource` directly on API implementation classes
- Mix routing logic with business logic in the same class
- Manually instantiate API classes (e.g., `new API_Echo().handleRequest()`)
- Create separate REST classes for each HTTP method on the same endpoint

**Benefits:**

- Better separation of concerns
- Easier to maintain and test
- One REST endpoint can support multiple operations
- API implementations can be reused at different endpoints

### Security Considerations

- **Never hardcode credentials** - use Named Credentials
- **Validate all inputs** in `getValidationErrors()`
- **Use HTTPS** for all external endpoints
- **Implement data masking** for sensitive fields
- **Use appropriate sharing** models (`with sharing` vs `without sharing`)

### Performance Optimization

- **Use asynchronous callouts** for long-running operations
- **Batch multiple API calls** when possible
- **Implement pagination** for large result sets
- **Set appropriate timeouts**
- **Avoid SOQL in loops** in `prepareRequest()`

### Understanding the Orchestration

The framework's orchestration ensures:

1. **Callouts happen first** (no uncommitted work)
2. **DML happens after** all callouts complete
3. **Errors are handled** at each stage

This is why you should:

- Never call DML directly in `process()` method
- Always use `doInsert()`, `doUpdate()`, `doDelete()` within `onSuccess()`
- Let the framework handle commit timing

---

## Troubleshooting

### Common Issues

#### API Call is Aborted

**Symptom**: Queue item shows `Status__c = 'Aborted'`

**Possible Causes**:

- API disabled via feature flag or `ApiRuntimeSwitch__c`
- Missing required parameters
- Missing ApiSetting__mdt record
- No triggering object when required

**Solutions**:

- Check `ErrorMessages__c` field for specific error
- Verify `ApiRuntimeSwitch__c` and feature flag settings
- Confirm ApiSetting__mdt exists with correct ClassName__c
- Provide required parameters

---

#### Namespace Errors

**Symptom**: "Type cannot be constructed: API_Outbound"

**Possible Cause**: Missing namespace prefix in managed package context. The same code snippet also fails a separate framework convention: every Apex class must declare its sharing
mode (`with sharing`, `inherited sharing`, or `without sharing`). Both rules apply independently.

**Solution**:

```apex
// ❌ WRONG — missing sharing modifier AND namespace prefix (both required in subscriber org)
public class MyAPI extends API_Outbound
{
}

// ✅ CORRECT — explicit sharing modifier AND namespace-prefixed base class
public inherited sharing class MyAPI extends kern.API_Outbound
{
}
```

---

#### Callout Not Executing

**Symptom**: No HTTP callout occurring

**Possible Causes**:

- Mock mode enabled
- Test.setMock() not called in test
- Named Credential misconfigured

**Solutions**:

- Check `IsMockedResponse__c` field
- Verify `ApiSetting__mdt.MockingEnabled__c` and `MockAllInboundAPIs` feature flag
- Ensure Named Credential exists and is accessible

---

#### Database Changes Not Committing

**Symptom**: Records not saved despite successful API call

**Possible Causes**:

- Not calling `doInsert()` / `doUpdate()` within `onSuccess()`
- Calling DML directly instead of using framework
- Exception during commit

**Solutions**:

- Use `doInsert()`, `doUpdate()`, `doDelete()` within `onSuccess()` instead of direct DML
- Check debug logs for commit errors
- Verify object permissions (CRUD/FLS)

---

#### Callout from Triggers Error

**Symptom**: "Callout from triggers with uncommitted work pending is not allowed"

**Possible Cause**: Attempting to make callout with uncommitted DML

**Solution**: The framework already handles this! Ensure you're using `API_Dispatcher.execute()` which orchestrates callouts before commits.

---

## Support and Resources

### Code Examples in Framework

- `API_Echo` - Simple inbound example
- `API_PostExample` - Outbound POST with DTOs
- `API_GetPwndPasswords` - Outbound GET with parameters
- [`API_CallCurrentOrg`](reference/apex/API_CallCurrentOrg.md) - Intra-org API base class
- `API_SendMail` - Complex outbound with nested DTOs (in examples)
- `API_PersonRetrieve` - Inbound GET with validation (in examples)
- `API_PersonUpdate` - Inbound PATCH with DML (in examples)

### Getting Help

- Check debug logs for detailed error messages
- Review `ApiCall__c` records for request/response details
- Search for similar patterns in existing API classes
- Consult with the platform team

---

**Document Version History**

| Version | Date          | Author         | Changes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|---------|---------------|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1.0     | November 2024 | Framework Team | Initial comprehensive guide                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 2.0     | January 2025  | Framework Team | Added managed package namespace, orchestration pattern, real-world examples                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 2.1     | January 2025  | Framework Team | Applied code standards with ApexDoc, detailed method explanations, intra-org API documentation, factual retry mechanism, removed fictional references                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 2.2     | January 2025  | Framework Team | Added custom retry strategy documentation, clarified LINEAR_BACKOFF default behavior, documented `createRetryStrategy()` extensibility pattern                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 3.0     | February 2026 | Framework Team | Updated all class names to current framework conventions (API_Outbound, API_Inbound, API_Dispatcher, TST_Builder, TST_Factory, SEL_ApiCall, etc.). Added reference links, Salesforce doc links, and rebuilt TOC.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| 3.1     | March 2026    | Framework Team | Pre-release sweep: fixed REST routing class prefix (URL_* to REST_*), corrected all ApiCall__c and ApiSetting__mdt field names, fixed UTIL_Retry.Strategy and UTIL_CircuitBreaker.Breaker interface names, fixed SEL_ApiCall instance method calls, corrected TOC anchors and numbering, added missing sharing declarations and @IsTest annotations.                                                                                                                                                                                                                                                                                                                                                                                                               |
| 3.2     | March 2026    | Framework Team | Third-pass review: replaced fictitious abortRequest() method with actual getValidationErrors() throughout (Virtual Methods Reference, all code examples), fixed requestParameters property references to inputs, fixed UTIL_HttpClient delegation mode example (useHandler is static entry point), renamed populateRequestDTO to prepareRequest (actual method name), corrected getHttpMethod return type from String to HttpMethod enum, fixed HTTP_VERB_GET references to HttpMethod.GET, corrected getServiceName signature (protected, not global), removed non-existent API_PostExampleMock from flow test, fixed missing private modifiers on test patterns, replaced inline DML with DML_Builder, corrected API_PersonUpdate description from PUT to PATCH. |
| 3.3     | March 2026    | Framework Team | Fourth-pass review: added missing H4 TOC entries for Safe Mode (Usage, Behavior, Use Cases), API Test Harness (Features, Deployment), and Best Practices for Flow Integration (5 sub-headings). Removed fictional API_NotifyAccountCreated_Mock and unnecessary Test.setMock from async flow test example.                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 3.4     | March 2026    | Framework Team | Documented delegation mode caller override precedence for UTIL_HttpClient — credential, path, retry, circuit breaker, and failure logging settings provided by the caller take precedence over the handler's ApiSetting__mdt defaults.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

---

## Related Documentation

- [Logging - Guide](Logging%20-%20Guide.md) - Automatic API logging, correlation tracking, and performance monitoring
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger-based API callout orchestration via `API_Dispatcher`
- [DML - Guide](DML%20-%20Guide.md) - Unit of Work pattern used in `onSuccess()`
- [Selectors - Guide](Selectors%20-%20Guide.md) - Query patterns for DTO population and validation
- [Validation - Guide](Validation%20-%20Guide.md) - Input validation patterns via `getValidationErrors()`
- [UTIL_HttpClient](reference/apex/UTIL_HttpClient.md) - Fluent HTTP client for ad-hoc calls with automatic retry, logging, and circuit breaker
