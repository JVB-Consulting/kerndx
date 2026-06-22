---
layout: page
pageClass: kl-landing-page
---

<KernLanding>

<template #examples>

<CodeCompare title="Paginate past 2,000 rows — and know when the data shifts under you" link="/selectors-guide#pagination" linkText="Selectors Guide → Pagination" wrote="5 lines" caps="7">

<template #before>

```apex
// Page 82 of 25-row pages = OFFSET 2025 → runtime governor blow-up
Integer offset = (pageNumber - 1) * pageSize; // 2025 — over the 2,000 cap
List<Account> rows = [
	SELECT Id, Name FROM Account WHERE Type = 'Customer'
	ORDER BY Name ASC LIMIT :pageSize OFFSET :offset // ☠ NUMBER_OUTSIDE_VALID_RANGE
];
Integer total = [SELECT COUNT() FROM Account WHERE Type = 'Customer']; // 2nd query
// FLS? You enforce it by hand. Rows deleted under you? You'll never know.
```

</template>

<template #after>

```apex
kern.QRY_Builder.QueryPage page = kern.QRY_Builder
	.selectFrom(Account.SObjectType)
	.condition(Account.Type).equals('Customer')
	.orderBy(Account.Name).ascending()
	.getPage(82, 25); // page 82 — no OFFSET wall, USER_MODE FLS on

page.records; // this page
page.totalRecords; // count came back with the page — no 2nd query
page.totalPages; // computed for you
page.hasMorePages; // wire straight to a "Next" button
page.deletedRecords; // rows the cursor saw deleted during this fetch
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Cursor pagination">Reliability</p>
<a class="kl-ledger-chip" href="/selectors-guide#pagination">Cursor paging clears the 2,000-row OFFSET ceiling that plain LIMIT/OFFSET hits — getPage() picks and wires the cursor for you</a>
<a class="kl-ledger-chip" href="/selectors-guide#pagination">page.totalRecords folded into the same cursor call (getNumRecords()) — no second COUNT() query</a>
<a class="kl-ledger-chip" href="/selectors-guide#pagination">page.deletedRecords comes from the cursor's getNumDeletedRecords() — rows it saw deleted during this fetch, not silently dropped from the count</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Governance</p>
<a class="kl-ledger-chip" href="/selectors-guide#user-mode-security">Ran the cursor in USER_MODE — the running user's CRUD, FLS, and sharing — no hand-rolled checks</a>
<a class="kl-ledger-chip" href="/selectors-guide#sharing-enforcement">Runs with inherited sharing — the cursor honours the caller's sharing context, not a silent without-sharing read</a>
<a class="kl-ledger-chip" href="/selectors-guide#user-mode-security">If you ever opt out with withSystemMode(), that bypass is logged to an audit trail — auditable by default</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Observability</p>
<a class="kl-ledger-chip" href="/selectors-guide#query-performance-logging">Slow queries self-report: any query at 1000ms or slower (default) logs a performance entry — on by default, silent when fast</a>
</div>

</template>

<template #why>

Both paginate the same list, but the right runs on a server-side cursor instead of `LIMIT/OFFSET` — so it clears the 2,000-row OFFSET wall, folds the total count into the same call, surfaces rows the cursor saw deleted during the fetch instead of silently skipping them, and enforces the running user's field permissions by default. Salesforce cursors aren't KernDX-only — the difference is `getPage()` hands you the matching pagination cursor plus the totals, page math, and deleted-row tracking in one call.

</template>

</CodeCompare>

<CodeCompare title="Create an Account, Opportunity, and Contact — atomically" link="/fast-start-dml#parent-child-insert" linkText="DML Fast Start → Parent-Child Insert" wrote="5 lines" caps="6">

<template #before>

```apex
Account newAccount = new Account(Name = name);
insert newAccount; // committed immediately
Opportunity newOpportunity = new Opportunity(
	Name = dealName, StageName = 'Prospecting',
	CloseDate = Date.today().addDays(30),
	AccountId = newAccount.Id); // manual FK stitch
