# Code Scanning - Guide

**Framework:** KernDX
**Package Type:** Managed Package

> **Note for Subscriber Implementations:** When using KernDX with a custom namespace, prefix framework class references with your namespace (e.g., `ClientNS.LOG_Builder`).
> See the [AI Agent Instructions](AI%20Agent%20Instructions.md) for details.

**Target Audience:**
- **Developers** - Configuring scanners in IDE and CI/CD, understanding rule violations, suppressing false positives
- **Architects** - Designing quality gates, selecting enforcement tiers, planning phased adoption
- **DevOps** - Integrating scanners into deployment pipelines, configuring CI/CD tools

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Architecture](#architecture)
   - [Enforcement Layers](#enforcement-layers)
   - [File Listing](#file-listing)
4. [PMD Rule Reference](#pmd-rule-reference)
   - [Priority 1 Blockers](#priority-1-blockers)
     - [KernTriggerMustDelegate](#kerntriggermustdelegate)
     - [KernNoInlineSOQL](#kernnoinlinesoql)
     - [KernNoCoverageTheatre](#kernnocoveragetheatre)
     - [KernCoverageExemptRequiresReason](#kerncoverageexemptrequiresreason)
   - [Priority 3 Should Fix](#priority-3-should-fix)
     - [KernNoDirectDML](#kernnodirectdml)
     - [KernNoSystemDebug](#kernnosystemdebug)
     - [KernNoRawHttp](#kernnorawhttp)
     - [KernUseSchedulerBase](#kernuseschedulerbase)
     - [KernNoRawSchedule](#kernnorawschedule)
     - [KernNoRawEventPublish](#kernnoraweventpublish)
     - [KernNoRawHttpMock](#kernnorawhttpmock)
     - [KernNoRawRestContext](#kernnorawrestcontext)
     - [KernNoRawEmail](#kernnorawemail)
     - [KernRestResourceNaming](#kernrestresourcenaming)
     - [KernNoInlineDmlInTests](#kernnoinlinedmlintests)
   - [Priority 5 Informational](#priority-5-informational)
     - [KernNoLegacyAssert](#kernnolegacyassert)
     - [KernUseTestBuilder](#kernusetestbuilder)
     - [KernNoRawCache](#kernnorawcache)
     - [KernNoRawDescribe](#kernnorawdescribe)
     - [KernNoRawTypeForName](#kernnorawtypeforname)
     - [KernNoRawEnqueueJob](#kernnorawenqueuejob)
     - [KernNoRawCrypto](#kernnorawcrypto)
     - [KernNoRawFeatureManagement](#kernnorawfeaturemanagement)
     - [KernNoBooleanExceptionThrown](#kernnobooleanexceptionthrown)
   - [PMD Rule Summary Table](#pmd-rule-summary-table)
5. [ESLint Rules (LWC)](#eslint-rules-lwc)
   - [kerndx/use-component-builder](#kerndxuse-component-builder)
   - [kerndx/no-console-log](#kerndxno-console-log)
   - [kerndx/enforce-component-naming](#kerndxenforce-component-naming)
   - [kerndx/no-coverage-exempt-without-reason](#kerndxno-coverage-exempt-without-reason)
   - [kerndx/no-jest-theatre](#kerndxno-jest-theatre)
   - [kerndx/no-mutating-shared-fixture](#kerndxno-mutating-shared-fixture)
   - [ESLint Setup](#eslint-setup)
6. [Naming Validator (Flows & Custom Objects)](#naming-validator-flows--custom-objects)
   - [Configuration](#configuration)
   - [Running the Validator](#running-the-validator)
   - [Customizing for Your Org](#customizing-for-your-org)
7. [Deploy-Time Scanners](#deploy-time-scanners)
   - [Access-Mode Scanner](#access-mode-scanner)
   - [Flow-Reference Scanner](#flow-reference-scanner)
   - [Umbrella Scan](#umbrella-scan)
8. [Suppression](#suppression)
   - [Apex (PMD)](#apex-pmd)
   - [LWC (ESLint)](#lwc-eslint)
   - [Flow/Object Naming](#flowobject-naming)
9. [IDE Integration](#ide-integration)
   - [VS Code](#vs-code)
   - [IntelliJ / Illuminated Cloud](#intellij--illuminated-cloud)
10. [CI/CD Integration](#cicd-integration)
    - [Salesforce Code Analyzer v5 (Recommended)](#salesforce-code-analyzer-v5-recommended)
    - [GitHub Actions](#github-actions)
    - [Gearset](#gearset)
    - [Copado](#copado)
    - [AutoRABIT](#autorabit)
    - [CodeScan](#codescan)
    - [Legacy SF Scanner (v4)](#legacy-sf-scanner-v4)
11. [Building Org-Specific Rules](#building-org-specific-rules)
12. [Phased Adoption Strategy](#phased-adoption-strategy)
    - [Phase 1: Blockers Only](#phase-1-blockers-only)
    - [Phase 2: Framework Compliance](#phase-2-framework-compliance)
    - [Phase 3: Best Practices](#phase-3-best-practices)
    - [Tracking Progress](#tracking-progress)
13. [PMD Version Compatibility](#pmd-version-compatibility)
14. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                           | Go to...                                                                   |
|---------------|----------------------------------------|----------------------------------------------------------------------------|
| **Developer** | Understand a PMD violation             | [PMD Rule Reference](#pmd-rule-reference)                                  |
| **Developer** | Fix an ESLint error in my LWC          | [ESLint Rules (LWC)](#eslint-rules-lwc)                                    |
| **Developer** | Suppress a rule for a valid reason     | [Suppression](#suppression)                                                |
| **Developer** | Set up scanning in VS Code             | [IDE Integration](#ide-integration)                                        |
| **Architect** | Plan a phased rollout                  | [Phased Adoption Strategy](#phased-adoption-strategy)                      |
| **Architect** | Build org-specific naming rules        | [Building Org-Specific Rules](#building-org-specific-rules)                |
| **DevOps**    | Add scanning to a CI/CD pipeline       | [CI/CD Integration](#cicd-integration)                                     |
| **DevOps**    | Validate Flow and Object naming        | [Naming Validator (Flows & Custom Objects)](#naming-validator-flows--custom-objects) |

---

## Overview

KernDX ships a multi-layered compliance scanner that enforces framework abstractions, prevents anti-patterns, and maintains naming consistency across an entire Salesforce
project. The scanner is located in the `scanner/` directory and is designed to run in three complementary layers:

1. **PMD rulesets** -- static analysis for Apex code (framework compliance, test-quality gates, and optional org-specific naming)
2. **ESLint plugin** -- static analysis for LWC JavaScript (ComponentBuilder enforcement, console blocking, naming, and Jest test-quality gates)
3. **Naming validator** -- Node.js script for declarative metadata that PMD and ESLint cannot parse (Flows, Custom Objects)

**Why automated scanning matters:** Without automated enforcement, framework bypasses accumulate silently. A developer writes `insert record;` instead of
`DML_Builder.newTransaction().doInsert(record).execute()`, and the code works -- but loses transactional safety, sharing enforcement, error handling, and logging.
The scanner catches these bypasses at the earliest possible point: in the IDE as the developer types, or at the latest in CI/CD before the code reaches an org.

> **Companion Document:** For a quick-start walkthrough of scanner setup and first scan, see **Fast Start - Code Scanning.md**. This guide is the comprehensive
> reference covering every rule, suppression mechanism, and integration option.

---

## Architecture

### Enforcement Layers

The three layers cover different artefact types using the best-suited tool for each:

```text
+----------------------------------+     +----------------------------------+     +----------------------------------+
|         PMD Rulesets             |     |       ESLint Plugin              |     |       Naming Validator           |
|  (Apex classes & triggers)       |     |  (LWC JavaScript)                |     |  (Flows & Custom Objects)        |
+----------------------------------+     +----------------------------------+     +----------------------------------+
|  kerndx-pmd-ruleset.xml         |     |  eslint-plugin-kerndx/           |     |  validate-naming.js              |
|  24 XPath rules, PMD 7           |     |  6 ESLint rules                  |     |  Node.js script, org-specific    |
|  Framework anti-patterns         |     |  ComponentBuilder, console,      |     |  Flow & Custom Object naming     |
|  Priority 1/3/5 tiers            |     |  component naming                |     |  Configurable domains/brands     |
+----------------------------------+     +----------------------------------+     +----------------------------------+
         |                                        |                                        |
         v                                        v                                        v
   IDE (VS Code, IntelliJ)                  IDE (ESLint extension)                   CLI (node script)
   CI/CD (Code Analyzer, Gearset,           CI/CD (npm run lint)                     CI/CD (node command)
          Copado, AutoRABIT, CodeScan)
```

**Layer interaction:** The three layers are independent and complementary. PMD handles Apex, ESLint handles JavaScript, and the naming validator handles XML/directory-based
metadata. No layer duplicates another's coverage. Run all three for complete enforcement.

### File Listing

| File | Scope | Purpose |
|------|-------|---------|
| `kerndx-pmd-ruleset.xml` | Any KernDX subscriber | 24 XPath rules enforcing framework anti-patterns (inline SOQL, direct DML, System.debug, coverage theatre, inline DML in tests, etc.) |
| `subscriber-naming-pmd-ruleset.xml` | Subscriber (org-specific example) | Apex class naming (`Domain_[Brand_]Layer_Name`), trigger naming (`TRG_ObjectName`), 40-char limit |
| `combined-pmd-ruleset.xml` | Both (single-file reference) | Includes both PMD rulesets via `<rule ref="..."/>` -- for tools that accept only one ruleset file |
| `eslint-plugin-kerndx/` | Any KernDX subscriber | 6 ESLint rules: ComponentBuilder usage, console.log blocking, LWC component naming, coverage-exempt justification, jest-theatre prevention, shared-fixture mutation prevention |
| `validate-naming.js` | Org-specific | Flow and Custom Object naming validation -- configurable domains, brands, and flow types |

---

## PMD Rule Reference

All 24 PMD rules live in `scanner/kerndx-pmd-ruleset.xml`. They target PMD 7 and use XPath expressions to detect anti-patterns in the Apex AST. Rules are organized into
three priority tiers.

> For current framework statistics, see [Metrics](Strategic%20Guide%20-%20Metrics.md).

| Priority | Meaning | Action Required |
|----------|---------|-----------------|
| **1** | Blocker | Must fix before merge. Bypasses core framework abstractions. |
| **3** | Should Fix | Direct use of platform APIs that have framework wrappers. Fix during normal development. |
| **5** | Informational | Best practices. Teams may adopt incrementally. |

### Priority 1 Blockers

These violations indicate code that bypasses core framework abstractions. They must be fixed before merge.

#### KernTriggerMustDelegate

Trigger bodies must contain only `new TRG_Dispatcher().run()`. Any logic in the trigger file itself bypasses the metadata-driven dispatch chain, bypass mechanisms,
performance monitoring, and action ordering provided by the [trigger framework](Triggers%20-%20Guide.md).

**What the rule detects:** Any statement inside a trigger's `BlockStatement` that is not a method call to `run()`. This includes variable declarations, SOQL, DML, loops,
conditionals, and calls to any method other than `TRG_Dispatcher.run()`.

```apex
// VIOLATION -- logic in trigger body
trigger AccountTrigger on Account (before insert)
{
   for(Account record : Trigger.new)
   {
      record.Description = 'Set by trigger';
   }
}

// CORRECT -- thin dispatcher, logic in handler classes
trigger TRG_Account on Account (before insert)
{
   new TRG_Dispatcher().run();
}
```

> **Why this is Priority 1:** Trigger logic that bypasses `TRG_Dispatcher` cannot be bypassed by admins via `TriggerSetting__mdt.BypassExecution__c`, cannot be reordered
> via `TriggerAction__mdt.Order__c`, and does not participate in performance logging. It also makes the trigger untestable in isolation.

#### KernNoInlineSOQL

All queries must go through `SEL_*` selectors or [QRY_Builder](reference/apex/QRY_Builder.md). Inline SOQL (`[SELECT ...]`) and `Database.query()` calls bypass field-level
security enforcement, caching, sharing control, and make query logic non-reusable.

**What the rule detects:** `SoqlExpression` nodes (inline `[SELECT ...]`) and calls to `Database.query()`, `Database.queryWithBinds()`, `Database.countQuery()`,
`Database.countQueryWithBinds()`, `Database.getQueryLocator()`, `Database.getQueryLocatorWithBinds()`, `Database.getCursor()`, and `Database.getCursorWithBinds()`.

```apex
// VIOLATION -- inline SOQL
List<Account> accounts = [SELECT Id, Name FROM Account WHERE Industry = 'Tech'];
List<Account> dynamic = Database.query('SELECT Id FROM Account');
Integer total = Database.countQuery('SELECT COUNT() FROM Account');

// CORRECT -- selector
List<Account> accounts = new SEL_Accounts().findByIndustry('Tech');

// CORRECT -- QRY_Builder for one-off queries
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
   .fields(new List<SObjectField>{Account.Name, Account.Industry})
   .condition(Account.Industry).equals('Tech').toList();
```

> **Note:** Framework infrastructure classes (selectors, query builders) that legitimately need raw SOQL use `@SuppressWarnings('PMD.KernNoInlineSOQL')` to opt out.

#### KernNoCoverageTheatre

Test methods must exercise observable behaviour, not merely execute production lines to inflate coverage. The rule blocks four patterns that
contribute coverage without actually verifying anything: tests with zero `Assert.*` calls, empty `catch` blocks that swallow exceptions, the
legacy `Boolean exceptionThrown` flag pattern, and `Assert.isNotNull` called on a record that was just returned by `TST_Builder.build()` (the
builder cannot return null, so the assertion is tautological).

```apex
// VIOLATION -- no assertions
@IsTest
private static void shouldProcessRecord()
{
   MyService.process(record);
}

// VIOLATION -- empty catch swallows the exception
@IsTest
private static void shouldHandleError()
{
   try { MyService.process(null); }
   catch(Exception e) { }
}

// VIOLATION -- Boolean exceptionThrown flag
@IsTest
private static void shouldThrowOnInvalid()
{
   Boolean exceptionThrown = false;
   try { MyService.process(null); }
   catch(Exception e) { exceptionThrown = true; }
   Assert.isTrue(exceptionThrown);
}

// VIOLATION -- Assert.isNotNull on a TST_Builder result (always non-null)
@IsTest
private static void shouldCreateAccount()
{
   Account account = (Account)TST_Builder.of(Account.SObjectType).build();
   Assert.isNotNull(account);
}

// CORRECT -- assert on observable behaviour
@IsTest
private static void shouldSetDefaultIndustry()
{
   Account account = (Account)TST_Builder.of(Account.SObjectType).build();
   Account result = (Account)new SEL_Accounts().findById(account.Id);
   Assert.areEqual('Technology', result.Industry, 'Default industry should be set');
}
```

> **Why this is Priority 1:** Coverage-theatre tests pass the 100% coverage gate while verifying nothing. They mask regressions because the test
> keeps passing even when the production code it "covers" breaks. Fixing them typically reveals bugs that the empty tests concealed.

#### KernCoverageExemptRequiresReason

The `// kern-coverage-exempt:` comment subtracts a line from the coverage denominator, so every exemption must cite a specific platform limitation.
Empty, short (under 15 characters), or hand-wavy reasons (`tricky`, `hard to test`, `TODO`, `FIXME`, `later`, `hack`, `XXX`) are blocked.

```apex
// VIOLATION -- no reason
// kern-coverage-exempt:
throw new UnreachableException();

// VIOLATION -- hand-wavy reason
// kern-coverage-exempt: hard to test
throw new UnreachableException();

// CORRECT -- cites a specific platform limitation
// kern-coverage-exempt: Apex cannot construct Database.QueryLocator directly; tested via live Batchable in IT harness
throw new UnreachableException();
```

The matching ESLint rule `kerndx/no-coverage-exempt-without-reason` enforces the same policy on LWC `// kern-coverage-exempt:` comments.

### Priority 3 Should Fix

These rules detect direct use of platform APIs that have framework wrappers. The framework wrappers provide additional capabilities (logging, error handling, security,
retry logic) that the raw APIs lack. Fix these during normal development.

#### KernNoDirectDML

Direct DML statements (`insert`, `update`, `delete`, `upsert`, `undelete`, `merge`) and `Database.*` DML methods must be replaced with
[DML_Builder](reference/apex/DML_Builder.md) for transactional safety, consistent error handling, and sharing enforcement.

**Detected patterns:** `insert record`, `update records`, `delete record`, `upsert record`, `undelete record`, `merge master duplicate`, `Database.insert()`,
`Database.update()`, `Database.delete()`, `Database.upsert()`, `Database.undelete()`, `Database.merge()`, `Database.convertLead()`, `Database.emptyRecycleBin()`,
`Database.insertAsync()`, `Database.updateAsync()`, `Database.deleteAsync()`, `Database.insertImmediate()`, `Database.updateImmediate()`, `Database.deleteImmediate()`.

```apex
// VIOLATION
insert account;
Database.update(contacts, false);

// CORRECT
DML_Builder.newTransaction()
   .doInsert(account)
   .doUpdate(contacts)
   .execute();
```

#### KernNoSystemDebug

`System.debug()` produces unstructured, non-persistent log output that disappears after the debug log expires. Use [LOG_Builder](reference/apex/LOG_Builder.md) for
structured logging via platform events that persists to `LogEntry__c`.

```apex
// VIOLATION
System.debug('Processing account: ' + account.Name);
System.debug(LoggingLevel.ERROR, 'Failed to process');

// CORRECT
LOG_Builder.build().info('Processing account: ' + account.Name).emitAt('MyClass.myMethod');
LOG_Builder.build().error('Failed to process').emitAt('MyClass.myMethod');
```

#### KernNoRawHttp

Direct instantiation of `HttpRequest` or `Http` bypasses framework features: retry logic, circuit breakers, logging, named credential integration, and mock support.
Use [UTIL_HttpClient](reference/apex/UTIL_HttpClient.md) static factories.

**Detected patterns:** `new HttpRequest()`, `new Http()`, `WebServiceCallout.invoke()`.

```apex
// VIOLATION
HttpRequest request = new HttpRequest();
request.setEndpoint('callout:PaymentGateway/charges');
request.setMethod('POST');
Http http = new Http();
HttpResponse response = http.send(request);

// CORRECT
HttpResponse response = UTIL_HttpClient.post('PaymentGateway', '/charges')
   .body(chargeRequest)
   .withRetry(3)
   .withCircuitBreaker()
   .send();
```

#### KernUseSchedulerBase

Schedulable classes must extend `SCHED_Base` instead of implementing `Schedulable` directly. `SCHED_Base` provides parameter resolution, metadata-driven configuration
via `ScheduledJob__c`, and structured error handling.

```apex
// VIOLATION
public with sharing class MyScheduledJob implements Schedulable
{
   public void execute(SchedulableContext context)
   {
      // job logic
   }
}

// CORRECT
global inherited sharing class SCHED_MyJob extends SCHED_Base
{
   public void execute(SchedulableContext context)
   {
      // job logic -- parameters available via getTextParameter('key') /
      // getNumericParameter('key') / getBooleanParameter('key')
   }
}
```

#### KernNoRawSchedule

`System.schedule()` calls bypass the framework's scheduling infrastructure. Use `SCHED_Base` with `ScheduledJob__c` custom metadata records for metadata-driven scheduling
that supports monitoring, parameter passing, and declarative configuration.

```apex
// VIOLATION
System.schedule('Nightly Sync', '0 0 0 * * ?', new MyScheduledJob());

// CORRECT -- configure via ScheduledJob__c metadata record
// The framework handles scheduling based on metadata configuration
```

#### KernNoRawEventPublish

Direct `EventBus.publish()` calls bypass the framework's event publishing infrastructure. Use [LOG_Builder](reference/apex/LOG_Builder.md) for log entry events or the
appropriate framework mechanism for domain events.

```apex
// VIOLATION
LogEntryEvent__e event = new LogEntryEvent__e(Message__c = 'Error occurred');
EventBus.publish(event);

// CORRECT
LOG_Builder.build().error('Error occurred').emitAt('MyClass.myMethod');
```

#### KernNoRawHttpMock

Implementing `HttpCalloutMock` or `WebServiceMock` directly bypasses the framework's mock infrastructure. Use `API_MockFactory` which provides consistent mock setup,
automatic response configuration, and integration with the API framework's test helpers.

```apex
// VIOLATION
@IsTest
private class MyMock implements HttpCalloutMock
{
   public HttpResponse respond(HttpRequest request)
   {
      HttpResponse response = new HttpResponse();
      response.setBody('{"status": "ok"}');
      response.setStatusCode(200);
      return response;
   }
}

// CORRECT
API_MockFactory.forService(API_SendEmail.class.getName()).body('{"messageId": "msg-12345"}').register();

// CORRECT -- error mock
API_MockFactory.registerErrorMock(API_SendEmail.class.getName());
```

#### KernNoRawRestContext

Direct access to `RestContext.request` and `RestContext.response` bypasses the framework's inbound API infrastructure. `REST_*` classes should only delegate to
`API_Dispatcher.processInboundService()`, and `API_Inbound` subclasses access request/response data via inherited properties that provide automatic logging, error
handling, and idempotency support.

```apex
// VIOLATION
@RestResource(UrlMapping='/v1/invoices/*')
global inherited sharing class REST_Invoices
{
   @HttpGet
   global static void getInvoice()
   {
      String invoiceId = RestContext.request.params.get('id');
      RestContext.response.responseBody = Blob.valueOf('{"id": "' + invoiceId + '"}');
   }
}

// CORRECT -- REST_* delegates, API_* handles logic via inherited properties
@RestResource(UrlMapping='/v1/invoices/*')
global inherited sharing class REST_Invoices
{
   @HttpGet
   global static void getInvoice()
   {
      API_Dispatcher.processInboundService(API_GetInvoice.class.getName());
   }
}
```

#### KernNoRawEmail

Direct `Messaging` API usage (`Messaging.sendEmail()`, `new SingleEmailMessage()`, `Messaging.renderStoredEmailTemplate()`) bypasses the framework's email abstraction.
Use `UTIL_Email` which provides template management, error handling, and logging integration.

```apex
// VIOLATION
Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
email.setToAddresses(new List<String>{'user@example.com'});
email.setSubject('Notification');
email.setPlainTextBody('Hello');
Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});

// CORRECT
UTIL_Email.send()
   .toAddress('user@example.com')
   .subject('Notification')
   .plainTextBody('Hello')
   .send();
```

#### KernRestResourceNaming

Classes annotated with `@RestResource` must follow the `REST_*` naming convention. `REST_*` classes serve as thin routing layers that delegate to
`API_Dispatcher.processInboundService()`, with business logic in `API_*` classes extending `API_Inbound`.

```apex
// VIOLATION
@RestResource(UrlMapping='/v1/accounts/*')
global inherited sharing class AccountService
{
   // ...
}

// CORRECT
@RestResource(UrlMapping='/v1/accounts/*')
global inherited sharing class REST_Accounts
{
   @HttpPost
   global static void createAccount()
   {
      API_Dispatcher.processInboundService(API_CreateAccount.class.getName());
   }
}
```

#### KernNoInlineDmlInTests

Direct DML statements (`insert`, `update`, `delete`, `upsert`, `undelete`, `merge`) inside `@IsTest` classes bypass the framework's test fixture
infrastructure. Test records must come from `TST_Builder.of(SObjectType).build()` (which respects trigger bypass configuration and default field
providers) or, when explicit DML semantics are under test, through `DML_Builder` — never raw `insert`. This rule is the test-specific counterpart to
`KernNoDirectDML` and fires only inside classes annotated `@IsTest`.

```apex
// VIOLATION (inside @IsTest class)
Account account = new Account(Name = 'Test');
insert account;
update account;

// CORRECT -- TST_Builder for fixtures
Account account = (Account)TST_Builder.of(Account.SObjectType).build();

// CORRECT -- DML_Builder when explicit DML is under test
DML_Builder.newTransaction().doInsert(record).execute();
```

### Priority 5 Informational

Best practices that improve code quality and consistency. Teams may adopt these rules incrementally.

#### KernNoLegacyAssert

Legacy `System.assert()`, `System.assertEquals()`, and `System.assertNotEquals()` should be replaced with the modern `Assert` class methods (`Assert.isTrue()`,
`Assert.areEqual()`, `Assert.areNotEqual()`, etc.) which provide clearer method names and better failure messages.

```apex
// VIOLATION
System.assertEquals('Expected', actual, 'Values should match');
System.assert(condition, 'Condition should be true');

// CORRECT
Assert.areEqual('Expected', actual, 'Values should match');
Assert.isTrue(condition, 'Condition should be true');
```

#### KernUseTestBuilder

Direct SObject construction in test classes (`new Account(Name = 'Test')`) should use `TST_Builder.of(SObjectType).build()` instead. `TST_Builder` ensures consistent
defaults, respects trigger framework configuration, and reduces test maintenance. This rule only fires inside `@IsTest` classes.

```apex
// VIOLATION (inside @IsTest class)
Account account = new Account(Name = 'Test Corp', Industry = 'Tech');
insert account;

// CORRECT
Account account = (Account)TST_Builder.of(Account.SObjectType)
   .withOverride(Account.Industry, 'Tech').build();
```

#### KernNoRawCache

Direct `Cache.Org.*` and `Cache.Session.*` calls bypass the framework's caching abstraction. Use `UTIL_Cache` which provides automatic partition management, graceful
degradation when cache is unavailable, and consistent key namespacing.

```apex
// VIOLATION
Cache.Org.put('local.MyPartition.key', value);
Object cached = Cache.Org.get('local.MyPartition.key');

// CORRECT
UTIL_Cache.org().put('key', value);
Object cached = UTIL_Cache.org().get('key');
```

#### KernNoRawDescribe

`Schema.getGlobalDescribe()` is expensive and uncached. Use `UTIL_SObjectDescribe` which caches describe results and provides type-safe accessors for fields, record types,
and object metadata. Note: individual `.getDescribe()` calls on `SObjectField` and `SObjectType` tokens are acceptable and not flagged.

```apex
// VIOLATION
Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
Schema.SObjectType accountType = globalDescribe.get('Account');
List<Schema.DescribeTabResult> tabs = Schema.describeTabs();

// CORRECT
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);
Map<String, SObjectField> fieldMap = describe.getFieldsMap();
```

#### KernNoRawTypeForName

`Type.forName()` does not account for namespace resolution in managed package contexts. Use `UTIL_System.getTypeForClassName()` which chains through subscriber-first
resolution, namespace prefixing, and custom `ClassTypeResolver__mdt` resolvers.

```apex
// VIOLATION
Type handlerType = Type.forName('TRG_SetAccountDefaults');

// CORRECT
Type handlerType = UTIL_System.getTypeForClassName('TRG_SetAccountDefaults');

// CORRECT -- with interface validation
Type handlerType = UTIL_System.getTypeForClassName('TRG_SetAccountDefaults', IF_Trigger.BeforeInsert.class);
```

#### KernNoRawEnqueueJob

Direct `System.enqueueJob()` calls bypass the framework's async processing infrastructure. Use `UTIL_AsynchronousJobLauncher` which provides stack depth tracking,
governor limit awareness, and fallback strategies when queueable limits are reached.

```apex
// VIOLATION
System.enqueueJob(new MyQueueable());

// CORRECT
UTIL_AsynchronousJobLauncher.enqueue(new MyQueueable());
```

#### KernNoRawCrypto

Direct `Crypto.*` calls bypass the framework's cryptographic utilities. Use `UTIL_Crypto` which provides simplified APIs for common operations: hashing, encryption,
decryption, and key generation.

```apex
// VIOLATION
Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(input));
Blob key = Crypto.generateAesKey(256);

// CORRECT
String hash = UTIL_Crypto.generateSHA256Hash(input);
Blob key = UTIL_Crypto.generateEncryptionKey();
```

#### KernNoRawFeatureManagement

Direct `FeatureManagement` API calls bypass the framework's feature flag abstraction. Use `UTIL_FeatureFlag.isEnabled()` which provides metadata-driven feature flags via
`FeatureFlag__mdt`, caching, and consistent flag naming conventions.

```apex
// VIOLATION
Boolean isEnabled = FeatureManagement.checkPermission('MyFeature');
Integer limit = FeatureManagement.checkPackageIntegerValue('MaxRetries');

// CORRECT
Boolean isEnabled = UTIL_FeatureFlag.isEnabled('MyFeature');
```

#### KernNoBooleanExceptionThrown

The legacy `Boolean exceptionThrown = false; try { ... } catch(...) { exceptionThrown = true; }` pattern is noisier than necessary and does not
verify the exception type. Use `Assert.fail(...)` after the call that should throw, plus `Assert.isInstanceOfType(error, ExceptionClass.class, ...)`
in the `catch` block.

```apex
// VIOLATION
Boolean exceptionThrown = false;
try
{
   MyService.processInvalid(null);
}
catch(IllegalArgumentException error)
{
   exceptionThrown = true;
}
Assert.isTrue(exceptionThrown, 'Should have thrown');

// CORRECT
try
{
   MyService.processInvalid(null);
   Assert.fail('Should throw IllegalArgumentException');
}
catch(Exception error)
{
   Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect exception type');
}
```

### PMD Rule Summary Table

| Rule | Detects | Use Instead | Priority |
|------|---------|-------------|----------|
| `KernTriggerMustDelegate` | Logic in trigger body | `new TRG_Dispatcher().run()` | 1 |
| `KernNoInlineSOQL` | `[SELECT ...]`, `Database.query()` | Selector or [QRY_Builder](reference/apex/QRY_Builder.md) | 1 |
| `KernNoCoverageTheatre` | Assertion-less tests, empty catches, `Boolean exceptionThrown`, tautological `Assert.isNotNull` | Assert on observable behaviour | 1 |
| `KernCoverageExemptRequiresReason` | Empty, short, or hand-wavy `// kern-coverage-exempt:` reasons | Cite a specific platform limitation | 1 |
| `KernNoDirectDML` | `insert`/`update`/`delete`, `Database.*` DML | [DML_Builder](reference/apex/DML_Builder.md) | 3 |
| `KernNoSystemDebug` | `System.debug()` | [LOG_Builder](reference/apex/LOG_Builder.md) | 3 |
| `KernNoRawHttp` | `new HttpRequest()`, `new Http()` | [UTIL_HttpClient](reference/apex/UTIL_HttpClient.md) | 3 |
| `KernUseSchedulerBase` | `implements Schedulable` directly | `extends SCHED_Base` | 3 |
| `KernNoRawSchedule` | `System.schedule()` | `SCHED_Base` + `ScheduledJob__c` | 3 |
| `KernNoRawEventPublish` | `EventBus.publish()` | [LOG_Builder](reference/apex/LOG_Builder.md) / framework events | 3 |
| `KernNoRawHttpMock` | `implements HttpCalloutMock/WebServiceMock` | `API_MockFactory` | 3 |
| `KernNoRawRestContext` | `RestContext.request/response` | `API_Inbound` framework | 3 |
| `KernNoRawEmail` | `Messaging.sendEmail()`, `new SingleEmailMessage()` | `UTIL_Email` | 3 |
| `KernRestResourceNaming` | `@RestResource` on non-`REST_*` class | `REST_*` + `API_Dispatcher` | 3 |
| `KernNoInlineDmlInTests` | Raw `insert`/`update`/`delete` inside `@IsTest` classes | `TST_Builder` or `DML_Builder` | 3 |
| `KernNoLegacyAssert` | `System.assert*()` | `Assert.*` | 5 |
| `KernUseTestBuilder` | `new Account(Name = ...)` in tests | `TST_Builder` | 5 |
| `KernNoRawCache` | `Cache.Org.*`, `Cache.Session.*` | `UTIL_Cache` | 5 |
| `KernNoRawDescribe` | `Schema.getGlobalDescribe()` | `UTIL_SObjectDescribe` | 5 |
| `KernNoRawTypeForName` | `Type.forName()` | `UTIL_System.getTypeForClassName()` | 5 |
| `KernNoRawEnqueueJob` | `System.enqueueJob()` | `UTIL_AsynchronousJobLauncher` | 5 |
| `KernNoRawCrypto` | `Crypto.*` | `UTIL_Crypto` | 5 |
| `KernNoRawFeatureManagement` | `FeatureManagement.checkPermission()` | `UTIL_FeatureFlag.isEnabled()` | 5 |
| `KernNoBooleanExceptionThrown` | `Boolean exceptionThrown` try/catch pattern | `Assert.fail` + `Assert.isInstanceOfType` | 5 |

---

## ESLint Rules (LWC)

The `eslint-plugin-kerndx` plugin enforces framework and naming conventions in LWC components. PMD cannot parse JavaScript, so LWC compliance is handled entirely by
ESLint. The plugin contains six rules.

### kerndx/use-component-builder

**Purpose:** LWC components must extend `ComponentBuilder(...)` instead of `LightningElement`. ComponentBuilder provides toast notifications, controller calls, navigation,
messaging, and structured console logging that `LightningElement` does not offer.

**What the rule detects:**
- `extends LightningElement` -- direct usage
- Aliased imports -- if a developer writes `import {LightningElement as Base} from 'lwc'`, the rule tracks the alias and still catches `extends Base`

```javascript
// VIOLATION
import {LightningElement} from 'lwc';
export default class MyComponent extends LightningElement
{
   // ...
}

// VIOLATION -- aliased import
import {LightningElement as Base} from 'lwc';
export default class MyComponent extends Base
{
   // ...
}

// CORRECT
import {ComponentBuilder} from 'c/componentBuilder';
export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
   async handleSave()
   {
      await this.callControllerMethod('saveAccount', {account: this.account});
      this.showSuccessToast('Saved');
   }
}
```

**When to suppress:** Template-only components that have no JavaScript logic requiring framework methods. In practice this is rare -- most components benefit from at least
the `notification` module for error handling.

```javascript
// eslint-disable-next-line kerndx/use-component-builder -- template-only component, no framework methods needed
export default class StaticNotice extends LightningElement {}
```

### kerndx/no-console-log

**Purpose:** Native `console.log()` and related methods produce uncontrolled output that cannot be filtered, persisted, or correlated. ComponentBuilder provides
`this.consoleLog()` and `this.consoleError()` which integrate with the framework's logging infrastructure.

**What the rule detects:**
- `console.log()`, `console.error()`, `console.warn()`, `console.info()`, `console.debug()`
- `window.console.log()`, `window.console.error()`, etc.
- `globalThis.console.log()`, `globalThis.console.error()`, etc.

```javascript
// VIOLATION
console.log('Account loaded:', account);
console.error('Failed to save');
window.console.log('Debug info');

// CORRECT
this.consoleLog('Account loaded:', account);
this.consoleError('Failed to save');
```

### kerndx/enforce-component-naming

**Purpose:** LWC component folder names must follow a `domain[Brand]FeatureVariant` pattern to maintain organizational consistency. This rule is org-specific -- the
domains and brands are configured in the rule source.

**What the rule detects:**
- Component folder names that do not start with a recognized domain prefix
- Component folder names that exceed 40 characters
- Folder names starting with `__` are excluded (internal LWC convention)

**Default configuration (subscriber example):**
- Domains: `sls`, `ord`, `prd`, `svc`, `sub`, `mkt`, `cmn`
- Brands: `Lex`, `Ear`
- Pattern: `^(sls|ord|prd|svc|sub|mkt|cmn)(?:Lex|Ear)?[A-Z][a-zA-Z0-9]*$`

```javascript
// VIOLATION -- missing domain prefix
// Component folder: returnWizard/returnWizard.js
export default class ReturnWizard extends ComponentBuilder('notification') {}

// CORRECT
// Component folder: ordReturnWizard/ordReturnWizard.js
export default class OrdReturnWizard extends ComponentBuilder('notification') {}

// CORRECT -- with brand
// Component folder: svcLexWarrantyTimeline/svcLexWarrantyTimeline.js
export default class SvcLexWarrantyTimeline extends ComponentBuilder('navigation') {}
```

**Customizing:** Edit the `DOMAINS` and `BRANDS` arrays at the top of `scanner/eslint-plugin-kerndx/rules/enforce-component-naming.js` to match your organization's naming
convention. The `MAX_LENGTH` constant (default 40) can also be adjusted.

### kerndx/no-coverage-exempt-without-reason

**Purpose:** The JavaScript counterpart to the PMD `KernCoverageExemptRequiresReason` rule. Every `// kern-coverage-exempt:` comment in LWC
JavaScript subtracts a line from the coverage denominator, so the reason text must cite a specific platform limitation. Empty, short
(under 15 characters), or hand-wavy reasons are blocked.

**What the rule detects:**
- `// kern-coverage-exempt:` with no reason after the colon
- Reasons shorter than 15 characters
- Blocklisted reasons (case-insensitive): `hard to test`, `tricky`, `todo`, `fixme`, `later`, `xxx`, `hack`

```javascript
// VIOLATION -- no reason
// kern-coverage-exempt:
throw new Error('unreachable');

// VIOLATION -- blocklisted reason
// kern-coverage-exempt: hard to test
throw new Error('unreachable');

// CORRECT -- cites a specific platform limitation
// kern-coverage-exempt: jsdom cannot trigger the real navigator.clipboard permission prompt
throw new Error('unreachable');
```

### kerndx/no-jest-theatre

**Purpose:** Jest tests must actually exercise behaviour. Tests that pass regardless of what the production code does inflate coverage without
verifying anything. Two theatrical patterns are blocked: assertion-less tests (`it(...)` blocks with zero `expect(...)` calls), and hollow
`createElement` assertions (`expect(element).toBeTruthy()` or `expect(element).toBeDefined()` on a value returned by `createElement` — this only
verifies that `createElement` did not throw).

**What the rule detects:**
- An `it(...)` or `test(...)` block whose body contains no `expect(...)` calls
- An `it(...)` block whose only `expect(...)` call is `toBeTruthy()` or `toBeDefined()` on a `createElement` result

Only applies to files ending in `.test.js` or under `__tests__/`.

```javascript
// VIOLATION -- no assertions
it('renders component', () =>
{
    const element = createElement('c-my-component', {is: MyComponent});
    document.body.appendChild(element);
});

// VIOLATION -- hollow assertion
it('creates element', () =>
{
    const element = createElement('c-my-component', {is: MyComponent});
    expect(element).toBeTruthy();
});

// CORRECT -- assert on rendered state, events, or controller calls
it('shows success toast on save', async () =>
{
    const element = createElement('c-my-component', {is: MyComponent});
    document.body.appendChild(element);
    await element.handleSave();
    expect(element.showSuccessToast).toHaveBeenCalledWith('Saved');
});
```

### kerndx/no-mutating-shared-fixture

**Purpose:** A `describe(...)` block that creates its DOM fixture in `beforeAll(...)` with `createElement(...)` and then has any `it(...)` that
mutates the element (via `dispatchEvent`, `.click()`, public-API setter, or `querySelector(...).click()`) is order-dependent — each test inherits
the previous test's mutations. This hides regressions and makes test failures hard to reproduce.

**Fix:** Downgrade `beforeAll` to `beforeEach` so each test rebuilds the fixture, or move the `createElement(...)` call into the mutating
`it(...)` block itself.

Only applies to files ending in `.test.js` or under `__tests__/`.

```javascript
// VIOLATION -- shared fixture mutated by multiple tests
describe('c-my-component', () =>
{
    let element;

    beforeAll(() =>
    {
        element = createElement('c-my-component', {is: MyComponent});
        document.body.appendChild(element);
    });

    it('dispatches event on click', () =>
    {
        element.querySelector('button').click();
        expect(element.eventDispatched).toBe(true);
    });

    it('shows panel on toggle', () =>
    {
        element.dispatchEvent(new CustomEvent('toggle'));
        expect(element.panelVisible).toBe(true);
    });
});

// CORRECT -- beforeEach rebuilds fixture per test
describe('c-my-component', () =>
{
    let element;

    beforeEach(() =>
    {
        element = createElement('c-my-component', {is: MyComponent});
        document.body.appendChild(element);
    });
});
```

### ESLint Setup

The ESLint configuration is already set up in `force-app/main/default/lwc/eslint.config.mjs`. Run the linter with:

```bash
npm run lint
```

ESLint violations appear inline in VS Code when the ESLint extension is installed. No additional IDE configuration is required beyond having the extension active.

---

## Naming Validator (Flows & Custom Objects)

The `validate-naming.js` script validates naming conventions for Salesforce artefact types that PMD and ESLint cannot parse: Flows (XML metadata) and Custom Objects
(directory-based metadata). It is a standalone Node.js script designed to be customized per subscriber org.

### Configuration

The script uses three configuration arrays at the top of the file:

| Array | Purpose | Default (subscriber) |
|-------|---------|----------------------|
| `DOMAINS` | Organizational domain codes | `SLS`, `ORD`, `PRD`, `SVC`, `SUB`, `MKT`, `CMN` |
| `BRANDS` | Optional brand segments | `ACM`, `BTA` |
| `FLOW_TYPES` | Flow type abbreviations | `BS`, `AS`, `BD`, `SCR`, `AL`, `SCH`, `PE`, `SF` |

**Flow pattern:** `Domain_[Brand_]Object_Type_Action` (80-character limit)

Examples: `ORD_Order_BS_SetDefaults`, `SVC_ACM_WarrantyClaim_SCR_CreateClaim`, `CMN_Account_AL_SyncToExternal`

**Custom Object pattern:** `Domain_[Brand_]ObjectName__c` (40-character limit)

Examples: `ORD_ReturnRequest__c`, `SVC_ACM_WarrantyClaim__c`

### Running the Validator

```bash
# Default -- scans ./force-app
node scanner/validate-naming.js

# Explicit path
node scanner/validate-naming.js path/to/force-app

# The script auto-detects SFDX standard layout (force-app/main/default/) vs flat layout
```

The script outputs:
- Number of artefacts checked
- Near-limit warnings (within 5 characters of the limit)
- Violations grouped by category with expected pattern
- Exit code 0 (no violations) or 1 (violations found) for CI/CD integration

### Customizing for Your Org

Subscribers adapt the configuration arrays to their naming convention:

1. Open `scanner/validate-naming.js`
2. Edit `DOMAINS` to match your organizational domains (e.g., `['FIN', 'HR', 'OPS', 'CMN']`)
3. Edit `BRANDS` to match your brand codes (e.g., `['PRO', 'ENT']`) or set to `[]` if not used
4. Edit `FLOW_TYPES` to match your flow type abbreviations
5. Adjust `CHARACTER_LIMITS` if your org uses different limits

---

## Deploy-Time Scanners

PMD, ESLint, and the naming validator analyse source files in isolation. The deploy-time scanners under `scripts/` complement those layers by checking source against the
target Salesforce org — they catch misconfigurations that are only visible when the metadata is compared to live org state. Run them ahead of any package build or
deployment validation.

### Access-Mode Scanner

`scripts/scan-access-modes.js` enforces explicit access-mode declarations on every production query and DML call. Builders chained off `QRY_Builder.selectFrom()`,
`DML_Builder.newTransaction()`, and `new DML_Transaction()` must call `.withUserMode()`, `.withSystemMode()`, or `.setAccessLevel()`. Raw `Database.query()`,
`Database.queryWithBinds()`, `Database.getQueryLocator()`, `Database.countQuery()`, `Search.query()`, and `Search.find()` must include an explicit `AccessLevel` argument.

```bash
npm run scan:access-modes
```

The script exits 0 on a clean run and 1 on any violation. Framework-internal classes (`QRY_Builder.cls`, `DML_Builder.cls`, etc.) are allowlisted because they implement
the access-mode primitives.

### Flow-Reference Scanner

`scripts/scan-flow-references.js` validates every `TriggerAction__mdt` CMDT record whose `FlowName__c` is populated. For each
referenced flow it checks:

1. **Existence** — the flow's API name is present in the dev org's `FlowDefinitionView`.
2. **Active status** — `FlowDefinitionView.IsActive = true`.
3. **Variable contract** — for non-record-triggered flows, the flow's metadata declares an SObject variable named `record` whose `objectType` matches the dispatching
   `TriggerSetting__mdt.SObjectType__c` and which is both input and output. Update-context CMDT rows (Event = "Before Update" / "After Update") additionally require a
   `recordPrior` SObject variable.

The scanner uses the `FlowDefinitionView` standard SObject for the existence check and the Tooling API's `Flow.Metadata` for the contract check; both queries are batched
into single round-trips per scan.

```bash
npm run scan:flow-references
npm run scan:flow-references -- --org SubscriberOrg
```

The default org alias is the value of the `KERN_DEV_ORG` env var (set this env var, or pass `--org <alias>` to point at a different scratch org, sandbox, or production org).

**Permission requirement.** The CI integration user must have `Manage Flow` to read `FlowDefinitionView`; without it, the org returns zero rows silently. `Manage Flow` is
included in the bundled `Kern Administrator` permission set, so assigning that permset to the CI user is the simplest path:

```bash
sf org assign permset -n kern__Administrator -o <integration-user>
```

If the CI user must stay below admin-level permissions, create a custom permission set in the subscriber org granting only the `Manage Flow` user permission and assign
that instead. Sysadmin-profile runners (the default in scratch-org-per-build pipelines) already satisfy `Manage Flow` via `Modify All Data`.

**Probe-before-scan sentinel.** Before checking individual records, the scanner runs `SELECT COUNT() FROM FlowDefinitionView`. If the count is zero AND the local
`force-app/main/default/flows/` directory contains `*.flow-meta.xml` files, the scanner exits with:

```text
Scanner cannot see any flows in the dev org. Either (a) the running user is missing the 'Manage Flow' user permission (assign it via the Kern Administrator permset, a sysadmin profile, or a custom permset that grants Manage Flow), or (b) the dev org has no flows deployed. Re-run after granting permissions or deploying flows.
```

This converts the silent-zero-rows failure mode (the most common misconfiguration) into a loud, actionable error that points at the fix.

**Reported errors.** When violations are found, the scanner prints one entry per affected CMDT record. Each message names the offending CMDT row, the offending flow, and
the remedy:

| Failure | Sample message |
|---------|----------------|
| Existence | `TriggerAction 'SetAccountDefaults': flow 'Account_SetDefaults' does not exist in dev org. Either deploy the flow or remove the CMDT record.` |
| Inactive | `TriggerAction 'SetAccountDefaults': flow 'Account_SetDefaults' is inactive. Activate the flow or remove the CMDT record.` |
| Missing variable | `TriggerAction 'SetAccountDefaults': flow 'Account_SetDefaults' is missing required variable 'record: Account' (in/out). Either fix the flow declaration or correct the CMDT row's FlowName__c.` |
| Wrong objectType | `TriggerAction 'SetAccountDefaults': flow 'Account_SetDefaults' variable 'record' has type 'SObject/Contact' but TriggerSetting requires 'Account'.` |

### Umbrella Scan

The `scan` script chains the access-mode and flow-reference scanners. Use it as the single command in CI pipelines or as a pre-deploy local check:

```bash
npm run scan
```

The chain stops at the first failing scanner so the failing output is easy to spot in CI logs. Running the individual scripts (`scan:access-modes`, `scan:flow-references`)
remains supported for targeted runs.

---

## Suppression

Every scanning layer provides mechanisms to suppress rules when a violation is intentional and justified. Always include a comment explaining why the suppression is
necessary.

### Apex (PMD)

**Per-class suppression:** Add `@SuppressWarnings` to the class declaration. All methods in the class are exempt from the specified rule.

```apex
@SuppressWarnings('PMD.KernNoDirectDML')
public inherited sharing class DML_SharingProxy
{
   // Framework infrastructure -- direct DML is intentional here
}
```

**Per-method suppression:** Add `@SuppressWarnings` to the method declaration. Only that method is exempt.

```apex
public inherited sharing class MyService
{
   @SuppressWarnings('PMD.KernNoInlineSOQL')
   private List<Account> legacyQuery()
   {
      // Temporary: migrating to selector in JIRA-1234
      return [SELECT Id, Name FROM Account WHERE Legacy__c = true];
   }
}
```

**Multiple rules:** Comma-separate rule names within a single annotation.

```apex
@SuppressWarnings('PMD.KernNoDirectDML, PMD.KernNoRawHttp')
public inherited sharing class LegacyIntegration
{
   // Scheduled for refactoring in Sprint 14
}
```

### LWC (ESLint)

**Per-line suppression:**

```javascript
// eslint-disable-next-line kerndx/use-component-builder -- template-only component
export default class StaticBanner extends LightningElement {}
```

**Per-file suppression:**

```javascript
/* eslint-disable kerndx/no-console-log */
// This utility file provides console wrappers for non-ComponentBuilder contexts
```

**Block suppression:**

```javascript
/* eslint-disable kerndx/no-console-log */
console.log('Debugging integration');
console.error('Integration error');
/* eslint-enable kerndx/no-console-log */
```

### Flow/Object Naming

The naming validator does not have inline suppression. Instead:

1. **Edit configuration arrays** in `validate-naming.js` to expand acceptable patterns
2. **Exclude specific paths** from the scan by modifying the script's directory traversal logic
3. **Filter output** in CI/CD by piping through a grep exclusion for known exceptions

---

## IDE Integration

### VS Code

**PMD (Apex):** Install the **Apex PMD** extension from the VS Code marketplace. Add to `.vscode/settings.json`:

```json
{
   "apexPMD.rulesets": [
      "scanner/kerndx-pmd-ruleset.xml"
   ]
}
```

If you also use org-specific naming rules:

```json
{
   "apexPMD.rulesets": [
      "scanner/kerndx-pmd-ruleset.xml",
      "scanner/subscriber-naming-pmd-ruleset.xml"
   ]
}
```

Violations appear inline with squiggly underlines as you type. Hover over a violation to see the rule name and message. The Apex PMD extension supports multiple rulesets
natively.

**ESLint (LWC):** Install the **ESLint** extension. With the configuration already in `eslint.config.mjs`, violations from `kerndx/use-component-builder`,
`kerndx/no-console-log`, and `kerndx/enforce-component-naming` appear inline automatically.

### IntelliJ / Illuminated Cloud

Illuminated Cloud (the Apex IDE plugin for IntelliJ) only accepts a single PMD ruleset path. Use the combined ruleset:

**Settings > Illuminated Cloud > PMD > Custom Ruleset Path:**

```text
scanner/combined-pmd-ruleset.xml
```

The combined file uses PMD `<rule ref="..."/>` elements to include both `kerndx-pmd-ruleset.xml` and `subscriber-naming-pmd-ruleset.xml` by reference. No rules are duplicated.

---

## CI/CD Integration

### Salesforce Code Analyzer v5 (Recommended)

SF Code Analyzer v5 (`sf code-analyzer`) ships with PMD 7 and supports custom rulesets natively.

**Configuration file** (`code-analyzer.yml` in project root):

```yaml
engines:
  pmd:
    custom_rulesets:
      - scanner/kerndx-pmd-ruleset.xml
```

**Run commands:**

```bash
# Full scan with all configured rules
sf code-analyzer run --target force-app/ --view detail

# KernDX framework rules only (by ruleset name)
sf code-analyzer run --config-file code-analyzer.yml --rule-selector pmd:KernDXFrameworkCompliance --target force-app/ --view detail

# Scan specific file or directory
sf code-analyzer run --config-file code-analyzer.yml --target force-app/main/default/classes/MyService.cls --view detail
```

### GitHub Actions

```yaml
name: Code Quality
on: [pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install SF CLI
        run: npm install -g @salesforce/cli

      - name: Run Code Analyzer (Apex)
        run: sf code-analyzer run --target force-app/ --view detail --config-file code-analyzer.yml

      - name: Run ESLint (LWC)
        run: npm ci && npm run lint

      - name: Run Naming Validator
        run: node scanner/validate-naming.js force-app
```

### Gearset

1. Go to **Static Code Analysis** settings
2. Upload `scanner/kerndx-pmd-ruleset.xml` as a custom ruleset
3. Optionally upload `scanner/subscriber-naming-pmd-ruleset.xml` for org-specific naming
4. Enable for deployment validations

Gearset runs PMD against all Apex classes and triggers during deployment validation. Both rulesets are standard PMD XML -- no additional configuration beyond uploading them.

### Copado

1. Navigate to **PMD SCA Settings** or **Quality Gate** configuration
2. Add PMD rulesets as custom rulesets
3. Set enforcement level per rule priority:
   - Priority 1 rules: **Block** (fail the deployment)
   - Priority 3 rules: **Warn** or **Block** (team preference)
   - Priority 5 rules: **Warn** (informational only)

Copado supports custom PMD rulesets natively. Upload the XML files and they run on every deployment.

### AutoRABIT

1. Go to **Static Code Analysis > Apex PMD**
2. Upload PMD rulesets
3. Assign to your project's analysis profile

AutoRABIT runs PMD as part of its static analysis pipeline. Custom rulesets are uploaded through the UI and apply to all Apex scans in the assigned profile.

### CodeScan

1. Add rulesets as custom rulesets in your **Quality Profile**
2. Activate the KernDX rules
3. Set severity thresholds:
   - Priority 1 = Critical
   - Priority 3 = Major
   - Priority 5 = Info

### Legacy SF Scanner (v4)

For teams still on the deprecated `sfdx-scanner` (v4):

```bash
sfdx scanner:run --pmdconfig scanner/kerndx-pmd-ruleset.xml --target force-app/ --format table
```

> **Note:** SF Code Analyzer v5 (`sf code-analyzer`) replaces `sfdx-scanner`. Migrate when possible -- v5 ships PMD 7 which is required for the XPath rule class used in
> the KernDX ruleset.

---

## Building Org-Specific Rules

The `subscriber-naming-pmd-ruleset.xml` file is an example of org-specific naming rules built for a subscriber organization. Subscribers can create their own by following
this approach.

**Step 1: Copy the template**

Copy `scanner/subscriber-naming-pmd-ruleset.xml` to a new file (e.g., `scanner/myorg-naming-pmd-ruleset.xml`).

**Step 2: Modify the naming patterns**

Edit the XPath regex patterns to match your naming convention. For example, to enforce `FIN_`/`HR_`/`OPS_` domain prefixes:

```xml
<rule name="MyOrgApexClassNaming"
      language="apex"
      message="Apex class does not follow naming: Domain_Layer_Name"
      class="net.sourceforge.pmd.lang.rule.xpath.XPathRule">
   <priority>3</priority>
   <properties>
      <property name="xpath">
         <value>
<![CDATA[
//UserClass[
   not(
      matches(
         @SimpleName,
         '^(FIN|HR|OPS|CMN)_(SEL|TRG|FLOW|SVC|BATCH|SCHED|API|REST|DTO|CTRL|UTIL)_[A-Z][a-zA-Z0-9]+(_TEST)?$'
      )
   )
]
]]>
         </value>
      </property>
   </properties>
</rule>
```

**Step 3: Update the combined ruleset**

Create or update a combined ruleset that references both the framework rules and your org-specific rules:

```xml
<ruleset name="Framework + MyOrg Combined"
         xmlns="http://pmd.sourceforge.net/ruleset/2.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://pmd.sourceforge.net/ruleset/2.0.0 https://pmd.sourceforge.io/ruleset_2_0_0.xsd">
   <description>Combined ruleset for KernDX framework + MyOrg naming.</description>
   <rule ref="kerndx-pmd-ruleset.xml"/>
   <rule ref="myorg-naming-pmd-ruleset.xml"/>
</ruleset>
```

**Step 4: Customize the naming validator**

Edit the `DOMAINS`, `BRANDS`, and `FLOW_TYPES` arrays in `scanner/validate-naming.js` to match your org's naming convention for Flows and Custom Objects.

**Step 5: Customize LWC naming**

Edit the `DOMAINS` and `BRANDS` arrays in `scanner/eslint-plugin-kerndx/rules/enforce-component-naming.js` to match your LWC naming convention.

> **Reference:** PMD 7 XPath documentation is available at [pmd.github.io](https://pmd.github.io/pmd/pmd_userdocs_extending_writing_xpath_rules.html). The Apex AST node
> types used in these rules (`UserClass`, `UserTrigger`, `MethodCallExpression`, `NewObjectExpression`, `SoqlExpression`, etc.) are documented in the PMD Apex language
> module.

---

## Phased Adoption Strategy

For teams with existing codebases that predate KernDX adoption, a phased rollout prevents overwhelming developers with hundreds of violations at once.

### Phase 1: Blockers Only

Enable Priority 1 rules (`KernTriggerMustDelegate`, `KernNoInlineSOQL`, `KernNoCoverageTheatre`, `KernCoverageExemptRequiresReason`). These represent the most critical framework bypasses -- code that circumvents the trigger
framework entirely, bypasses the query abstraction layer, or inflates coverage without actually verifying behaviour.

**Action items:**
- Configure IDE and CI/CD with `kerndx-pmd-ruleset.xml`
- Suppress P3 and P5 rules globally or accept them as warnings (not blockers)
- Refactor existing triggers to use `TRG_Dispatcher`
- Move inline SOQL to selectors or `QRY_Builder`
- Add real assertions to tests flagged as coverage-theatre; replace empty catches and `Boolean exceptionThrown` patterns with `Assert.fail` + `Assert.isInstanceOfType`
- Audit every `// kern-coverage-exempt:` comment — rewrite hand-wavy reasons to cite a specific platform limitation

**Expected effort:** High for initial migration (trigger refactoring), low ongoing.

### Phase 2: Framework Compliance

Add Priority 3 rules. Migrate direct platform API usage to framework wrappers.

**Migration checklist:**

| From | To | Guide |
|------|----|-------|
| `insert`/`update`/`delete` | `DML_Builder.newTransaction()...execute()` | [DML - Guide](DML%20-%20Guide.md) |
| `System.debug()` | `LOG_Builder.build()...emitAt()` | [Logging - Guide](Logging%20-%20Guide.md) |
| `new HttpRequest()` | `UTIL_HttpClient.post()` | [Web Services - Guide](Web%20Services%20-%20Guide.md) |
| `implements Schedulable` | `extends SCHED_Base` | [Async Processing - Guide](Async%20Processing%20-%20Guide.md) |
| `System.schedule()` | `ScheduledJob__c` metadata | [Async Processing - Guide](Async%20Processing%20-%20Guide.md) |
| `EventBus.publish()` | `LOG_Builder` / framework events | [Logging - Guide](Logging%20-%20Guide.md) |
| `implements HttpCalloutMock` | `API_MockFactory` | [E2E Testing - Guide](E2E%20Testing%20-%20Guide.md) |
| `RestContext.request` | `API_Inbound` properties | [Web Services - Guide](Web%20Services%20-%20Guide.md) |
| `Messaging.sendEmail()` | `UTIL_Email` | [Utilities - Guide](Utilities%20-%20Guide.md) |

**Expected effort:** Medium. Migrate file by file during normal development.

### Phase 3: Best Practices

Add Priority 5 rules. Adopt framework utilities for caching, describe calls, type resolution, async job launching, cryptography, and feature flags.

**Expected effort:** Low. These are incremental improvements that can be adopted as developers touch existing code.

### Tracking Progress

Run the scanner and count violations by priority to track progress over sprints:

```bash
sf code-analyzer run --target force-app/ --view detail --config-file code-analyzer.yml
```

Track the violation count per priority tier in a spreadsheet or dashboard. Target zero P1 violations immediately, zero P3 within a quarter, and steady reduction in P5 over
time.

---

## PMD Version Compatibility

The KernDX PMD rulesets target **PMD 7**, which uses the rule class:

```text
net.sourceforge.pmd.lang.rule.xpath.XPathRule
```

For teams still on **PMD 6** (e.g., older versions of `sfdx-scanner`), change the `class` attribute on each `<rule>` element to:

```text
net.sourceforge.pmd.lang.apex.rule.ApexXPathRule
```

| Tool | PMD Version | Ruleset Compatible |
|------|-------------|-------------------|
| SF Code Analyzer v5 (`sf code-analyzer`) | PMD 7 | Yes (default) |
| VS Code Apex PMD extension | PMD 7 | Yes (default) |
| Illuminated Cloud (IntelliJ) | PMD 7 | Yes (default) |
| Gearset | PMD 7 | Yes (default) |
| Copado | Varies | Check version, change class attribute if PMD 6 |
| AutoRABIT | Varies | Check version, change class attribute if PMD 6 |
| CodeScan | PMD 7 | Yes (default) |
| Legacy `sfdx-scanner` (v4) | PMD 6 | Requires class attribute change |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| **Fast Start - Code Scanning.md** | Quick-start walkthrough for first scan setup |
| [Triggers - Guide](Triggers%20-%20Guide.md) | Trigger framework and `TRG_Dispatcher` patterns |
| [Selectors - Guide](Selectors%20-%20Guide.md) | `SEL_*` selectors and `QRY_Builder` usage |
| [DML - Guide](DML%20-%20Guide.md) | `DML_Builder` transactional DML patterns |
| [Logging - Guide](Logging%20-%20Guide.md) | `LOG_Builder` structured logging |
| [Web Services - Guide](Web%20Services%20-%20Guide.md) | `UTIL_HttpClient`, `API_Inbound`, `API_Outbound` |
| [LWC - Guide](LWC%20-%20Guide.md) | ComponentBuilder and LWC framework patterns |
| [Utilities - Guide](Utilities%20-%20Guide.md) | `UTIL_Cache`, `UTIL_Crypto`, `UTIL_Email`, and other utilities |
| [Async Processing - Guide](Async%20Processing%20-%20Guide.md) | `SCHED_Base`, `UTIL_AsynchronousJobLauncher` |
| [Security - Guide](Security%20-%20Guide.md) | Sharing enforcement and security patterns |
| [`scanner/README.md`](../scanner/README.md) | Quick reference for scanner files and rules |
