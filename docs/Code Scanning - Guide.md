---
navOrder: 90
---

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
        - [KernSecurityBypassCallSite](#kernsecuritybypasscallsite)
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
7. [Secret Scanning](#secret-scanning)
8. [Deploy-Time Scanners](#deploy-time-scanners)
    - [Access-Mode Scanner](#access-mode-scanner)
    - [Flow-Reference Scanner](#flow-reference-scanner)
    - [Umbrella Scan](#umbrella-scan)
9. [Suppression](#suppression)
    - [Apex (PMD)](#apex-pmd)
    - [LWC (ESLint)](#lwc-eslint)
    - [Flow/Object Naming](#flowobject-naming)
10. [IDE Integration](#ide-integration)
    - [VS Code](#vs-code)
    - [IntelliJ / Illuminated Cloud](#intellij--illuminated-cloud)
11. [CI/CD Integration](#cicd-integration)
    - [Salesforce Code Analyzer v5 (Recommended)](#salesforce-code-analyzer-v5-recommended)
    - [GitHub Actions](#github-actions)
    - [Gearset](#gearset)
    - [Copado](#copado)
    - [AutoRABIT](#autorabit)
    - [CodeScan](#codescan)
    - [Legacy SF Scanner (v4)](#legacy-sf-scanner-v4)
12. [Building Org-Specific Rules](#building-org-specific-rules)
13. [Phased Adoption Strategy](#phased-adoption-strategy)
    - [Phase 1: Blockers Only](#phase-1-blockers-only)
    - [Phase 2: Framework Compliance](#phase-2-framework-compliance)
    - [Phase 3: Best Practices](#phase-3-best-practices)
    - [Tracking Progress](#tracking-progress)
14. [PMD Version Compatibility](#pmd-version-compatibility)
15. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                       | Go to...                                                                             |
|---------------|------------------------------------|--------------------------------------------------------------------------------------|
| **Developer** | Understand a PMD violation         | [PMD Rule Reference](#pmd-rule-reference)                                            |
| **Developer** | Fix an ESLint error in my LWC      | [ESLint Rules (LWC)](#eslint-rules-lwc)                                              |
| **Developer** | Suppress a rule for a valid reason | [Suppression](#suppression)                                                          |
| **Developer** | Set up scanning in VS Code         | [IDE Integration](#ide-integration)                                                  |
| **Architect** | Plan a phased rollout              | [Phased Adoption Strategy](#phased-adoption-strategy)                                |
| **Architect** | Build org-specific naming rules    | [Building Org-Specific Rules](#building-org-specific-rules)                          |
| **DevOps**    | Add scanning to a CI/CD pipeline   | [CI/CD Integration](#cicd-integration)                                               |
| **DevOps**    | Validate Flow and Object naming    | [Naming Validator (Flows & Custom Objects)](#naming-validator-flows--custom-objects) |

---

## Overview

**In one paragraph:** A framework only helps if people actually use it. Nothing stops a developer from writing a plain `insert record;` or a raw `System.debug()` instead of the framework's safer equivalent, and on a busy team those shortcuts pile up until the framework's guarantees no longer hold. This guide describes the set of checkers (a "scanner") that watch your code and flag those shortcuts automatically, so they get caught and fixed instead of quietly accumulating. You catch a problem either in your editor as you type, or in your build pipeline before the code reaches a Salesforce org. Developers use this guide to understand and fix a flagged violation; architects use it to plan a phased rollout; DevOps uses it to wire the checks into a deployment pipeline. Reach for it whenever you set up code quality gates or hit a rule you want to understand.

**Why this matters in practice:** Take one example. A developer writes `insert record;` instead of `DML_Builder.newTransaction().doInsert(record).execute()`. The code compiles and works, so nothing looks wrong. But that one line quietly gives up four things the framework would have provided: an all-or-nothing transaction, the running user's own permissions and record sharing enforced, consistent error handling, and logging. The scanner flags that line the moment it is written, so the gap never reaches production.

**The three checkers.** Salesforce code comes in different shapes, and no single tool can read all of them, so the scanner uses three complementary checkers, each matched to what it reads best. They live in the `scanner/` directory.

1. **PMD rulesets** check your Apex code: framework compliance, test-quality gates, and optional org-specific naming.
2. **ESLint plugin** checks your Lightning Web Component (LWC) JavaScript: the shared base class, blocking raw `console` output, naming, and Jest test-quality gates.
3. **Naming validator** is a Node.js script that checks declarative metadata the first two tools cannot read (Flows and Custom Objects).

> **Companion Document:** If you just want to get a first scan running, start with the quick walkthrough in **Fast Start - Code Scanning.md**. This guide is the full reference instead: it covers every rule, every way to suppress one, and every integration option.

---

## Architecture

### Enforcement Layers

Each of the three checkers reads a different kind of file, using the tool best suited to that file type. The diagram below shows what each one covers and where it runs (in your editor and in the build pipeline).

```text
+----------------------------------+     +----------------------------------+     +----------------------------------+
|         PMD Rulesets             |     |       ESLint Plugin              |     |       Naming Validator           |
|  (Apex classes & triggers)       |     |  (LWC JavaScript)                |     |  (Flows & Custom Objects)        |
+----------------------------------+     +----------------------------------+     +----------------------------------+
|  kerndx-pmd-ruleset.xml         |     |  eslint-plugin-kerndx/           |     |  validate-naming.js              |
|  25 XPath rules, PMD 7           |     |  6 ESLint rules                  |     |  Node.js script, org-specific    |
|  Framework anti-patterns         |     |  ComponentBuilder, console,      |     |  Flow & Custom Object naming     |
|  Priority 1/3/5 tiers            |     |  component naming                |     |  Configurable domains/brands     |
+----------------------------------+     +----------------------------------+     +----------------------------------+
         |                                        |                                        |
         v                                        v                                        v
   IDE (VS Code, IntelliJ)                  IDE (ESLint extension)                   CLI (node script)
   CI/CD (Code Analyzer, Gearset,           CI/CD (npm run lint)                     CI/CD (node command)
          Copado, AutoRABIT, CodeScan)
```

**How the layers fit together:** The three checkers run independently and do not overlap. PMD handles Apex, ESLint handles JavaScript, and the naming validator handles the XML and directory-based metadata neither of the others can read. Because none of them duplicates another's coverage, you run all three to check the whole project.

### File Listing

| File                                | Scope                             | Purpose                                                                                                                                                                        |
|-------------------------------------|-----------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `kerndx-pmd-ruleset.xml`            | Any KernDX org                    | 25 XPath rules enforcing framework anti-patterns (inline SOQL, direct DML, System.debug, coverage theatre, inline DML in tests, etc.)                                          |
| `subscriber-naming-pmd-ruleset.xml` | Your org (example)                | Apex class naming (`Domain_[Brand_]Layer_Name`), trigger naming (`TRG_ObjectName`), 40-char limit                                                                              |
| `combined-pmd-ruleset.xml`          | Both (single-file reference)      | Includes both PMD rulesets via `<rule ref="..."/>`, for tools that accept only one ruleset file                                                                              |
| `eslint-plugin-kerndx/`             | Any KernDX org                    | 6 ESLint rules: ComponentBuilder usage, console.log blocking, LWC component naming, coverage-exempt justification, jest-theatre prevention, shared-fixture mutation prevention |
| `validate-naming.js`                | Org-specific                      | Flow and Custom Object naming validation, with configurable domains, brands, and flow types                                                                                       |

---

## PMD Rule Reference

This section is the lookup table for every Apex rule: what it flags, why, and what to write instead. All 25 PMD rules live in `scanner/kerndx-pmd-ruleset.xml`. Under the hood each one is an XPath expression that scans the parsed form of your Apex (the abstract syntax tree, or AST) for a common risky mistake, targeting the PMD 7 engine. The rules are sorted into three priority tiers so you know which ones to fix first.

> For current framework statistics, see [Metrics](Strategic%20Guide%20-%20Metrics.md).

| Priority | Meaning       | Action Required                                                                          |
|----------|---------------|------------------------------------------------------------------------------------------|
| **1**    | Blocker       | Must fix before merge. Bypasses core framework abstractions.                             |
| **3**    | Should Fix    | Direct use of platform APIs that have framework wrappers. Fix during normal development. |
| **5**    | Informational | Best practices. Teams may adopt incrementally.                                           |

### Priority 1 Blockers

A violation at this top priority means the code has stepped around the core of the framework, so the framework's guarantees no longer apply to it. Fix these before the code merges.

#### KernTriggerMustDelegate

**The goal:** keep your trigger files as thin as possible so all real logic lives in handler classes the framework can control. This rule enforces that: a trigger body must contain only `new TRG_Dispatcher().run()`. Put any other logic directly in the trigger file and it runs outside the framework, losing the configuration-driven run order, the master off-switches admins rely on, performance monitoring, and the ability to test the logic on its own. See the [trigger framework guide](Triggers%20-%20Guide.md) for the full picture.

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

> **Why this is Priority 1:** Trigger logic that skips `TRG_Dispatcher` is stuck. An admin cannot switch it off in an incident via `TriggerSetting__mdt.BypassExecution__c`. You cannot reorder it via `TriggerAction__mdt.Order__c`. It never shows up in performance logging. And you cannot test it on its own.

#### KernNoInlineSOQL

**The goal:** every query runs through one consistent layer so it enforces security, can be cached, and can be reused. This rule requires that: all queries go through a `SEL_*` selector class or [QRY_Builder](reference/apex/QRY_Builder.md). A query written inline (`[SELECT ...]`) or with `Database.query()` skips field-level security (FLS, which is permission checks on individual fields), skips caching, skips sharing control, and cannot be reused elsewhere.

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

**The problem:** a test can run production code, count toward your coverage number, and still check nothing at all. That kind of test gives false confidence: it keeps passing even after the code it "covers" breaks. The goal of this rule is to make sure a test actually verifies behaviour, not just executes lines to lift the coverage figure.

It blocks four ways a test can look thorough while proving nothing:

- A test with no `Assert.*` calls at all.
- An empty `catch` block that silently swallows an exception.
- The legacy `Boolean exceptionThrown` flag pattern.
- `Assert.isNotNull` on a record just returned by `TST_Builder.build()`. The builder can never return null, so this assertion is always true and proves nothing.

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

> **Why this is Priority 1:** these tests sail through the 100% coverage gate while verifying nothing, so they hide regressions: the test stays green even when the production code it "covers" has broken. In practice, fixing them often surfaces bugs the hollow tests were concealing.

#### KernCoverageExemptRequiresReason

Sometimes a line genuinely cannot be tested (for example, a platform restriction makes it impossible to reach). You mark such a line with a `// kern-coverage-exempt:` comment, which removes it from the coverage count. Because that lets a line escape the coverage gate, this rule insists the comment explain exactly why, citing a specific platform limitation. Empty, very short (under 15 characters), or hand-wavy reasons (`tricky`, `hard to test`, `TODO`, `FIXME`, `later`, `hack`, `XXX`) are blocked, so the escape hatch can't be used to quietly dodge a test you simply didn't write.

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

Each of these rules catches a place where you used a raw Salesforce API directly when the framework offers a wrapper around it. The wrapper adds things the raw API lacks: logging, error handling, security checks, and retry logic. None of these is an emergency, so fix them as you touch the code during normal development.

#### KernNoDirectDML

**You want to:** save records safely. Writing records with a bare `insert`, `update`, `delete`, `upsert`, `undelete`, or `merge` statement (or the matching `Database.*` method) gives up the protections the framework adds. Route the change through [DML_Builder](reference/apex/DML_Builder.md) instead, and you get an all-or-nothing transaction, consistent error handling, and the running user's permissions enforced.

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

**You want to:** log something and still be able to find it later. `System.debug()` writes to a debug log that expires, so the moment you need it most (after a production failure) it is gone, and you cannot search or chart it. Use [LOG_Builder](reference/apex/LOG_Builder.md) instead: it saves each log as a real, queryable record (`LogEntry__c`, published through a platform event), so the evidence is still there next week.

```apex
// VIOLATION
System.debug('Processing account: ' + account.Name);
System.debug(LoggingLevel.ERROR, 'Failed to process');

// CORRECT
LOG_Builder.build().info('Processing account: ' + account.Name).emitAt('MyClass.myMethod');
LOG_Builder.build().error('Failed to process').emitAt('MyClass.myMethod');
```

#### KernNoRawHttp

**You want to:** call an external system and have it cope with flaky networks. Building an `HttpRequest` or `Http` by hand gives you none of that. The framework wrapper adds retries, a circuit breaker (after repeated failures it stops calling a failing system for a cool-off, then resumes), logging, named-credential integration, and easy mocking for tests. Use the [UTIL_HttpClient](reference/apex/UTIL_HttpClient.md) static factory methods instead.

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

**You want to:** schedule a job and configure it without editing code. A class that implements `Schedulable` directly cannot do that. Extend `SCHED_Base` instead and you get parameters resolved for you, configuration driven by `ScheduledJob__c` records (so admins can adjust it), and structured error handling.

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

**You want to:** start a scheduled job through the framework so it can be monitored and configured. A direct `System.schedule()` call sidesteps that. Use `SCHED_Base` together with `ScheduledJob__c` custom metadata records instead: scheduling is then driven by configuration, supports monitoring, and lets you pass parameters without touching code.

```apex
// VIOLATION
System.schedule('Nightly Sync', '0 0 0 * * ?', new MyScheduledJob());

// CORRECT -- configure via ScheduledJob__c metadata record
// The framework handles scheduling based on metadata configuration
```

#### KernNoRawEventPublish

**You want to:** publish a platform event through the framework so it is handled consistently. A direct `EventBus.publish()` call skips that path. For log events, use [LOG_Builder](reference/apex/LOG_Builder.md); for your own domain events, use the matching framework mechanism.

```apex
// VIOLATION
LogEntryEvent__e event = new LogEntryEvent__e(Message__c = 'Error occurred');
EventBus.publish(event);

// CORRECT
LOG_Builder.build().error('Error occurred').emitAt('MyClass.myMethod');
```

#### KernNoRawHttpMock

**You want to:** fake an HTTP response in a test without boilerplate. Writing your own `HttpCalloutMock` or `WebServiceMock` works but skips the framework's mock support. Use `API_MockFactory` instead: it sets up mocks consistently, configures responses for you, and plugs into the API framework's test helpers.

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

**You want to:** handle an inbound API call with logging, error handling, and safe retries built in. Reading `RestContext.request` and `RestContext.response` directly skips all of that. Keep your `REST_*` class thin: it should only hand off to `API_Dispatcher.processInboundService()`. Your `API_Inbound` subclass then reads the request and writes the response through inherited properties, which automatically add logging, error handling, and idempotency (if the exact same request arrives twice, the first result is returned again rather than running the work a second time).

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

**You want to:** send email with template handling, error handling, and logging already wired in. Using the raw `Messaging` API (`Messaging.sendEmail()`, `new SingleEmailMessage()`, `Messaging.renderStoredEmailTemplate()`) gives you none of those. Use `UTIL_Email` instead.

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

**The goal:** keep inbound API code consistent so any developer can find the routing and the logic at a glance. This rule requires that any class annotated with `@RestResource` is named `REST_*`. A `REST_*` class is just a thin router that hands off to `API_Dispatcher.processInboundService()`; the actual business logic lives in an `API_*` class that extends `API_Inbound`.

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

**You want to:** create test records the framework way, so they pick up the right defaults and trigger settings. A raw `insert`, `update`, `delete`, `upsert`, `undelete`, or `merge` inside an `@IsTest` class skips the framework's test fixtures. Get your test records from `TST_Builder.of(SObjectType).build()`, which respects trigger-bypass configuration and default field providers. When the test is specifically about DML behaviour, use `DML_Builder` rather than a raw `insert`. This is the test-only version of `KernNoDirectDML`, and it fires only inside classes annotated `@IsTest`.

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

These are good-practice suggestions that improve code quality and consistency. They are not urgent, so adopt them at your own pace as you touch existing code.

#### KernNoLegacyAssert

**You want to:** clearer test assertions with better failure messages. The older `System.assert()`, `System.assertEquals()`, and `System.assertNotEquals()` still work, but the modern `Assert` class methods (`Assert.isTrue()`, `Assert.areEqual()`, `Assert.areNotEqual()`, and so on) read more clearly and report failures more helpfully.

```apex
// VIOLATION
System.assertEquals('Expected', actual, 'Values should match');
System.assert(condition, 'Condition should be true');

// CORRECT
Assert.areEqual('Expected', actual, 'Values should match');
Assert.isTrue(condition, 'Condition should be true');
```

#### KernUseTestBuilder

**You want to:** test records that stay consistent and need less upkeep. Building an SObject by hand in a test (`new Account(Name = 'Test')`) means every test repeats its own setup. `TST_Builder.of(SObjectType).build()` gives you consistent defaults, respects trigger framework configuration, and cuts the maintenance when fields change. This rule fires only inside `@IsTest` classes.

```apex
// VIOLATION (inside @IsTest class)
Account account = new Account(Name = 'Test Corp', Industry = 'Tech');
insert account;

// CORRECT
Account account = (Account)TST_Builder.of(Account.SObjectType)
   .withOverride(Account.Industry, 'Tech').build();
```

#### KernNoRawCache

**You want to:** cache data without worrying about partitions or what happens when the cache is full. Calling `Cache.Org.*` and `Cache.Session.*` directly leaves all of that to you. `UTIL_Cache` manages partitions for you, keeps working (degrading gracefully) when the cache is unavailable, and keeps your keys consistently namespaced.

```apex
// VIOLATION
Cache.Org.put('local.MyPartition.key', value);
Object cached = Cache.Org.get('local.MyPartition.key');

// CORRECT
UTIL_Cache.org().put('key', value);
Object cached = UTIL_Cache.org().get('key');
```

#### KernNoRawDescribe

**You want to:** read object and field metadata without paying for it repeatedly. `Schema.getGlobalDescribe()` is slow and rebuilds its result every time you call it. `UTIL_SObjectDescribe` caches describe results and gives you type-safe access to fields, record types, and object metadata. Note: individual `.getDescribe()` calls on `SObjectField` and `SObjectType` tokens are fine and are not flagged.

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

**You want to:** look up an Apex class by name and have it work whether the framework runs as a managed package or in your own namespace. The built-in `Type.forName()` does not handle that namespace resolution, so it can fail to find the class. `UTIL_System.getTypeForClassName()` does the work for you: it tries your own namespace first, applies the package namespace prefix when needed, and lets you point it at custom resolvers via `ClassTypeResolver__mdt`.

```apex
// VIOLATION
Type handlerType = Type.forName('TRG_SetAccountDefaults');

// CORRECT
Type handlerType = UTIL_System.getTypeForClassName('TRG_SetAccountDefaults');

// CORRECT -- with interface validation
Type handlerType = UTIL_System.getTypeForClassName('TRG_SetAccountDefaults', IF_Trigger.BeforeInsert.class);
```

#### KernNoRawEnqueueJob

**You want to:** kick off a background job without tripping over Salesforce's limits. A direct `System.enqueueJob()` call gives you no protection against them. `UTIL_AsynchronousJobLauncher` tracks how deep the job chain has gone, watches the platform's governor limits, and falls back to another strategy when you hit the cap on queued jobs.

```apex
// VIOLATION
System.enqueueJob(new MyQueueable());

// CORRECT
UTIL_AsynchronousJobLauncher.enqueue(new MyQueueable());
```

#### KernNoRawCrypto

**You want to:** hash or encrypt something with less ceremony. The raw `Crypto.*` API is low-level. `UTIL_Crypto` wraps the common operations (hashing, encryption, decryption, and key generation) in simpler calls.

```apex
// VIOLATION
Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(input));
Blob key = Crypto.generateAesKey(256);

// CORRECT
String hash = UTIL_Crypto.generateSHA256Hash(input);
Blob key = UTIL_Crypto.generateEncryptionKey();
```

#### KernNoRawFeatureManagement

**You want to:** turn a feature on or off through configuration rather than code. The raw `FeatureManagement` API does not give you that. `UTIL_FeatureFlag.isEnabled()` reads feature flags from `FeatureFlag__mdt` records, caches them, and keeps flag names consistent, so admins can flip a feature without a deployment.

```apex
// VIOLATION
Boolean isEnabled = FeatureManagement.checkPermission('MyFeature');
Integer limit = FeatureManagement.checkPackageIntegerValue('MaxRetries');

// CORRECT
Boolean isEnabled = UTIL_FeatureFlag.isEnabled('MyFeature');
```

#### KernNoBooleanExceptionThrown

**You want to:** prove a test threw the *right* kind of exception, with less code. The old `Boolean exceptionThrown = false; try { ... } catch(...) { exceptionThrown = true; }` pattern is wordy and only checks that *some* exception was thrown, not which one. Instead, call `Assert.fail(...)` right after the line that should throw (so the test fails if it doesn't), then check the type with `Assert.isInstanceOfType(error, ExceptionClass.class, ...)` in the `catch` block.

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

#### KernSecurityBypassCallSite

Sometimes you have a legitimate reason to turn a safety check off on purpose. KernDX supports that with a small set of deliberate opt-outs: on `QRY_Builder` and `DML_Builder`, `withSystemMode()` (run with all permission and sharing checks skipped, instead of with the current user's permissions and record sharing enforced), `bypassSharing()`, and `withoutSecurity()`; on `UTIL_ValidationRule`, `bypassObject()`, `bypassGroup()`, and `bypassRule()`; and on `TRG_Base`, `bypassAction()`. Each is a valid, supported call. Each is also a spot where the framework's default protections are deliberately switched off, so a reviewer should be able to see every one of them.

This rule is an **inventory, not a violation**. It flags each opt-out call site so that a pull request adding a *new* one shows up in review. To acknowledge an expected one, add `@SuppressWarnings('PMD.KernSecurityBypassCallSite')` or an inline `// NOPMD` comment with the reason. That suppression comment becomes the permanent, reviewable record that the opt-out was intended.

**What the rule detects:** method calls named `withSystemMode`, `bypassSharing`, `withoutSecurity`, `bypassObject`, `bypassGroup`, `bypassRule`, or
`bypassAction`.

> **Why this is Priority 5:** these are supported APIs, not mistakes. The rule's job is to make the *full set* of opt-outs visible and reviewable, not to discourage them. At runtime, the [bypass-audit log](Logging%20-%20Guide.md#log-grouping--flood-control) records the same activity, so the deploy-time inventory and the runtime audit can be checked against each other.

### PMD Rule Summary Table

| Rule                               | Detects                                                                                         | Use Instead                                                     | Priority |
|------------------------------------|-------------------------------------------------------------------------------------------------|-----------------------------------------------------------------|----------|
| `KernTriggerMustDelegate`          | Logic in trigger body                                                                           | `new TRG_Dispatcher().run()`                                    | 1        |
| `KernNoInlineSOQL`                 | `[SELECT ...]`, `Database.query()`                                                              | Selector or [QRY_Builder](reference/apex/QRY_Builder.md)        | 1        |
| `KernNoCoverageTheatre`            | Assertion-less tests, empty catches, `Boolean exceptionThrown`, tautological `Assert.isNotNull` | Assert on observable behaviour                                  | 1        |
| `KernCoverageExemptRequiresReason` | Empty, short, or hand-wavy `// kern-coverage-exempt:` reasons                                   | Cite a specific platform limitation                             | 1        |
| `KernNoDirectDML`                  | `insert`/`update`/`delete`, `Database.*` DML                                                    | [DML_Builder](reference/apex/DML_Builder.md)                    | 3        |
| `KernNoSystemDebug`                | `System.debug()`                                                                                | [LOG_Builder](reference/apex/LOG_Builder.md)                    | 3        |
| `KernNoRawHttp`                    | `new HttpRequest()`, `new Http()`                                                               | [UTIL_HttpClient](reference/apex/UTIL_HttpClient.md)            | 3        |
| `KernUseSchedulerBase`             | `implements Schedulable` directly                                                               | `extends SCHED_Base`                                            | 3        |
| `KernNoRawSchedule`                | `System.schedule()`                                                                             | `SCHED_Base` + `ScheduledJob__c`                                | 3        |
| `KernNoRawEventPublish`            | `EventBus.publish()`                                                                            | [LOG_Builder](reference/apex/LOG_Builder.md) / framework events | 3        |
| `KernNoRawHttpMock`                | `implements HttpCalloutMock/WebServiceMock`                                                     | `API_MockFactory`                                               | 3        |
| `KernNoRawRestContext`             | `RestContext.request/response`                                                                  | `API_Inbound` framework                                         | 3        |
| `KernNoRawEmail`                   | `Messaging.sendEmail()`, `new SingleEmailMessage()`                                             | `UTIL_Email`                                                    | 3        |
| `KernRestResourceNaming`           | `@RestResource` on non-`REST_*` class                                                           | `REST_*` + `API_Dispatcher`                                     | 3        |
| `KernNoInlineDmlInTests`           | Raw `insert`/`update`/`delete` inside `@IsTest` classes                                         | `TST_Builder` or `DML_Builder`                                  | 3        |
| `KernNoLegacyAssert`               | `System.assert*()`                                                                              | `Assert.*`                                                      | 5        |
| `KernUseTestBuilder`               | `new Account(Name = ...)` in tests                                                              | `TST_Builder`                                                   | 5        |
| `KernNoRawCache`                   | `Cache.Org.*`, `Cache.Session.*`                                                                | `UTIL_Cache`                                                    | 5        |
| `KernNoRawDescribe`                | `Schema.getGlobalDescribe()`                                                                    | `UTIL_SObjectDescribe`                                          | 5        |
| `KernNoRawTypeForName`             | `Type.forName()`                                                                                | `UTIL_System.getTypeForClassName()`                             | 5        |
| `KernNoRawEnqueueJob`              | `System.enqueueJob()`                                                                           | `UTIL_AsynchronousJobLauncher`                                  | 5        |
| `KernNoRawCrypto`                  | `Crypto.*`                                                                                      | `UTIL_Crypto`                                                   | 5        |
| `KernNoRawFeatureManagement`       | `FeatureManagement.checkPermission()`                                                           | `UTIL_FeatureFlag.isEnabled()`                                  | 5        |
| `KernNoBooleanExceptionThrown`     | `Boolean exceptionThrown` try/catch pattern                                                     | `Assert.fail` + `Assert.isInstanceOfType`                       | 5        |
| `KernSecurityBypassCallSite`       | Security-bypass call sites (`withSystemMode`, `bypassSharing`, `bypassAction`, …)               | Acknowledge with `@SuppressWarnings`/`// NOPMD` + reason        | 5        |

---

## ESLint Rules (LWC)

PMD reads Apex but not JavaScript, so the checks for Lightning Web Components (LWC) live in a separate ESLint plugin, `eslint-plugin-kerndx`. It enforces the same kinds of framework and naming conventions on the JavaScript side. The plugin contains six rules.

### kerndx/use-component-builder

**You want to:** stop re-writing the same plumbing in every component. Every LWC needs the same wiring: toast notifications, calls to Apex controllers, navigation, messaging, and structured logging. `LightningElement` (the Salesforce base class) gives you none of that, so this rule requires that your component extends `ComponentBuilder(...)` instead, a base class with all of it already built in.

**What the rule detects:**

- `extends LightningElement` used directly.
- Aliased imports. If you write `import {LightningElement as Base} from 'lwc'`, the rule follows the alias and still catches `extends Base`.

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

**When to suppress:** a template-only component that has no JavaScript logic needing the framework methods. In practice this is rare, because most components benefit from at least the `notification` module for error handling.

```javascript
// eslint-disable-next-line kerndx/use-component-builder -- template-only component, no framework methods needed
export default class StaticNotice extends LightningElement {}
```

### kerndx/no-console-log

**You want to:** log from a component and keep the output. Native `console.log()` and its siblings write output you cannot filter, keep, or tie back to a single user action. ComponentBuilder gives you `this.consoleLog()` and `this.consoleError()` instead, which feed into the framework's logging so the output is searchable and kept.

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

**The goal:** keep component names consistent so anyone can tell at a glance which part of the business a component belongs to. This rule requires LWC folder names to follow a `domain[Brand]FeatureVariant` pattern. It is org-specific: you set the list of domains and brands in the rule's source.

**What the rule detects:**

- Component folder names that do not start with a recognized domain prefix.
- Component folder names longer than 40 characters.
- Folder names starting with `__` are skipped (that is an internal LWC convention).

**Default configuration (example for your org):**

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

This is the JavaScript version of the PMD `KernCoverageExemptRequiresReason` rule, applying the same policy to LWC. A `// kern-coverage-exempt:` comment removes a line from the coverage count, so the comment must say exactly why, citing a specific platform limitation. Empty, very short (under 15 characters), or hand-wavy reasons are blocked.

**What the rule detects:**

- `// kern-coverage-exempt:` with no reason after the colon.
- A reason shorter than 15 characters.
- A blocklisted reason (case-insensitive): `hard to test`, `tricky`, `todo`, `fixme`, `later`, `xxx`, `hack`.

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

This is the LWC counterpart to the Apex `KernNoCoverageTheatre` rule: a Jest test should prove something, not just run. A test that passes no matter what the production code does lifts your coverage number while verifying nothing. The rule blocks two such patterns:

- An assertion-less test: an `it(...)` block with zero `expect(...)` calls.
- A hollow `createElement` assertion: `expect(element).toBeTruthy()` or `expect(element).toBeDefined()` on a value returned by `createElement`. That only confirms `createElement` did not throw, which proves nothing about the component.

**What the rule detects:**

- An `it(...)` or `test(...)` block whose body contains no `expect(...)` calls.
- An `it(...)` block whose only `expect(...)` call is `toBeTruthy()` or `toBeDefined()` on a `createElement` result.

It applies only to files ending in `.test.js` or under `__tests__/`.

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

**The problem this prevents:** a `describe(...)` block builds one shared DOM fixture in `beforeAll(...)` with `createElement(...)`, and then several `it(...)` tests change that same element (via `dispatchEvent`, `.click()`, a public-API setter, or `querySelector(...).click()`). Because they share one fixture, each test inherits whatever the previous test did to it, so the tests now depend on the order they run in. That hides regressions and makes a failure hard to reproduce.

**The fix:** change `beforeAll` to `beforeEach` so every test gets a fresh fixture, or move the `createElement(...)` call inside the `it(...)` block that mutates it.

It applies only to files ending in `.test.js` or under `__tests__/`.

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

The ESLint configuration ships ready to go in `force-app/main/default/lwc/eslint.config.mjs`, so there is nothing to set up. Run the linter with:

```bash
npm run lint
```

ESLint violations appear inline in VS Code when the ESLint extension is installed. No additional IDE configuration is required beyond having the extension active.

---

## Naming Validator (Flows & Custom Objects)

Flows and Custom Objects are not Apex or JavaScript, so neither PMD nor ESLint can read them. The `validate-naming.js` script fills that gap: it checks naming conventions for Flows (which are XML metadata) and Custom Objects (which are directory-based metadata). It is a standalone Node.js script, and you tailor it to your own org's naming convention.

### Configuration

You drive the script with three configuration arrays at the top of the file:

| Array        | Purpose                     | Default (example)                                |
|--------------|-----------------------------|--------------------------------------------------|
| `DOMAINS`    | Organizational domain codes | `SLS`, `ORD`, `PRD`, `SVC`, `SUB`, `MKT`, `CMN`  |
| `BRANDS`     | Optional brand segments     | `ACM`, `BTA`                                     |
| `FLOW_TYPES` | Flow type abbreviations     | `BS`, `AS`, `BD`, `SCR`, `AL`, `SCH`, `PE`, `SF` |

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

The script reports:

- How many artefacts it checked.
- Near-limit warnings (names within 5 characters of the limit), so you can rename before they overflow.
- Violations, grouped by category, each shown with the pattern it expected.
- An exit code your pipeline can act on: 0 when clean, 1 when it found violations.

### Customizing for Your Org

Adapt the configuration arrays to your own naming convention:

1. Open `scanner/validate-naming.js`
2. Edit `DOMAINS` to match your organizational domains (e.g., `['FIN', 'HR', 'OPS', 'CMN']`)
3. Edit `BRANDS` to match your brand codes (e.g., `['PRO', 'ENT']`) or set to `[]` if not used
4. Edit `FLOW_TYPES` to match your flow type abbreviations
5. Adjust `CHARACTER_LIMITS` if your org uses different limits

---

## Secret Scanning

**The goal:** stop a hardcoded password, token, or key from ever reaching your repository. The pipeline includes a Salesforce-aware gate, `kerndx secret-scan`, that inspects changed files for credentials before they merge. It pairs with [runtime data masking](Security%20-%20Guide.md#data-masking): masking keeps secrets out of your *data*, this gate keeps them out of your *source*.

The PMD and ESLint scanners only read Apex and LWC. The secret scan reads a **wider set of files**, because credentials slip into `.env`, `.yml`, `.json`, `.sh`, and other config files at least as often as into code. It runs over the same changed files as the rest of the pipeline.

**What it detects:** common credential shapes, with extra coverage for Salesforce-specific ones.

| Category        | Examples                                                                                            |
|-----------------|-----------------------------------------------------------------------------------------------------|
| Salesforce      | SFDX auth URLs (`force://…`), access / session tokens, OAuth refresh tokens, connected-app consumer keys and secrets |
| Cloud providers | AWS access key IDs, GitHub tokens, Slack tokens, Google API keys                                     |
| Generic         | PEM private-key blocks, JSON Web Tokens, and credential-shaped variable assignments                 |

**How it runs.** In CI (`--ci`) the gate is strict: any blocking finding **fails the build**. Run locally, it is advisory instead. It reports what it found and exits cleanly so your push still goes through, giving you a chance to catch a secret before CI does. CI is the hard gate.

**Telling it a finding is safe.** Sometimes the scan flags something you have confirmed is fine. You can mark it three ways (none of these turns the gate off):

- An inline `// kerndx-secret-allow: <reason>` comment on the flagged line.
- A path allowlist, via the `secret_scanning.ignore_globs` setting in your pipeline config.
- A fingerprint entry (`path:ruleId:sha8`) in a `.kerndxsecretsignore` file, for a one-off finding the patterns cannot otherwise tell apart.

Because every one of these carries a reason or an explicit fingerprint, each allowed exception stays visible in review.

---

## Deploy-Time Scanners

PMD, ESLint, and the naming validator each look at source files on their own. The deploy-time scanners under `scripts/` do something the others cannot: they compare your source against the actual target org. That catches misconfigurations you can only see by looking at live org state, not the files alone. Run them before any package build or deployment validation.

### Access-Mode Scanner

**What it guards:** that every query and DML call states, out loud, whose permissions it runs under, so nothing silently runs with all security checks skipped by accident. `scripts/scan-access-modes.js` enforces this. Builders chained off `QRY_Builder.selectFrom()`, `DML_Builder.newTransaction()`, and `new DML_Transaction()` must call `.withUserMode()`, `.withSystemMode()`, or `.setAccessLevel()`. Raw `Database.query()`, `Database.queryWithBinds()`, `Database.getQueryLocator()`, `Database.countQuery()`, `Search.query()`, and `Search.find()` must pass an explicit `AccessLevel` argument.

```bash
npm run scan:access-modes
```

The script exits 0 on a clean run and 1 on any violation. The classes that actually implement the access-mode machinery (`QRY_Builder.cls`, `DML_Builder.cls`, and the like) are allowlisted, since the rule does not apply to the code that provides the feature.

### Flow-Reference Scanner

**What it guards:** that every trigger configured to run a Flow points at a real, working Flow, so you don't ship a configuration record that fails at runtime. `scripts/scan-flow-references.js` checks each `TriggerAction__mdt` configuration record whose `FlowName__c` is filled in. For each referenced flow it verifies three things:

1. **It exists.** The flow's API name is present in the dev org's `FlowDefinitionView`.
2. **It is active.** `FlowDefinitionView.IsActive = true`.
3. **Its variables match.** For non-record-triggered flows, the flow's metadata must declare an SObject variable named `record` whose `objectType` matches the dispatching
   `TriggerSetting__mdt.SObjectType__c`, and which is both input and output. Configuration records for update contexts (Event = "Before Update" or "After Update") additionally
   require a `recordPrior` SObject variable.

For the existence check the scanner reads the `FlowDefinitionView` standard SObject; for the variable check it reads the Tooling API's `Flow.Metadata`. It batches both queries into a single round-trip each per scan, to keep the scan fast.

```bash
npm run scan:flow-references
npm run scan:flow-references -- --org SubscriberOrg
```

By default the scanner targets the org named in the `KERN_DEV_ORG` environment variable. Set that variable, or pass `--org <alias>` to point at a different scratch org, sandbox, or production org.

**Permission requirement.** The user running the scan in CI needs the `Manage Flow` permission to read `FlowDefinitionView`. Without it, the org returns zero rows and says nothing, which looks like "no flows" rather than "no access". The bundled `Kern Administrator` permission set already includes `Manage Flow`, so the simplest fix is to assign that permission set to the CI user:

```bash
sf org assign permset -n kern__Administrator -o <integration-user>
```

If the CI user must stay below admin level, create a custom permission set in your org that grants only the `Manage Flow` user permission, and assign that instead. Runners that use a system-administrator profile (the default in pipelines that create a fresh scratch org per build) already have `Manage Flow` through `Modify All Data`.

**It checks its own access first.** Before checking individual records, the scanner runs `SELECT COUNT() FROM FlowDefinitionView`. If the count is zero *and* your local `force-app/main/default/flows/` directory contains `*.flow-meta.xml` files, the scanner stops and prints:

```text
Scanner cannot see any flows in the dev org. Either (a) the running user is missing the 'Manage Flow' user permission (assign it via the Kern Administrator permset, a sysadmin profile, or a custom permset that grants Manage Flow), or (b) the dev org has no flows deployed. Re-run after granting permissions or deploying flows.
```

That turns the most common misconfiguration, where zero rows come back silently, into a loud error that names the fix.

**What an error looks like.** When it finds violations, the scanner prints one entry per affected configuration record. Each message names the record at fault, the flow at fault, and what to do about it:

| Failure          | Sample message                                                                                                                                                                                   |
|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Existence        | `TriggerAction 'SetAccountDefaults': flow 'Account_SetDefaults' does not exist in dev org. Either deploy the flow or remove the CMDT record.`                                                    |
| Inactive         | `TriggerAction 'SetAccountDefaults': flow 'Account_SetDefaults' is inactive. Activate the flow or remove the CMDT record.`                                                                       |
| Missing variable | `TriggerAction 'SetAccountDefaults': flow 'Account_SetDefaults' is missing required variable 'record: Account' (in/out). Either fix the flow declaration or correct the CMDT row's FlowName__c.` |
| Wrong objectType | `TriggerAction 'SetAccountDefaults': flow 'Account_SetDefaults' variable 'record' has type 'SObject/Contact' but TriggerSetting requires 'Account'.`                                             |

### Umbrella Scan

If you would rather run one command than two, the `scan` script runs the access-mode and flow-reference scanners back to back. Use it as the single CI command, or as a quick check before you deploy locally:

```bash
npm run scan
```

It stops at the first scanner that fails, so the error you need to read is the last thing in the CI log. You can still run the individual scripts (`scan:access-modes`, `scan:flow-references`) when you want to target just one.

---

## Suppression

Sometimes a flagged line is deliberate and correct. Every checker lets you suppress a rule in that case, and every one of them asks you to leave a comment saying why, so the exception stays visible to the next reviewer.

### Apex (PMD)

**Per-class suppression:** add `@SuppressWarnings` to the class declaration. Every method in the class is then exempt from the named rule.

```apex
@SuppressWarnings('PMD.KernNoDirectDML')
public inherited sharing class DML_SharingProxy
{
   // Framework infrastructure -- direct DML is intentional here
}
```

**Per-method suppression:** add `@SuppressWarnings` to the method declaration. Only that one method is exempt.

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

**Multiple rules:** list the rule names, comma-separated, in a single annotation.

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

The naming validator has no inline suppression comment. You handle exceptions one of three ways instead:

1. **Widen the rules.** Edit the configuration arrays in `validate-naming.js` to accept more patterns.
2. **Skip a path.** Change the script's directory-walking logic to exclude specific paths.
3. **Filter the output.** In CI, pipe the output through a `grep` exclusion for known exceptions.

---

## IDE Integration

### VS Code

The earlier a violation shows up, the cheaper it is to fix. Wiring the checks into your editor means you see them as you type, long before CI.

**PMD (Apex):** Install the **Apex PMD** extension from the VS Code marketplace, then add this to `.vscode/settings.json`:

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

Violations now appear inline as squiggly underlines while you type. Hover over one to see the rule name and message. The Apex PMD extension supports more than one ruleset out of the box.

**ESLint (LWC):** Install the **ESLint** extension. Because the configuration already lives in `eslint.config.mjs`, violations from `kerndx/use-component-builder`, `kerndx/no-console-log`, and `kerndx/enforce-component-naming` appear inline automatically, with nothing else to set up.

### IntelliJ / Illuminated Cloud

Illuminated Cloud (the Apex IDE plugin for IntelliJ) accepts only one PMD ruleset path, so point it at the combined ruleset that bundles both:

**Settings > Illuminated Cloud > PMD > Custom Ruleset Path:**

```text
scanner/combined-pmd-ruleset.xml
```

The combined file uses PMD `<rule ref="..."/>` elements to pull in both `kerndx-pmd-ruleset.xml` and `subscriber-naming-pmd-ruleset.xml` by reference, with no rule counted twice.

---

## CI/CD Integration

Your editor catches violations as you type, but the build pipeline is the safety net that catches what slips through, before code reaches an org. The rulesets are standard PMD XML, so most Salesforce CI tools accept them. The sections below give the exact setup for the common ones, starting with the recommended Salesforce-native option.

### Salesforce Code Analyzer v5 (Recommended)

SF Code Analyzer v5 (`sf code-analyzer`) ships with PMD 7 and accepts custom rulesets directly, so it is the simplest fit for the KernDX rules.

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

Gearset then runs PMD against all your Apex classes and triggers during deployment validation. Both rulesets are standard PMD XML, so uploading them is all the setup there is.

### Copado

1. Navigate to **PMD SCA Settings** or **Quality Gate** configuration
2. Add PMD rulesets as custom rulesets
3. Set enforcement level per rule priority:
    - Priority 1 rules: **Block** (fail the deployment)
    - Priority 3 rules: **Warn** or **Block** (team preference)
    - Priority 5 rules: **Warn** (informational only)

Copado accepts custom PMD rulesets directly: upload the XML files, and they run on every deployment.

### AutoRABIT

1. Go to **Static Code Analysis > Apex PMD**
2. Upload PMD rulesets
3. Assign to your project's analysis profile

AutoRABIT runs PMD as part of its static analysis pipeline. You upload custom rulesets through the UI, and they apply to every Apex scan in the assigned profile.

### CodeScan

1. Add rulesets as custom rulesets in your **Quality Profile**
2. Activate the KernDX rules
3. Set severity thresholds:
    - Priority 1 = Critical
    - Priority 3 = Major
    - Priority 5 = Info

### Legacy SF Scanner (v4)

If your team is still on the older, now-deprecated `sfdx-scanner` (v4), run:

```bash
sfdx scanner:run --pmdconfig scanner/kerndx-pmd-ruleset.xml --target force-app/ --format table
```

> **Note:** SF Code Analyzer v5 (`sf code-analyzer`) replaces `sfdx-scanner`. Move to v5 when you can: it ships PMD 7, which the KernDX ruleset needs for its XPath rule class.

---

## Building Org-Specific Rules

The framework rules are fixed, but your org's naming convention is your own, so the scanner lets you add naming rules of your own. The shipped `subscriber-naming-pmd-ruleset.xml` is a worked example you copy and adapt. Here is the process.

**Step 1: Copy the template**

Copy `scanner/subscriber-naming-pmd-ruleset.xml` to a new file (for example, `scanner/myorg-naming-pmd-ruleset.xml`).

**Step 2: Modify the naming patterns**

Edit the XPath regular expressions to match your own convention. For example, to require `FIN_`, `HR_`, or `OPS_` domain prefixes:

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

Create or update a combined ruleset that references both the framework rules and your new org-specific ones:

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

If you turn every rule on at once over an existing codebase, developers face hundreds of violations on day one and tune the whole thing out. Rolling the rules out in stages avoids that. Start with the rules that matter most and add the rest as the team has capacity. This applies to any codebase written before you adopted KernDX.

### Phase 1: Blockers Only

Turn on the Priority 1 rules first: `KernTriggerMustDelegate`, `KernNoInlineSOQL`, `KernNoCoverageTheatre`, and `KernCoverageExemptRequiresReason`. These catch the most serious gaps: code that steps around the trigger framework completely, code that queries outside the query layer, and tests that lift coverage without verifying anything.

**Action items:**

- Configure your IDE and CI with `kerndx-pmd-ruleset.xml`.
- Suppress the P3 and P5 rules for now, or accept them as warnings rather than blockers.
- Refactor existing triggers to use `TRG_Dispatcher`.
- Move inline SOQL into selectors or `QRY_Builder`.
- Add real assertions to any test flagged as coverage-theatre. Replace empty catches and `Boolean exceptionThrown` patterns with `Assert.fail` plus `Assert.isInstanceOfType`.
- Review every `// kern-coverage-exempt:` comment, and rewrite any hand-wavy reason to cite a specific platform limitation.

**Expected effort:** High for initial migration (trigger refactoring), low ongoing.

### Phase 2: Framework Compliance

Once the blockers are clear, add the Priority 3 rules and start moving raw platform API calls over to their framework wrappers. The table below maps each common raw call to its replacement and the guide that explains it.

**Migration checklist:**

| From                         | To                                         | Guide                                                         |
|------------------------------|--------------------------------------------|---------------------------------------------------------------|
| `insert`/`update`/`delete`   | `DML_Builder.newTransaction()...execute()` | [DML - Guide](DML%20-%20Guide.md)                             |
| `System.debug()`             | `LOG_Builder.build()...emitAt()`           | [Logging - Guide](Logging%20-%20Guide.md)                     |
| `new HttpRequest()`          | `UTIL_HttpClient.post()`                   | [Web Services - Guide](Web%20Services%20-%20Guide.md)         |
| `implements Schedulable`     | `extends SCHED_Base`                       | [Async Processing - Guide](Async%20Processing%20-%20Guide.md) |
| `System.schedule()`          | `ScheduledJob__c` metadata                 | [Async Processing - Guide](Async%20Processing%20-%20Guide.md) |
| `EventBus.publish()`         | `LOG_Builder` / framework events           | [Logging - Guide](Logging%20-%20Guide.md)                     |
| `implements HttpCalloutMock` | `API_MockFactory`                          | [E2E Testing - Guide](E2E%20Testing%20-%20Guide.md)           |
| `RestContext.request`        | `API_Inbound` properties                   | [Web Services - Guide](Web%20Services%20-%20Guide.md)         |
| `Messaging.sendEmail()`      | `UTIL_Email`                               | [Utilities - Guide](Utilities%20-%20Guide.md)                 |

**Expected effort:** Medium. Migrate file by file during normal development.

### Phase 3: Best Practices

Finally, add the Priority 5 rules and pick up the framework utilities for caching, describe calls, type resolution, launching async jobs, cryptography, and feature flags.

**Expected effort:** Low. These are small improvements your team can fold in whenever they next touch the code.

### Tracking Progress

To see how the rollout is going, run the scanner and count violations by priority over time:

```bash
sf code-analyzer run --target force-app/ --view detail --config-file code-analyzer.yml
```

Record the violation count per priority tier in a spreadsheet or dashboard. A reasonable target: zero P1 violations right away, zero P3 within a quarter, and a steady drop in P5 from there.

---

## PMD Version Compatibility

The KernDX PMD rulesets are written for **PMD 7**, which uses this rule class:

```text
net.sourceforge.pmd.lang.rule.xpath.XPathRule
```

If your tooling is still on **PMD 6** (for example, an older `sfdx-scanner`), change the `class` attribute on each `<rule>` element to this older form:

```text
net.sourceforge.pmd.lang.apex.rule.ApexXPathRule
```

| Tool                                     | PMD Version | Ruleset Compatible                             |
|------------------------------------------|-------------|------------------------------------------------|
| SF Code Analyzer v5 (`sf code-analyzer`) | PMD 7       | Yes (default)                                  |
| VS Code Apex PMD extension               | PMD 7       | Yes (default)                                  |
| Illuminated Cloud (IntelliJ)             | PMD 7       | Yes (default)                                  |
| Gearset                                  | PMD 7       | Yes (default)                                  |
| Copado                                   | Varies      | Check version, change class attribute if PMD 6 |
| AutoRABIT                                | Varies      | Check version, change class attribute if PMD 6 |
| CodeScan                                 | PMD 7       | Yes (default)                                  |
| Legacy `sfdx-scanner` (v4)               | PMD 6       | Requires class attribute change                |

---

## Related Documentation

| Document                                                      | Description                                                    |
|---------------------------------------------------------------|----------------------------------------------------------------|
| **Fast Start - Code Scanning.md**                             | Quick-start walkthrough for first scan setup                   |
| [Triggers - Guide](Triggers%20-%20Guide.md)                   | Trigger framework and `TRG_Dispatcher` patterns                |
| [Selectors - Guide](Selectors%20-%20Guide.md)                 | `SEL_*` selectors and `QRY_Builder` usage                      |
| [DML - Guide](DML%20-%20Guide.md)                             | `DML_Builder` transactional DML patterns                       |
| [Logging - Guide](Logging%20-%20Guide.md)                     | `LOG_Builder` structured logging                               |
| [Web Services - Guide](Web%20Services%20-%20Guide.md)         | `UTIL_HttpClient`, `API_Inbound`, `API_Outbound`               |
| [LWC - Guide](LWC%20-%20Guide.md)                             | ComponentBuilder and LWC framework patterns                    |
| [Utilities - Guide](Utilities%20-%20Guide.md)                 | `UTIL_Cache`, `UTIL_Crypto`, `UTIL_Email`, and other utilities |
| [Async Processing - Guide](Async%20Processing%20-%20Guide.md) | `SCHED_Base`, `UTIL_AsynchronousJobLauncher`                   |
| [Security - Guide](Security%20-%20Guide.md)                   | Sharing enforcement and security patterns                      |
| [Framework Compliance Scanner](https://github.com/JVB-Consulting/kerndx/blob/main/scanner/README.md)          | Quick reference for scanner files and rules                    |
