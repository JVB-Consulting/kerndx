---
navOrder: 3
searchTerms: {"background-work":["@future"]}
---

# From Plain Apex to KernDX

Find the Apex you already write, then copy the KernDX version beside it. Each job below shows one familiar
operation, the KernDX version, one line on what changes, and one link to learn more.

- In your org, KernDX classes start with `kern.` and its objects and fields with `kern__`. Every sample here uses those prefixes.
- Keep `kern.ClassName` and the next call on one line. A line break straight after `kern.QRY_Builder`, before
  `.selectFrom`, does not compile.
- Deciding whether to use KernDX at all? Start with the [Strategic Guide - Overview](Strategic%20Guide%20-%20Overview.md).

## Reading records (SOQL)

### SELECT

```apex
// Plain Apex
List<Account> accounts = [SELECT Name, Industry, Phone FROM Account];
```

```apex
// KernDX
List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField> {Account.Name, Account.Industry, Account.Phone})
	.toList();
```

If you choose no fields, the read returns each record with only its `Id` filled in.

### WHERE

```apex
// Plain Apex
List<Account> accounts = [
	SELECT Name FROM Account
	WHERE Industry = 'Technology' AND AnnualRevenue > 1000000
];
```

```apex
// KernDX
List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField> {Account.Name})
	.condition(Account.Industry).equals('Technology')
	.andCondition(Account.AnnualRevenue).greaterThan(1000000)
	.toList();
```

### COUNT

```apex
// Plain Apex
Integer total = [SELECT COUNT() FROM Account WHERE Industry = 'Technology'];
```

```apex
// KernDX
Integer total = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.condition(Account.Industry).equals('Technology')
	.count();
```

`count()` returns the number of matching records as an `Integer`.

### SUM and GROUP BY (aggregate query)

```apex
// Plain Apex
List<AggregateResult> rows = [SELECT Industry, SUM(AnnualRevenue) revenue FROM Account GROUP BY Industry];
```

```apex
// KernDX
List<kern.QRY_Builder.AggregateRow> rows = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.sum(Account.AnnualRevenue, 'revenue')
	.groupBy(Account.Industry)
	.toAggregateList();

String industry = rows[0].getString('Industry');
Decimal revenue = rows[0].getDecimal('revenue');
```

You get one row per group. Read the grouped field by its field name, and the total by the name you gave it.