Contact newContact = new Contact(LastName = lastName, AccountId = newAccount.Id);
insert newOpportunity;
insert newContact; // if this throws and the service
// catches it, the Account + Opportunity stay committed — orphaned. Doing it
// safely means a Savepoint + try/catch + Database.rollback(savepoint). Every time.
```

</template>

<template #after>

```apex
kern.DML_Builder.newTransaction()
	.doInsert(newAccount)
	.doInsert(newOpportunity, Opportunity.AccountId, newAccount)
	.doInsert(newContact, Contact.AccountId, newAccount)
	.execute(); // one savepoint, all-or-nothing.
// FKs auto-wired after each parent inserts; any failure rolls back
// the whole graph. USER_MODE FLS by default.
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Atomic graph">Reliability</p>
<a class="kl-ledger-chip" href="/dml-guide#use-all-or-nothing-appropriately">One savepoint — any insert failure rolls the whole graph back, so no orphaned parent can leak</a>
<a class="kl-ledger-chip" href="/dml-guide#registering-relationships">Each foreign key is wired from the new parent's Id after it inserts — no manual AccountId stitching</a>
<a class="kl-ledger-chip" href="/dml-guide#managing-dependencies">Parents are inserted before their children — the Account is always inserted before its Opportunity and Contact</a>
<a class="kl-ledger-chip" href="/dml-guide#batch-processing">Guards the per-transaction DML-row limit before committing — fails fast and points you to .async()</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Governance</p>
<a class="kl-ledger-chip" href="/dml-guide#access-mode-user-mode-system-mode">Inserts run in USER_MODE by default — the running user's FLS and CRUD enforced on every row</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Observability</p>
<a class="kl-ledger-chip" href="/dml-guide#handle-dml-errors-properly">Returns a TransactionResult; switch to .allowPartial() and per-row failures are logged for you instead of thrown</a>
</div>

</template>

<template #why>

The right wires each foreign key from the new parent's id, commits all three on one savepoint, and rolls the whole graph back if any insert fails — so a half-saved parent can never leak. The left leaves the FK stitching, the permission check, and the rollback to you, on every service method.

</template>

</CodeCompare>

<CodeCompare title="A resilient callout — and the test, in one chain" link="/fast-start-resilience#step-1-make-a-resilient-callout" linkText="Resilience Fast Start → Resilient Callout" wrote="9 lines" caps="8">

<template #before>

```apex
// Hand-rolled resilient POST — and you still own the test.
HttpRequest request = new HttpRequest();
request.setEndpoint('callout:PaymentGateway/charges');
request.setMethod('POST');
request.setBody(JSON.serialize(chargeRequest));
Set<Integer> retryable = new Set<Integer>{ 500, 502, 503, 504 };
HttpResponse response;
Integer attempts = 0;
do
{
	attempts++;
	response = new Http().send(request);
}
while(retryable.contains(response.getStatusCode()) && attempts < 4);
// no circuit breaker · no masking before you log the body · no
// dead-letter — and to test it you hand-write an HttpCalloutMock
// class and wire Test.setMock yourself
```

</template>

<template #after>

