---
layout: page
pageClass: kl-landing-page
sidebar: false
---

<KernLanding>

<template #examples>

<CodeCompare title="Paginate past 2,000 rows, and know when the data shifts under you" link="/selectors-guide#pagination" linkText="Selectors Guide → Pagination" wrote="5 lines" caps="8">

<template #before>

```apex
// Page 82 of 25-row pages = OFFSET 2025 → governor blow-up
Integer offset = (pageNumber - 1) * pageSize; // over the 2,000 cap
List<Account> rows = [
	SELECT Id, Name FROM Account WHERE Type = 'Customer'
	ORDER BY Name ASC LIMIT :pageSize OFFSET :offset // ☠
];
Integer total = [SELECT COUNT() FROM Account]; // 2nd query
// FLS by hand. Rows deleted under you? You'll never know.
```

</template>

<template #after>

```apex
kern.QRY_Builder.QueryPage page = kern.QRY_Builder
	.selectFrom(Account.SObjectType)
	.condition(Account.Type).equals('Customer')
	.orderBy(Account.Name).ascending()
	.getPage(82, 25); // no OFFSET wall, USER_MODE FLS on

page.records; // this page
page.totalRecords; // count came back — no 2nd query
page.totalPages; // computed for you
page.hasMorePages; // wire to a "Next" button
page.deletedRecords; // rows the cursor saw deleted
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<a class="kl-ledger-chip hero" href="/selectors-guide#pagination"><span class="kl-chip-t">Cursor pagination</span><span class="kl-chip-d">Clears the 2,000-row OFFSET ceiling that plain LIMIT/OFFSET hits: getPage() runs and wires a pagination cursor for you.</span></a>
<a class="kl-ledger-chip" href="/selectors-guide#pagination"><span class="kl-chip-t">Total count, no 2nd query</span><span class="kl-chip-d">page.totalRecords folds into the same cursor call, with no separate COUNT() query.</span></a>
<a class="kl-ledger-chip" href="/selectors-guide#cursor-based-processing"><span class="kl-chip-t">Deleted-row tracking</span><span class="kl-chip-d">page.deletedRecords flags rows the cursor saw deleted mid-fetch, not silently dropped.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<a class="kl-ledger-chip" href="/selectors-guide#user-mode-security"><span class="kl-chip-t">USER_MODE by default</span><span class="kl-chip-d">Runs the running user's object and field permissions (CRUD and FLS) plus record sharing, with no hand-rolled checks.</span></a>
<a class="kl-ledger-chip" href="/selectors-guide#user-mode-security"><span class="kl-chip-t">Audited bypass</span><span class="kl-chip-d">withSystemMode() opt-outs are logged to an audit trail.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<a class="kl-ledger-chip" href="/selectors-guide#query-performance-logging"><span class="kl-chip-t">Slow-query telemetry</span><span class="kl-chip-d">Any query at 1000ms or slower (the default) logs a performance entry. Fast queries stay silent.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="performance">Performance</p>
<a class="kl-ledger-chip" href="/selectors-guide#platform-cache-integration"><span class="kl-chip-t">Cache the read inline</span><span class="kl-chip-d">withCache(ttlSeconds) parks the result in platform cache for the chosen lifetime, so repeat reads skip the query.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="testing">Testing</p>
<a class="kl-ledger-chip" href="/selectors-guide#mocking-with-tst-mock"><span class="kl-chip-t">Inject mock records</span><span class="kl-chip-d">TST_Mock.of(type).build() serves mock records (with mock Ids and no DML) from the next query for that type.</span></a>
</div>

</template>

<template #why>

Salesforce exposes query cursors, but you normally wire one by hand. `getPage()` runs a pagination cursor for you, folds the row count into that same call instead of a second query, and reports what the cursor saw deleted mid-fetch. All of it runs in the running user's CRUD, FLS and sharing mode by default.

</template>

</CodeCompare>

<CodeCompare title="Create an Account, Opportunity, and Contact in a single atomic save" link="/fast-start-dml#parent-child-insert" linkText="DML Fast Start → Parent-Child Insert" wrote="5 lines" caps="7">

<template #before>

```apex
Account newAccount = new Account(Name = name);
insert newAccount; // committed immediately
Opportunity newOpportunity = new Opportunity(
	Name = dealName, StageName = 'Prospecting',
	CloseDate = Date.today().addDays(30),
	AccountId = newAccount.Id); // manual FK stitch
