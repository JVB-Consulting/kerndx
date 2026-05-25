# KernDX Framework — AI Code Generation Context

> Provide this file to any AI code assistant (Claude, Gemini, GPT, Cursor, Copilot, etc.) as project knowledge,
> system prompt, or rules file. Namespace: `kern`. API version: 66.0.
>
> **Audience: subscribers writing code that uses KernDX in their own org.** If you're
> instead working inside this repository (modifying the kern source itself or extending
> the framework), [`AGENTS.md`](../AGENTS.md) at the repo root is the entry point for
> that context.

## STOP — Before Generating Code

**Collect these from the user before writing any code:**
1. **Namespace** — e.g., `kern`. Required for all framework class references.
2. **Class prefix convention** — e.g., `PRJ_`, `ACME_`, or none.
3. **Org alias** — only if deployment commands are needed.

If provided upfront, proceed immediately.

**Schema rule — If custom object fields are unknown, ask the user. Do not guess field API names.**

---

## CRITICAL — Namespace Prefix Rule

**Every framework class reference MUST be prefixed with the namespace.** Without it, code will NOT compile.
This is the single most common AI generation error. Verify EVERY line of generated code.

**Decision rule — apply this to every class reference:**

1. Does `docs/reference/apex/<ClassName>.md` exist in this repo? → It is a KernDX framework class. **Add the `kern.` prefix.**
2. Is the class defined inside YOUR subscriber repository? → **No prefix.**

This rule replaces any hardcoded list of framework classes (the kern namespace has 95+ global types and inner classes; any hardcoded list has gaps). The auto-generated reference under `docs/reference/apex/` is the authoritative inventory — if a class is documented there, it ships in the kern package.

**Inner-class and interface members of framework classes also require the prefix** (e.g. `kern.IF_Trigger.BeforeInsert`, `kern.UTIL_AsyncChain.ChainStep`, `kern.TST_Mock.MockBuilder`). The rule applies to the outermost class name; nested types inherit the same namespace.

**Your own subscriber classes do NOT get the namespace prefix.** Adding the prefix to your own classes causes `Invalid type` errors.

```apex
// WRONG — missing prefix on framework classes → "Invalid type: TRG_Base"
public class TRG_SetDefaults extends TRG_Base implements IF_Trigger.BeforeInsert { }
QRY_Builder.selectFrom(Account.SObjectType).toList();

// WRONG — adding prefix to YOUR OWN subscriber class → "Invalid type: kern.API_CreateOrder"
kern.API_Dispatcher.processInboundService(kern.API_CreateOrder.class.getName());

// RIGHT — prefix ONLY on framework classes; subscriber classes are bare
public with sharing class TRG_SetDefaults extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert { }
kern.QRY_Builder.selectFrom(Account.SObjectType).toList();
kern.API_Dispatcher.processInboundService(API_CreateOrder.class.getName());
```

**Self-check after generating:** For every class name in the generated code, run the decision rule. Framework classes (those documented under `docs/reference/apex/`) without the `kern.` prefix → add it. Subscriber classes with the prefix → remove it. Both errors cause deployment failure.

**Always follow every rule in this document. Do not use alternative patterns (fflib, AT4DX, etc.).**

---

## Coding Standards

### Formatting

**Apex:** Tabs (size 3), Allman bracing, 180-char line limit.
```apex
public with sharing class MyClass
{
	public void myMethod()
	{
		if(condition)
		{
			// code
		}
	}
}
```

**Line wrap (>180 chars):** paren on new line, args indented:
```apex
TriggerAction__mdt action = TST_Factory.newTriggerActionForContext
(
	TRIGGER_ACTION,
	TRIGGER_SETTING,
	TriggerOperation.BEFORE_INSERT
);
```

**JavaScript (LWC):** Tabs, single quotes, semicolons, Allman bracing, camelCase, JSDoc required on LWC component classes (`@description`, `@author`, `@date`) and methods with parameters (`@param {type} name`).

### Naming Conventions

| Prefix | Use | Example |
|--------|-----|---------|
| `SEL_*` | Object selectors | `SEL_Cases` |
| `QRY_*` | Query infrastructure | `QRY_Builder` |
| `DML_*` | DML operations | `DML_Builder` |
| `TRG_*` | Trigger handlers/dispatcher | `TRG_SetDefaults` |
| `IF_*` | Interfaces | `IF_Trigger` |
| `API_*` | Web services | `API_SendEmail` |
| `REST_*` | REST endpoints | `REST_Echo` |
| `DTO_*` | Data Transfer Objects | `DTO_JsonBase` |
| `CTRL_*` | LWC controllers | `CTRL_ScheduledJob` |
| `FLOW_*` | Flow invocables | `FLOW_CreateAccount` |
| `SVC_*` | Service facades | `SVC_Onboarding` |
| `SCHED_*` | Schedulables | `SCHED_PurgeRecords` |
| `BATCH_*` | Batch jobs | `BATCH_Process` |
| `UTIL_*` | Utilities | `UTIL_String` |
| `LOG_*` | Logging | `LOG_Builder` |
| `MAP_*` | In-memory indexing | `MAP_SObject` |
| `TST_*` | Test utilities | `TST_Builder` |
| `*_TEST` | Test classes | `SEL_Cases_TEST` |

### ApexDoc (Required)

**Class-level** (blank line between each tag):
```apex
/**
 * @description Handler for Foobar defaults.
 *
 * @see TRG_SetFoobarDefaults_TEST
 *
 * @author <your-author-tag>
 *
 * @group Trigger Actions
 *
 * @date January 2026
 */
```

Tags in order: `@description`, `@see`, `@author`, `@group`, `@date`, `@since`, `@example`

**Method-level (REQUIRED on EVERY method — including constructors and overrides like `getFields()`, `configure()`, `onSuccess()`):**
`@description`, `@param` (each), `@return` (if non-void), `@throws`, `@since` (if global)

**Do NOT skip ApexDoc on overridden methods.** Every method needs at minimum `@description`. Constructors also need `@description`.

**`@since`:** Required on ALL `global` members (classes, methods, properties). Format: `@since 1.0`. Not required on `public`/`private`. Subscribers rarely need `@since` — only on `REST_*` classes (the only subscriber class type that requires `global`).

