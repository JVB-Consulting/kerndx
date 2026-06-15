# KernDX Conventions

Canonical, tool-agnostic code conventions for the KernDX framework. Applies to all contributors and any AI coding assistant working in this repository.

**KernDX** — Salesforce managed package framework. Namespace: `kern`. API: 67.0. Omit namespace in source code.

## Subscriber Context

Subscribers may have custom namespaces, additional class prefixes, and different org aliases.

**When generating code for subscribers:**

1. Ask for namespace if not specified
2. Apply stated prefix conventions (e.g., `ACME_SEL_*`)
3. Use `Namespace.ClassName` format (e.g., `ClientNS.QRY_Builder`)

## Critical Rules

- **100% test coverage** — Apex and LWC (enforced locally by scripts/evaluate-coverage.js; scanner rules catch coverage-theatre anti-patterns)
- **Declare sharing** — `with sharing`, `inherited sharing`, or `without sharing` explicitly. *Rationale: Apex's implicit-sharing default silently elevates privileges, which is
  invisible at the call site; an explicit modifier forces an authorial choice every reviewer can see.*
- **Least-privilege sharing** — Default `with sharing` for subscriber code (including subscriber selectors that extend `kern.SEL_Base`). Framework-internal selectors and utilities
  inside the `kern` namespace use `inherited sharing` to inherit the caller's sharing context. `without sharing` only when justified.
- **NO inline SOQL** — Use `SEL_*` or `QRY_Builder`. *Rationale: selectors centralize field-sets, FLS posture, and query shape, which makes them tunable, mockable, and auditable;
  ad-hoc `[SELECT ...]` queries are invisible to the masking layer and the bypass-audit channel.*
- **NO `System.debug`** — Use `LOG_Builder`
- **NO `LightningElement`** — Use `ComponentBuilder`
- **NO fflib layering pattern in subscriber code** — extend `kern.SEL_Base` (not `fflib_SObjectSelector`), `kern.TRG_Base` (not `fflib_SObjectDomain`), `kern.DML_Builder` (not
  `fflib_SObjectUnitOfWork`); never call `newQueryFactory()`. (The framework reuses the BSD-licensed `UTIL_SObjectDescribe` + `DML_Transaction` utilities derived from the same
  lineage — see `NOTICES.md` — but subscriber code goes through the kern surface.)
- **NO abbreviations** — `account` not `acc`, `message` not `msg`. *Rationale: full names are searchable across the codebase; abbreviated identifiers ("acc", "msg", "ctx") collide
  across modules and break grep/IDE jumps for AI tools.*
- **NO `// Given/When/Then/Cleanup` comments**
- **NO test cleanup code** — SF resets static state between tests
- **NO hardcoded field API names** — Use `SObjectField.getDescribe().getName()`
- **Name semantically-meaningful literals** — When a literal's meaning is not self-evident, or it repeats, lift it into a named `static final` constant whose name explains intent (a `CUSTOM_METADATA_SUFFIX` constant not a bare `'__mdt'`; reuse `SEL_MaskingRule.RULE_MASK_*` not re-typed rule names). Reuse an existing constant before adding one. Keep a new
  constant local to its owning class (`@TestVisible` so tests can read it) until a second consumer genuinely exists — don't pre-promote to a shared utility — and when it is shared,
  give it a domain-appropriate home (an SObject/metadata constant belongs with describe/selector utilities, never a generic string helper). *Judgment, not blanket:* a self-evident
  `0`/`1` or a genuinely one-off, locally-obvious string needs no constant — the test is whether a name would help a future reader grasp intent. *Rationale: a named constant turns
  an opaque literal into documentation at the point of use and gives grep/IDE a single definition to jump to and change.*
- **Methods are verbs** — name a method for the action it performs (`buildReadme`, `renderTargetXml`, `resolveRuleDeployName`), not the value it returns (`readme`, `targetXml`,
  `ruleDeployName`). `get*`/`find*`/`resolve*`/`build*`/`render*`/`parse*`/`map*`/`to*` all read as actions; a bare noun-phrase does not. *Rationale: a verb says what a call does
  at the call site without opening the body.*
- **Prefer safe-navigation + null-coalescing** — write `x?.member ?? fallback` over `x == null ? fallback : x.member`; `?.` short-circuits a member access on a possibly-null
  receiver, `??` supplies the fallback. Applies only when the else-branch is a member access on that same receiver — a branch that wraps the value (`new List{x}`) or calls a
  function of it (`f(x)`) stays a ternary. *Rationale: reads as "the member, or the fallback," and `?.` also guards a null member.*