Contact newContact = new Contact(
	LastName = lastName, AccountId = newAccount.Id);
insert newOpportunity;
insert newContact; // if this throws and the service catches it,
// the Account + Opportunity stay committed — orphaned. Safe means a
// Savepoint + try/catch + Database.rollback(savepoint). Every time.
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
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<a class="kl-ledger-chip hero" href="/dml-guide#use-all-or-nothing-appropriately"><span class="kl-chip-t">Atomic graph</span><span class="kl-chip-d">One savepoint. Any insert failure rolls the whole graph back, so no orphaned parent leaks.</span></a>
<a class="kl-ledger-chip" href="/dml-guide#registering-relationships"><span class="kl-chip-t">Auto-wired foreign keys</span><span class="kl-chip-d">Each foreign key is set from the new parent's Id after it inserts, with no manual AccountId stitching.</span></a>
<a class="kl-ledger-chip" href="/dml-guide#managing-dependencies"><span class="kl-chip-t">Dependency ordering</span><span class="kl-chip-d">Parents insert before children, so the Account always saves before its Opportunity and Contact.</span></a>
<a class="kl-ledger-chip" href="/dml-guide#how-to-opt-out"><span class="kl-chip-t">DML-row-limit guard</span><span class="kl-chip-d">Guards the per-transaction DML-row limit before committing. It fails fast and points you to .async().</span></a>
<a class="kl-ledger-chip" href="/dml-guide#upsert-with-external-id"><span class="kl-chip-t">Match-or-create on an external key</span><span class="kl-chip-d">doUpsert(record, externalIdField) matches on a stable external ID, so a replayed integration write updates the existing record instead of duplicating it.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<a class="kl-ledger-chip" href="/dml-guide#access-mode-user-mode-system-mode"><span class="kl-chip-t">USER_MODE by default</span><span class="kl-chip-d">Inserts run in USER_MODE, so the running user's FLS and CRUD are enforced on every row.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<a class="kl-ledger-chip" href="/dml-guide#handle-dml-errors-properly"><span class="kl-chip-t">Per-row error results</span><span class="kl-chip-d">Returns a TransactionResult; switch to .allowPartial() and per-row failures come back on the result instead of throwing.</span></a>
</div>

</template>

<template #why>

Each foreign key is set from the new parent's Id the moment that parent inserts, and all three rows commit on a single savepoint. So if any insert fails, the whole graph rolls back and a half-saved parent never leaks.

</template>

</CodeCompare>

<CodeCompare title="A resilient callout and its test, in one chain" link="/fast-start-resilience#step-1-make-a-resilient-callout" linkText="Resilience Fast Start → Resilient Callout" wrote="9 lines" caps="9">

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
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<a class="kl-ledger-chip hero" href="/fast-start-resilience#retry-built-into-a-callout"><span class="kl-chip-t">Two-layer retry</span><span class="kl-chip-d">Retries transient 5xx responses {500, 502, 503, 504} immediately. You never typed the loop or the codes.</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#automatic-retries"><span class="kl-chip-t">Async re-drive</span><span class="kl-chip-d">Still failing? The call is persisted and a scheduled Flow re-drives it at a backoff date.</span></a>
<a class="kl-ledger-chip" href="/resilience-guide#platform-cache-and-cross-transaction-state"><span class="kl-chip-t">Cross-transaction breaker</span><span class="kl-chip-d">Circuit-breaker state lives in Platform Cache, keyed by the credential, shared across transactions.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<a class="kl-ledger-chip" href="/web-services-guide#data-masking"><span class="kl-chip-t">Masked before save</span><span class="kl-chip-d">Card and secret-key rules redact Request__c / Response__c before the ApiCall__c row is saved.</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#accessing-large-payloads"><span class="kl-chip-t">Large-payload overflow</span><span class="kl-chip-d">A body too large for the field overflows to a ContentVersion file, masked the same way.</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#where-things-are-logged"><span class="kl-chip-t">Audit in SYSTEM_MODE</span><span class="kl-chip-d">The whole audit write runs in SYSTEM_MODE, fixed up front and not overridable per-call.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<a class="kl-ledger-chip" href="/web-services-guide#where-things-are-logged"><span class="kl-chip-t">Failure records on exhaustion</span><span class="kl-chip-d">On retry exhaustion it persists an ApiIssue__c record (when failure logging is enabled).</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="testing">Testing</p>
<a class="kl-ledger-chip" href="/web-services-guide#api-mockfactory-programmatic-mocking"><span class="kl-chip-t">One-line mock</span><span class="kl-chip-d">API_MockFactory.forService(...).register() replaces the whole HttpCalloutMock + Test.setMock.</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#call-verification"><span class="kl-chip-t">Verify what was sent</span><span class="kl-chip-d">Assert a mock was called and the last request body contained the right field, Mockito-style, with no captor wiring.</span></a>
</div>