**`@example`:** Must use ` ```apex ` code fences.

**All properties and constants** require `@description`. **Bidirectional `@see`** between main class and test class.

### Critical Rules

| Rule | Correct | Wrong |
|------|---------|-------|
| No inline SOQL | `kern.QRY_Builder.selectFrom(...)` or `new SEL_Cases()` | `[SELECT ...]` |
| No System.debug | `kern.LOG_Builder.build().info('msg').emitAt('Class.method')` | `System.debug(...)` |
| No LightningElement | `extends ComponentBuilder('notification')` | `extends LightningElement` |
| No fflib layering pattern in subscriber code | `kern.QRY_Builder`, `kern.DML_Builder`, `extends kern.SEL_Base`, `extends kern.TRG_Base` | `fflib_SObjectSelector`, `fflib_SObjectDomain`, `fflib_Application`, `fflib_SObjectUnitOfWork`, `newQueryFactory()`. The framework's own `UTIL_SObjectDescribe` + `DML_Transaction` utilities are BSD-licensed from the same lineage (see `NOTICES.md`); subscriber code goes through `kern.*` not `fflib_*`. |
| No abbreviations | `account`, `message` | `acc`, `msg` |
| No Given/When/Then | Self-documenting code | `// Given`, `// When` |
| No test cleanup | SF resets static state between tests | Cleanup code in tests |
| No hardcoded field names | `field.getDescribe().getName()` | String literal field names |
| No section separators | Clean code | `//====` banners |
| No inline DML in tests | `kern.TST_Builder.of(SObjectType).build()` | `insert new Account()` |
| Use Assert.* | `Assert.isTrue(result, 'msg')` | `System.assert(...)` |
| Declare sharing | Always `with sharing`; `inherited sharing` only for `SCHED_*` | Missing sharing |
| No unnecessary global | `public` everywhere; `global` only for `REST_*` and `SCHED_*` | `global` on handlers/selectors/services/flows |

### Sharing & Access by Class Type (mandatory)

**Subscriber code uses `with sharing` everywhere.** The `inherited sharing` you may see in framework source is a managed package internal pattern — it does NOT apply to subscriber orgs.

| Class Type | Sharing | Access |
|------------|---------|--------|
| `TRG_*` handlers | `with sharing` | `public` |
| `SEL_*` selectors | `with sharing` (subscriber) / `inherited sharing` (framework) | `public` |
| `API_*` Inbound/Outbound | `with sharing` | `public` |
| `REST_*` routing | `with sharing` | `global` — SF requires for `@RestResource` |
| `SVC_*` services | `with sharing` | `public` |
| `FLOW_*` invocables | `with sharing` | `public` |
| `SCHED_*` schedulables | `inherited sharing` | `global` — framework uses `Type.newInstance()` cross-namespace |
| `UTIL_*` utilities | `with sharing` | `public` |
| `*_TEST` test classes | (none) | `private` |

**Sharing rule:** Always `with sharing`. Never `without sharing` unless explicitly justified.

**Access rule:** Always `public`. Exceptions: `REST_*` classes (`global` required for `@RestResource`) and `SCHED_*` classes (`global` required for cross-namespace `Type.newInstance()`).

### PMD

Cyclomatic complexity ≤15/method, ≤50/class. Parameters ≤5. Nested ifs ≤4. Suppress: `@SuppressWarnings('PMD.RuleName')`.

---

## Selector Framework (SEL_Base)

Extend `kern.SEL_Base`. Define default fields. Custom methods use `query` property (NOT `QRY_Builder.selectFrom()`).

```apex
/**
 * @description Selector for the Case SObject.
 *
 * @see SEL_Cases_TEST
 */
public with sharing class SEL_Cases extends kern.SEL_Base  // MUST be "with sharing" in subscriber code
{
	/** @description Constructs the Case selector. */
	public SEL_Cases() { super(Case.SObjectType); }

	/** @description Returns the default fields for Case queries. */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{ Case.Id, Case.Subject, Case.Status };
	}

	/** @description Returns related field paths for Case queries. */
	public override List<String> getFieldPaths()
	{
		return new List<String>{ 'Account.Name', 'Owner.Name' };
	}

	/** @description Finds open cases ordered by creation date. */
	public List<Case> findOpen()
	{
		return query.condition(Case.IsClosed).equals(false)
			.orderBy(Case.CreatedDate).descending().toList();
	}
}
```

**Inherited methods:** `findById(Id)` / `findById(Set<Id>)` | `findByIdOrThrow(Id/Set<Id>)` | `findByField(field, value/Set)` | `findFirstByField(field, value)` | `findByFields(Map)` / `findFirstByFields(Map)` | `query` (property → `QRY_Builder.Builder`) | `toList()` / `getFirst()` / `getRandomItem()` | `count()` / `exists()` | `toQueryLocator()`

---

## Query Builder (QRY_Builder)

SEL_* for reusable queries; QRY_Builder directly for one-off. Prefer `List<SObjectField>` for compile-time safety.

```apex
List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry })
	.condition(Account.Industry).equals('Tech')
	.orderBy(Account.Name).ascending()
	.withLimit(100)
	.toList();
```

**Fields:** `.fields(List<SObjectField/String>)` | `.addFields()` | `.addField()` | `.relatedField(String)` | `.relatedFields(List<String>)` | `.selectAllFields()` | `.fieldSet()` | `.subselect(Builder, String)`

**Conditions:** `.condition(field)` | `.andCondition(field)` | `.orCondition(field)` | `.addCondition(QRY_Condition.Evaluable)`

**Operators:** `.equals()` | `.notEquals()` | `.greaterThan()` | `.greaterThanOrEquals()` | `.lessThan()` | `.lessThanOrEquals()` | `.isNull()` | `.isNotNull()` | `.isIn(Set/List/Builder)` | `.notInSet(Set/List/List<SObject>)` | `.notIn(Builder)` | `.contains()` | `.startsWith()` | `.endsWith()` | `.includes()` | `.excludes()`

**Ordering:** `.orderBy(field)` → `.ascending()` / `.descending()` / `.nullsFirst()` / `.nullsLast()` | `.orderBy(field, sortDescending)` | `.orderBy(field, sortDescending, nullsLast)`

**Aggregates:** `.groupBy(field)` | `.sum()` / `.avg()` / `.min()` / `.max()` / `.count(String)` / `.countDistinct()` | `.havingSumOf()` / `.havingCount()` etc. | Terminal: `.toAggregateList()` → `List<QRY_Builder.AggregateRow>` (NOT `AggregateResult`)

**Limit/Cache/Scope:** `.withLimit()` | `.withOffset()` | `.withCache(seconds)` | `.usingScope(QRY_Builder.Scope)` | `.forUpdate()` | `.allRows()`