- **NO code section separators** — No `//====` banners
- **NO inline DML in tests** — Use `TST_Builder.build()` or `DML_Builder`
- **Use `Assert.*`** not `System.Assert.*`
- **Prefer `Foobar__c` in tests** — Standard objects only when required
- **Minimize `global`** — Default to `public` (or `@TestVisible private` for test factories). Only upgrade to `global` when a concrete subscriber use case justifies it — `global`
  is a permanent API contract that subscribers can bind to and is effectively impossible to remove without a breaking release. Before marking any class, method, property, inner
  class, enum, or DTO field `global`, confirm it is genuinely needed by subscriber Apex, not just used internally within the `kern` namespace.

## Naming Conventions

| Prefix    | Use                           |
|-----------|-------------------------------|
| `UTIL_*`  | Utilities                     |
| `LOG_*`   | Logging                       |
| `QRY_*`   | Query infrastructure          |
| `SEL_*`   | Object selectors              |
| `DML_*`   | DML operations                |
| `MAP_*`   | In-memory record indexing     |
| `TRG_*`   | Trigger handlers & dispatcher |
| `IF_*`    | Interfaces                    |
| `API_*`   | Web services                  |
| `REST_*`  | REST endpoints                |
| `DTO_*`   | Data Transfer Objects         |
| `CTRL_*`  | LWC controllers               |
| `FLOW_*`  | Flow invocables               |
| `SVC_*`   | Service facades               |
| `SCHED_*` | Schedulables                  |
| `BATCH_*` | Batch jobs                    |
| `TST_*`   | Test utilities                |
| `*_TEST`  | Test classes                  |

## Formatting

**Apex:**

- **Tabs (size 3)** — *Rationale: tabs let each contributor render leading indentation at their preferred visible width without changing the bytes on disk; size 3 matches the
  framework's own source so subscriber and kern code visually align in diffs.*
- **Allman bracing** — *Rationale: opening brace on its own line keeps block boundaries scannable when lines wrap near the 180-char limit; matches the framework's own source so
  subscriber code reads consistently with `kern.*` internals in the same diff.*
- **180 char lines** — *Rationale: long-name-friendly (Salesforce identifiers — `kern__SubscriberPackageVersionId__c`, ApexDoc tag clusters — get unreadable when wrapped at 80)
  without going so wide that side-by-side diffs wrap.*
- **ApexDoc required** — *Rationale: ApexDoc is the only documentation surface the auto-generated `docs/reference/apex/` consumes. A missing ApexDoc block produces a missing API
  reference for subscribers; PR-gate enforces.*

**JS:** Tabs, single quotes, semicolons, Allman bracing, camelCase, JSDoc required on LWC component classes (`@description`, `@author`, `@date`) and methods with parameters (`@param {type} name`).

```apex
if(condition)
{
	// code
}

// Line wrap (>180 chars): opening paren on new line, args indented
TriggerAction__mdt action = TST_Factory.newTriggerActionForContext
(
	TEST_BEFORE_INSERT,
	TRIGGER_SETTING,
	TriggerOperation.BEFORE_INSERT
);
```

## ApexDoc

**Class:** `@description`, `@see`, `@author`, `@group`, `@date`, `@since`, `@example` (blank line between each tag)
**Method (REQUIRED):** `@description`, `@param` (each), `@return` (if non-void), `@throws`, `@since` (global only), `@example`
**Properties:** All require `@description`
**Bidirectional `@see`:** Main class ↔ test class
**`@since` (REQUIRED on all `global` members):** Classes, methods, properties, inner classes, enums. Format: `@since 1.0`. Not required on `public`/`private`/`protected`.
**`@date`:** `Month Year` or `Month Year, Month Year` (created, modified)
**`@example`:** Must use ```` ```apex ```` code fences with valid Apex

```apex
/**
 * @description Handler for Foobar defaults.
 *
 * @see TRG_SetFoobarDefaults_TEST
 *
 * @author developer@example.com
 *
 * @group Trigger Actions
 *
 * @date January 2026
 *
 * @since 1.0
 */