</template>

<template #why>

The non-obvious part: a transient 5xx comes back *on* the response rather than thrown, and once in-transaction retries are spent the call is persisted so a scheduled Flow can re-drive it at a backoff date. The resilience outlives the original transaction. After repeated failures the framework stops calling a failing dependency for a cool-off, then resumes (a circuit breaker), and that state lives in Platform Cache keyed by the credential, so a dependency that's down stays shorted across transactions, not just within one.

</template>

</CodeCompare>

<CodeCompare title="Log an error that survives the rollback that erased the record" link="/fast-start-logging" linkText="Logging Fast Start →" wrote="4 lines" caps="8">

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
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<a class="kl-ledger-chip hero" href="/logging-guide#architecture"><span class="kl-chip-t">Rollback-proof</span><span class="kl-chip-d">Published as a platform event, so the saved log outlives the rollback that erases the payment.</span></a>
<a class="kl-ledger-chip" href="/logging-guide#log-buffering"><span class="kl-chip-t">ERROR flushes early</span><span class="kl-chip-d">An ERROR-level entry is never held in the suspended-save buffer; it flushes before the re-throw.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<a class="kl-ledger-chip" href="/logging-guide#performance-logging"><span class="kl-chip-t">Governor-limit snapshot</span><span class="kl-chip-d">Snapshots every limit (SOQL, DML, CPU, heap, callouts, each as used of maximum) onto the row.</span></a>
<a class="kl-ledger-chip" href="/logging-guide#correlation-tracking"><span class="kl-chip-t">Correlation id</span><span class="kl-chip-d">One startCorrelation() stamps a shared id on every log, so you query the whole flow by that one id.</span></a>
<a class="kl-ledger-chip" href="/logging-guide#async-context-propagation"><span class="kl-chip-t">Correlation survives the async hop</span><span class="kl-chip-d">serializeContext() / hydrateContext() carry the correlation id across a Queueable, Batch, or Future, so one flow stays joinable.</span></a>
<a class="kl-ledger-chip" href="/logging-guide#operation-context-stack"><span class="kl-chip-t">Full execution context</span><span class="kl-chip-d">Captures class + method, the context (trigger/REST/batch…), and the user who emitted the log.</span></a>
<a class="kl-ledger-chip" href="/fast-start-logging#log-an-exception-with-full-stack-trace"><span class="kl-chip-t">Exception detail</span><span class="kl-chip-d">Records the exception type, the full stack trace, and the failing line number.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<a class="kl-ledger-chip" href="/fast-start-logging#sensitive-data-is-masked-by-default"><span class="kl-chip-t">Masked by default</span><span class="kl-chip-d">Runs the row through the masking framework before publish, on by default.</span></a>
</div>

</template>

<template #why>