```apex
HttpResponse charge = kern.UTIL_HttpClient
	.post('PaymentGateway', '/charges')
	.body(chargeRequest)
	.withRetry(5, 10)
	.withCircuitBreaker()
	.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
	.send(); // a transient 5xx comes back ON the response — never thrown

// …and the whole mock + assertion in the test, one chain:
kern.API_MockFactory.forService('PaymentGateway')
	.body('{"error":"unavailable"}').statusCode(503).register();
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Two-layer retry">Reliability</p>
<a class="kl-ledger-chip" href="/fast-start-resilience#retry-built-into-a-callout">Retries transient 5xx {500, 502, 503, 504} immediately — you never typed the loop or the codes</a>
<a class="kl-ledger-chip" href="/web-services-guide#automatic-retries">Still failing? the call is persisted and a scheduled Flow re-drives it at a backoff date — async, no thread held</a>
<a class="kl-ledger-chip" href="/resilience-guide#platform-cache-and-cross-transaction-state">Circuit-breaker state lives in Platform Cache, keyed by the credential and shared across transactions</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Governance</p>
<a class="kl-ledger-chip" href="/web-services-guide#data-masking">Card and secret-key rules redact Request__c / Response__c before the ApiCall__c row is saved — shipped on by default</a>
<a class="kl-ledger-chip" href="/web-services-guide#accessing-large-payloads">A body too large for the ApiCall__c field overflows to a ContentVersion file — masked the same way</a>
<a class="kl-ledger-chip" href="/web-services-guide#where-things-are-logged">The whole audit write (ApiCall__c, ApiIssue__c, ContentVersion) runs in SYSTEM_MODE, fixed up front and not overridable per-call</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Observability</p>
<a class="kl-ledger-chip" href="/web-services-guide#where-things-are-logged">On retry exhaustion it dead-letters to an ApiIssue__c record (when failure logging is on)</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Testing</p>
<a class="kl-ledger-chip" href="/web-services-guide#api-mockfactory-programmatic-mocking">One API_MockFactory.forService(...).register() replaces the whole HttpCalloutMock class and Test.setMock wiring</a>
</div>

</template>

<template #why>

On the left you hand-write the retry loop, the circuit breaker, the masking, and the dead-letter record — plus an `HttpCalloutMock` class to test any of it. On the right the chain retries transient 5xx {500,502,503,504} in-transaction, then — if it keeps failing — persists the call so a scheduled Flow re-runs it at a backoff date; it trips a credential-keyed circuit breaker, persists the masked request and response, dead-letters on exhaustion, and a one-line `API_MockFactory` stands in for the live dependency in tests. No `HttpCalloutMock`, no `Test.setMock`.

</template>

</CodeCompare>

<CodeCompare title="Log an error that survives the rollback that erased the record" link="/fast-start-logging" linkText="Logging Fast Start →" wrote="4 lines" caps="7">

<template #before>

```apex
try
{
	chargeCard(payment);
}
catch(Exception error)
{
	// Write a trace so we know what failed...
	insert new Error_Log__c(
		Message__c = error.getMessage(),
		Stack__c = error.getStackTraceString(),
		Record__c = payment.Id);
	throw error; // ...then the rollback ERASES that Error_Log__c too.
}
```

</template>

<template #after>

```apex
try
{
	chargeCard(payment);
}
catch(Exception error)
{
	kern.LOG_Builder.build()
		.error(error)
		.forRecord(payment.Id)
		.emitAt('PaymentService.charge');
	throw error; // the log is a platform event — it OUTLIVES the rollback.
}
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Rollback-proof">Reliability</p>
<a class="kl-ledger-chip" href="/logging-guide#architecture">Published as a platform event, so the saved log row outlives the rollback that erases the payment</a>
<a class="kl-ledger-chip" href="/logging-guide#log-buffering">An ERROR-level entry is never held in the suspended-save buffer — it flushes before the re-throw</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Observability</p>
<a class="kl-ledger-chip" href="/fast-start-logging#exception-logging">Snapshotted every governor limit (SOQL/DML/CPU/heap/callouts — used of maximum) onto the row</a>
<a class="kl-ledger-chip" href="/logging-guide#correlation-tracking">One startCorrelation() call stamps a shared correlation id on every log in the transaction — query the whole flow back by that one id</a>
<a class="kl-ledger-chip" href="/logging-guide#querying-log-entries">Captured the class + method, the execution context (trigger, REST, batch…), and the user who emitted the log — not the Automated Process user that persists it</a>
<a class="kl-ledger-chip" href="/fast-start-logging#log-an-exception-with-full-stack-trace">Recorded the exception type, the full stack trace, and the failing line number straight off the exception</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Governance</p>
<a class="kl-ledger-chip" href="/fast-start-logging#sensitive-data-is-masked-by-default">Ran the row through the masking framework before publish — on by default</a>
</div>

</template>

<template #why>

Both record the failure, but the right publishes it as a platform event — persisted in its own transaction — so the rollback that erases the payment can't erase the trace of *why* it failed. The left's `insert Error_Log__c` is undone by the very rollback the re-throw triggers, so the one trace you needed is gone.