```

## Trigger Framework

```apex
trigger TRG_ObjectName on ObjectName__c (before insert, before update)
{
	new TRG_Dispatcher().run();
}
```

- Only declare events actually needed by configured `TriggerAction__mdt` handlers
- Handlers extend `TRG_Base`, implement `IF_Trigger.BeforeInsert`/`BeforeUpdate`/`AfterInsert`/`AfterUpdate`/`BeforeDelete`/`AfterDelete`/`AfterUndelete`

**Metadata:** `TriggerAction__mdt` — `TriggerSetting__c` (→`TriggerSetting__mdt`) + `Event__c` picklist. `TriggerSetting__mdt` uses `SObjectType__c` (→`EntityDefinition`). Record
naming: `ClassName_Event`.

**triggerOldMap:** Lazy-loaded `Map<Id, SObject>` on `TRG_Base` — `triggerOldMap.get(newRecord.Id)`.

**Bypass:** Object: `TRG_Base.bypass(SObjectType)/.isBypassed()/.clearBypass()/.clearAllBypasses()` (also String overloads) | Action:
`.bypassAction(name)/.isActionBypassed()/.clearActionBypass()/.clearAllActionBypasses()` | Flow: `FLOW_BypassTrigger` | Declarative: `TriggerSetting__mdt.BypassExecution__c`

**Test pattern:** `TST_Factory` metadata → `TST_Builder.build()` insert (fires trigger) → `SEL_*`/`QRY_Builder` for assertions. No selector? Use
`QRY_Builder.selectFrom(SObjectType).condition(field).equals(value).getFirst()`.

```apex
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_SetFoobarDefaults_TEST
{
	/** @description The trigger setting developer name. */
	private static final String TRIGGER_SETTING = SEL_Foobar.OBJECT_NAME;
	/** @description The trigger action class name. */
	private static final String TRIGGER_ACTION = TRG_SetFoobarDefaults.class.getName();

	@IsTest
	private static void shouldSetDefaultWhenFieldBlank()
	{
		TST_Factory.newTriggerActionForContext(TRIGGER_ACTION, TST_Factory.newTriggerSetting(TRIGGER_SETTING), TriggerOperation.BEFORE_INSERT);
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		Foobar__c result = (Foobar__c)new SEL_Foobar().findById(record.Id);
		Assert.isNotNull(result.Name, 'Default should be set');
	}
}
```

## Selector Framework

Extend `SEL_Base`, define default fields. Custom query methods use `query` property (NOT `QRY_Builder.selectFrom()`). `query` returns a fresh `QRY_Builder.Builder` pre-configured
with SObjectType and default fields.

**Namespace prefix:** subscriber code MUST reference framework classes with the `kern.` prefix (e.g. `extends kern.SEL_Base`). Examples in this guide use the prefix to match what
subscriber code looks like in production. Framework-internal code (everything under `force-app/` of this repository) omits the prefix because it is in the same namespace.

```apex
// Subscriber selectors default to `with sharing` — the safest default. Framework-internal selectors
// inside the kern namespace use `inherited sharing` to follow the caller's sharing context.
public with sharing class SEL_Cases extends kern.SEL_Base
{
	public SEL_Cases() { super(Case.SObjectType); }

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{ Case.Subject };
	}

	public List<Case> findOpen()
	{
		return query.condition(Case.IsClosed).equals(false).orderBy(Case.CreatedDate).descending().toList();
	}
}
```

**Inherited:** `query` (property) | `findById(Id)`/`findById(Set<Id>)` | `findByIdOrThrow(Id/Set<Id>)` | `findByField(field, value)`/`findByField(field, Set/List)` |
`findFirstByField(field, value)` | `findByFields(Map)`/`findFirstByFields(Map)` | `toList()`/`getFirst()`/`getRandomItem()` | `count()`/`exists()` | `toQueryLocator()`

## QRY_Builder

SEL_\* for reusable queries; QRY_Builder directly for one-off. Prefer `List<SObjectField>` for compile-time safety (`List<String>` only for relationship traversals).

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{Account.Name, Account.Industry})
	.condition(Account.Industry).equals('Tech')
	.orderBy(Account.Name).ascending().withLimit(100).toList();
```

**Builder:** `.fields()`/`.addFields()`/`.addField()`/`.relatedField(String)`/`.relatedFields(List<String>)`/`.selectAllFields()`/`.fieldSet()`/`.subselect(Builder, String)` |
`.condition()` → `.equals`/`.notEquals`/`.greaterThan`/`.greaterThanOrEquals`/`.lessThan`/`.lessThanOrEquals`/`.isIn`/`.notInSet`/`.isNull`/`.isNotNull`/`.contains`/`.startsWith`/`.endsWith`/`.includes`/`.excludes()` | `.andCondition()`/`.orCondition()`/`.addCondition()` | `.orderBy()` → `.ascending`/`.descending`/`.nullsFirst`/`.nullsLast()` |
`.orderBy(field, sortDescending)`/`.orderBy(field, sortDescending, nullsLast)` | `.groupBy()`/`.sum()`/`.avg()`/`.min()`/`.max()`/`.count()`/`.countDistinct()` | `.havingSumOf()`/`.havingAvgOf()`/`.havingMinOf()`/`.havingMaxOf()`/`.havingCountOf()`/`.havingCount()` | `.withLimit()`/`.withOffset()`/`.withCache()`/`.usingScope(Scope)`/`.forUpdate()`/`.allRows()`/`.withUserMode()`/`.stripInaccessible()`/`.withSharing()`/`.bypassSharing()` | `.withDataCategory(groupName)` → `.at()`/`.above()`/`.below()`/`.aboveOrBelow()`