**What changes:** reads check the current user's object and field permissions, and record sharing. Switch the
[user mode flag](Fast%20Start%20-%20Security.md#the-org-wide-kill-switch) off and the permission checks stop; record
sharing then follows your class's sharing keyword. Learn more: [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md).

## Saving records (DML: insert, update, delete)

```apex
// Plain Apex
insert account;
```

```apex
// KernDX
kern.DML_Builder.newTransaction()
	.doInsert(account)
	.execute();
```

**What changes:** the save checks the current user's object and field permissions, and record sharing. Switch the
[user mode flag](Fast%20Start%20-%20Security.md#the-org-wide-kill-switch) off and the permission checks stop; record
sharing then follows your class's sharing keyword. Every record in one
`execute()` is saved together or not at all. Learn more: [Fast Start - DML](Fast%20Start%20-%20DML.md).

## Logging (System.debug)

```apex
// Plain Apex
System.debug('Payment processed');
```

```apex
// KernDX
kern.LOG_Builder.build()
	.info('Payment processed')
	.forRecord(accountId)
	.emitAt('SVC.charge');
```

**What changes:** the message is saved as a log record (`kern__LogEntry__c`) that you can search later, linked to
the record, with the class and method name you pass to `emitAt`. Learn more: [Fast Start - Logging](Fast%20Start%20-%20Logging.md).

## Background work

```apex
// Plain Apex
System.enqueueJob(new MyJob());
```

```apex
// KernDX
String executionId = kern.UTIL_AsyncChain.newChain('EnrichAccounts')
	.then(new EnrichTechnologyAccountsStep())
	.execute();
```

The step is your own class:

```text
force-app/main/default/classes/EnrichTechnologyAccountsStep.cls
```

```apex
global inherited sharing class EnrichTechnologyAccountsStep extends kern.UTIL_AsyncChain.ChainStep
{
	global override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
	{
		List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Id})
				.condition(Account.Industry).equals('Technology')
				.toList();

		for(Account account : accounts)
		{
			account.Description = 'Enriched in the background';
		}

		kern.DML_Builder.newTransaction().doUpdate(accounts).execute();

		return kern.UTIL_AsyncChain.succeeded();
	}
}
```

**What changes:** this is not a one-line swap.

- The step class extends `kern.UTIL_AsyncChain.ChainStep`, is `global`, and declares no constructor, because the framework creates it from its class name.
- The `AsyncChain` feature flag must be on. It is on when you install, and it is the [switch that stops all chains](Async%20Processing%20-%20Guide.md#kill-switch).
- Add more steps with more `.then(...)` calls. `kern.UTIL_AsyncChain.getStatus(executionId)` tells you how the run is going.

Learn more: [Fast Start - Async Processing](Fast%20Start%20-%20Async%20Processing.md).

## Triggers

```apex
// Plain Apex
trigger AccountTrigger on Account (before insert)
{
	for(Account newAccount : Trigger.new)
	{
		if(String.isBlank(newAccount.Description))
		{
			newAccount.Description = 'Default';
		}
	}
}
```

The trigger file hands everything to KernDX:

```text
force-app/main/default/triggers/TRG_Account.trigger
```

```apex
trigger TRG_Account on Account (before insert, before update, after insert, after update, before delete, after delete, after undelete)
{
	new kern.TRG_Dispatcher().run();
}
```

Each piece of logic is its own class:

```text
force-app/main/default/classes/TRG_SetAccountDefaults.cls
```

```apex
public inherited sharing class TRG_SetAccountDefaults extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account newAccount = (Account)record;
			if(String.isBlank(newAccount.Description))
			{
				newAccount.Description = 'Default';
			}
		}
	}
}
```

The class is `public`, so the framework finds it through your org's Type Resolver: a class you create from the code
the Kern home page health check gives you. See [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

**What changes:** two configuration records switch the class on: a trigger setting (`kern__TriggerSetting__mdt`) for
the object, and a trigger action (`kern__TriggerAction__mdt`) that names the class, the event and the order. You can
test the class by calling `beforeInsert` on records in memory.
Learn more: [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md).

## Callouts

```apex
// Plain Apex
HttpRequest request = new HttpRequest();
request.setEndpoint('callout:OrderService/orders/42');
request.setMethod('GET');
HttpResponse response = new Http().send(request);
```

```apex
// KernDX
HttpResponse response = kern.UTIL_HttpClient.get('OrderService', '/orders/42')
	.withRetry(3)
	.send();
```

**What changes:** `OrderService` is your named credential (the Setup record that holds the address and the login).
A failed call is tried again up to three times, and `send()` never throws: a call that got no answer comes back
with status code 0. Learn more: [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md).

## Testing

```apex
// Plain Apex
Account account = new Account(Name = 'Acme');
insert account;
```

```apex
// KernDX
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'Acme')
	.build();
```

**What changes:** the builder fills in the required fields you did not set, then saves the record. Add
`.withoutInsertion()` before `.build()` to make the record in memory only.
Learn more: [Fast Start - Test Data](Fast%20Start%20-%20Test%20Data.md).

## Patterns you may know

| Pattern | In KernDX |
|---|---|
| Unit of Work: register related records, then save them together, so all are saved or none | `kern.DML_Builder.newTransaction()`, then `.doInsert(newAccount)`, `.doInsert(newContact, Contact.AccountId, newAccount)` and `.execute()`. The child gets the parent's new Id. Do not name a variable `contact`: Apex then reads `Contact.AccountId` as that variable's field. |
| Selector layer: one class holds all the queries for one object | A class that extends `kern.SEL_Base` ([Fast Start - Selectors](Fast%20Start%20-%20Selectors.md)) |
| Trigger handler: logic lives in classes, not in the trigger | A class that extends `kern.TRG_Base`, as in [Triggers](#triggers) above |