</template>

</CodeCompare>

</template>

<template #examplesMore>

<CodeCompare title="Reject a replayed request with a changed body — HTTP 409, automatically" link="/fast-start-inbound-apis#idempotency" linkText="Inbound APIs Fast Start → Idempotency" wrote="1 handler + a checkbox" caps="7">

<template #before>

```apex
// Hand-rolled inbound endpoint — you own the dedupe, or you don't have it.
@RestResource(urlMapping='/charge/*')
global with sharing class ChargeApi
{
	@HttpPost
	global static void doPost()
	{
		String key = RestContext.request.headers.get('Idempotency-Key');
		String body = RestContext.request.requestBody.toString();

		// Naive dedupe: did we see this key already?
		List<Payment__c> prior =
		[
			SELECT Id
			FROM Payment__c
			WHERE IdempotencyKey__c = :key
			LIMIT 1
		];
		if(!prior.isEmpty())
		{
			RestContext.response.statusCode = 200;   // assume it's the same request...
			return;                                  // ...but you never checked the BODY.
		}

		chargeCard(body);                            // a retry with a CHANGED body
		insert new Payment__c(IdempotencyKey__c = key);  // double-charges silently.
	}
}
```

</template>

<template #after>

```apex
// 1. A normal inbound handler — no dedupe code at all.
@RestResource(urlMapping='/charge/*')
global inherited sharing class REST_Charge
{
	@HttpPost
	global static void doPost()
	{
		kern.API_Dispatcher.processInboundService(API_Charge.class.getName());
	}
}

global inherited sharing class API_Charge extends kern.API_Inbound
{
	public override void processRequest()
	{
		chargeCard(requestBody);
	}
}

// 2. Flip ONE field on this service's kern__ApiSetting__mdt record:
//      kern__IdempotencyEnabled__c = true   (kern__Direction__c = Inbound)
//
// Now, for every caller that sends an Idempotency-Key header:
//   • same key + same body    → cached HTTP 200 (handler never re-runs)
//   • same key + CHANGED body → HTTP 409, JSON names the original ApiCall__c.Id
//   • new key                 → fresh processing
// All three outcomes, zero dedupe code. INBOUND, body-hash based.
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Body-hash dedupe">Reliability</p>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis">Same key + changed body → HTTP 409 naming the original ApiCall__c.Id</a>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis">Same key + same body → cached HTTP 200, your handler never re-runs</a>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis">The dedupe is a SHA-256 hash of the body — turned on by one config checkbox</a>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis">Replay lookup matches on the indexed Idempotency-Key, and only against requests that already completed successfully</a>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis">This is INBOUND body-hash idempotency — outbound uses a correlation-ID key you set, not a body hash</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Observability</p>
<a class="kl-ledger-chip" href="/web-services-guide#apicall-c-custom-object">The hit is recorded on the ApiCall__c record (IsIdempotencyHit__c + body-hash)</a>
<a class="kl-ledger-chip" href="/web-services-guide#automatic-web-service-context">A W3C correlation id is set on every request, before the idempotency check runs</a>
</div>

</template>

<template #why>

On the left you hand-write the dedupe — and the naive version checks only that the key was seen before, never that the body still matches, so a retry that mutates the payload under the same key double-charges in silence. On the right you write a plain inbound handler and flip one CMDT checkbox. The framework computes a SHA-256 hash of the request body, stores it on the ApiCall__c record alongside the (External-ID-indexed) Idempotency-Key, and on a replay makes the three-way decision for you: a matching key and body returns the cached 200 without re-running your handler, a matching key with a different body returns HTTP 409 with a JSON body naming the original ApiCall__c.Id, and a new key processes fresh. This is inbound body-hash idempotency — distinct from outbound, where the subscriber stamps a correlation-ID key via UTIL_HttpClient.withCorrelationId().

</template>

</CodeCompare>

<CodeCompare title="A governor-limit crash won't leave your chain stuck &quot;Running&quot;" link="/fast-start-async-processing#how-it-works" linkText="Async Processing Fast Start →" wrote="5 lines" caps="10">

<template #before>

```apex
// Hand-rolled Queueable chain
public class Step1 implements Queueable
{
	public void execute(QueueableContext context)
	{
		doWork(); // a CPU/heap limit here and the job just dies
		System.enqueueJob(new Step2()); // never reached — no Step2, no error row, no status
	}
}
// AsyncApexJob says "Failed", detail-free. Your tracking record sits
// in "Running" forever. You find out from an angry user, not a query.
```

</template>

<template #after>

```apex
kern.UTIL_AsyncChain.newChain('OrderSync')
	.then(new Step1())
	.then(new Step2())
	.onError(new NotifyAdminStep())
	.execute();