**Terminal:** `.toList()`/`.getFirst()`/`.toQueryLocator()`/`.toCursor()`/`.toAggregateList()` → `List<QRY_Builder.AggregateRow>` | `.getFirstAggregate()`/`.getPage(page, size)` →
`QueryPage`/`.getRandomItem()`/`.getRandomItems(n)`/`.count()`/`.exists()`/`.asMap()`/`.asMapById(field)`/`.asMapByString(field)`/`.asGroupedMapById(field)`/`.asGroupedMapByString(field)`/`.asIdSet()`/`.asIdList()`/`.asValueSet(field)`/`.asStringSet(field)`/`.toSoql()`

**Aggregates:** `.groupBy()` (call multiple times for multi-field) + functions + `.toAggregateList()` → `List<QRY_Builder.AggregateRow>` (NOT `AggregateResult`) | `.rollup()` |
`.cube()` | `.grouping(field)` for ROLLUP/CUBE subtotal detection
**Subqueries:** `.subselect(childBuilder, 'RelationshipName')`
**Semi-joins:** `.condition(field).isIn(subqueryBuilder)`/`.notIn(subqueryBuilder)` — NO terminal methods on subquery. `.notInSet(Set/List)` for value-based NOT IN;
`.notIn(Builder)` only for anti-join subqueries.
**Pagination:** `.getPage(page, size)` → `QueryPage` (`.records`/`.totalRecords`/`.hasMorePages`/`.deletedRecords`/`.cursor`)

**Security** (default SYSTEM_MODE + inherited sharing): `.withUserMode()` (USER_MODE, enforces CRUD/FLS/sharing) | `.stripInaccessible()` (post-query) | `.withSharing()`/`.bypassSharing()` (SYSTEM_MODE only, ignored with `withUserMode()`) | `.withoutSecurity()` (reset)

**Data Category:** `.withDataCategory(groupName)` → `DataCategoryBuilder` with `.at()`/`.above()`/`.below()`/`.aboveOrBelow()` — each with `(String)` and `(List<String>)`
overloads. Mutually exclusive with `WITH SECURITY_ENFORCED` — use `.withUserMode()` for security enforcement with data category queries. One filter per group.

## DML_Builder

```apex
DML_Builder.TransactionResult result = DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact, Contact.AccountId, account)
	.doUpdate(existingRecord)
	.allowPartial().execute();
```

**Methods:** `.doInsert()`/`.doUpdate()`/`.doDelete()`/`.doUpsert()`/`.doUndelete()`/`.allowPartial()`/`.bypassSharing()`/`.suppressLogging()`/`.suppressExceptions()`/`.async()`/`.execute()`
**TransactionResult:** `isSuccess()`/`getInsertedIds()`/`getErrors()`/`getSuccessCount()`/`getFailureCount()`
**Parent-child:** `.doInsert(child, relationshipField, parent)` auto-sets lookup. Parent must appear earlier.

## Flow Invocables

`global inherited sharing class FLOW_*` with `@InvocableMethod` + nested `DTO_Request`/`DTO_Response`.

```apex
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_CreateAccount
{
	@InvocableMethod(Category='Account Management' Label='Create Account' Description='Creates an Account.')
	global static List<DTO_Response> execute(List<DTO_Request> requests)
	{
		TRG_Base.validateSingleRequest(requests.size(), FLOW_CreateAccount.class.getName());
		DTO_Request request = requests.iterator().next();
		Account account = new Account(Name = request.accountName);
		DML_Builder.TransactionResult result = DML_Builder.newTransaction().doInsert(account).execute();
		DTO_Response response = new DTO_Response();
		response.accountId = account.Id;
		response.success = result.isSuccess();
		return new List<DTO_Response> {response};
	}

	global inherited sharing class DTO_Request
	{
		@InvocableVariable(Label='Account Name' Description='The name for the new Account' Required=true)
		global String accountName;
	}

	global inherited sharing class DTO_Response
	{
		@InvocableVariable(Label='Account ID' Description='The ID of the created Account')
		global Id accountId;
		@InvocableVariable(Label='Success' Description='Whether the operation succeeded')
		global Boolean success;
	}
}
```