The log is published as a platform event committed to the event bus *immediately*, independent of your transaction, so the rollback that erases the payment can't un-publish the record of *why* it failed. A plain `insert Error_Log__c` shares the failing transaction and is undone by the very rollback the re-throw triggers.

</template>

</CodeCompare>

</template>

<template #examplesMore>

<CodeCompare title="Reject a replayed request with a changed body: HTTP 409, automatically" link="/fast-start-inbound-apis#idempotency" linkText="Inbound APIs Fast Start → Idempotency" wrote="1 handler + a checkbox" caps="8">

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
			RestContext.response.statusCode = 200;   // assume same request...
			return;                                  // ...never checked the BODY.
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
		kern.API_Dispatcher
			.processInboundService(API_Charge.class.getName());
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
//   • same key + CHANGED body → HTTP 409, names the original ApiCall__c.Id
//   • new key                 → fresh processing
// All three outcomes, zero dedupe code. INBOUND, body-hash based.
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<a class="kl-ledger-chip hero" href="/web-services-guide#idempotency-inbound-apis"><span class="kl-chip-t">Body-hash dedupe</span><span class="kl-chip-d">Same key + changed body → HTTP 409 naming the original ApiCall__c.Id.</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis"><span class="kl-chip-t">Cached replay</span><span class="kl-chip-d">Same key + same body → cached HTTP 200, your handler never re-runs.</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis"><span class="kl-chip-t">One-checkbox SHA-256</span><span class="kl-chip-d">The dedupe is a SHA-256 hash of the body, turned on by one config checkbox.</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis"><span class="kl-chip-t">Completed-only match</span><span class="kl-chip-d">Replay matches the indexed Idempotency-Key, only against requests that completed successfully.</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#idempotency-inbound-apis"><span class="kl-chip-t">Inbound, not outbound</span><span class="kl-chip-d">This is INBOUND body-hash idempotency. Outbound uses an explicit idempotency key you set, not a body hash.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<a class="kl-ledger-chip" href="/web-services-guide#apicall-c-custom-object"><span class="kl-chip-t">Recorded on ApiCall__c</span><span class="kl-chip-d">The hit is recorded on the ApiCall__c record (IsIdempotencyHit__c + body-hash).</span></a>
<a class="kl-ledger-chip" href="/web-services-guide#automatic-web-service-context"><span class="kl-chip-t">Correlation id first</span><span class="kl-chip-d">A W3C correlation id is set on every request, before the idempotency check runs.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<a class="kl-ledger-chip" href="/fast-start-inbound-apis#feature-flag-gating"><span class="kl-chip-t">Feature-flag-gated endpoint</span><span class="kl-chip-d">Name a flag in RequiredFeatureFlag__c and a disabled inbound API aborts automatically, so you can take a live endpoint offline by toggling a flag, with no redeploy.</span></a>
</div>

</template>

<template #why>