// Each step runs in its own transaction (fresh limits).
// A Finalizer is attached to EVERY step, so even an
// uncatchable governor-limit crash marks the run Failed —
// with a reason + correlation id + a durable log. Never a zombie.
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Durable recovery">Reliability</p>
<a class="kl-ledger-chip" href="/async-processing-guide#monitoring-async-chain-failures">An uncatchable governor-limit crash still flips the run to Failed — never a zombie stuck on Running</a>
<a class="kl-ledger-chip" href="/fast-start-async-processing#how-it-works">Each step ran in its own Queueable transaction — a fresh set of governor limits per step</a>
<a class="kl-ledger-chip" href="/async-processing-guide#error-handling">An onError handler runs in its own callout-capable transaction, so it can notify out even after the failed step did DML</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Chain Monitor">Observability</p>
<a class="kl-ledger-chip" href="/async-processing-guide#overview">A real-time Chain Monitor UI surfaces running and failed chains without writing a query</a>
<a class="kl-ledger-chip" href="/async-processing-guide#monitoring">Live status persists to a queryable AsyncChainExecution__c row at every transition (Running → Completed/Failed/Aborted)</a>
<a class="kl-ledger-chip" href="/async-processing-guide#log-correlation">Logs emitted inside a step share the chain's correlation id, so one filter traces the whole multi-transaction run</a>
<a class="kl-ledger-chip" href="/async-processing-guide#monitoring">Status__c, CompletedSteps__c and CurrentStepName__c carry field-history tracking — a step-by-step audit trail</a>
<a class="kl-ledger-chip" href="/async-processing-guide#logging-strategy">On crash the Finalizer wrote a durable Error log stamped with the failed chain-execution record id</a>
<a class="kl-ledger-chip" href="/async-processing-guide#logging-strategy">Logs are reserved for actionable events — a clean, fast, successful run emits no log noise</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Performance</p>
<a class="kl-ledger-chip" href="/async-processing-guide#logging-strategy">Each step is timed; a slow step emits a structured performance log with CPU/heap/SOQL/DML deltas</a>
</div>

</template>

<template #why>

A crash inside a hand-rolled Queueable chain leaves no `finish()` hook, no error row, and a status stuck on "Running" — you hear about it from a user. The right attaches a Finalizer to every step, which runs with *fresh* limits even after an uncatchable crash, so the chain is marked failed with a reason and a correlated log instead of vanishing.

</template>

</CodeCompare>

<CodeCompare title="Scrub card numbers from your logs — without shredding your order IDs" link="/data-masking-guide#the-shipped-rules" linkText="Data Masking Guide → Shipped Rules" wrote="4 lines" caps="7">

<template #before>

```apex
// Hand-rolled redaction in the log message: any long digit run goes.
String body = '{"card":"4111 1111 1111 1111","orderId":"1234567890123456"}';

String safe = body.replaceAll('\\b(?:\\d[ -]?){13,19}\\b', '[REDACTED]');
// Now BOTH are gone:
//   {"card":"[REDACTED]","orderId":"[REDACTED]"}
// The order ID was never a card — but the regex can't tell, so support
// loses the one ID they needed to trace the transaction. Loosen the regex
// to spare the order ID and a real card slips through. There is no win.
insert new Error_Log__c(Message__c = safe);
```

</template>