**Rules:** `global inherited sharing` on class + DTOs | `@SuppressWarnings('PMD.AvoidGlobalModifier')` | `TRG_Base.validateSingleRequest()` | `@InvocableVariable` with
Label/Description/Required | `@InvocableMethod` with Category/Label/Description (+ `Callout=true` for HTTP) | `DML_Builder` for DML | Method takes `List<DTO_Request>`, returns
`void` or `List<DTO_Response>` | **Test:** Also test `shouldThrowWhenNoRequests()` with `Assert.fail`/`Assert.isInstanceOfType`

## LOG_Builder

Async logging via `LogEntryEvent__e`. **Never `System.debug()`.**

```apex
LOG_Builder.build().error(e).emitAt('MyClass.myMethod');
LOG_Builder.build().info('Done').emitAt('MyClass.myMethod');
LOG_Builder.build().error('Failed').at('Svc.charge').forRecord(id).withContext('amt', amount).emit();
LOG_Builder.LogScope scope = LOG_Builder.scope(); /* ... */ scope.close();
```

**Levels:** `.error(Exception/String)`/`.warn(String)`/`.info(String)`/`.debug(String)` (also `List<String>`)
**Chain:** `.at(String)`/`.forRecord(Id)`/`.withContext(String, Object)`/`.withSummary(String)`
**Terminal:** `.emitAt(String)` (shorthand for `.at().emit()`) / `.emit()`

## UTIL_HttpClient

Fluent HTTP client. Static factories: `get()`/`post()`/`put()`/`del()`/`patch()`. First arg: Named Credential or `ApiCredential__mdt` DeveloperName. Second: URL path.

```apex
UTIL_HttpClient.post('PaymentGateway', '/charges').body(chargeRequest).send();
UTIL_HttpClient.get('CRM', '/accounts/{id}').pathParam('id', accountId).asMap();
UTIL_HttpClient.post('EmailService', '/send').body(payload).timeout(30000)
	.withRetry(3).withCircuitBreaker().onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
	.withTriggeringRecord(record.Id).send();
```

**Terminal:** `.send()` → `HttpResponse` | `.asString()`/`.asMap()`/`.deserialize(Type)` | `.invoke()` (delegation)
**Builder:** `.body()`/`.header()`/`.headers()`/`.queryParam()`/`.pathParam()`/`.timeout()`/`.withRetry(n)`/`.withRetry(n, backoff)`/`.withExponentialBackoff(n, base)` (pick ONE)/`.retryOn(Set<Integer>)`/`.onFailure(FailureAction)`/`.withCircuitBreaker()`/`.withTriggeringRecord(Id)`/`.withCorrelationId()`/`.skipLogging()`/`.replaceRequestToken()`/`.replaceResponseToken()`/`.withParameter()`/`.withParameters()`
**Delegation:** `UTIL_HttpClient.useHandler(API_SendEmail.class).credential('Cred').withParameter(k, v).withTriggeringRecord(id).invoke()`

## Inbound Web Services

Two-class: `REST_*` (routing, `global inherited sharing`) + `API_*` (implementation, `public with sharing`, extends `API_Inbound`).

```apex
@RestResource(UrlMapping='/v1/invoices/*')
global inherited sharing class REST_Invoices
{
	@HttpPatch
	global static void updateInvoice()
	{
		API_Dispatcher.processInboundService(API_UpdateInvoice.class.getName());
	}
}
```

`public with sharing class API_* extends API_Inbound`. Same pattern as Outbound (`configure()`, `getValidationErrors()`) plus:

- **`onSuccess()`** — DML via inherited `doInsert()`/`doUpdate()`/`doDelete()` (NOT `DML_Builder`)
- **`updateResponseDTO()`** — runs after commit, populate response DTO from `result.isSuccess`
- Request DTOs: `@JsonAccess(Deserializable='always')`, `public` props
- Response DTOs: `@JsonAccess(Serializable='always')`, `public` props

## DTOs

Extend `DTO_JsonBase` + `@JsonAccess(Serializable='always' Deserializable='always')`. Standalone: `@AuraEnabled public`. Nested (in API class): `private` + ApexDoc. 1-3 → nest;
4+ → separate `DTO_*.cls` file. `populate(Id, DTO_NameValues)` uses `SEL_*`.

## Outbound Web Services

`public with sharing class API_* extends API_Outbound`. Overrides: `configure()` (set DTOs + `defaultMockBody`), `getRequiredInputs()`, `getValidationErrors()`.