A naive hand-rolled dedupe checks only that the key was seen before, never that the body still matches, so a retry that mutates the payload under the same key double-charges in silence. The framework instead stores a SHA-256 hash of the request body next to the (External-ID-indexed) Idempotency-Key, so a replay with a changed body is *detectable*: it returns HTTP 409 naming the original `ApiCall__c.Id`, while an identical replay returns the cached 200 without re-running your handler. This is inbound body-hash idempotency. Outbound instead uses an explicit idempotency key you stamp via `UTIL_HttpClient.withIdempotencyKey()`.

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
		System.enqueueJob(new Step2()); // never reached — no error row, no status
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
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<a class="kl-ledger-chip hero" href="/async-processing-guide#monitoring-async-chain-failures"><span class="kl-chip-t">Durable recovery</span><span class="kl-chip-d">An uncatchable governor-limit crash still flips the run to Failed, never a zombie stuck on Running.</span></a>
<a class="kl-ledger-chip" href="/fast-start-async-processing#how-it-works"><span class="kl-chip-t">Fresh limits per step</span><span class="kl-chip-d">Each step ran in its own Queueable transaction, with a fresh set of governor limits.</span></a>
<a class="kl-ledger-chip" href="/async-processing-guide#error-handling"><span class="kl-chip-t">Callout-capable onError</span><span class="kl-chip-d">An onError handler runs in its own callout-capable transaction, even after the failed step did DML.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<a class="kl-ledger-chip" href="/async-processing-guide#overview"><span class="kl-chip-t">Real-time Chain Monitor</span><span class="kl-chip-d">A live UI surfaces running and failed chains without writing a query.</span></a>
<a class="kl-ledger-chip" href="/async-processing-guide#monitoring"><span class="kl-chip-t">Queryable status</span><span class="kl-chip-d">Status persists to an AsyncChainExecution__c row at every transition (Running → Completed/Failed/Aborted).</span></a>
<a class="kl-ledger-chip" href="/async-processing-guide#log-correlation"><span class="kl-chip-t">Shared correlation id</span><span class="kl-chip-d">Logs inside a step share the chain's id, so one filter traces the whole multi-transaction run.</span></a>
<a class="kl-ledger-chip" href="/async-processing-guide#monitoring"><span class="kl-chip-t">Field-history audit</span><span class="kl-chip-d">Status__c, CompletedSteps__c, CurrentStepName__c, and CompletedAt__c carry field-history, giving a step-by-step trail.</span></a>
<a class="kl-ledger-chip" href="/async-processing-guide#monitoring-async-chain-failures"><span class="kl-chip-t">Durable crash log</span><span class="kl-chip-d">On crash the Finalizer wrote a durable Error log stamped with the failed chain-execution id.</span></a>
<a class="kl-ledger-chip" href="/async-processing-guide#logging-strategy"><span class="kl-chip-t">Quiet when clean</span><span class="kl-chip-d">Logs are reserved for actionable events, so a clean, fast, successful run emits no noise.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="performance">Performance</p>
<a class="kl-ledger-chip" href="/async-processing-guide#logging-strategy"><span class="kl-chip-t">Per-step timing</span><span class="kl-chip-d">Each step is timed; a slow step emits a structured performance log with CPU, heap, SOQL, and DML deltas.</span></a>
</div>

</template>

<template #why>

A hand-rolled Queueable that hits an uncatchable governor limit just dies: no `finish()` hook, no error row, status stuck on "Running." The framework attaches a Finalizer to every step, and a Finalizer is guaranteed to run with *fresh* limits even after that crash. So the run is marked Failed with a reason and a correlated log instead of vanishing.

</template>

</CodeCompare>

<CodeCompare title="Scrub card numbers from your logs without shredding your order IDs" link="/data-masking-guide#the-shipped-rules" linkText="Data Masking Guide → Shipped Rules" wrote="4 lines" caps="8">

<template #before>