<template #after>

```apex
// Just log it. The framework redacts the payment card on the way out.
String body = '{"card":"4111 1111 1111 1111","orderId":"1234567890123456"}';

kern.LOG_Builder.build()
	.info(body)
	.at('PaymentService.charge')
	.emit();

// The persisted LogEntry message reads:
//   {"card":"[CARD_REDACTED]","orderId":"1234567890123456"}
// 4111 1111 1111 1111 passes the Luhn check, so it is redacted.
// The 16-digit order ID FAILS Luhn, so it survives untouched.
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Luhn-precise">Governance</p>
<a class="kl-ledger-chip" href="/data-masking-guide#the-shipped-rules">Luhn-checked each match — the card redacted, the 16-digit order ID survived</a>
<a class="kl-ledger-chip" href="/data-masking-guide#what-ships-masked-by-default">On by default when you log — you configured nothing to get this</a>
<a class="kl-ledger-chip" href="/data-masking-guide#the-shipped-rules">The replacement reads [CARD_REDACTED] — the rule ships pre-wired, no Apex</a>
<a class="kl-ledger-chip" href="/data-masking-guide#what-ships-masked-by-default">The same rule also masks outbound-API, API-issue, and async-chain records</a>
<a class="kl-ledger-chip" href="/data-masking-guide#masking-records-on-your-own-objects">Point the same engine at your own object with declarative config — a masking target plus the object's masking toggle, no Apex</a>
<a class="kl-ledger-chip" href="/data-masking-guide#what-ships-masked-by-default">A master kill switch disables all framework masking for diagnostics</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Performance</p>
<a class="kl-ledger-chip" href="/data-masking-guide#performance">Bulk-safe: the card regex compiles once per transaction, then is reused across every record</a>
</div>

</template>

<template #why>

Both sides try to keep a raw card number out of your logs, but the left can't tell a card from any other 16-digit number — it either shreds the order ID alongside the card, or, loosened to spare the order ID, lets a real card through. On the right you just log the body: the framework masks its own outbound LogEntryEvent before it is published, with nothing to configure. The shipped payment-card rule runs in CreditCard mode, so every candidate match is independently checked against a Luhn (mod-10) checksum before it is replaced. The valid card (4111 1111 1111 1111) becomes [CARD_REDACTED]; the 16-digit order ID fails Luhn and passes through unchanged. The same rule is wired to the framework's outbound API records, API-issue records, and async-chain records too — so you get PCI-grade redaction of the value that matters and keep the identifier you need to trace the transaction.

</template>

</CodeCompare>

<CodeCompare title="Roll out a validation rule to production that logs violations but never blocks a save" link="/fast-start-custom-validations#shadow-mode" linkText="Custom Validations Fast Start → Shadow Mode" wrote="2 CMDT records + a checkbox" caps="7">

<template #before>

```apex
// Native Salesforce validation rule. It has exactly two states:
// off, or blocking EVERY save the instant you mark it Active —
// including the historical, dirty data you haven't cleaned yet.
//
//   Rule:    Customer_Requires_Contact
//   Formula: AND(ISPICKVAL(Type, "Customer"), ISBLANK(Phone))
//   Active:  [x]   <-- day one, prod saves start failing
//
// There is no "log it, don't block it" switch. To preview the
// blast radius you hand-roll a Flow that writes to a custom log
// object, or you flip Active on and brace for the support tickets.
update accounts;   // some now throw FIELD_CUSTOM_VALIDATION_EXCEPTION
```

</template>

<template #after>

```apex
// 1. AUTHOR two CMDT records, no Apex: a ValidationRuleGroup__mdt that
//    binds the object + timing (Account · Before · Insert/Update), then a
//    ValidationRule__mdt under it. RuleFormula__c returns TRUE when INVALID.
//
//   customMetadata/kern__ValidationRule.Customer_Requires_Contact.md-meta.xml
//   <values><field>kern__ValidationRuleGroup__c</field>
//     <value xsi:type="xsd:string">Account_Before_Save</value></values>
//   <values><field>kern__RuleFormula__c</field>
//     <value xsi:type="xsd:string">AND(ISPICKVAL(newRecord.Type, "Customer"), ISBLANK(newRecord.Phone))</value></values>
//   <values><field>kern__ErrorMessage__c</field>
//     <value xsi:type="xsd:string">Customer accounts need a phone</value></values>
//   <values><field>kern__Severity__c</field><value xsi:type="xsd:string">Error</value></values>
//   <values><field>kern__Order__c</field><value xsi:type="xsd:double">1</value></values>