```apex
public with sharing class API_SendEmail extends API_Outbound
{
	@TestVisible private static final String PARAM_RECIPIENT = 'recipient';
	@TestVisible private static final String PARAM_SUBJECT = 'subject';
	private static final String ERROR_NO_EMAIL = 'Triggering record does not have an email address';

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
		requiredInputs.add(PARAM_SUBJECT);
		return requiredInputs;
	}

	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		Foobar__c record = (Foobar__c)new SEL_Foobar().findById(queueItem.TriggeringRecordId__c);
		if(String.isBlank(record.Email__c)) { errors.add(ERROR_NO_EMAIL); }
		return errors;
	}

	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Request extends DTO_JsonBase
	{
		/** @description The email recipient address. */
		private String recipient;
		/** @description The email subject line. */
		private String subject;

		public override void populate(Id recordId, DTO_NameValues params)
		{
			super.populate(recordId, params);
			Foobar__c record = (Foobar__c)new SEL_Foobar().findById(recordId);
			this.recipient = record.Email__c;
			this.subject = params.get(PARAM_SUBJECT);
		}
	}

	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Response extends DTO_JsonBase
	{
		/** @description The message ID from the email gateway. */
		private String messageId;
	}
}
```

**Rules:** Default POST (only override if different) | `@TestVisible` param constants | `defaultMockBody` in `configure()` | DTO props `private` + ApexDoc | Don't override
`setHeaders()`/retry unless required
**Mock:** `API_MockFactory.registerErrorMock(serviceName)` | `API_MockFactory.forService(serviceName).body(json).statusCode(n).register()`

## Testing

**Structure:** Constants → `@IsTest` methods → helpers (no assertions) → inner classes
**Header:** `@IsTest(SeeAllData=false IsParallel=true) private class MyClass_TEST`
**Rules:** Test class-specific behaviour only | `ClassName.class.getName()` not hardcoded strings | ApexDoc on all constants | Reference API param constants | Test abort/error
conditions

**Exception testing:** `Assert.fail` + `Assert.isInstanceOfType` — never `Boolean exceptionThrown`:

```apex
try { methodThatShouldThrow(); Assert.fail('Should throw IllegalArgumentException'); }
catch(Exception error) { Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type'); }
```

### TST_Builder

```apex
TST_Builder.of(SObjectType).build();                                    // inserted
TST_Builder.of(SObjectType).withoutInsertion().build();                 // in-memory
TST_Builder.of(SObjectType).withOverride(field, value).build();         // overrides
TST_Builder.of(SObjectType).withCount(5).buildList();                   // bulk
```

**Methods:** `.of()`/`.withOverrides(Map)`/`.withOverride(field, value)`/`.withCycle(field, values)`/`.withCount(n)`/`.withChildren(SObjectType, Integer)`/`.withChildren(SObjectType, Integer, Map)`/`.withChildren(Builder)`/`.withChildren(String, Builder)`/`.withRecordType(String)`/`.withoutInsertion()`/`.withoutInsertion(true)` (mock
IDs)/`.build()`/`.buildList()`

### TST_Factory

`newTriggerSetting(objectApiName)` | `newTriggerAction(className, setting)` | `newTriggerActionForContext(className, setting, TriggerOperation)` |
`newValidationRule(name, formula, msg)` | `newValidationRuleGroup(setting)` | `newOutboundApiCall(service, recordId[, params])` | `newInboundApiCall(service)`

### TST_Mock

DML-free query interception. `TST_Mock.of(SObjectType).withOverride(field, val).build()` auto-registers for SEL queries. Manual: `TST_Mock.register(type, record)`/`.get(type)`/`.clear()`/`.clear(type)`. **Negative-path:** `TST_Mock.throwsException(type[, Exception/String])` makes any query against `type` throw — use to exercise catch blocks. Exception
fires before record path when both registered; cleared by `.clear()`/`.clear(type)`.

### Test Assertions

```apex
// Outbound (preferred convenience overloads)
API_OutboundTestHelper.assertCallSuccessful(serviceName, recordId, parameters)
API_OutboundTestHelper.assertCallSuccessful(serviceName, recordId)
API_OutboundTestHelper.assertCallAborted(serviceName, recordId, parameters)
API_OutboundTestHelper.assertCallAborted(serviceName, recordId)
// Outbound (queue item overloads)
API_OutboundTestHelper.assertCallSuccessful/assertCallFailed/assertCallAborted(queueItems)

// Inbound
API_InboundTestHelper.setupRestContext([dtoRequest[, headers]])
API_InboundTestHelper.assertCallSuccessful(serviceName[, dtoRequest[, headers]])
API_InboundTestHelper.assertCallFailed(serviceName[, dtoRequest])
API_InboundTestHelper.assertCallAborted(serviceName[, exceptionMessage])
API_InboundTestHelper.assertCallAborted(serviceName, dtoRequest, exceptionMessage)

// Query-based
SEL_ApiCall.assertServiceCompleted/assertServiceFailed/assertServiceAborted(serviceName[, errorPhrase])
```