**Security:** `.withUserMode()` / `.withSystemMode()` | `.stripInaccessible()` | `.withSharing()` / `.bypassSharing()` | `.withoutSecurity()`

> **Default access mode:** USER_MODE (CRUD, FLS, sharing enforced). Controlled by the `UserModeQueries_Enabled` feature flag (ships `IsEnabledByDefault__c = true`). Call `.withSystemMode()` per-query to bypass, or subclass `kern.SEL_Base` and override `systemModeRequired()` to return `true` to pin a selector's queries to SYSTEM_MODE regardless of the flag.

**Terminal:** `.toList()` | `.getFirst()` | `.toQueryLocator()` | `.toCursor()` | `.toAggregateList()` | `.getFirstAggregate()` | `.getPage(page, size)` → `QueryPage` | `.getRandomItem()` / `.getRandomItems(n)` | `.count()` | `.exists()` | `.asMap()` | `.asMapById(field)` | `.asMapByString(field)` | `.asGroupedMapById(field)` | `.asGroupedMapByString(field)` | `.asIdSet()` | `.asIdList()` | `.asValueSet(field)` | `.asStringSet(field)` | `.toSoql()`

### Semi-join Subqueries

**IMPORTANT:** Do NOT call terminal methods on subqueries:
```apex
// CORRECT
kern.QRY_Builder.Builder subquery = kern.QRY_Builder.selectFrom(Contact.SObjectType)
	.fields(new List<String>{ 'AccountId' })
	.condition(Contact.Email).isNotNull();

List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.condition(Account.Id).isIn(subquery)
	.toList();
```

### Compound Conditions

```apex
QRY_Condition.OrCondition statusGroup = new kern.QRY_Condition.OrCondition();
statusGroup.add(new kern.QRY_Condition.FieldCondition(Account.Status__c, kern.QRY_Condition.Operator.EQUALS, 'Active'));
statusGroup.add(new kern.QRY_Condition.FieldCondition(Account.Status__c, kern.QRY_Condition.Operator.EQUALS, 'Pending'));

List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.condition(Account.Industry).equals('Tech')
	.addCondition(statusGroup)
	.toList();
```

### Date Literals

```apex
.condition(Account.CreatedDate).equals(new kern.QRY_Condition.DateLiteral().lastNDays(30))
.condition(Case.CreatedDate).equals(new kern.QRY_Condition.DateLiteral().today())
```

Methods: `.today()` / `.yesterday()` / `.tomorrow()` | `.lastNDays(n)` / `.nextNDays(n)` | `.thisUnit(UnitOfTime)` | `.last(UnitOfTime)` / `.next(UnitOfTime)` | `.last(n, UnitOfTime)` / `.next(n, UnitOfTime)`

---

## DML Builder

```apex
kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact, Contact.AccountId, account)
	.doInsert(opportunity, Opportunity.AccountId, account)
	.execute();
```

**Operations:** `.doInsert(SObject/List)` | `.doInsert(child, relField, parent)` | `.doUpdate()` | `.doDelete()` | `.doUpsert()` | `.doUpsert(records, externalId)` | `.doUndelete()`

**Config:** `.allowPartial()` | `.withUserMode()` / `.withSystemMode()` | `.bypassSharing()` | `.suppressLogging()` | `.suppressExceptions()` | `.async()`

**Result:** `isSuccess()` | `getInsertedIds()` | `getErrors()` | `getSuccessCount()` | `getFailureCount()`

> **Default access mode:** USER_MODE (CRUD, FLS, sharing enforced). Controlled by the `UserModeDml_Enabled` feature flag (ships `IsEnabledByDefault__c = true`). Call `.withSystemMode()` on the transaction to bypass (e.g. writes to framework-owned audit objects).

Parent must appear earlier in chain. Framework auto-sets lookup IDs.

---

## Trigger Framework

### Trigger File

```apex
trigger TRG_Account on Account (before insert, before update, after insert, after update)
{
	new kern.TRG_Dispatcher().run();
}
```

Only declare events needed by configured `TriggerAction__mdt` handlers.

### Trigger Action Class

```apex
public with sharing class TRG_SetAccountDefaults extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
{
	/** @description Default description text. */
	private static final String DEFAULT_DESCRIPTION = 'New Account';

	/**
	 * @description Sets default Description on Account records when blank.
	 *
	 * @param newRecords The list of new Account records.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account account = (Account)record;

			if(String.isBlank(account.Description))
			{
				account.Description = DEFAULT_DESCRIPTION;
			}
		}
	}
}
```

**Rules:** Extract magic strings to named constants with `@description`. ApexDoc on every method including overrides.

### IF_Trigger Interfaces

**These are interface contracts — code will NOT compile if signatures differ. Copy exactly.**

| Interface | Method Signature |
|-----------|-----------------|
| `kern.IF_Trigger.BeforeInsert` | `void beforeInsert(List<SObject> newRecords)` |
| `kern.IF_Trigger.AfterInsert` | `void afterInsert(List<SObject> newRecords)` |
| `kern.IF_Trigger.BeforeUpdate` | `void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)` |
| `kern.IF_Trigger.AfterUpdate` | `void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)` |
| `kern.IF_Trigger.BeforeDelete` | `void beforeDelete(List<SObject> oldRecords)` |
| `kern.IF_Trigger.AfterDelete` | `void afterDelete(List<SObject> oldRecords)` |
| `kern.IF_Trigger.AfterUndelete` | `void afterUndelete(List<SObject> newRecords)` |

**Do NOT use `triggerNew` or omit the parameter.** Iterate the method parameter (e.g., `for(SObject record : newRecords)`).

**TRG_Base properties:** `triggerOldMap` (lazy `Map<Id, SObject>`) — use `triggerOldMap.get(newRecord.Id)` in update handlers.

### Custom Metadata Configuration (REQUIRED)

**A trigger handler will NOT execute without these records.** Always generate them alongside the handler class.

Two records needed per handler: a `TriggerSetting` (one per SObject) and a `TriggerAction` (one per handler + event).

**File naming:** `kern__TriggerSetting.{ObjectName}.md-meta.xml` and `kern__TriggerAction.{ActionName}_{Event}.md-meta.xml`

**TriggerSetting** — one per SObject (skip if already exists). File: `kern__TriggerSetting.{ObjectName}.md-meta.xml`

| Field | Value |
|-------|-------|
| `kern__SObjectType__c` | Object API name (e.g., `Account`) |
| `kern__BypassExecution__c` | `false` |

