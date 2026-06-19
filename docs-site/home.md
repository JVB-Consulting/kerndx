---
layout: page
pageClass: kl-landing-page
---

<KernLanding>

<template #examples>

<CodeCompare title="Log an error that survives the rollback that erased the record" link="/fast-start-logging" linkText="Logging Fast Start →">

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
		Stack__c   = error.getStackTraceString(),
		Record__c  = payment.Id);
	throw error;   // ...then the rollback ERASES that Error_Log__c too.
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
	throw error;   // the log is a platform event — it OUTLIVES the rollback.
}
```

</template>

<template #why>

Both record the failure, but the right publishes it as a platform event — persisted in its own transaction — so the rollback that erases the payment can't erase the trace of *why* it failed. The left's `insert Error_Log__c` is undone by the very rollback the re-throw triggers, so the one trace you needed is gone.

</template>

</CodeCompare>

<CodeCompare title="Paginate past 2,000 rows — and know when the data shifts under you" link="/selectors-guide#pagination" linkText="Selectors Guide → Pagination">

<template #before>

```apex
// Page 81 of 25-row pages = OFFSET 2000 → runtime governor blow-up
Integer offset = (pageNumber - 1) * pageSize;       // 2000+
List<Account> rows = [
	SELECT Id, Name FROM Account WHERE Type = 'Customer'
	ORDER BY Name ASC LIMIT :pageSize OFFSET :offset // ☠ NUMBER_OUTSIDE_VALID_RANGE
];
Integer total = [SELECT COUNT() FROM Account WHERE Type = 'Customer']; // 2nd query
// FLS? You enforce it by hand. Rows deleted since page 1? You'll never know.
```

</template>

<template #after>

```apex
kern.QRY_Builder.QueryPage page = kern.QRY_Builder
	.selectFrom(Account.SObjectType)
	.condition(Account.Type).equals('Customer')
	.orderBy(Account.Name).ascending()
	.getPage(81, 25);    // page 81 — no OFFSET wall, USER_MODE FLS on

page.records;        // this page
page.totalRecords;   // count came back with the page — no 2nd query
page.totalPages;     // computed for you
page.hasMorePages;   // wire straight to a "Next" button
page.deletedRecords; // rows vanished mid-paging → "list changed, refresh"
```

</template>

<template #why>

Both paginate the same list, but the right runs on a server-side cursor instead of `LIMIT/OFFSET` — so it clears the 2,000-row OFFSET wall, folds the total count into the same call, reports rows deleted mid-paging instead of silently skipping them, and enforces the running user's field permissions by default.

</template>

</CodeCompare>

<CodeCompare title="A governor-limit crash won't leave your chain stuck &quot;Running&quot;" link="/fast-start-async-processing#how-it-works" linkText="Async Processing Fast Start →">

<template #before>

```apex
// Hand-rolled Queueable chain
public class Step1 implements Queueable
{
	public void execute(QueueableContext context)
	{
		doWork();                       // a CPU/heap limit here and the job just dies
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

<template #why>

A crash inside a hand-rolled Queueable chain leaves no `finish()` hook, no error row, and a status stuck on "Running" — you hear about it from a user. The right attaches a Finalizer to every step, which runs with *fresh* limits even after an uncatchable crash, so the chain is marked failed with a reason and a correlated log instead of vanishing.

</template>

</CodeCompare>

<CodeCompare title="Create an Account, Opportunity, and Contact — atomically" link="/fast-start-dml#parent-child-insert" linkText="DML Fast Start → Parent-Child Insert">

<template #before>

```apex
Account account = new Account(Name = name);
insert account;                       // committed immediately
Opportunity opportunity = new Opportunity(
	Name = dealName, StageName = 'Prospecting',
	CloseDate = Date.today().addDays(30),
	AccountId = account.Id);          // manual FK stitch
Contact contact = new Contact(LastName = lastName, AccountId = account.Id);
insert opportunity;
insert contact;                       // if this throws and the service
// catches it, account + opportunity stay committed — orphaned. Doing it
// safely means a Savepoint + try/catch + Database.rollback(savepoint). Every time.
```

</template>

<template #after>

```apex
kern.DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(opportunity, Opportunity.AccountId, account)
	.doInsert(contact, Contact.AccountId, account)
	.execute();   // one savepoint, all-or-nothing.
// FKs auto-wired after the account inserts; any failure rolls back
// the whole graph. USER_MODE FLS by default.
```

</template>

<template #why>

The right wires each foreign key from the new parent's id, commits all three on one savepoint, and rolls the whole graph back if any insert fails — so a half-saved parent can never leak. The left leaves the FK stitching, the permission check, and the rollback to you, on every service method.

</template>

</CodeCompare>

<CodeCompare title="Test a validation rule with zero DML" link="/fast-start-custom-validations#tier-2-test-your-rules-10-minutes" linkText="Custom Validations Fast Start →">

<template #before>

```apex
@IsTest
static void customerNeedsContact()
{
	Account account = new Account(Name = 'Acme', Type = 'Customer');
	insert account;             // setup DML
	Test.startTest();
	try
	{
		update account;          // fire the trigger
		Assert.fail('expected validation');
	}
	catch(DmlException error)
	{
		Assert.isTrue(error.getDmlMessage(0)
			.contains('requires a Contact'));  // brittle substring
	}
	Test.stopTest();
}
```

</template>

<template #after>

```apex
@IsTest
static void customerNeedsContact()
{
	Account account = new Account(Name = 'Acme', Type = 'Customer');

	// No insert, no trigger, no DmlException string-matching —
	// evaluate the DEPLOYED rule's formula in-memory, by name:
	kern.UTIL_ValidationTestHelper.assertRuleFails(account, 'Customer_Requires_Contact');

	account.Type = 'Prospect';
	kern.UTIL_ValidationTestHelper.assertRulePasses(account, 'Customer_Requires_Contact');
}
```

</template>

<template #why>

Both assert the same rule fires, but the right evaluates your deployed rule's formula in-memory, by name — no setup DML, no trigger, no brittle `DmlException` substring that breaks the day someone rewords the error. It's governor-cheap and `global`, so it runs from a subscriber org too.

</template>

</CodeCompare>

<CodeCompare title="A resilient callout — and the test, in one chain" link="/fast-start-resilience#step-1-make-a-resilient-callout" linkText="Resilience Fast Start → Resilient Callout">

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
	.withExponentialBackoff(3, 2)
	.withCircuitBreaker()
	.withIdempotencyKey('order-12345')
	.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
	.send(); // a transient 5xx comes back ON the response

// …and the whole mock + assertion in the test, one chain:
kern.API_MockFactory.forService(CREDENTIAL)
	.body('{"error":"unavailable"}').statusCode(503).register();
```

</template>

<template #why>

On the left you hand-write the retry loop, the circuit breaker, the masking, and the dead-letter record — plus an `HttpCalloutMock` class to test any of it. On the right the chain retries the framework's transient set {500,502,503,504}, trips a credential-keyed circuit breaker, persists the masked request and response, dead-letters on exhaustion, and a one-line `API_MockFactory` stands in for the live dependency in tests. No `HttpCalloutMock`, no `Test.setMock`.

</template>

</CodeCompare>

</template>

</KernLanding>