### Outbound Test Pattern

```apex
private static final String SERVICE_NAME = API_SendEmail.class.getName();
private static final String TEST_SUBJECT = 'Test Subject';

@IsTest
private static void shouldCompleteSuccessfully()
{
	Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
		.withOverride(Foobar__c.Email__c, 'test@example.com').build();
	Map<String, String> parameters = new Map<String, String>{ API_SendEmail.PARAM_SUBJECT => TEST_SUBJECT };
	API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, parameters);
}
// Abort: create record missing required data → assertCallAborted(SERVICE_NAME, record.Id, parameters)
```

### Inbound Test Pattern

Success: `setupRestContext(request)` → call REST method → `SEL_ApiCall.assertServiceCompleted(SERVICE_NAME)`
Abort: `API_InboundTestHelper.assertCallAborted(SERVICE_NAME, new DTO_Request(), 'error message')`

### SEL_Foobar Field Constants

`FIELD_INTEGER`/`FIELD_TEXT`/`FIELD_EMAIL`/`FIELD_PHONE`/`FIELD_PICKLIST`/`FIELD_DATE`/`FIELD_DATETIME`/`FIELD_DECIMAL`/`FIELD_CURRENCY`/`FIELD_PERCENT`/`FIELD_CHECKBOX`/`FIELD_URL`/`FIELD_LOOKUP`

## LWC

**ComponentBuilder (required) — never `LightningElement`:**

```javascript
import {ComponentBuilder} from 'kern/componentBuilder'; // MUST be kern/, not c/ — the package namespace owns the module

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	async handleSave()
	{
		await this.callControllerMethod('saveAccount', {account: this.account});
		this.showSuccessToast('Saved');
	}
}
```

**Modules:** `notification` (showSuccess/Error/Warning/InfoToast, customNotification — `showErrorToast` auto-normalises Apex error objects via `c/utilitySystem.reduceErrors` so
`.catch(error => this.showErrorToast(error))` produces a sensible toast; string args pass through unchanged) | `controller` (callControllerMethod, handleWireResponse) |
`navigation` (redirectToRecordPage, generateRecordPageURL) | `lightning-message` (addMessageChannelSubscription, publishLightningMessage, clearSubscriptions) | `flow-navigation` (dispatchFlowNext/Back/FinishEvent) | `all`
**Base (always):** `dispatchCustomEvent()`/`consoleLog()`/`consoleError()`/`isLoading`
**HTML:** Lightning base components only — not raw HTML. **Meta:** apiVersion 67.0, isExposed true.

**Jest — DOM-based:**

```javascript
jest.mock('c/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		const {LightningElement} = require('lwc');
		return class extends LightningElement
		{
			showSuccessToast = jest.fn();
			showErrorToast = jest.fn();
			showInfoToast = jest.fn();
			showWarningToast = jest.fn();
			callControllerMethod = jest.fn().mockResolvedValue({});
		};
	})
}), {virtual: true});
// createElement → Object.assign(element, props) → document.body.appendChild → await Promise.resolve()
```

**Jest — prototype-based (headless quick actions):**

```javascript
const prototype = require('c/myAction').default.prototype;
const execute = require('@salesforce/apex/CTRL_MyAction.execute').default;
const createMockContext = (overrides = {}) =>
	({recordId: 'a00000000000001', showSuccessToast: jest.fn(), showErrorToast: jest.fn(), dispatchEvent: jest.fn(), ...overrides});
// await prototype.invoke.call(context);
```

**Jest mocks:** `lightning/navigation`, `lightning/messageService`, `lightning/empApi`, `lightning/flowSupport`

## Anti-Patterns

1. **`QRY_Builder.selectFrom()` inside selector** — use `query` property
2. **`new UTIL_HttpClient()`** — use static factories
3. **`.toList()` on semi-join subquery** — pass builder directly to `.isIn()`/`.notIn()`
4. **Complex DTO as `@AuraEnabled` parameter** — LWC Proxy wrappers break Aura deserialization. Use `String requestJson` + `JSON.deserialize()` (see `CTRL_ScheduledJob.saveRecord`)

## Framework Utilities