**TriggerAction** — one per handler + event. File: `kern__TriggerAction.{ActionName}_{Event}.md-meta.xml`

| Field | Value |
|-------|-------|
| `kern__ApexClassName__c` | Handler class name (no namespace prefix) |
| `kern__Event__c` | `Before Insert` / `Before Update` / `After Insert` / `After Update` / `Before Delete` / `After Delete` / `After Undelete` |
| `kern__Order__c` | Execution sequence (lower first; use 100, 200, etc.) |
| `kern__TriggerSetting__c` | DeveloperName of the TriggerSetting record |
| `kern__Description__c` | Human-readable description |

**Copy-paste XML reference** (TriggerAction — the most field-heavy record):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Set Account Defaults - Before Insert</label>
    <protected>false</protected>
    <values><field>kern__ApexClassName__c</field><value xsi:type="xsd:string">TRG_SetAccountDefaults</value></values>
    <values><field>kern__Event__c</field><value xsi:type="xsd:string">Before Insert</value></values>
    <values><field>kern__Order__c</field><value xsi:type="xsd:double">100.0</value></values>
    <values><field>kern__TriggerSetting__c</field><value xsi:type="xsd:string">Account</value></values>
    <values><field>kern__Description__c</field><value xsi:type="xsd:string">Sets default Description when blank on Account insert</value></values>
</CustomMetadata>
```

TriggerSetting and ApiSetting use the same XML structure — only the field names differ (see tables above and below).

### Flow as a Trigger Action

Subscribers can register an auto-launched Flow as a trigger action by setting `kern__FlowName__c` on a
`TriggerAction__mdt` row and leaving `kern__ApexClassName__c` blank. The framework dispatches via its built-in
flow runner and the flow inherits ordering, bypass, recursion control, performance monitoring, audit logging, and
feature-flag gating. No subscriber Apex is required — registration is metadata-only.

Configure via a `TriggerAction__mdt` record with these flow-specific fields:

| Field | Required | Default | Allowed values |
|---|---|---|---|
| `kern__FlowName__c` | Yes (XOR with `ApexClassName__c`) | — | Bare flow API name (no namespace prefix — the framework resolves cross-namespace) |
| `kern__ApexClassName__c` | Leave blank for flow rows | — | The `MutuallyExclusiveTarget` validation rule rejects rows with both `FlowName__c` and `ApexClassName__c` populated, and rows with neither populated. |
| `kern__FailureAction__c` | No | `LogAndContinue` | `LogAndContinue` (logs error, DML proceeds — for orchestration), `BlockDml` (calls `record.addError`, blocks save — for validation). Applies to Apex and flow actions alike. |

The registered flow declares variable `record` (input + output, type matching the trigger object) and — for update contexts — variable `recordPrior` (input only). Variable type must match `TriggerSetting__mdt.SObjectType__c` exactly. `LogSetting__c.EnableFlowActionLogging__c` (`Off` / `ErrorsOnly` (default) / `AlwaysOn`) controls audit volume.

**Mock harness for tests:** `kern.TST_InvokeFlowMock.forFlow(name).succeed().withOutputRecord(record).register()` short-circuits `Flow.Interview` at test time. Helpers: `.fail(message).register()`, `.assertInvoked(name, count)`, `.assertNotInvoked(name)`, `.getLastInputRecord(name)`, `.getLastInputPriorRecord(name)`, `.clear()`. Mocks test framework orchestration, not flow logic — pair with one deployed-flow integration test per flow.

### Bypass

Object: `kern.TRG_Base.bypass(SObjectType)` / `.isBypassed()` / `.clearBypass()` / `.clearAllBypasses()`
Action: `.bypassAction(name)` / `.isActionBypassed()` / `.clearActionBypass()` / `.clearAllActionBypasses()`
Declarative: `TriggerSetting__mdt.BypassExecution__c`
Audit: every `bypass*()` / `clear*Bypass()` call emits a `LogEntryEvent__e` with category `BypassEvent` — the runtime audit trail is always on. Set a free-text reason for the whole transaction via `kern.TRG_Base.setBypassReason(String)` and it attaches to every bypass emission that follows. (The underlying `BypassAction` enum and `resolveBypassAction(String)` resolver are framework-internal — `public`, not `global` — and drive the declarative `FLOW_BypassTrigger` invocable; subscribers do not call them directly.)

### Trigger Test Pattern

```apex
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_SetAccountDefaults_TEST
{
	/** @description The trigger setting developer name. */
	private static final String TRIGGER_SETTING = 'Account';
	/** @description The trigger action class name. */
	private static final String TRIGGER_ACTION = TRG_SetAccountDefaults.class.getName();

	@IsTest
	private static void shouldSetDefaultWhenDescriptionBlank()
	{
		kern.TST_Factory.newTriggerActionForContext(
			TRIGGER_ACTION,
			kern.TST_Factory.newTriggerSetting(TRIGGER_SETTING),
			TriggerOperation.BEFORE_INSERT
		);

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		Account result = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{ Account.Description })
			.condition(Account.Id).equals(record.Id)
			.getFirst();

		Assert.isNotNull(result.Description, 'Default should be set');
	}
}
```

---

## HTTP Client (UTIL_HttpClient)

Static factories only — **never `new UTIL_HttpClient()`**.

```apex
kern.UTIL_HttpClient.post('PaymentGateway', '/charges').body(chargeRequest).send();
kern.UTIL_HttpClient.get('CRM', '/accounts/{id}').pathParam('id', accountId).asMap();
kern.UTIL_HttpClient.post('EmailService', '/send').body(payload).timeout(30000)
	.withRetry(3).withCircuitBreaker().onFailure(kern.UTIL_HttpClient.FailureAction.LOG_FAILURE)
	.withTriggeringRecord(record.Id).send();