// 2. Turn on Shadow Mode — ONE field. The live rule still fires on
//    every in-scope save and evaluates the SAME formula, but each
//    would-be violation is logged instead of calling addError().
//    The save commits — even with Severity = Error.
//
//   <values><field>kern__ShadowMode__c</field>
//     <value xsi:type="xsd:boolean">true</value></values>

// 3. Watch the blast radius accumulate, then flip ShadowMode__c to
//    false to enforce. Violations land in LogEntry__c tagged [SHADOW]:
List<LogEntry__c> shadowViolations = kern.QRY_Builder.selectFrom(LogEntry__c.SObjectType)
	.fields(new List<SObjectField>{ LogEntry__c.ShortMessage__c, LogEntry__c.CreatedDate })
	.condition(LogEntry__c.LogLevel__c).equals('WARN')
	.andCondition(LogEntry__c.ShortMessage__c).contains('[SHADOW]')
	.orderBy(LogEntry__c.CreatedDate).descending()
	.withLimit(100)
	.toList();
// Each ShortMessage__c reads: "[SHADOW] Customer_Requires_Contact:
// Customer accounts need a phone". Zero blocked saves.
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Shadow mode">Reliability</p>
<a class="kl-ledger-chip" href="/validation-guide#shadow-mode">Save never blocked — even with Severity = Error, a shadow violation is logged, not raised</a>
<a class="kl-ledger-chip" href="/fast-start-custom-validations#shadow-mode">Fires on every in-scope save against the SAME deployed formula — one checkbox flips shadow to enforce</a>
<a class="kl-ledger-chip" href="/validation-guide#severity-levels">A formula that throws still won't block the save — the evaluation error is logged and swallowed, not rethrown</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Observability</p>
<a class="kl-ledger-chip" href="/validation-guide#querying-shadow-violations">Each would-be violation logged as a WARN tagged [SHADOW] in ShortMessage__c for you to query</a>
<a class="kl-ledger-chip" href="/validation-guide#querying-shadow-violations">Inspect shadow rows with the same QRY_Builder fluent selector you query everything else with</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Governance</p>
<a class="kl-ledger-chip" href="/validation-guide#severity-levels">Three documented outcomes: Severity Error blocks the save, Warning logs it, Shadow logs it regardless of severity</a>
<a class="kl-ledger-chip" href="/validation-guide#querying-shadow-violations">The log read runs in USER_MODE by default — it honors the running user's LogEntry__c field permissions</a>
</div>

</template>

<template #why>

A native validation rule has exactly two states — off, or blocking every offending save the instant you mark it Active. There is no safe "observe first" middle ground, so a new rule meets your dirty production data as a wall of FIELD_CUSTOM_VALIDATION_EXCEPTION errors and angry tickets. KernDX adds a single declarative checkbox: with ShadowMode__c = true the live rule still fires on every in-scope save and evaluates the very same deployed formula, but each would-be violation is written to LogEntry__c as a WARN tagged [SHADOW] instead of calling addError() — so nothing is blocked. You query the log, see exactly which records (and how many) the rule would have stopped, fix or accept them, then flip one checkbox to false to enforce. You roll a rule into production and measure its blast radius before it ever costs a user a save.

</template>

</CodeCompare>

<CodeCompare title="One trigger. Metadata-ordered actions. No hand-rolled recursion guards." link="/triggers-guide" linkText="Triggers Guide →" wrote="a 1-line trigger" caps="9">

<template #before>