`UTIL_Exceptions` (IllegalState/Configuration/NotFoundException) | `UTIL_Cache` (durable `auto()` Session→Org, opt-in `inTransaction()` per-request memoization, opt-in
`autoWithTransactionFallback()` Session→Org→Transaction graceful degradation reporting `cacheTypeUsed = Scope.IN_TRANSACTION` on the fallback path — `inTransaction` /
`IN_TRANSACTION` because `transaction` is on Apex's reserved-words list) | `UTIL_CircuitBreaker` | `UTIL_Retry` (linear/exponential) | `UTIL_FeatureFlag.isEnabled(flagName)` (Apex) / `c/featureFlag.isFlagEnabled(flagName)` (LWC bridge via `CTRL_FeatureFlag`) | `UTIL_BypassAudit.emit(surface, action, target, extras)` / `setBypassReason(reason)` (framework-wide bypass audit) | `UTIL_TypeResolver` (subscriber-first) | `UTIL_String`/`Date`/`Number`/`Set`/`List`/`Map`/`SObject`/`Email`/`Random`/`Security` |
`UTIL_SObjectDescribe` (request-cached describe wrapper — `getDescribe(sobjectType)`, `.getField(name)` namespace-aware default, `.getFieldDescribe(name)` returns cached
`DescribeFieldResult` with `isUpdateable`/`isCreateable`; static `getCachedFieldDescribe(SObjectField)` / `getCachedFieldName(SObjectField)` for token-keyed lookups)

## Async Chain Orchestration

`UTIL_AsyncChain` — sequences steps across Queueable transactions with shared state, error handling, and progress tracking.

```apex
UTIL_AsyncChain.newChain('DataMigration')
	.then(new LoadDataStep())
	.then(new TransformDataStep(), true)
	.withInitialContext('batchSize', 200)
	.onError(new NotifyAdminStep())
	.onComplete(new CleanupStep())
	.execute();
```

**IF_Chain.Step:** `StepResult work(ChainContext context)` — implement this interface or extend `ChainStep` (abstract, adds `stepName` property).
**ChainBuilder:** `.then(step)`/`.then(step, continueOnError)`/`.withInitialContext(key, value)`/`.withMaxSteps(n)`/`.withAsyncOptions(opts)`/`.onError(step)`/`.onComplete(step)`/`.execute()`/`.execute(correlationId)`
**ChainContext:** `.put(key, value)`/`.get(key)`/`.getAs(key, Type)`/`.has(key)`/`.getChainExecutionId()`/`.getCorrelationId()`/`.getPreviousStepResult()`/`.getCurrentStepIndex()`
**StepResult:** `UTIL_AsyncChain.succeeded()`/`.succeeded(msg)`/`.succeeded(msg, data)`/`.failed(msg)`/`.failed(exception)` — properties: `success`, `message`, `data`, `error`
**ApiStep:** Wraps `API_Outbound` handler as a chain step.
`new UTIL_AsyncChain.ApiStep(API_SendEmail.class).credential('Gateway').withParameter(k, v).withParameterFrom(param, contextKey).triggeringRecord(id).triggeringRecordFrom(contextKey)`
**Status:** `UTIL_AsyncChain.getStatus(chainExecutionId)` → `Map<String, Object>` (executionId, chainName, status, totalSteps, completedSteps, errorMessage)

## Schedulable Framework

`global inherited sharing class SCHED_* extends SCHED_Base` implementing `IF_Schedulable`. `IF_Schedulable` extends `Schedulable` with `getParameterDefinitions()` and
`setParameterValues(DTO_NameValues)`.

```apex
global class SCHED_PurgeOldRecords extends SCHED_Base
{
	public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<DTO_ScheduledParameterDefinition>
		{
			DTO_ScheduledParameterDefinition.of('objectName').required(),
			DTO_ScheduledParameterDefinition.of('batchSize').asNumeric().withDefault('2000')
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

## Type Resolution

Chain: `PackageClassResolver` → `ClassTypeResolver__mdt` resolvers (by `Order__c`). Subscriber-first: no namespace → package namespace.

```apex
Type handlerType = UTIL_System.getTypeForClassName('TRG_SetFoobarDefaults');
Type validatedType = UTIL_System.getTypeForClassName('TRG_SetFoobarDefaults', IF_Trigger.BeforeInsert.class);
```

Custom resolver: extend `UTIL_TypeResolver.BaseClassResolver`, register via `ClassTypeResolver__mdt` (`ClassName__c` + `Order__c`).

## PMD Rules

**Blocks CI:** No assertions, trigger logic in trigger, hardcoded IDs, SOQL injection, empty catch, missing ApexDoc
**Limits:** Cyclomatic complexity ≤15/method, ≤50/class; params ≤5; nested ifs ≤4
**Suppress:** `@SuppressWarnings('PMD.RuleName')` — justified only

## Documentation

**Markdown:** TOC required (>3 sections), 180 char lines, link class refs to `reference/apex/ClassName.md`
**Release notes:** `release-notes/` folder, only `global` artifacts, describe shipped implementation
**Code examples:** Use framework patterns, add namespace prefix for subscriber org examples