```

**Factories:** `.get()` / `.post()` / `.put()` / `.del()` / `.patch()` / `.useHandler(Type)`

**Builder:** `.body()` | `.header()` | `.headers()` | `.queryParam()` | `.pathParam()` | `.timeout()` | `.withRetry(n)` | `.withExponentialBackoff(n, base)` | `.retryOn(Set<Integer>)` | `.onFailure(FailureAction)` | `.withCircuitBreaker()` | `.withTriggeringRecord(Id)` | `.withCorrelationId()` | `.skipLogging()` | `.withParameter()` | `.withParameters()`

**Terminal:** `.send()` → `HttpResponse` | `.asString()` | `.asMap()` | `.deserialize(Type)` | `.invoke()`

---

## Outbound Web Services (API_Outbound)

```apex
public with sharing class API_SendNotification extends kern.API_Outbound
{
	@TestVisible
	private static final String PARAM_RECIPIENT = 'recipient';

	private static final String ERROR_NO_EMAIL = 'Record does not have an email address';

	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"messageId": "msg-12345"}';
	}

	public override Set<String> getRequiredInputs()
	{
		Set<String> requiredInputs = super.getRequiredInputs();
		requiredInputs.add(PARAM_RECIPIENT);
		return requiredInputs;
	}

	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		Foobar__c record = (Foobar__c)new SEL_Foobar().findById(queueItem.TriggeringRecordId__c);

		if(String.isBlank(record.Email__c))
		{
			errors.add(ERROR_NO_EMAIL);
		}

		return errors;
	}

	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Request extends kern.DTO_JsonBase
	{
		/** @description The recipient address. */
		private String recipient;

		public override void populate(Id recordId, kern.DTO_NameValues params)
		{
			super.populate(recordId, params);
			Foobar__c record = (Foobar__c)new SEL_Foobar().findById(recordId);
			this.recipient = record.Email__c;
		}
	}

	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Response extends kern.DTO_JsonBase
	{
		/** @description The message ID from the gateway. */
		private String messageId;
	}
}
```

**Rules:** `with sharing` | Default POST for outbound (override `getHttpMethod()` if different) | `super.configure()` first | `super.getRequiredInputs()` and add | `@TestVisible` param constants | `defaultMockBody` in configure | DTO props `private` + ApexDoc | `@JsonAccess` on all DTOs | Extend `kern.DTO_JsonBase` | `super.populate()` first

### API Custom Metadata Configuration (REQUIRED for both Inbound and Outbound)

**An API service will NOT execute without an `ApiSetting__mdt` record.** Always generate it alongside the API class.

**File naming:** `kern__ApiSetting.{ServiceName}.md-meta.xml`

**ApiSetting fields** (same XML wrapper as trigger metadata):

| Field | Outbound | Inbound |
|-------|----------|---------|
| `kern__ClassName__c` | Handler class name (no namespace) | Same |
| `kern__Direction__c` | `Outbound` | `Inbound` |
| `kern__EndpointPath__c` | API path (e.g., `/notifications`) | REST route pattern (e.g., `/v1/person/*`) |
| `kern__IsActive__c` | `true` | `true` |
| `kern__MockingEnabled__c` | `true` (enables test mocking) | Same |
| `kern__LogIssues__c` | `true` | `true` |
| `kern__Priority__c` | `100.0` | `100.0` |
| `kern__ApiCredential__c` | Named Credential DeveloperName | — |

DeveloperName (filename) should match class without `API_` prefix (e.g., `kern__ApiSetting.SendNotification`).

**Copy-paste XML reference** (ApiSetting — outbound).
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Send Notification</label>
    <protected>false</protected>
    <values><field>kern__ClassName__c</field><value xsi:type="xsd:string">API_SendNotification</value></values>
    <values><field>kern__Direction__c</field><value xsi:type="xsd:string">Outbound</value></values>
    <values><field>kern__EndpointPath__c</field><value xsi:type="xsd:string">/notifications</value></values>
    <values><field>kern__IsActive__c</field><value xsi:type="xsd:boolean">true</value></values>
    <values><field>kern__MockingEnabled__c</field><value xsi:type="xsd:boolean">true</value></values>
    <values><field>kern__LogIssues__c</field><value xsi:type="xsd:boolean">true</value></values>
    <values><field>kern__Priority__c</field><value xsi:type="xsd:double">100.0</value></values>
</CustomMetadata>
```

**Copy-paste XML reference** (ApiSetting — inbound).
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Get Person</label>
    <protected>false</protected>
    <values><field>kern__ClassName__c</field><value xsi:type="xsd:string">API_PersonRetrieve</value></values>
    <values><field>kern__Direction__c</field><value xsi:type="xsd:string">Inbound</value></values>
    <values><field>kern__EndpointPath__c</field><value xsi:type="xsd:string">/v1/person/*</value></values>
    <values><field>kern__IsActive__c</field><value xsi:type="xsd:boolean">true</value></values>
    <values><field>kern__LogIssues__c</field><value xsi:type="xsd:boolean">true</value></values>
    <values><field>kern__Priority__c</field><value xsi:type="xsd:double">100.0</value></values>
</CustomMetadata>
```

### Outbound Test Pattern

```apex
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class API_SendNotification_TEST
{
	private static final String SERVICE_NAME = API_SendNotification.class.getName();

	@IsTest
	private static void shouldCompleteSuccessfully()
	{
		Foobar__c record = (Foobar__c)kern.TST_Builder.of(Foobar__c.SObjectType)
			.withOverride(Foobar__c.Email__c, 'test@example.com').build();
		Map<String, String> parameters = new Map<String, String>
		{
			API_SendNotification.PARAM_RECIPIENT => 'recipient@example.com'
		};
		kern.API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, parameters);
	}
	// Abort: build record missing required data → assertCallAborted(SERVICE_NAME, record.Id, parameters)

	@IsTest
	private static void shouldFailWhenApiReturnsError()
	{
		kern.API_MockFactory.registerErrorMock(SERVICE_NAME);
		Foobar__c record = (Foobar__c)kern.TST_Builder.of(Foobar__c.SObjectType)
			.withOverride(Foobar__c.Email__c, 'test@example.com').build();
		kern__ApiCall__c apiCall = kern.TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
		kern.API_OutboundTestHelper.assertCallFailed(new List<kern__ApiCall__c>{ apiCall });
	}
}
```

### API_MockFactory

```apex
kern.API_MockFactory.forService(SERVICE_NAME).body('{"id":"123"}').statusCode(200).register();
kern.API_MockFactory.registerErrorMock(SERVICE_NAME);
kern.API_MockFactory.wasCalled(SERVICE_NAME);
```

---

## Inbound Web Services

**Two-class:** `REST_*` (routing, `global with sharing`) + `API_*` (logic, `public with sharing`, extends `kern.API_Inbound`).

### REST Routing Class

```apex
@RestResource(UrlMapping='/v1/contact-form/*')
global with sharing class REST_ContactForm
{
	@HttpPost
	global static void submitForm()
	{
		kern.API_Dispatcher.processInboundService(API_ContactFormSubmit.class.getName());
	}
}
```

### API Handler

`public with sharing class API_* extends kern.API_Inbound`. Same pattern as Outbound (`configure()`, `getValidationErrors()`, DTOs extend `kern.DTO_JsonBase`) plus:
- **`onSuccess()`** — DML via inherited `doInsert()`/`doUpdate()`/`doDelete()` (NOT `kern.DML_Builder`)
- **`updateResponseDTO()`** — runs after commit, populate response DTO from `result.isSuccess`
- Both Request and Response DTOs: `@JsonAccess(Serializable='always' Deserializable='always')`, `public` props
- No manual `JSON.serialize()` — framework serializes DTOs

### Inbound Test Pattern

```apex
kern.API_InboundTestHelper.assertCallSuccessful(SERVICE_NAME, request);
kern.API_InboundTestHelper.assertCallAborted(SERVICE_NAME, new DTO_Request(), 'error message');
```

**REST routing test** (separate class, suppress `PMD.ApexUnitTestClassShouldHaveAsserts`):
```apex
kern.API_InboundTestHelper.setupRestContext(request);
Test.startTest();
REST_ContactForm.submitForm();
Test.stopTest();
kern.SEL_ApiCall.assertServiceCompleted(API_ContactFormSubmit.class.getName());
```

---

## Flow Invocables (FLOW_*)

```apex
public with sharing class FLOW_CreateAccount
{
	@InvocableMethod(Category='Account Management' Label='Create Account' Description='Creates an Account.')
	public static List<DTO_Response> execute(List<DTO_Request> requests)
	{
		if(requests == null || requests.size() != 1)
		{
			throw new IllegalArgumentException('FLOW_CreateAccount expects a single request');
		}
		DTO_Request request = requests.iterator().next();

		Account account = new Account(Name = request.accountName);
		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction().doInsert(account).execute();

		DTO_Response response = new DTO_Response();
		response.accountId = account.Id;
		response.success = result.isSuccess();
		return new List<DTO_Response>{ response };
	}

	public class DTO_Request
	{
		@InvocableVariable(Label='Account Name' Description='The name for the new Account' Required=true)
		public String accountName;
	}

	public class DTO_Response
	{
		@InvocableVariable(Label='Account ID' Description='The ID of the created Account')
		public Id accountId;

		@InvocableVariable(Label='Success' Description='Whether the operation succeeded')
		public Boolean success;
	}
}
```

**Rules:** `public with sharing` on class + DTOs | guard `requests.size() == 1` with a platform-native `IllegalArgumentException` (the framework's `TRG_Base.validateSingleRequest` is `public` and not subscriber-callable) | `@InvocableVariable` with Label/Description/Required | `@InvocableMethod` with Category/Label/Description | `kern.DML_Builder` for DML | Method takes `List<DTO_Request>`, returns `void` or `List<DTO_Response>`

### Flow Test Pattern

```apex
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FLOW_CreateAccount_TEST
{
	@IsTest
	private static void shouldCreateAccount()
	{
		FLOW_CreateAccount.DTO_Request request = new FLOW_CreateAccount.DTO_Request();
		request.accountName = 'Test Account';

		Test.startTest();
		List<FLOW_CreateAccount.DTO_Response> responses =
			FLOW_CreateAccount.execute(new List<FLOW_CreateAccount.DTO_Request>{ request });
		Test.stopTest();

		Assert.isTrue(responses[0].success, 'Should succeed');
	}

	@IsTest
	private static void shouldThrowWhenNoRequests()
	{
		try
		{
			FLOW_CreateAccount.execute(new List<FLOW_CreateAccount.DTO_Request>());
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}
}
```

---

## Logging (LOG_Builder)

**Never `System.debug()`.** Use platform event logging:

```apex
kern.LOG_Builder.build().error(e).emitAt('MyClass.myMethod');
kern.LOG_Builder.build().info('Done').emitAt('MyClass.myMethod');
kern.LOG_Builder.build().warn('Threshold exceeded').emitAt('MyClass.myMethod');

// Long form
kern.LOG_Builder.build()
	.error('Payment failed')
	.at('PaymentService.charge')
	.forRecord(paymentId)
	.withContext('amount', payment.Amount__c)
	.emit();

// Scoped
kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
kern.LOG_Builder.build().info('Step 1').emitAt('MyClass.step');
scope.close();
```

**Levels:** `.error(Exception/String)` | `.warn(String)` | `.info(String)` | `.debug(String)` (also `List<String>`)
**Chain:** `.at(String)` | `.forRecord(Id)` | `.withContext(key, value)` | `.withSummary(String)`
**Terminal:** `.emitAt(String)` (shorthand) | `.emit()`

---

## Testing

### Structure

`@IsTest(SeeAllData=false IsParallel=true) private class MyClass_TEST` — Constants → @IsTest methods → helpers → inner classes.

### TST_Builder

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();                           // inserted
Account inMemory = (Account)kern.TST_Builder.of(Account.SObjectType).withoutInsertion().build();        // in-memory
Account mockId = (Account)kern.TST_Builder.of(Account.SObjectType).withoutInsertion(true).build();      // mock ID
Account custom = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Industry, 'Tech').build();                                                     // override
List<SObject> bulk = kern.TST_Builder.of(Account.SObjectType).withCount(5).buildList();                  // bulk
Account parent = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withChildren(Contact.SObjectType, 3).build();                                                       // children
```

### TST_Mock (DML-free)

```apex
Foobar__c mock = (Foobar__c)kern.TST_Mock.of(Foobar__c.SObjectType)
	.withOverride(Foobar__c.Name, 'Test').build();
// Selector queries now return mock data
```

**Negative-path:** `kern.TST_Mock.throwsException(SObjectType[, Exception/String])` makes any query against the
type throw -- use to exercise catch blocks without mocking at a different layer. Exception fires before record
path when both are registered; cleared by `kern.TST_Mock.clear()` / `kern.TST_Mock.clear(SObjectType)`.

```apex
kern.TST_Mock.throwsException(Account.SObjectType, new QueryException('Simulated failure'));
try
{
	new SEL_Accounts().findById(someAccountId);
	Assert.fail('Expected QueryException');
}
catch(QueryException error)
{
	Assert.areEqual('Simulated failure', error.getMessage(), 'Caught the simulated failure');
}
```

### TST_Factory

`kern.TST_Factory.newTriggerSetting(objectApiName)` | `.newTriggerAction(className, setting)` | `.newTriggerActionForContext(className, setting, TriggerOperation)` | `.newValidationRule(name, formula, msg)` | `.newValidationRuleGroup(setting)` | `.newOutboundApiCall(service, recordId[, params])` | `.newInboundApiCall(service)`

### Exception Testing

```apex
try
{
	methodThatShouldThrow();
	Assert.fail('Should throw IllegalArgumentException');
}
catch(Exception error)
{
	Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
}
```

**Never use `Boolean exceptionThrown`.**

### SEL_Foobar Field Constants

For test overrides: `FIELD_INTEGER` | `FIELD_TEXT` | `FIELD_EMAIL` | `FIELD_PHONE` | `FIELD_PICKLIST` | `FIELD_DATE` | `FIELD_DATETIME` | `FIELD_DECIMAL` | `FIELD_CURRENCY` | `FIELD_PERCENT` | `FIELD_CHECKBOX` | `FIELD_URL` | `FIELD_LOOKUP`

---

## Lightning Web Components

**Never `LightningElement`.** Always `ComponentBuilder`.

**⚠ CRITICAL: The import MUST use the package namespace, not `c/`:**
```javascript
WRONG: import { ComponentBuilder } from 'c/componentBuilder';     // WILL NOT RESOLVE
RIGHT: import { ComponentBuilder } from 'kern/componentBuilder';  // Correct namespace
```

```javascript
import { ComponentBuilder } from 'kern/componentBuilder';  // MUST be kern/, not c/

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	async handleSave()
	{
		try
		{
			await this.callControllerMethod('saveRecord', { account: this.account });
			this.showSuccessToast('Saved');
		}
		catch(error)
		{
			this.showErrorToast(error);
		}
	}
}
```

**Modules:** `notification` (showSuccess/Error/Warning/InfoToast) | `controller` (callControllerMethod, handleWireResponse) | `navigation` (redirectToRecordPage, generateRecordPageURL) | `flow-navigation` (dispatchFlowNext/Back/FinishEvent) | `lightning-message` (addMessageChannelSubscription, publishLightningMessage) | `all`

**Base (always):** `dispatchCustomEvent()` | `consoleLog()` | `consoleError()` | `isLoading`

**HTML:** Lightning base components only (not raw HTML). **Meta:** apiVersion 66.0, isExposed true.

### Jest Test Pattern

```javascript
jest.mock('kern/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		const { LightningElement } = require('lwc');
		return class extends LightningElement
		{
			showSuccessToast = jest.fn();
			showErrorToast = jest.fn();
			callControllerMethod = jest.fn().mockResolvedValue({});
		};
	})
}), { virtual: true });
```

---

## DTOs

Extend `kern.DTO_JsonBase` + `@JsonAccess(Serializable='always' Deserializable='always')`.

- **Standalone** (separate file, exposed to UI): `@AuraEnabled public` props
- **Nested** (inside API class): `private` props + ApexDoc
- Always `super.populate()` first in `populate()` overrides
- Use `SEL_*` in `populate()` — no inline SOQL

---

## Framework Utilities

`kern.UTIL_Exceptions` (IllegalState/Configuration/NotFoundException) | `kern.UTIL_Cache` | `kern.UTIL_CircuitBreaker` | `kern.UTIL_Retry` | `kern.UTIL_FeatureFlag.isEnabled(flagName)` | `kern.UTIL_TypeResolver` | `kern.UTIL_String` / `Date` / `Number` / `Set` / `List` / `Map` / `SObject` / `Email` / `Random` / `Security` | `kern.UTIL_SObjectDescribe` (request-cached describe wrapper — `getDescribe(sobjectType)`, `.getField(name)` namespace-aware by default, `.getFieldDescribe(name)` returns cached `DescribeFieldResult` with `isUpdateable`/`isCreateable`; static `getCachedFieldDescribe(SObjectField)` / `getCachedFieldName(SObjectField)` for token-keyed lookups; never use raw `Schema.getGlobalDescribe()` / `fields.getMap()` from package code — namespace handling is the trap that bites)

### Framework-shipped Feature Flags

Ten pre-built `FeatureFlag__mdt` records ship with the package. Query via `kern.UTIL_FeatureFlag.isEnabled('FlagDeveloperName')`; flip values by deploying an override record that sets `IsEnabledByDefault__c` (and, if strategies are attached, `ResultOnNoMatch__c`).

| Flag | Default | Purpose |
|------|:-------:|---------|
| `UserModeQueries_Enabled` | `true` | Drives the default `AccessLevel` on `kern.QRY_Builder` / `kern.SEL_Base`. When `true` queries run USER_MODE (CRUD+FLS+sharing enforced); when `false` they fall back to SYSTEM_MODE. Emergency kill switch only. |
| `UserModeDml_Enabled` | `true` | Same for `kern.DML_Builder` writes (insert/update/delete/upsert/undelete). |
| `MaskingFramework_Enabled` | `true` | Master switch for the data-masking framework (`MaskingRule__mdt` + `MaskingTarget__mdt`). |
| `AsyncChain` | `true` | Master kill switch for `kern.UTIL_AsyncChain`. When `false` new chain executions abort immediately. |
| `DisableAllAPIs` | `false` | Disables both inbound and outbound calls through the web-services framework. |
| `DisableAllInboundAPIs` | `false` | Disables inbound `kern.API_Inbound` routing only. |
| `DisableAllOutboundAPIs` | `false` | Disables outbound `kern.API_Outbound` calls only. |
| `MockAllAPIs` | `false` | Returns mock responses for every outbound call (tests + dry runs). |
| `MockAllInboundAPIs` | `false` | Returns mock responses for every inbound call. |
| `TestFeatureFlag` | `true` | Example / smoke-test flag. Safe to leave as-is. |

---

## Data Masking (declarative, no subscriber code)

Sensitive-data redaction is declarative — subscribers configure `MaskingRule__mdt` + `MaskingTarget__mdt` records, there is no subscriber-written Apex class. The framework runs masking as a before-insert / before-update pre-step on the trigger dispatcher for package-owned objects (`ApiCall__c`, `ApiIssue__c`, `AsyncChainExecution__c`, `LogEntryEvent__e` / `LogEntry__c`).

**Ship set:** 14 `MaskingRule__mdt` records (2 active by default — `MaskSecretKeys` JSON-key redaction, `MaskCreditCard` Luhn-validated card redaction; 12 inactive templates for SSN, email, phone, IBAN, SWIFT, Medicare, JWT, AWS keys, etc.). 8 `MaskingTarget__mdt` wildcard records wire the active rules onto all four logged objects.

**Mode picklist values on `MaskingRule__mdt.Mode__c`:** `Regex`, `JsonKey`, `ExactMatch`, `CreditCard`.
**Optional short-circuit fields:** `MinInputLength__c` (skip rule for shorter values) and `ApplicableFieldTypes__c` (semicolon-delimited `System.DisplayType` names — e.g., `STRING;TEXTAREA;ENCRYPTEDSTRING`).
**Failure handling:** `MaskingRule__mdt.FailureAction__c` = `LogAndContinue` / `WriteFailureMarker` / `BlockDml`.
**Kill switch:** `FeatureFlag.MaskingFramework_Enabled` (default `true`). Per-object opt-out: `TriggerSetting__mdt.ApplyMasking__c`.
**Performance logging (opt-in):** `LogSetting__c.EnableMaskerPerformanceLogging__c = true` with `LogSetting__c.MaskerPerformanceThresholdMs__c` (default 100 ms) emits `LogEntryEvent__e` via `UTIL_MaskerPerformanceTimer` for batches exceeding the threshold.

Subscribers extend the default ship set by deploying additional `MaskingRule__mdt` + `MaskingTarget__mdt` records; no Apex needed.

---

## Async Chain Orchestration

`kern.UTIL_AsyncChain` — sequences steps across Queueable transactions with shared state, error handling, and progress tracking.

```apex
kern.UTIL_AsyncChain.newChain('DataMigration')
	.then(new LoadDataStep())
	.then(new TransformDataStep(), true)
	.withInitialContext('batchSize', 200)
	.onError(new NotifyAdminStep())
	.execute();
```

**IF_Chain.Step interface:** Implement `kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)` or extend `kern.UTIL_AsyncChain.ChainStep` (abstract, adds `stepName` property).

```apex
public with sharing class LoadDataStep extends kern.UTIL_AsyncChain.ChainStep
{
	public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
	{
		List<Account> accounts = new SEL_Accounts().toList();
		context.put('accountCount', accounts.size());
		return kern.UTIL_AsyncChain.succeeded('Loaded ' + accounts.size() + ' accounts');
	}
}
```

**ChainBuilder:** `.then(step)`/`.then(step, continueOnError)`/`.withInitialContext(key, value)`/`.withMaxSteps(n)`/`.withAsyncOptions(opts)`/`.onError(step)`/`.onComplete(step)`/`.execute()`/`.execute(correlationId)`
**ChainContext:** `.put(key, value)`/`.get(key)`/`.getAs(key, Type)`/`.has(key)`/`.getChainExecutionId()`/`.getCorrelationId()`/`.getPreviousStepResult()`/`.getCurrentStepIndex()`
**StepResult:** `kern.UTIL_AsyncChain.succeeded()`/`.succeeded(msg)`/`.succeeded(msg, data)`/`.failed(msg)`/`.failed(exception)` — properties: `success`, `message`, `data`, `error`
**ApiStep:** Wraps `kern.API_Outbound` handler as a chain step:
```apex
new kern.UTIL_AsyncChain.ApiStep(API_SendEmail.class)
	.credential('Gateway')
	.withParameter(API_SendEmail.PARAM_RECIPIENT, 'test@example.com')
	.withParameterFrom('subject', 'emailSubject')
	.triggeringRecordFrom('recordId')
```
**Status:** `kern.UTIL_AsyncChain.getStatus(chainExecutionId)` → `Map<String, Object>`

---

## Schedulable Framework

Subscriber schedulable classes must be `global inherited sharing` extending `kern.SCHED_Base`.

```apex
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SCHED_PurgeOldRecords extends kern.SCHED_Base
{
	public override List<kern.DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<kern.DTO_ScheduledParameterDefinition>
		{
			kern.DTO_ScheduledParameterDefinition.of('objectName').required(),
			kern.DTO_ScheduledParameterDefinition.of('batchSize').asNumeric().withDefault('2000')
		};
	}

	public void execute(SchedulableContext context)
	{
		String objectName = getTextParameter('objectName');
		Integer batchSize = getNumericParameter('batchSize');
	}
}
```

**SCHED_Base accessors:** `getTextParameter(name)`/`getNumericParameter(name)`/`getBooleanParameter(name)`
**DTO_ScheduledParameterDefinition:** `.of(name)` → `.required()`/`.asNumeric()`/`.asBoolean()`/`.withDefault(value)`/`.withDescription(text)`

---

## Common Agent Mistakes (beyond Critical Rules table above)

| # | Wrong | Right |
|---|-------|-------|
| 1 | DTO missing `@JsonAccess` | `@JsonAccess(Serializable='always' Deserializable='always')` |
| 2 | Missing `super.configure()` | Always call `super.configure()` first |
| 3 | Missing `super.populate()` | Always call `super.populate()` first |
| 4 | Missing `super.getRequiredInputs()` | Call super and add to returned set |
| 5 | `.toList()` on semi-join subquery | Pass Builder directly to `.isIn()`/`.notIn()` |
| 6 | `new UTIL_HttpClient()` | `kern.UTIL_HttpClient.post('Cred', '/path')` |
| 7 | `Boolean exceptionThrown` | `Assert.fail` + `Assert.isInstanceOfType` |
| 8 | Namespace missing in subscriber | `kern.QRY_Builder`, `kern.SEL_Base`, `kern.TRG_Base` |
| 9 | `inherited sharing` in subscriber code | `with sharing` — except `SCHED_*` which uses `inherited sharing` |
| 10 | `global` on non-REST/SCHED classes | `public` everywhere — only `REST_*` and `SCHED_*` need `global` |
| 11 | Manual JSON.serialize in response | Use `updateResponseDTO()` — framework serializes |
| 12 | `[SELECT ...]` in test classes | Use `kern.QRY_Builder` or `SEL_*` even in tests |
| 13 | Missing `@SuppressWarnings` on tests | `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')` on test classes |
| 14 | `import from 'c/componentBuilder'` | `import from 'kern/componentBuilder'` — must use package namespace |

---

## KernDX vs fflib

| Concept | fflib | KernDX |
|---------|-------|--------|
| Selectors | `extends fflib_SObjectSelector` | `extends kern.SEL_Base` |
| Queries | `Database.query(newQueryFactory().toSOQL())` | `kern.QRY_Builder.selectFrom().toList()` |
| DML | `fflib_SObjectUnitOfWork` | `kern.DML_Builder.newTransaction().execute()` |
| Triggers | `fflib_SObjectDomain` | `extends kern.TRG_Base implements kern.IF_Trigger.*` |
| Logging | `System.debug()` | `kern.LOG_Builder.build().error(e).emitAt()` |