```apex
// Plain Apex: one fat trigger, inline logic, hand-rolled recursion guard.
trigger AccountTrigger on Account(before update)
{
	if(AccountTriggerHandler.alreadyRan) // static re-entry guard
	{
		return;
	}
	AccountTriggerHandler.alreadyRan = true;

	for(Account a : Trigger.new)
	{
		Account prior = Trigger.oldMap.get(a.Id);
		// rating logic + naming logic + territory logic all crammed here,
		// in an order nobody can change without editing + redeploying Apex.
		if(a.AnnualRevenue != prior.AnnualRevenue)
		{
			a.Rating = a.AnnualRevenue > 1000000 ? 'Hot' : 'Warm';
		}
		// ...next dev appends here; ordering is "whoever edited last"...
	}
}
// Disable it in an incident: comment it out + deploy. Reorder: edit + deploy.
// Unit-test one rule in isolation: you can't — it's welded to the loop + guard.
```

</template>

<template #after>

```apex
// 1. The trigger is one line — forever.
trigger AccountTrigger on Account(before update)
{
	new kern.TRG_Dispatcher().run();
}

// 2. Each rule is its own class, testable in isolation, ordered by metadata.
public inherited sharing class TRG_SetAccountRating
	extends kern.TRG_Base implements kern.IF_Trigger.BeforeUpdate
{
	public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		for(Account a : (List<Account>) newRecords)
		{
			Account prior = (Account) triggerOldMap.get(a.Id); // TRG_Base helper
			if(a.AnnualRevenue != prior.AnnualRevenue)
			{
				a.Rating = a.AnnualRevenue > 1000000 ? 'Hot' : 'Warm';
			}
		}
	}
}

// 3. Order, kill switch, and recursion are CONFIG, not code — TriggerAction__mdt:
//    ApexClassName__c   = TRG_SetAccountRating
//    Event__c           = Before Update
//    Order__c           = 20        // reorder without a deploy
//    BypassExecution__c = false     // flip to true to kill it mid-incident
//    AllowRecursion__c  = false     // shield re-entry (defaults to true)
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-marquee="Config, not code">Governance</p>
<a class="kl-ledger-chip" href="/triggers-guide#order-c-required">Actions dispatch in Order__c sequence</a>
<a class="kl-ledger-chip" href="/triggers-guide#bypassexecution-c-subscriber-controlled-1">Flip BypassExecution__c to kill an action with no deploy</a>
<a class="kl-ledger-chip" href="/triggers-guide#object-level-bypass-triggersetting-mdt">Disable every trigger action for an object in one call with TRG_Base.bypass()</a>
<a class="kl-ledger-chip" href="/triggers-guide#feature-flag-gating">Gate an action on a feature flag without touching code</a>
<a class="kl-ledger-chip" href="/triggers-guide#flow-as-a-trigger-action">Register a Flow as an ordered step in the same pipeline</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Reliability</p>
<a class="kl-ledger-chip" href="/triggers-guide#recursion-prevention">Set AllowRecursion__c = false to stop the action re-firing on re-entry</a>
<a class="kl-ledger-chip" href="/triggers-guide#failure-action-strategies">On action failure, choose Block DML or Log and Continue</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Observability</p>
<a class="kl-ledger-chip" href="/triggers-guide#bypass-audit-trail">Programmatic bypass calls write to the shared audit trail</a>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Testing</p>
<a class="kl-ledger-chip" href="/triggers-guide#testing-individual-actions">Each action is one class, unit-tested in isolation</a>
</div>

</template>

<template #why>

A one-line trigger delegates to `TRG_Dispatcher().run()`, which loads each `TriggerAction__mdt` row for the object + event, sorts them by `Order__c` ascending, and dispatches to a small single-purpose class via the matching `IF_Trigger` interface. Execution order, the per-action kill switch, recursion control, and feature-flag gating all move out of Apex and into subscriber-editable metadata — reorderable and disable-able with no redeploy. Each action takes its record list directly, so it is unit-testable without a DML round-trip, and any programmatic object/action bypass is written to the same audit trail as the query, DML, and validation surfaces.

</template>

</CodeCompare>

</template>

</KernLanding>