```apex
// Hand-rolled redaction in the log message: any long digit run goes.
String body = '{"card":"4111 1111 1111 1111","orderId":"1234567890123456"}';

String safe = body.replaceAll('\\b(?:\\d[ -]?){13,19}\\b', '[REDACTED]');
// Now BOTH are gone:
//   {"card":"[REDACTED]","orderId":"[REDACTED]"}
// The order ID was never a card — but the regex can't tell, so support
// loses the one ID they needed. Loosen it to spare the order ID and a
// real card slips through. There is no win.
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
<p class="kl-cat-h" data-cat="governance">Governance</p>
<a class="kl-ledger-chip hero" href="/data-masking-guide#the-shipped-rules"><span class="kl-chip-t">Luhn-precise</span><span class="kl-chip-d">Luhn-checked each match: the card redacted, the 16-digit order ID survived.</span></a>
<a class="kl-ledger-chip" href="/data-masking-guide#what-ships-masked-by-default"><span class="kl-chip-t">On by default</span><span class="kl-chip-d">On by default when you log. You configured nothing to get this.</span></a>
<a class="kl-ledger-chip" href="/data-masking-guide#the-shipped-rules"><span class="kl-chip-t">Pre-wired rule</span><span class="kl-chip-d">The replacement reads [CARD_REDACTED], and the rule ships pre-wired, with no Apex.</span></a>
<a class="kl-ledger-chip" href="/data-masking-guide#what-ships-masked-by-default"><span class="kl-chip-t">Covers framework records</span><span class="kl-chip-d">The same rule also masks the framework's outbound-API, API-issue, async-chain, and log records.</span></a>
<a class="kl-ledger-chip" href="/data-masking-guide#masking-records-on-your-own-objects"><span class="kl-chip-t">Point at your own objects</span><span class="kl-chip-d">Aim the same engine at your object with config: a masking target plus the object's toggle, no Apex.</span></a>
<a class="kl-ledger-chip" href="/data-masking-guide#what-ships-masked-by-default"><span class="kl-chip-t">Master kill switch</span><span class="kl-chip-d">A master kill switch disables all framework masking for diagnostics.</span></a>
<a class="kl-ledger-chip" href="/data-masking-guide#the-shipped-rules"><span class="kl-chip-t">15 dormant rule templates</span><span class="kl-chip-d">SSN, JWT, AWS keys, IBAN, SWIFT, private IPs and more ship as proven patterns. Activate one by wiring a target and flipping its IsActive flag, with no regex to write.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="performance">Performance</p>
<a class="kl-ledger-chip" href="/data-masking-guide#performance"><span class="kl-chip-t">Bulk-safe regex</span><span class="kl-chip-d">The card regex compiles once per transaction, then is reused across every record.</span></a>
</div>

</template>

<template #why>

A blunt regex can't tell a card from any other 16-digit number: it either shreds the order ID alongside the card or, loosened to spare the order ID, lets a real card through. The shipped rule runs in CreditCard mode and checks each candidate match against a Luhn (mod-10) checksum first, so the valid card (4111 1111 1111 1111) is redacted while the order ID, which fails Luhn, passes through untouched. The masking runs on the framework's own `LogEntryEvent` before it is published, with nothing to configure.

</template>

</CodeCompare>

<CodeCompare title="Roll out a validation rule to production that logs violations but never blocks a save" link="/fast-start-custom-validations#shadow-mode" linkText="Custom Validations Fast Start → Shadow Mode" wrote="2 CMDT records + a checkbox" caps="8">

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
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<a class="kl-ledger-chip hero" href="/validation-guide#shadow-mode"><span class="kl-chip-t">Shadow mode</span><span class="kl-chip-d">Save never blocked: even with Severity = Error, a shadow violation is logged, not raised.</span></a>
<a class="kl-ledger-chip" href="/fast-start-custom-validations#shadow-mode"><span class="kl-chip-t">Same deployed formula</span><span class="kl-chip-d">Fires on every in-scope save against the SAME formula, and one checkbox flips shadow to enforce.</span></a>
<a class="kl-ledger-chip" href="/validation-guide#troubleshooting"><span class="kl-chip-t">Throw-safe evaluation</span><span class="kl-chip-d">A formula that throws still won't block the save. The error is logged and swallowed, not rethrown.</span></a>
<a class="kl-ledger-chip" href="/validation-guide#validating-records-in-flow"><span class="kl-chip-t">Same rules, callable from Flow</span><span class="kl-chip-d">An Execute Validation Rules invocable runs the very same formula rules from a Flow and returns errors/warnings without blocking the save.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<a class="kl-ledger-chip" href="/validation-guide#querying-shadow-violations"><span class="kl-chip-t">[SHADOW] in ShortMessage__c</span><span class="kl-chip-d">Each would-be violation logged as a WARN tagged [SHADOW] in ShortMessage__c for you to query.</span></a>
<a class="kl-ledger-chip" href="/validation-guide#querying-shadow-violations"><span class="kl-chip-t">Query with QRY_Builder</span><span class="kl-chip-d">Inspect shadow rows with the same fluent selector you query everything else with.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<a class="kl-ledger-chip" href="/validation-guide#shadow-mode"><span class="kl-chip-t">Three documented outcomes</span><span class="kl-chip-d">Severity Error blocks the save, Warning logs it, Shadow logs it regardless of severity.</span></a>
<a class="kl-ledger-chip" href="/selectors-guide#user-mode-security"><span class="kl-chip-t">USER_MODE log read</span><span class="kl-chip-d">The log read runs in USER_MODE by default, honouring the running user's LogEntry__c permissions.</span></a>
</div>

</template>

<template #why>

A native validation rule has two states only: off, or blocking every offending save the instant it is Active. So a new rule meets your dirty production data as a wall of `FIELD_CUSTOM_VALIDATION_EXCEPTION` errors. With `ShadowMode__c = true` the rule still fires on every in-scope save and evaluates the very same deployed formula, but each would-be violation is written to `LogEntry__c` as a `[SHADOW]` WARN instead of calling `addError()`, so nothing is blocked. You measure the blast radius from the log, then flip one checkbox to enforce.

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
		// rating + naming + territory logic all crammed here, in an
		// order nobody can change without editing + redeploying Apex.
		if(a.AnnualRevenue != prior.AnnualRevenue)
		{
			a.Rating = a.AnnualRevenue > 1000000 ? 'Hot' : 'Warm';
		}
		// ...next dev appends here; ordering is "whoever edited last"...
	}
}
// Disable in an incident: comment it out + deploy. Reorder: edit + deploy.
// Unit-test one rule alone: you can't — it's welded to the loop + guard.
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
<p class="kl-cat-h" data-cat="governance">Governance</p>
<a class="kl-ledger-chip hero" href="/triggers-guide#order-c-required"><span class="kl-chip-t">Config, not code</span><span class="kl-chip-d">Actions dispatch in Order__c sequence, so you reorder them without a deploy.</span></a>
<a class="kl-ledger-chip" href="/triggers-guide#bypassexecution-c-subscriber-controlled-1"><span class="kl-chip-t">Per-action kill switch</span><span class="kl-chip-d">Flip BypassExecution__c to kill an action with no deploy.</span></a>
<a class="kl-ledger-chip" href="/triggers-guide#object-level-bypass-triggersetting-mdt"><span class="kl-chip-t">Object-level bypass</span><span class="kl-chip-d">Disable every trigger action for an object in one call with TRG_Base.bypass().</span></a>
<a class="kl-ledger-chip" href="/triggers-guide#feature-flag-gating"><span class="kl-chip-t">Feature-flag gating</span><span class="kl-chip-d">Gate an action on a feature flag without touching code.</span></a>
<a class="kl-ledger-chip" href="/triggers-guide#flow-as-a-trigger-action"><span class="kl-chip-t">Flow as a step</span><span class="kl-chip-d">Register a Flow as an ordered step in the same pipeline.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<a class="kl-ledger-chip" href="/triggers-guide#recursion-prevention"><span class="kl-chip-t">Recursion guard</span><span class="kl-chip-d">Set AllowRecursion__c = false to stop the action re-firing on re-entry.</span></a>
<a class="kl-ledger-chip" href="/triggers-guide#failure-action-strategies"><span class="kl-chip-t">Failure strategy</span><span class="kl-chip-d">On action failure, choose Block DML or Log and Continue.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<a class="kl-ledger-chip" href="/triggers-guide#bypass-audit-trail"><span class="kl-chip-t">Bypass audit trail</span><span class="kl-chip-d">Programmatic bypass calls write to the shared audit trail.</span></a>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="testing">Testing</p>
<a class="kl-ledger-chip" href="/triggers-guide#testing-an-action-without-dml"><span class="kl-chip-t">DML-free action tests</span><span class="kl-chip-d">Call an action directly on in-memory rows (TST_Builder/TST_Mock) and mock its selector reads, so you unit-test one rule with no DML.</span></a>
</div>

</template>

<template #why>

A one-line trigger hands off to `TRG_Dispatcher().run()`, which queries the `TriggerAction__mdt` rows for that object and event, sorts them by `Order__c`, and dispatches each to a small single-purpose class through the matching `IF_Trigger` interface. Because order, bypass, recursion, and flag-gating are *rows* rather than Apex, they change with no redeploy. And because each action just takes a record list, you unit-test one in isolation.

</template>

</CodeCompare>

</template>

</KernLanding>
