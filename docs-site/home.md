---
layout: page
pageClass: kl-landing-page
sidebar: false
---

<KernLanding>

<template #features>

The KernDX samples here use the managed package's `kern.` and `kern__` prefixes. Samples in the guides sometimes leave them off: [how to read the code samples](/installation#how-to-read-the-code-samples).

<FeatureGroup id="group-read-and-save-data" title="Read and save data" summary="5 examples" open>

<CodeCompare id="selectors" title="Paginate past 2,000 rows, and know when the data shifts under you" link="/selectors-guide#pagination" linkText="Selectors Guide → Pagination" wrote="5 lines" caps="8">

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
// SEL_Accounts is your own selector: a with sharing class extending kern.SEL_Base.
kern.QRY_Builder.QueryPage page = new SEL_Accounts().query
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
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/selectors-guide#pagination">Cursor pagination</a><span class="kl-chip-d">Clears the 2,000-row OFFSET ceiling that plain LIMIT/OFFSET hits: getPage() runs and wires a pagination cursor for you.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#pagination">Total count, no 2nd query</a><span class="kl-chip-d">page.totalRecords folds into the same cursor call, with no separate COUNT() query.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#cursor-based-processing">Deleted-row tracking</a><span class="kl-chip-d">page.deletedRecords flags rows the cursor saw deleted mid-fetch, not silently dropped.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#user-mode-security">USER_MODE by default</a><span class="kl-chip-d">Runs the running user's object and field permissions (CRUD and FLS) plus record sharing, with no hand-rolled checks.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#user-mode-security">Audited bypass</a><span class="kl-chip-d">withSystemMode() opt-outs are logged to an audit trail.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#query-performance-logging">Slow-query telemetry</a><span class="kl-chip-d">Any query at 1000ms or slower (the default) logs a performance entry. Fast queries stay silent.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="performance">Performance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#where-are-cached-rows-kept">Cache the read inline</a><span class="kl-chip-d">withCache(ttlSeconds) keeps this read in memory for the rest of the transaction, so a repeat costs no query. A system-mode read that states its sharing can be kept in Platform Cache for the chosen lifetime.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="testing">Testing</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#mocking-with-tst-mock">Inject mock records</a><span class="kl-chip-d">TST_Mock.of(type).build() serves mock records (with mock Ids and no DML) from the next query for that type.</span></div>
</div>

</template>

<template #why>

Salesforce exposes query cursors, but you normally wire one by hand. `getPage()` runs a pagination cursor for you, folds the row count into that same call instead of a second query, and reports what the cursor saw deleted mid-fetch. All of it runs in the running user's CRUD, FLS and sharing mode by default.

</template>

</CodeCompare>

<CodeCompare id="saving-records" title="Create an Account, Opportunity, and Contact in a single atomic save" link="/fast-start-dml#parent-child-insert" linkText="DML Fast Start → Parent-Child Insert" wrote="5 lines" caps="7">

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
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/dml-guide#use-all-or-nothing-appropriately">Atomic graph</a><span class="kl-chip-d">One savepoint. Any insert failure rolls the whole graph back, so no orphaned parent leaks.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dml-guide#registering-relationships">Auto-wired foreign keys</a><span class="kl-chip-d">Each foreign key is set from the new parent's Id after it inserts, with no manual AccountId stitching.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dml-guide#managing-dependencies">Dependency ordering</a><span class="kl-chip-d">Parents insert before children, so the Account always saves before its Opportunity and Contact.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dml-guide#how-to-opt-out">DML-row-limit guard</a><span class="kl-chip-d">Guards the per-transaction DML-row limit before committing. It fails fast and points you to .async().</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dml-guide#upsert-with-external-id">Match-or-create on an external key</a><span class="kl-chip-d">doUpsert(record, externalIdField) matches on a stable external ID, so a replayed integration write updates the existing record instead of duplicating it.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dml-guide#access-mode-user-mode-system-mode">USER_MODE by default</a><span class="kl-chip-d">Inserts run in USER_MODE, so the running user's FLS and CRUD are enforced on every row.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dml-guide#handle-dml-errors-properly">Per-row error results</a><span class="kl-chip-d">Returns a TransactionResult; switch to .allowPartial() and per-row failures come back on the result instead of throwing.</span></div>
</div>

</template>

<template #why>

Each foreign key is set from the new parent's Id the moment that parent inserts, and all three rows commit on a single savepoint. So if any insert fails, the whole graph rolls back and a half-saved parent never leaks.

</template>

</CodeCompare>

<CodeCompare id="dtos" title="Read a JSON body into a typed class: a typo in a field name is a compile error, not a null" link="/dtos-guide" linkText="DTOs Guide →" wrote="1 class" caps="7">

<template #lead>

**Why:** a DTO is a small class holding exactly the fields to move in or out, which turns itself into JSON and back. If your code reads a field by a misspelt name, the class will not compile, and the outside format stays apart from your objects, so an API change touches one class.

</template>

<template #before>

```apex
Map<String, Object> customer = (Map<String, Object>)
	JSON.deserializeUntyped(response.getBody());
String email = (String)customer.get('emial'); // typo: null, no error
Map<String, Object> address = (Map<String, Object>)customer.get('address');
String city = (String)address.get('city');
// Every caller casts and guesses the shape again.
// The JSON shape leaks into every class that touches it.
```

</template>

<template #after>

```apex
// public is enough: getObjectType() names the class, so KernDX does not look it up by name
@JsonAccess(serializable='always' deserializable='always')
public inherited sharing class DTO_Customer extends kern.DTO_JsonBase
{
	public String email;
	public DTO_Address address;
	public override Type getObjectType()
	{
		return DTO_Customer.class;
	}
	@JsonAccess(serializable='always' deserializable='always')
	public class DTO_Address
	{
		public String city;
	}
}

DTO_Customer customer = (DTO_Customer)new DTO_Customer().deserialize(response.getBody());
String email = customer.email;        // a typo here will not compile
String city = customer.address?.city; // the nested part is typed too
String body = customer.serialize();   // and back to JSON
```

</template>

<template #footprint>

**You write:** 1 Apex class (the DTO). **You configure:** nothing.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Safety</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/dtos-guide#creating-json-dtos">Typed fields</a><span class="kl-chip-d">deserialize and serialize work on your own class, so a shape mistake shows up when you save it.</span><span class="kl-chip-s"><a href="/reference/apex/dto-jsonbase">kern.DTO_JsonBase</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Shape</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dtos-guide#implementing-populate-methods">Fill it from a record</a><span class="kl-chip-d">Override populate(recordId) to fill the DTO, reading through your selector.</span><span class="kl-chip-s"><a href="/reference/apex/dto-base">kern.DTO_Base</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dtos-guide#implementing-transform-methods">Reshape in one place</a><span class="kl-chip-d">transform copies one DTO into another, so changing an API contract leaves your objects alone.</span><span class="kl-chip-s"><a href="/reference/apex/dto-base">kern.DTO_Base</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dtos-guide#jsonpath-for-reflective-access">Read one value by path</a><span class="kl-chip-d">UTIL_JsonPath finds a value deep in a JSON body without a class for every level.</span><span class="kl-chip-s"><a href="/reference/apex/util-jsonpath">kern.UTIL_JsonPath</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Integrate</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dtos-guide#dtos-in-rest-apis">The body of an API call</a><span class="kl-chip-d">Inbound and outbound API handlers carry their request and response as DTOs, so the same class reads the JSON in and writes it out.</span><span class="kl-chip-s"><a href="/reference/apex/api-inbound">kern.API_Inbound</a> · <a href="/reference/apex/api-outbound">kern.API_Outbound</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dtos-guide#passing-complex-dtos-as-auraenabled-parameters">Sent to a component as JSON</a><span class="kl-chip-d">A controller takes the DTO as one JSON string and turns it back into your class, the pattern used throughout KernDX.</span><span class="kl-chip-s"><a href="/reference/apex/dto-jsonbase">kern.DTO_JsonBase</a> · <code>kern/moduleController</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Ready-made</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/dtos-guide#built-in-dto-classes">DTOs that ship</a><span class="kl-chip-d">Name-value pairs, picklists, tables and change-event headers are already written.</span><span class="kl-chip-s"><a href="/reference/apex/dto-namevalues">kern.DTO_NameValues</a> · <a href="/reference/apex/dto-picklist">kern.DTO_PickList</a> · <a href="/reference/apex/dto-basetable">kern.DTO_BaseTable</a> · <a href="/reference/apex/dto-changeeventheader">kern.DTO_ChangeEventHeader</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="security" title="Encrypt a value for this session, and choose sharing per read, without key handling code" link="/security-guide" linkText="Security Guide →" wrote="2 calls" caps="12">

<template #lead>

**Why:** one call encrypts and one decrypts; the key is made, kept per user and replaced for you, and every value carries a tamper check. It is for values you hold during a session: keys expire within 8 hours, so it is not long-term storage.

</template>

<template #before>

```apex
Blob key = Crypto.generateAesKey(256);
// ...now store the key somewhere safe, per user, and replace it yourself
Blob cipher = Crypto.encryptWithManagedIV('AES256', key, Blob.valueOf(cardToken));
String sealed = EncodingUtil.base64Encode(cipher);
// No tamper check: a changed value fails late, or decrypts to rubbish.

// Sharing is fixed by the class keyword, for every query in it:
public without sharing class CaseReader { }
```

</template>

<template #after>

```apex
String sealed = kern.UTIL_SessionEncryption.encrypt(cardToken);
String plain = kern.UTIL_SessionEncryption.decrypt(sealed);
// Key made and kept per user in Platform Cache, replaced after 8 hours.
// Each value carries a tamper check (HMAC-SHA256), checked on decrypt.

// Sharing chosen per read: past sharing, field checks still on.
// SEL_Cases is your own selector: a with sharing class extending kern.SEL_Base.
List<SObject> openCases = new SEL_Cases().query
	.condition(Case.IsClosed).equals(false)
	.bypassSharing() // written to the bypass audit trail
	.toList();
```

</template>

<template #footprint>

**You write:** 2 calls, and your own selector class. **You configure:** space in the package's `kern.Library` cache partition, where the keys are kept.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Encryption</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/security-guide#how-automatic-key-management-works">No key handling in your code</a><span class="kl-chip-d">The key is made, cached with an expiry and found again for you.</span><span class="kl-chip-s"><a href="/reference/apex/util-sessionencryption">kern.UTIL_SessionEncryption</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#encryption-methods">Tamper check on every value</a><span class="kl-chip-d">A random starting value plus an HMAC-SHA256 check, verified on decrypt.</span><span class="kl-chip-s"><a href="/reference/apex/util-sessionencryption">kern.UTIL_SessionEncryption</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/security-guide#how-automatic-key-management-works">A key per user, replaced after 8 hours</a><span class="kl-chip-d">Keys are kept apart per user and expire on their own.</span><span class="kl-chip-s"><a href="/reference/apex/util-sessionencryption">kern.UTIL_SessionEncryption</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/security-guide#how-automatic-key-management-works">The cache is picked for you</a><span class="kl-chip-d">Keys go to the session cache, or to the org cache when there is no session.</span><span class="kl-chip-s"><a href="/reference/apex/util-sessionencryption">kern.UTIL_SessionEncryption</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#important-considerations">Check before you rely on it</a><span class="kl-chip-d">isAvailable() says whether Platform Cache is ready for encryption.</span><span class="kl-chip-s"><a href="/reference/apex/util-sessionencryption">kern.UTIL_SessionEncryption</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Sharing and field security</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#safe-by-default">User mode on every read and save</a><span class="kl-chip-d">Queries and saves check the running user's object access, field access and record sharing unless you say otherwise.</span><span class="kl-chip-s"><a href="/reference/apex/qry-builder">kern.QRY_Builder</a> · <a href="/reference/apex/dml-builder">kern.DML_Builder</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#per-query-sharing-control">Sharing per read or save</a><span class="kl-chip-d">withSharing() and bypassSharing() on a read, bypassSharing() on a save, while field and object checks stay on.</span><span class="kl-chip-s"><a href="/reference/apex/qry-builder">kern.QRY_Builder</a> · <a href="/reference/apex/dml-builder">kern.DML_Builder</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#qry-builder-security-methods">Hidden fields removed</a><span class="kl-chip-d">stripInaccessible() drops fields the user cannot read from the rows.</span><span class="kl-chip-s"><a href="/reference/apex/qry-builder">kern.QRY_Builder</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/security-guide#creating-custom-selectors-with-sharing-control">System mode stated once per selector</a><span class="kl-chip-d">A selector that must read past the user's access says so in one method, not at every read.</span><span class="kl-chip-s"><a href="/reference/apex/sel-base">kern.SEL_Base</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#always-enforce-crud-fls-in-user-facing-code">Permission check from a Flow</a><span class="kl-chip-d">Check Object Permissions answers read, create, edit and delete for the running user.</span><span class="kl-chip-s"><a href="/reference/apex/flow-checkobjectpermissions">kern.FLOW_CheckObjectPermissions</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#how-do-i-see-who-turned-a-check-off">Every bypass written down</a><span class="kl-chip-d">Each time code turns sharing, a security mode, a trigger or a validation rule off, an audit log entry says who, when and what, and the reason you set, if you set one.</span><span class="kl-chip-s"><a href="/reference/apex/trg-base">kern.TRG_Base</a> · <a href="/reference/metadata/featureflag-mdt">kern__FeatureFlag__mdt</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#org-wide-access-mode-kill-switches">An org-wide switch back</a><span class="kl-chip-d">One flag record each turns user mode off for all queries or all saves, with no deployment.</span><span class="kl-chip-s"><a href="/reference/metadata/featureflag-mdt">kern__FeatureFlag__mdt</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="data-masking" title="Scrub card numbers from your logs without shredding your order IDs" link="/data-masking-guide#the-shipped-rules" linkText="Data Masking Guide → Shipped Rules" wrote="4 lines" caps="8">

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
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/data-masking-guide#the-shipped-rules">Luhn-precise</a><span class="kl-chip-d">Luhn-checked each match: the card redacted, the 16-digit order ID survived.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/data-masking-guide#what-ships-masked-by-default">On by default</a><span class="kl-chip-d">On by default when you log. You configured nothing to get this.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/data-masking-guide#the-shipped-rules">Pre-wired rule</a><span class="kl-chip-d">The replacement reads [CARD_REDACTED], and the rule ships pre-wired, with no Apex.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/data-masking-guide#what-ships-masked-by-default">Covers framework records</a><span class="kl-chip-d">The same rule also masks the framework's outbound-API, API-issue, async-chain, and log records.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/data-masking-guide#masking-records-on-your-own-objects">Point at your own objects</a><span class="kl-chip-d">Aim the same engine at your object with config: a masking target plus the object's toggle, no Apex.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/data-masking-guide#what-ships-masked-by-default">Master kill switch</a><span class="kl-chip-d">A master kill switch disables all framework masking for diagnostics.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/data-masking-guide#the-shipped-rules">14 dormant rule templates</a><span class="kl-chip-d">SSN, AWS keys, IBAN, SWIFT, private IPs and more ship as proven patterns. Activate one by wiring a target and flipping its IsActive flag, with no regex to write.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="performance">Performance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/data-masking-guide#performance">Bulk-safe regex</a><span class="kl-chip-d">The card regex compiles once per transaction, then is reused across every record.</span></div>
</div>

</template>

<template #why>

A blunt regex can't tell a card from any other 16-digit number: it either shreds the order ID alongside the card or, loosened to spare the order ID, lets a real card through.

The shipped rule runs in CreditCard mode and checks each candidate match against a Luhn (mod-10) checksum first. So the valid card (4111 1111 1111 1111) is redacted, while the order ID, which fails Luhn, passes through untouched.

The masking runs on the framework's own `LogEntryEvent__e` before it is published, with nothing to configure.

</template>

</CodeCompare>

</FeatureGroup>

<FeatureGroup id="group-automate" title="Automate" summary="6 examples: triggers, validation rules, background chains, scheduled jobs, Flow actions, feature flags">

<CodeCompare id="triggers" title="One trigger. Metadata-ordered actions. No hand-rolled recursion guards." link="/triggers-guide" linkText="Triggers Guide →" wrote="a 1-line trigger" caps="9">

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

// 3. Order, kill switch, and recursion are CONFIG, not code — kern__TriggerAction__mdt:
//    kern__ApexClassName__c   = TRG_SetAccountRating
//    kern__Event__c           = Before Update
//    kern__Order__c           = 20        // reorder without a deploy
//    kern__BypassExecution__c = false     // flip to true to kill it mid-incident
//    kern__AllowRecursion__c  = false     // shield re-entry (defaults to true)
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/triggers-guide#order-c-required">Config, not code</a><span class="kl-chip-d">Actions dispatch in Order__c sequence, so you reorder them without a deploy.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#bypassexecution-c-subscriber-controlled-1">Per-action kill switch</a><span class="kl-chip-d">Flip BypassExecution__c to kill an action with no deploy.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#object-level-bypass-triggersetting-mdt">Object-level bypass</a><span class="kl-chip-d">Disable every trigger action for an object in one call with TRG_Base.bypass().</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#feature-flag-gating">Feature-flag gating</a><span class="kl-chip-d">Gate an action on a feature flag without touching code.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#flow-as-a-trigger-action">Flow as a step</a><span class="kl-chip-d">Register a Flow as an ordered step in the same pipeline.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#recursion-prevention">Recursion guard</a><span class="kl-chip-d">Set AllowRecursion__c = false to stop the action re-firing on re-entry.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#failure-action-strategies">Failure strategy</a><span class="kl-chip-d">On action failure, choose Block DML or Log and Continue.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#bypass-audit-trail">Bypass audit trail</a><span class="kl-chip-d">Programmatic bypass calls write to the shared audit trail.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="testing">Testing</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#testing-an-action-without-dml">DML-free action tests</a><span class="kl-chip-d">Call an action directly on in-memory rows (TST_Builder/TST_Mock) and mock its selector reads, so you unit-test one rule with no DML.</span></div>
</div>

</template>

<template #why>

A one-line trigger hands off to `TRG_Dispatcher().run()`. It queries the `TriggerAction__mdt` rows for that object and event, sorts them by `Order__c`, and dispatches each to a small single-purpose class through the matching `IF_Trigger` interface.

Because order, bypass, recursion, and flag-gating are *rows* rather than Apex, they change with no redeploy. And because each action just takes a record list, you unit-test one in isolation.

</template>

</CodeCompare>

<CodeCompare id="validation" title="Roll out a validation rule to production that logs violations but never blocks a save" link="/fast-start-custom-validations#shadow-mode" linkText="Custom Validations Fast Start → Shadow Mode" wrote="2 CMDT records + a checkbox" caps="8">

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
// 1. AUTHOR two CMDT records, no Apex: a kern__ValidationRuleGroup__mdt that
//    binds the object + timing (Account · Before · Insert/Update), then a
//    kern__ValidationRule__mdt under it. kern__RuleFormula__c returns TRUE when INVALID.
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

// 3. Watch the blast radius accumulate, then flip kern__ShadowMode__c to
//    false to enforce. Violations land in kern__LogEntry__c tagged [SHADOW].
//    SEL_LogEntries is your own selector: a with sharing class extending kern.SEL_Base.
List<kern__LogEntry__c> shadowViolations = new SEL_LogEntries().query
	.fields(new List<SObjectField>{ kern__LogEntry__c.kern__ShortMessage__c, kern__LogEntry__c.CreatedDate })
	.condition(kern__LogEntry__c.kern__LogLevel__c).equals('WARN')
	.andCondition(kern__LogEntry__c.kern__ShortMessage__c).contains('[SHADOW]')
	.orderBy(kern__LogEntry__c.CreatedDate).descending()
	.withLimit(100)
	.toList();
// Each kern__ShortMessage__c reads: "[SHADOW] Customer_Requires_Contact:
// Customer accounts need a phone". Zero blocked saves.
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/validation-guide#shadow-mode">Shadow mode</a><span class="kl-chip-d">Save never blocked: even with Severity = Error, a shadow violation is logged, not raised.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-custom-validations#shadow-mode">Same deployed formula</a><span class="kl-chip-d">Fires on every in-scope save against the SAME formula, and one checkbox flips shadow to enforce.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/validation-guide#troubleshooting">Throw-safe evaluation</a><span class="kl-chip-d">A formula that throws still won't block the save. The error is logged and swallowed, not rethrown.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/validation-guide#validating-records-in-flow">Same rules, callable from Flow</a><span class="kl-chip-d">An Execute Validation Rules invocable runs the very same formula rules from a Flow and returns errors/warnings without blocking the save.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/validation-guide#querying-shadow-violations">[SHADOW] in ShortMessage__c</a><span class="kl-chip-d">Each would-be violation logged as a WARN tagged [SHADOW] in ShortMessage__c for you to query.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/validation-guide#querying-shadow-violations">Query through a selector</a><span class="kl-chip-d">Inspect shadow rows through a selector, the same way you read everything else.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/validation-guide#shadow-mode">Three documented outcomes</a><span class="kl-chip-d">Severity Error blocks the save, Warning logs it, Shadow logs it regardless of severity.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#who-can-see-the-framework-s-own-records">USER_MODE log read</a><span class="kl-chip-d">The log read runs in USER_MODE by default. Log entries are private on a new install, so run it as someone who can see every entry, such as a holder of the Kern Administrator permission set.</span></div>
</div>

</template>

<template #why>

A native validation rule has two states only: off, or blocking every offending save the instant it is Active. So a new rule meets your dirty production data as a wall of `FIELD_CUSTOM_VALIDATION_EXCEPTION` errors.

With `ShadowMode__c = true` the rule still fires on every in-scope save and evaluates the very same deployed formula, but each would-be violation is written to `LogEntry__c` as a `[SHADOW]` WARN instead of calling `addError()`, so nothing is blocked.

You measure the blast radius from the log, then flip one checkbox to enforce.

</template>

</CodeCompare>

<CodeCompare id="async-chains" title="A governor-limit crash won't leave your chain stuck &quot;Running&quot;" link="/fast-start-async-processing#how-it-works" linkText="Async Processing Fast Start →" wrote="5 lines" caps="10">

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
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/async-processing-guide#monitoring-async-chain-failures">Durable recovery</a><span class="kl-chip-d">An uncatchable governor-limit crash still flips the run to Failed, never a zombie stuck on Running.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-async-processing#how-it-works">Fresh limits per step</a><span class="kl-chip-d">Each step ran in its own Queueable transaction, with a fresh set of governor limits.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/async-processing-guide#error-handling">Callout-capable onError</a><span class="kl-chip-d">An onError handler runs in its own callout-capable transaction, even after the failed step did DML.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/async-processing-guide#what-problem-does-this-solve">Real-time Chain Monitor</a><span class="kl-chip-d">A live UI surfaces running and failed chains without writing a query.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/async-processing-guide#monitoring">Queryable status</a><span class="kl-chip-d">Status persists to an AsyncChainExecution__c row at every transition (Running → Completed/Failed/Aborted).</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/logging-guide#the-whole-action">The whole action in one search</a><span class="kl-chip-d">Every chain run has its own tracking ID, and every entry also carries the ID of the action that started it, so one search brings back the action and every chain it launched.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/async-processing-guide#monitoring">Field-history audit</a><span class="kl-chip-d">Status__c, CompletedSteps__c, CurrentStepName__c, and CompletedAt__c carry field-history, giving a step-by-step trail.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/async-processing-guide#monitoring-async-chain-failures">Durable crash log</a><span class="kl-chip-d">On crash the Finalizer wrote a durable Error log stamped with the failed chain-execution id.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/async-processing-guide#logging-strategy">Quiet when clean</a><span class="kl-chip-d">Logs are reserved for actionable events, so a clean, fast, successful run emits no noise.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="performance">Performance</p>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/async-processing-guide#logging-strategy">Per-step timing</a><span class="kl-chip-d">Each step is timed; a slow step emits a structured performance log with CPU, heap, SOQL, and DML deltas.</span></div>
</div>

</template>

<template #why>

A hand-rolled Queueable that hits an uncatchable governor limit just dies: no `finish()` hook, no error row, status stuck on "Running." The framework attaches a Finalizer to every step, and a Finalizer is guaranteed to run with *fresh* limits even after that crash. So the run is marked Failed with a reason and a correlated log instead of vanishing.

</template>

</CodeCompare>

<CodeCompare id="scheduled-jobs" title="A scheduled job an admin can time and tune from a record" link="/fast-start-scheduled-jobs" linkText="Scheduled Jobs Fast Start →" wrote="1 class + 1 record" caps="14">

<template #lead>

**Why:** saving a Scheduled Job record schedules your class, so nobody runs System.schedule or writes cron by hand. The job declares its settings, and an admin changes them on the record with no deployment.

</template>

<template #before>

```apex
public class CaseArchiveJob implements Schedulable
{
	public void execute(SchedulableContext context)
	{
		CaseArchiveService.archiveOlderThan(90); // change 90? edit and deploy
	}
}
// Then, in anonymous Apex, by someone who knows cron:
System.schedule('Case archive', '0 0 2 * * ?', new CaseArchiveJob());
// To change the time: find the job, stop it, schedule it again.
```

</template>

<template #after>

```apex
// global: KernDX creates this class by name, from its Scheduled Job record
global inherited sharing class CaseArchiveJob extends kern.SCHED_Base
{
	public override List<kern.DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<kern.DTO_ScheduledParameterDefinition>
		{
			kern.DTO_ScheduledParameterDefinition.of('daysToKeep', 'Days to keep').asNumeric().withDefault('90')
		};
	}
	public void execute(SchedulableContext context)
	{
		CaseArchiveService.archiveOlderThan(getNumericParameter('daysToKeep'));
	}
}
// An admin saves a Scheduled Job record: Class Name, Schedule, Days to keep.
```

</template>

<template #footprint>

**You write:** 1 Apex class. **You configure:** 1 `ScheduledJob__c` record.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Operations</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#step-2-schedule-it-with-a-record">Scheduled by a record</a><span class="kl-chip-d">Saving an active Scheduled Job record schedules the class; switching it off unschedules it.</span><span class="kl-chip-s"><a href="/reference/objects/scheduledjob-c">kern__ScheduledJob__c</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#tier-3-production-patterns-5-minutes">Settings an admin can edit</a><span class="kl-chip-d">Each declared parameter becomes a field in the Scheduled Jobs editor. Its value is stored on the record, and your code reads it with a typed getter.</span><span class="kl-chip-s"><a href="/reference/apex/sched-base">kern.SCHED_Base</a> · <a href="/reference/apex/dto-scheduledparameterdefinition">kern.DTO_ScheduledParameterDefinition</a> · <a href="/reference/objects/scheduledjob-c">kern__ScheduledJob__c</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#how-it-works">Next run shown before you save</a><span class="kl-chip-d">The editor fills in your time zone and previews when the job will run next.</span><span class="kl-chip-s"><a href="/reference/objects/scheduledjob-c">kern__ScheduledJob__c</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#step-6-run-it-now-and-read-the-outcome">Run now</a><span class="kl-chip-d">A button on the record runs the job straight away, without moving its next run.</span><span class="kl-chip-s"><code>kern/scheduledJobDetail</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Limits</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/async-processing-guide#running-many-jobs-on-one-job-runner">Many jobs, few scheduled-job slots</a><span class="kl-chip-d">Put jobs on the job runner and they share its few slots, and may run as often as every five minutes.</span><span class="kl-chip-s"><a href="/reference/apex/sched-jobrunner">kern.SCHED_JobRunner</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#tier-3-production-patterns-5-minutes">No run on top of a run</a><span class="kl-chip-d">A run that is due while the last one is still going is skipped and recorded as Skipped, unless you allow it.</span><span class="kl-chip-s"><a href="/reference/objects/scheduledjob-c">kern__ScheduledJob__c</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#tier-3-production-patterns-5-minutes">The important job first</a><span class="kl-chip-d">When several jobs are due together, a lower run priority starts first.</span><span class="kl-chip-s"><a href="/reference/objects/scheduledjob-c">kern__ScheduledJob__c</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#step-7-see-a-failed-run-and-its-log-entry">The outcome of every run</a><span class="kl-chip-d">Each run records Succeeded, Failed, Skipped or Parked on the record, and a failed run links to its log entry.</span><span class="kl-chip-s"><a href="/reference/objects/scheduledjob-c">kern__ScheduledJob__c</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#tier-3-production-patterns-5-minutes">Health Check watches the runner</a><span class="kl-chip-d">Three readings say whether the runner still checks, whether a job waits for a missing runner, and how many slots are in use.</span><span class="kl-chip-s"><code>kern/healthCheck</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-scheduled-jobs#step-3-give-yourself-the-job-runner-permission-set">Only some people use the runner</a><span class="kl-chip-d">Putting a job on the runner, and Run now, need the Kern Job Runner Management permission set.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Ready-made jobs</p>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/async-processing-guide#declarative-scheduling-with-scheduledjob-c">Delete old records</a><span class="kl-chip-d">SCHED_PurgeRecords clears old rows on a schedule, set up with a record only.</span><span class="kl-chip-s"><a href="/reference/apex/sched-purgerecords">kern.SCHED_PurgeRecords</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/security-guide#access-review-primitives">Deactivate unused users</a><span class="kl-chip-d">SCHED_DeactivateUsers switches off users who have not logged in.</span><span class="kl-chip-s"><a href="/reference/apex/sched-deactivateusers">kern.SCHED_DeactivateUsers</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/async-processing-guide#declarative-scheduling-with-scheduledjob-c">Send queued callouts</a><span class="kl-chip-d">SCHED_PerformBatchedCallouts sends queued API calls in batches.</span><span class="kl-chip-s"><a href="/reference/apex/sched-performbatchedcallouts">kern.SCHED_PerformBatchedCallouts</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/async-processing-guide#monitoring-async-chain-failures">Find stuck chains</a><span class="kl-chip-d">SCHED_ChainWatchdog finds background chains that have stopped moving, marks them Stalled and runs their error handling once, so none stays Running for ever.</span><span class="kl-chip-s"><a href="/reference/apex/sched-chainwatchdog">kern.SCHED_ChainWatchdog</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="flow-actions" title="Give a Flow a callout, a feature check and a log entry, with no Apex of your own" link="/web-services-guide#how-do-i-call-it-from-a-flow" linkText="Web Services Guide → Flow actions" beforeLabel="Plain Flow Builder" afterLabel="KernDX in Flow Builder" wrote="0 lines of Apex" caps="12" capsLabel="ready-made actions and gains">

<template #lead>

**Why:** the actions a Flow needs most ship ready to drag in. They run the same framework code as your Apex, so a callout from a Flow is retried, logged and masked exactly like one from Apex.

</template>

<template #before>

```text
Action: Create HTTP Callout     (External Services)
	Named Credential: Posts
	Method: GET     Path: /posts/1
	Sample response → Flow builds the output type
	                → the body as Flow variables

No Apex, and fine for a simple call. What it does not give you:
no retry, no circuit breaker, no API Call record of the request
and response, nothing masked, and no tracking ID shared with the
other log entries of the same Flow run.
A feature check or a log entry still needs an Apex action of your own.
```

</template>

<template #after>

```text
Action: Start Flow Correlation
	Flow Name: Checkout                 → a tracking ID for this run
Action: Is Feature Flag Enabled
	flagNames: NewCheckout              → true or false for this user
Action: Invoke Callout Synchronously
	API Name: API_GetPost               → the same handler as the Apex call
	          → Response Body, API Call Id, success flag
Action: Log Flow Event
	Correlation ID: from the first action
	Message:        Post fetched        → a log entry tied to this run

No Apex class of your own. The callout uses the same handler,
API Setting, retries and masking as the Apex call.
```

</template>

<template #footprint>

**You write:** no Apex (the handler is the one from Outbound services). **You configure:** 4 actions in one Flow.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Integrate</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/web-services-guide#how-do-i-call-it-from-a-flow">Callouts, now or later</a><span class="kl-chip-d">Invoke Callout Synchronously waits for the answer; Invoke Callout Asynchronously queues the call and lets the Flow move on.</span><span class="kl-chip-s"><a href="/reference/apex/flow-callapi">kern.FLOW_CallApi</a> · <a href="/reference/apex/flow-callapiasync">kern.FLOW_CallApiAsync</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#synchronous-callouts-from-screen-flows">The same retries, record and masking</a><span class="kl-chip-d">The callout runs your Apex handler, so it is retried, kept as an API Call record and masked like a call from Apex.</span><span class="kl-chip-s"><a href="/reference/apex/flow-callapi">kern.FLOW_CallApi</a> · <a href="/reference/apex/api-outbound">kern.API_Outbound</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/administration-tools-guide#triage-and-retry-failed-integration-calls">Retry failed calls</a><span class="kl-chip-d">Retry API Issues runs the failed calls of the issues you pick again, in one background job.</span><span class="kl-chip-s"><a href="/reference/apex/flow-retryapiissues">kern.FLOW_RetryApiIssues</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/feature-flags-guide#evaluating-a-flag-in-flows">Check a feature flag</a><span class="kl-chip-d">Is Feature Flag Enabled gives the same answer the Apex check gives, for the running user.</span><span class="kl-chip-s"><a href="/reference/apex/flow-checkfeatureflag">kern.FLOW_CheckFeatureFlag</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/security-guide#always-enforce-crud-fls-in-user-facing-code">Check permissions first</a><span class="kl-chip-d">Check Object Permissions says whether the user can read, create, edit and delete an object, so a screen can hide what they cannot do.</span><span class="kl-chip-s"><a href="/reference/apex/flow-checkobjectpermissions">kern.FLOW_CheckObjectPermissions</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#flow-based-bypass-flow-bypasstrigger">Bypass a trigger, written down</a><span class="kl-chip-d">Trigger Bypass and Is Bypassed switch trigger actions off and on from a Flow; every bypass goes to the audit trail.</span><span class="kl-chip-s"><a href="/reference/apex/flow-bypasstrigger">kern.FLOW_BypassTrigger</a> · <a href="/reference/apex/flow-checktriggerbypassed">kern.FLOW_CheckTriggerBypassed</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/logging-guide#flow-bookend-pattern">Logs tied to one run</a><span class="kl-chip-d">Start Flow Correlation, Log Flow Event and End Flow Correlation give every entry of one Flow run the same tracking ID.</span><span class="kl-chip-s"><a href="/reference/apex/flow-loggerstart">kern.FLOW_LoggerStart</a> · <a href="/reference/apex/flow-loggerlog">kern.FLOW_LoggerLog</a> · <a href="/reference/apex/flow-loggerend">kern.FLOW_LoggerEnd</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/utilities-guide#logging-from-flows-flow-writelog">One detailed log line</a><span class="kl-chip-d">Write Detailed Log Messages writes an entry with the level and details you choose, with no correlation setup.</span><span class="kl-chip-s"><a href="/reference/apex/flow-writelog">kern.FLOW_WriteLog</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Validation</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/validation-guide#validating-records-in-flow">The same validation rules</a><span class="kl-chip-d">Execute Validation Rules runs your formula rules from a Flow and returns errors and warnings without blocking the save.</span><span class="kl-chip-s"><a href="/reference/apex/flow-executevalidationrules">kern.FLOW_ExecuteValidationRules</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/validation-guide#bypassing-validation-in-flow">Bypass a rule for one transaction</a><span class="kl-chip-d">Bypass Validation and Clear Validation Bypass switch rules off for an object, a group or one rule, and the bypass is audited.</span><span class="kl-chip-s"><a href="/reference/apex/flow-bypassvalidation">kern.FLOW_BypassValidation</a> · <a href="/reference/apex/flow-clearvalidationbypass">kern.FLOW_ClearValidationBypass</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Everyday tasks</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/reference/apex/flow-getpicklistvalues">Picklist values for a screen</a><span class="kl-chip-d">Get PickList Values returns the values of a picklist field, ready for a choice list.</span><span class="kl-chip-s"><a href="/reference/apex/flow-getpicklistvalues">kern.FLOW_GetPicklistValues</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/utilities-guide#email-from-flows-flow-sendemail">Email from a template, with an activity</a><span class="kl-chip-d">Send Email (Flow-Delegated) and Log Activity sends a template email and can log it as an activity.</span><span class="kl-chip-s"><a href="/reference/apex/flow-sendemail">kern.FLOW_SendEmail</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="feature-flags" title="Turn a feature on for a pilot group first, with no deployment" link="/fast-start-feature-flags" linkText="Feature Flags Fast Start →" wrote="1 line" caps="9">

<template #lead>

**Why:** a flag is a record, so switching it on, off or for a pilot group is a configuration change the next transaction sees. Apex, Flow and LWC ask the same question and get the same answer, and a flag that does not exist answers false.

</template>

<template #before>

```apex
// A checkbox on your own hierarchy custom setting
Checkout_Settings__c settings = Checkout_Settings__c.getInstance();
if(settings.Use_New_Checkout__c)
{
	newCheckout();
}
// The setting holds an org value, a profile value and a user value,
// with no code. A permission set, a public group or a custom
// permission cannot hold a value, so a pilot is chosen by profile or user.
// The Flow and the LWC each read the setting their own way.
```

</template>

<template #after>

```apex
if(kern.UTIL_FeatureFlag.isEnabled('NewCheckout'))
{
	newCheckout(); // on for a profile, permission set or group, set in records
}
// The same flag, the same answer, everywhere:
//   Flow: the Is Feature Flag Enabled action
//   LWC:  await isFlagEnabled('NewCheckout') from kern/featureFlag
// A flag that does not exist returns false.
```

</template>

<template #footprint>

**You write:** 1 line of Apex. **You configure:** 1 `FeatureFlag__mdt` record, plus `FeatureFlagStrategy__mdt` records to choose the pilot group.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Rollout</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/feature-flags-guide#strategy-types">Pilot before going wide</a><span class="kl-chip-d">Target a custom permission, a profile, a permission set, a public group, a custom setting or custom metadata.</span><span class="kl-chip-s"><a href="/reference/metadata/featureflagstrategy-mdt">kern__FeatureFlagStrategy__mdt</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/feature-flags-guide#how-does-it-work">No deployment to switch</a><span class="kl-chip-d">Change the record and the next transaction sees it.</span><span class="kl-chip-s"><a href="/reference/apex/util-featureflag">kern.UTIL_FeatureFlag</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/feature-flags-guide#evaluation-order">Safe when missing</a><span class="kl-chip-d">A flag name that matches no active flag returns false, so new code stays off.</span><span class="kl-chip-s"><a href="/reference/apex/util-featureflag">kern.UTIL_FeatureFlag</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/feature-flags-guide#custom-strategy-handlers">Your own rule</a><span class="kl-chip-d">A strategy can call a class of yours, for logic no record type covers.</span><span class="kl-chip-s"><a href="/reference/apex/util-featureflag-int-featureflagstrategy">kern.UTIL_FeatureFlag.INT_FeatureFlagStrategy</a> · <a href="/reference/apex/util-featureflag-int-userawarefeatureflagstrategy">kern.UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/feature-flags-guide#specific-user-check">Ask for another user</a><span class="kl-chip-d">Check a flag for a user by Id or username, not only the running user.</span><span class="kl-chip-s"><a href="/reference/apex/util-featureflag">kern.UTIL_FeatureFlag</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">One answer</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/feature-flags-guide#evaluating-a-flag-in-lwc">Apex, Flow and LWC agree</a><span class="kl-chip-d">All three go through the same check for the running user.</span><span class="kl-chip-s"><a href="/reference/apex/flow-checkfeatureflag">kern.FLOW_CheckFeatureFlag</a> · <code>kern/featureFlag</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/triggers-guide#feature-flag-bypass">Gates triggers, rules and APIs too</a><span class="kl-chip-d">Trigger actions, validation rules and API settings name a flag that must be on, or one that bypasses them, with no code.</span><span class="kl-chip-s"><a href="/reference/metadata/triggeraction-mdt">kern__TriggerAction__mdt</a> · <a href="/reference/metadata/validationrule-mdt">kern__ValidationRule__mdt</a> · <a href="/reference/metadata/apisetting-mdt">kern__ApiSetting__mdt</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="performance">Performance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/feature-flags-guide#performance-and-soql-cost">One query for every flag</a><span class="kl-chip-d">The first check of a transaction loads all active flags at once; later checks reuse them.</span><span class="kl-chip-s"><a href="/reference/apex/util-featureflag">kern.UTIL_FeatureFlag</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="testing">Testing</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/feature-flags-guide#seeding-a-flag-in-memory">A flag made in the test</a><span class="kl-chip-d">TST_Factory makes an on or off flag in memory, so a test covers both paths with no metadata deployed.</span><span class="kl-chip-s"><a href="/reference/apex/tst-factory">kern.TST_Factory</a></span></div>
</div>

</template>

</CodeCompare>

</FeatureGroup>

<FeatureGroup id="group-integrate" title="Integrate" summary="4 examples: outbound services, resilient callouts, inbound APIs, logging">

<CodeCompare id="outbound-calls" title="Write a service once as a handler class, and let every Apex caller and Flow share it" link="/fast-start-outbound-apis" linkText="Outbound APIs Fast Start →" wrote="1 class + 1 record" caps="13">

<template #lead>

**Why:** an `API_Outbound` handler is one small class for one service: what it sends and how it reads the answer. Its API Setting record (custom metadata) holds the endpoint path, the retry count and the circuit breaker switch.

Every caller, from Apex, a Flow or a background job, uses the same class and the same record, so a change is made once and needs no deployment. Every call is kept as an API Call record with its request and response.

</template>

<template #before>

```apex
HttpRequest request = new HttpRequest();
request.setEndpoint('callout:Posts/posts/1');
request.setMethod('GET');
request.setTimeout(10000);
HttpResponse response = new Http().send(request);
String post = response.getBody();
// This block is copied into every class that calls the service,
// and a Flow needs an Apex action of its own around it.
// The path and timeout live in code: a change means a deploy.
// No saved record of the call, nothing masked.
```

</template>

<template #after>

```apex
// global: KernDX creates this class by name, from its API Setting record
global with sharing class API_GetPost extends kern.API_Outbound
{
	public override void configure()
	{
		super.configure();
		requiresTriggeringRecord = false; // no record starts this call
	}
	public override kern.API_Base.HttpMethod getHttpMethod()
	{
		return kern.API_Base.HttpMethod.GET;
	}
}
// Its API Setting record holds Class Name (API_GetPost), Endpoint Path (/posts/1),
// Max Retry Count and Circuit Breaker Enabled. Any Apex caller:
kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_GetPost.class).invoke();
String post = handler.result.responseBody; // kept as an API Call record
// A Flow calls the same class with Invoke Callout Synchronously.
```

</template>

<template #footprint>

**You write:** 1 Apex class. **You configure:** 1 `ApiSetting__mdt` record, and 1 `ApiCredential__mdt` record that names your Named Credential.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/web-services-guide#apisetting-mdt-custom-metadata-type">Retries set in configuration</a><span class="kl-chip-d">Max Retry Count and Retry Backoff (sec) on the API Setting record decide how often a failed call is sent again, for every caller at once.</span><span class="kl-chip-s"><a href="/reference/apex/api-outbound">kern.API_Outbound</a> · <a href="/reference/metadata/apisetting-mdt">kern__ApiSetting__mdt</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#circuit-breaker-pattern">Circuit breaker by checkbox</a><span class="kl-chip-d">Tick Circuit Breaker Enabled and the framework stops calling a failing system for a cool-off, then tries again.</span><span class="kl-chip-s"><a href="/reference/metadata/apisetting-mdt">kern__ApiSetting__mdt</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/web-services-guide#api-dispatcher-usage">Callouts before saves</a><span class="kl-chip-d">The dispatcher makes every callout first and saves after, so you never see "uncommitted work pending".</span><span class="kl-chip-s"><a href="/reference/apex/api-dispatcher">kern.API_Dispatcher</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#where-things-are-logged">A failure record when retries run out</a><span class="kl-chip-d">A call that still fails is saved as an API issue you can retry later.</span><span class="kl-chip-s"><a href="/reference/apex/api-base">kern.API_Base</a> · <a href="/reference/objects/apiissue-c">kern__ApiIssue__c</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#where-things-are-logged">Every call kept</a><span class="kl-chip-d">Each call is saved as an API Call record with its request, its response and how long it took.</span><span class="kl-chip-s"><a href="/reference/apex/api-base">kern.API_Base</a> · <a href="/reference/apex/api-dispatcher">kern.API_Dispatcher</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#automatic-web-service-context">A tracking ID on every call</a><span class="kl-chip-d">Each API Call record keeps the trace ID the call sent, and the log entries written while it ran carry that same ID, so you go from the call to its logs.</span><span class="kl-chip-s"><a href="/reference/apex/api-outbound">kern.API_Outbound</a> · <a href="/reference/objects/apicall-c">kern__ApiCall__c</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#performance-monitoring">Every call timed</a><span class="kl-chip-d">The call record keeps the callout, handler, save and total time in milliseconds.</span><span class="kl-chip-s"><a href="/reference/apex/api-dispatcher">kern.API_Dispatcher</a> · <a href="/reference/objects/apicall-c">kern__ApiCall__c</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#maskingrule-mdt-maskingtarget-mdt">Masked before it is saved</a><span class="kl-chip-d">Card numbers and secret keys are removed from the saved request and response.</span><span class="kl-chip-s"><a href="/reference/metadata/maskingrule-mdt"><code>kern__MaskingRule__mdt</code></a>: the Mask Secret Key Fields in JSON and Mask Payment Card Numbers rules</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#apiruntimeswitch-c-hierarchy-custom-setting">Emergency off switch</a><span class="kl-chip-d">One feature flag stops all API calls, with no deployment. It reads the API Runtime Switch hierarchy setting, so you set it for one user, a profile or the whole org.</span><span class="kl-chip-s"><a href="/reference/apex/api-base">kern.API_Base</a> · <a href="/reference/objects/apiruntimeswitch-c">kern__ApiRuntimeSwitch__c</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/web-services-guide#named-credentials">Endpoint and credential out of code</a><span class="kl-chip-d">The path sits on the API Setting record and the credential in a Named Credential, so neither is in your class.</span><span class="kl-chip-s"><a href="/reference/metadata/apisetting-mdt">kern__ApiSetting__mdt</a> · <a href="/reference/metadata/apicredential-mdt">kern__ApiCredential__mdt</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="testing">Testing</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#mock-mode-and-api-mockfactory">Mock answers without code</a><span class="kl-chip-d">Tick Mocking Enabled on a service and it answers with mock data for chosen users, with no live endpoint.</span><span class="kl-chip-s"><a href="/reference/apex/api-base">kern.API_Base</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Background work</p>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/web-services-guide#how-do-i-call-it-from-a-flow">Same handler, in the background</a><span class="kl-chip-d">Save a queued API Call record and the framework runs the same handler later, then logs the result.</span><span class="kl-chip-s"><a href="/reference/objects/apicall-c">kern__ApiCall__c</a> · <a href="/fast-start-outbound-apis">Outbound APIs Fast Start</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/dtos-guide#dtos-in-rest-apis">Typed request and response</a><span class="kl-chip-d">The handler's request and response are DTOs, so the body is a class, not a map.</span><span class="kl-chip-s"><a href="/reference/apex/api-outbound">kern.API_Outbound</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="resilient-callouts" title="Retry, circuit breaker and a test mock for one callout, in one chain" link="/fast-start-resilience#step-1-make-a-resilient-callout" linkText="Resilience Fast Start → Resilient Callout" wrote="10 lines" caps="10">

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
	.withIdempotencyKey(chargeRequest.orderNumber) // the same key on every attempt: any value unique to this charge, such as its order number
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
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/fast-start-resilience#retry-built-into-a-callout">Retry that knows what is safe</a><span class="kl-chip-d">Re-sends a 408 or 503 at once, and a 500, 502 or 504 too, because the call carries an idempotency key (one ID sent with every attempt, so the other system can spot a repeat). You never typed the loop or the codes.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#automatic-retries">Async re-drive</a><span class="kl-chip-d">Still failing? The call is persisted and a scheduled Flow re-drives it at a backoff date.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/resilience-guide#platform-cache-and-cross-transaction-state">Cross-transaction breaker</a><span class="kl-chip-d">Circuit-breaker state lives in Platform Cache, keyed by the credential, shared across transactions.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#data-masking">Masked before save</a><span class="kl-chip-d">Card and secret-key rules redact Request__c / Response__c before the ApiCall__c row is saved.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#accessing-large-payloads">Large-payload overflow</a><span class="kl-chip-d">A body too large for the field overflows to a ContentVersion file, masked the same way.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#where-things-are-logged">Audit in SYSTEM_MODE</a><span class="kl-chip-d">The whole audit write runs in SYSTEM_MODE, fixed up front and not overridable per-call.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#where-things-are-logged">Failure records on exhaustion</a><span class="kl-chip-d">On retry exhaustion it persists an ApiIssue__c record (when failure logging is enabled).</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#failures-and-retries">Says when it may have landed</a><span class="kl-chip-d">When a request that is not safe to repeat fails after it may have reached the other system, its API issue is marked External System May Have Acted, so nobody sends it again without checking first.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="testing">Testing</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#api-mockfactory-programmatic-mocking">One-line mock</a><span class="kl-chip-d">API_MockFactory.forService(...).register() replaces the whole HttpCalloutMock + Test.setMock.</span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/web-services-guide#call-verification">Verify what was sent</a><span class="kl-chip-d">Assert a mock was called and the last request body contained the right field, Mockito-style, with no captor wiring.</span></div>
</div>

</template>

<template #why>

The non-obvious part: a transient 5xx comes back *on* the response rather than thrown, and because the call carries an idempotency key, the framework knows a repeat is safe. Once in-transaction retries are spent, the call is saved so a scheduled Flow can send it again at a backoff date.

Without a key, a POST that got a 500, 502 or 504 is not sent again, because the other system may already have charged the card.

The resilience outlives the original transaction. After repeated failures the framework stops calling a failing dependency for a cool-off, then resumes (a circuit breaker). That state lives in Platform Cache keyed by the credential, so a dependency that's down stays shorted across transactions, not just within one.

</template>

</CodeCompare>

<CodeCompare id="inbound-apis" title="Reject a replayed request with a changed body: HTTP 409, automatically" link="/fast-start-inbound-apis#idempotency" linkText="Inbound APIs Fast Start → Idempotency" wrote="1 handler + a checkbox" caps="9">

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
//   • same key + CHANGED body → HTTP 409, names the original kern__ApiCall__c.Id
//   • new key                 → fresh processing
// All three outcomes, zero dedupe code. INBOUND, body-hash based.
```

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/web-services-guide#idempotency-inbound-apis">Body-hash dedupe</a><span class="kl-chip-d">Same key + changed body → HTTP 409 naming the original ApiCall__c.Id.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#idempotency-inbound-apis">Cached replay</a><span class="kl-chip-d">Same key + same body → cached HTTP 200, your handler never re-runs.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#idempotency-inbound-apis">One-checkbox SHA-256</a><span class="kl-chip-d">The dedupe is a SHA-256 hash of the body, turned on by one config checkbox.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#idempotency-inbound-apis">Completed-only match</a><span class="kl-chip-d">Replay matches the indexed Idempotency-Key, only against requests that completed successfully.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#idempotency-inbound-apis">Inbound, not outbound</a><span class="kl-chip-d">This is INBOUND body-hash idempotency. Outbound uses an explicit idempotency key you set, not a body hash.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#failures-and-retries">Replay a failed request on purpose</a><span class="kl-chip-d">A failed inbound request is saved on an API issue (the error record KernDX keeps) with its path, method and body. Press Retry on the issue, or Retry Selected on the API Issues list for many at once, to run it through your handler again as a new call. Unlike Cached replay, this does re-run your handler.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#apicall-c-custom-object">Recorded on ApiCall__c</a><span class="kl-chip-d">The hit is recorded on the ApiCall__c record (IsIdempotencyHit__c + body-hash).</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/web-services-guide#automatic-web-service-context">Correlation id first</a><span class="kl-chip-d">A W3C correlation id is set on every request, before the idempotency check runs.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-inbound-apis#feature-flag-gating">Feature-flag-gated endpoint</a><span class="kl-chip-d">Name a flag in RequiredFeatureFlag__c and a disabled inbound API aborts automatically, so you can take a live endpoint offline by toggling a flag, with no redeploy.</span></div>
</div>

</template>

<template #why>

A naive hand-rolled dedupe checks only that the key was seen before, never that the body still matches, so a retry that mutates the payload under the same key double-charges in silence.

The framework instead stores a SHA-256 hash of the request body next to the (External-ID-indexed) Idempotency-Key, so a replay with a changed body is *detectable*: it returns HTTP 409 naming the original `ApiCall__c.Id`, while an identical replay returns the cached 200 without re-running your handler.

This is inbound body-hash idempotency. Outbound instead uses an explicit idempotency key you stamp via `UTIL_HttpClient.withIdempotencyKey()`.

</template>

</CodeCompare>

<CodeCompare id="logging" title="Log an error that survives the rollback that erased the record" link="/fast-start-logging" linkText="Logging Fast Start →" wrote="4 lines" caps="8">

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
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/logging-guide#how-does-it-work">Rollback-proof</a><span class="kl-chip-d">Published as a platform event, so the saved log outlives the rollback that erases the payment.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/logging-guide#log-buffering">ERROR flushes early</a><span class="kl-chip-d">An ERROR-level entry is never held in the suspended-save buffer; it flushes before the re-throw.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/logging-guide#performance-logging">Governor-limit snapshot</a><span class="kl-chip-d">Snapshots every limit (SOQL, DML, CPU, heap, callouts, each as used of maximum) onto the row.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/logging-guide#correlation-tracking">Correlation id</a><span class="kl-chip-d">One startCorrelation() stamps a shared id on every log, so you query the whole flow by that one id.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/logging-guide#async-context-propagation">Correlation survives the async hop</a><span class="kl-chip-d">serializeContext() / hydrateContext() carry the correlation id across a Queueable, Batch, or Future, so one flow stays joinable.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/logging-guide#who-wrote-an-entry">Who wrote it</a><span class="kl-chip-d">Records who wrote the entry (Framework, Apex, Flow or Component) and which class, Flow or component, plus the context (trigger, REST, batch…) and the running user.</span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-logging#log-an-exception-with-full-stack-trace">Exception detail</a><span class="kl-chip-d">Records the exception type, the full stack trace, and the failing line number.</span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-logging#sensitive-data-is-masked-by-default">Masked by default</a><span class="kl-chip-d">Runs the row through the masking framework before publish, on by default.</span></div>
</div>

</template>

<template #why>

The log is published as a platform event committed to the event bus *immediately*, independent of your transaction, so the rollback that erases the payment can't un-publish the record of *why* it failed. A plain `insert Error_Log__c` shares the failing transaction and is undone by the very rollback the re-throw triggers.

</template>

</CodeCompare>

</FeatureGroup>

<FeatureGroup id="group-build-test-and-run" title="Build, test and run" summary="5 examples: Lightning web components, test data, code scanning, Platform Cache, admin consoles">

<CodeCompare id="lwc" title="A component with toasts and navigation, without wiring either" link="/fast-start-lwc" linkText="LWC Fast Start →" beforeLabel="Plain LWC" wrote="1 base class" caps="12">

<template #lead>

**Why:** ComponentBuilder is a base class with the common wiring already built in: toasts, Apex calls, navigation, the message service and Flow navigation. You name the parts a component uses, and each one is one method call.

</template>

<template #before>

```js
import {LightningElement} from 'lwc';
import {NavigationMixin} from 'lightning/navigation';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

export default class AccountCard extends NavigationMixin(LightningElement)
{
	handleSaved(event)
	{
		this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Saved', variant: 'success'}));
		this[NavigationMixin.Navigate]({type: 'standard__recordPage',
			attributes: {recordId: event.detail.id, actionName: 'view'}});
	}
}
```

</template>

<template #after>

```js
import {ComponentBuilder} from 'kern/componentBuilder';

// Ask only for the parts this component uses
export default class AccountCard extends ComponentBuilder('notification', 'navigation')
{
	handleSaved(event)
	{
		this.showSuccessToast('Saved');
		this.redirectToRecordPage(event.detail.id);
	}
}
```

</template>

<template #footprint>

**You write:** 1 Lightning web component. **You configure:** nothing.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Less code</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/lwc-guide#componentbuilder-pattern">Only the parts you name</a><span class="kl-chip-d">ComponentBuilder('notification', 'navigation') switches on those two modules and nothing else.</span><span class="kl-chip-s"><code>kern/componentBuilder</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/lwc-guide#notification-methods">Toasts in one call</a><span class="kl-chip-d">showSuccessToast, showInfoToast, showWarningToast and showErrorToast; the error one also reads an Apex error for you.</span><span class="kl-chip-s"><code>kern/moduleNotification</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/lwc-guide#navigation-methods">Navigation in one call</a><span class="kl-chip-d">redirectToRecordPage opens a record; generateRecordPageURL returns its link.</span><span class="kl-chip-s"><code>kern/moduleNavigation</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/lwc-guide#controller-methods">Apex calls that handle their errors</a><span class="kl-chip-d">callControllerMethod logs a failure and shows an error toast, unless you ask it to throw.</span><span class="kl-chip-s"><code>kern/moduleController</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Built in too</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/lwc-guide#lightning-message-service-methods">Message service and Flow navigation</a><span class="kl-chip-d">Ask for 'lightning-message' or 'flow-navigation' and those are wired the same way.</span><span class="kl-chip-s"><code>kern/moduleLightningMessageService</code> · <code>kern/moduleFlowNavigation</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/lwc-guide#featureflag-feature-flag-bridge">Feature flags in a component</a><span class="kl-chip-d">isFlagEnabled gives the same answer as the Apex and Flow checks.</span><span class="kl-chip-s"><code>kern/featureFlag</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/lwc-guide#utility-modules">Everyday helpers</a><span class="kl-chip-d">Ready-made string, array and error helpers, such as turning Apex errors into one readable message.</span><span class="kl-chip-s"><code>kern/utilityString</code> · <code>kern/utilityArray</code> · <code>kern/utilitySystem</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/lwc-guide#complete-component-inventory">A ready-made table</a><span class="kl-chip-d">paginatedTable pages, sorts and selects rows for you.</span><span class="kl-chip-s"><code>kern/paginatedTable</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/lwc-guide#flow-screen-components">Flow screen parts</a><span class="kl-chip-d">A Flow footer and a JSON viewer drop into Flow screens as they are.</span><span class="kl-chip-s"><code>kern/flowFooter</code> · <code>kern/jsonViewer</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/lwc-guide#correlation-tracking">Browser logs joined to server logs</a><span class="kl-chip-d">The logger saves component logs in Salesforce under the same tracking ID as the Apex they called.</span><span class="kl-chip-s"><code>kern/utilityLogger</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/lwc-guide#performance-timing">Time a step in the browser</a><span class="kl-chip-d">startTimer measures how long a step takes and logs it with the other entries.</span><span class="kl-chip-s"><code>kern/utilityLogger</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/lwc-guide#server-integration">Saved like an Apex log</a><span class="kl-chip-d">Browser entries are written through the same Apex log builder, so they are masked and searchable like any other entry.</span><span class="kl-chip-s"><code>kern/utilityLogger</code> · <a href="/reference/apex/log-builder">kern.LOG_Builder</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="test-data" title="Two hundred test records in one line, or none at all" link="/fast-start-test-data" linkText="Test Data Fast Start →" wrote="2 chains" caps="14">

<template #lead>

**Why:** Salesforce has no built-in test-data factory. Test.loadData loads rows from a CSV file kept as a static resource, but the file must carry every required field and is one more thing to keep in step with the org, so most teams build records by hand.

The builder fills required fields for you, saves a list with one save, and can skip the database by handing a selector pretend rows.

</template>

<template #before>

```apex
List<Account> accounts = new List<Account>();
for(Integer i = 0; i < 200; i++)
{
	accounts.add(new Account(Name = 'Test ' + i, Industry = 'Technology'));
	// ...and every required field your org added, by hand
}
insert accounts;
// To test the code that reads them, the rows must really be saved:
// there is no way to hand a query pretend rows.
```

</template>

<template #after>

```apex
// 200 Accounts, required fields filled in, saved with one save
List<SObject> accounts = kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Industry, 'Technology')
	.withCount(200)
	.buildList();

// SEL_Accounts is your own selector: a with sharing class extending kern.SEL_Base.
// Or no database at all: the next Account read in this test gets these
kern.TST_Mock.of(Account.SObjectType).withCount(3).buildList();
List<SObject> found = new SEL_Accounts().query.toList(); // the 3 mock rows
```

</template>

<template #footprint>

**You write:** test code only. **You configure:** nothing.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Speed</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/selectors-guide#mocking-with-tst-mock">Pretend query results</a><span class="kl-chip-d">TST_Mock rows come back from the next query for that object, with mock Ids and no save.</span><span class="kl-chip-s"><a href="/reference/apex/tst-mock">kern.TST_Mock</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/test-data-guide#insertion-modes">Records without the database</a><span class="kl-chip-d">withoutInsertion(true) builds records in memory with valid mock Ids.</span><span class="kl-chip-s"><a href="/reference/apex/tst-builder">kern.TST_Builder</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/test-data-guide#bulk-creation">One save for the whole list</a><span class="kl-chip-d">withCount(n).buildList() saves many records together, so bulk tests stay inside the limits.</span><span class="kl-chip-s"><a href="/reference/apex/tst-builder">kern.TST_Builder</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#mocking-with-tst-mock">Pretend totals and groups</a><span class="kl-chip-d">registerAggregateRows answers a grouped query (sums or counts per group) with the rows you give it.</span><span class="kl-chip-s"><a href="/reference/apex/tst-mock">kern.TST_Mock</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Less setup</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/test-data-guide#copy-this-first">Required fields filled in</a><span class="kl-chip-d">You set only the fields your test is about.</span><span class="kl-chip-s"><a href="/reference/apex/tst-builder">kern.TST_Builder</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/test-data-guide#relationships">Parent and children together</a><span class="kl-chip-d">withChildren builds the children and links them to the parent for you.</span><span class="kl-chip-s"><a href="/reference/apex/tst-builder">kern.TST_Builder</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/test-data-guide#token-maps-vs-string-maps">Field typos caught when you save the class</a><span class="kl-chip-d">withOverride takes a field token such as Account.Industry, so a wrong name will not compile.</span><span class="kl-chip-s"><a href="/reference/apex/tst-builder">kern.TST_Builder</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/test-data-guide#cycling-values-across-records">Values spread across the list</a><span class="kl-chip-d">withCycle repeats a list of values over the records, so no index sums.</span><span class="kl-chip-s"><a href="/reference/apex/tst-builder">kern.TST_Builder</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/test-data-guide#record-types">A record type by name</a><span class="kl-chip-d">withRecordType takes the developer name and finds the Id for you.</span><span class="kl-chip-s"><a href="/reference/apex/tst-builder">kern.TST_Builder</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Shared setup</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/test-data-guide#users-and-permission-sets">Users with their permissions</a><span class="kl-chip-d">TST_Factory makes users and assigns permission sets or groups in one or two calls.</span><span class="kl-chip-s"><a href="/reference/apex/tst-factory">kern.TST_Factory</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/test-data-guide#feature-flags">Feature flags on or off</a><span class="kl-chip-d">Make a flag in memory for the test, on or off, with nothing deployed.</span><span class="kl-chip-s"><a href="/reference/apex/tst-factory">kern.TST_Factory</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Failure paths</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/selectors-guide#mocking-with-tst-mock">Make a read fail on purpose</a><span class="kl-chip-d">throwsException makes the next read of an object throw, so you can test your error handling.</span><span class="kl-chip-s"><a href="/reference/apex/tst-mock">kern.TST_Mock</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/web-services-guide#mock-mode-and-api-mockfactory">A callout answer in one line</a><span class="kl-chip-d">API_MockFactory gives an API handler a pretend response, and tells you whether it was called.</span><span class="kl-chip-s"><a href="/reference/apex/api-mockfactory">kern.API_MockFactory</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="observability">Observability</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/test-data-guide#logger-configuration">Check what was logged</a><span class="kl-chip-d">Set ignoreTestMode and the test keeps its log entries, written by the same code as in production.</span><span class="kl-chip-s"><a href="/reference/apex/log-builder">kern.LOG_Builder</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="code-scanning" title="Catch a query that skips the selector before it is merged, not in review" link="/fast-start-code-scanning" linkText="Code Scanning Fast Start →" beforeLabel="Plain Salesforce Code Analyzer and code review" afterLabel="KernDX rules in Code Analyzer" wrote="1 scan" caps="16" capsLabel="checks you didn't write">

<template #lead>

**Why:** KernDX ships PMD rules (checks that read your Apex and report a pattern) that know its own way of working. Salesforce Code Analyzer runs them next to its standard rules, in your editor or in CI, and each finding says what to write instead.

</template>

<template #before>

```apex
// Your team agreed: every read goes through a selector.
public with sharing class CaseService
{
	public static List<Case> openCases()
	{
		return [SELECT Id, Subject FROM Case WHERE IsClosed = false WITH USER_MODE];
	}
}
// The standard rules check security and general style. This query
// runs in user mode, so the security rules have nothing to report:
// they do not know your team's rule. The rule lives in a wiki, and
// a reviewer has to spot every break of it, in every pull request.
```

</template>

<template #after>

```text
sf code-analyzer run --config-file code-analyzer.yml --target force-app/ --view detail

// The finding, shortened:
CaseService.cls line 6   KernNoInlineSOQL   severity 2 (High)
	Inline SOQL is not allowed. Read through a selector (SEL_*),
	or its query property for a custom query.

// What the message points you to. SEL_Cases is your own selector:
// a with sharing class extending kern.SEL_Base.
return (List<Case>)new SEL_Cases().query
	.condition(Case.IsClosed).equals(false)
	.toList();
```

</template>

<template #footprint>

**You write:** nothing. **You configure:** copy `kerndx-pmd-ruleset.xml` into a `scanner` folder and add a `code-analyzer.yml` file, or run the bundle's `kerndx init`, which writes both.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Framework patterns</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Reads through selectors</a><span class="kl-chip-d">KernNoInlineSOQL flags an inline query or Database.query, test classes too.</span><span class="kl-chip-s"><code>KernNoInlineSOQL</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Saves through DML_Builder</a><span class="kl-chip-d">KernNoDirectDML flags insert, update, delete, upsert and undelete written by hand.</span><span class="kl-chip-s"><code>KernNoDirectDML</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Logs and callouts the KernDX way</a><span class="kl-chip-d">KernNoSystemDebug points to LOG_Builder; KernNoRawHttp points to UTIL_HttpClient.</span><span class="kl-chip-s"><code>KernNoSystemDebug</code> · <code>KernNoRawHttp</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Jobs through SCHED_Base</a><span class="kl-chip-d">KernUseSchedulerBase and KernNoRawSchedule flag a plain Schedulable and System.schedule.</span><span class="kl-chip-s"><code>KernUseSchedulerBase</code> · <code>KernNoRawSchedule</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">One trigger, one line</a><span class="kl-chip-d">A trigger that does more than hand over to the dispatcher is reported.</span><span class="kl-chip-s"><code>KernTriggerMustDelegate</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Cache, describes, crypto, email and events</a><span class="kl-chip-d">Raw platform calls for these are reported and pointed to the KernDX helper that wraps them.</span><span class="kl-chip-s"><code>KernNoRawCache</code> · <code>KernNoRawDescribe</code> · <code>KernNoRawCrypto</code> · <code>KernNoRawEmail</code> · <code>KernNoRawEventPublish</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Limits</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Limits read through one helper</a><span class="kl-chip-d">A raw Limits call is reported, so every limit check goes through the same wrapper.</span><span class="kl-chip-s"><code>KernLimitsThroughWrapper</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Tests and security</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Tests that really test</a><span class="kl-chip-d">KernNoCoverageTheatre flags a test with no assertion or an empty catch; KernNoBooleanExceptionThrown flags a flag set in a catch.</span><span class="kl-chip-s"><code>KernNoCoverageTheatre</code> · <code>KernNoBooleanExceptionThrown</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/code-scanning-guide#suppression">Exemptions need a reason</a><span class="kl-chip-d">Switching off the coverage check is itself reported, so a reviewer looks for the comment that says why.</span><span class="kl-chip-s"><code>KernCoverageExemptRequiresReason</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Test data through the builder</a><span class="kl-chip-d">Hand-built test records and inline saves in tests are reported.</span><span class="kl-chip-s"><code>KernUseTestBuilder</code> · <code>KernNoInlineDmlInTests</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Bypasses marked for review</a><span class="kl-chip-d">KernSecurityBypassCallSite flags each place that bypasses sharing or field security, so someone confirms it.</span><span class="kl-chip-s"><code>KernSecurityBypassCallSite</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/code-scanning-guide#pmd-rule-summary-table">Problems that show only after install</a><span class="kl-chip-d">An invocable class with no empty constructor, or a JSON class without JsonAccess, is reported before it fails in another org.</span><span class="kl-chip-s"><code>KernInvocableClassNeedsNoArgConstructor</code> · <code>KernJsonReadClassNeedsJsonAccess</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Beyond Apex</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/code-scanning-guide#eslint-rules-lwc">The same for components</a><span class="kl-chip-d">The ESLint plugin asks for ComponentBuilder and flags text a user sees that is not in a label.</span><span class="kl-chip-s"><code>kerndx/use-component-builder</code> · <code>kerndx/no-hardcoded-user-text</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/code-scanning-guide#naming-validator-flows-custom-objects">Flows and objects named one way</a><span class="kl-chip-d">A naming check reads Flows and custom objects, which PMD and ESLint cannot.</span><span class="kl-chip-s"><code>scanner/validate-naming.js</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/code-scanning-guide#building-org-specific-rules">Your own naming rules</a><span class="kl-chip-d">A shipped template shows how to add PMD rules for your org's names.</span><span class="kl-chip-s"><code>scanner/subscriber-naming-pmd-ruleset.xml</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Review and CI</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/fast-start-code-scanning#ci-cd-integration">Fail the build when you choose</a><span class="kl-chip-d">A scan only reports until you add --severity-threshold; then findings at that level fail the CI job.</span><span class="kl-chip-s"><a href="/fast-start-code-scanning">Code Scanning Fast Start</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="cache" title="Keep a slow result in Platform Cache, without key rules or a missing cache breaking the call" link="/utilities-guide#platform-cache-framework-util-cache" linkText="Utilities Guide → Platform Cache" wrote="1 store" caps="11">

<template #lead>

**Why:** Platform Cache keeps a value between requests, so you skip a slow query or callout the next time. UTIL_Cache puts a safe layer over it: it tries the session cache, then the org cache, accepts any key, zips large values, and returns null or false instead of throwing when no cache is there.

The package brings its own partition (a share of the cache), named Library and shown in Setup as LibraryCache.

</template>

<template #before>

```apex
Cache.OrgPartition partition = Cache.Org.getPartition('local.Rates');
Object rates = partition.get('usdToEur');
if(rates == null)
{
	rates = RateService.fetch();
	partition.put('usdToEur', rates, 3600);
}
// A key may hold only letters and digits, 50 at most: 'usd-to-eur' fails.
// A value over 100KB is refused; nothing is zipped for you.
// A partition name that does not exist throws, at every call.
// A value per user? Build the key with the user Id yourself.
```

</template>

<template #after>

```apex
kern.UTIL_Cache.Store cache = kern.UTIL_Cache.auto(); // session cache, then org cache
Object rates = cache.get('usd-to-eur');               // any key: a long or odd one is hashed
if(rates == null)
{
	rates = RateService.fetch();
	cache.put('usd-to-eur', rates, 3600);             // zipped when it is large
}
// No cache space? get returns null and put returns false; nothing throws.
kern.UTIL_Cache.OperationResult result = cache.getLastOperationResult();
// result.status says what happened, and errorMessage says why.
// Your own partition instead: kern.UTIL_Cache.partition('local.Rates')
```

</template>

<template #footprint>

**You write:** a few calls in your own class. **You configure:** space for the `kern.Library` partition in Setup (Platform Cache).

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="reliability">Reliability</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/utilities-guide#auto-cache-intelligent-selection">Session first, then org</a><span class="kl-chip-d">auto() uses the session cache when there is one and the org cache when there is not, for example in a background job.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/utilities-guide#graceful-fallback-handling">Nothing throws</a><span class="kl-chip-d">A missing partition or no cache space gives null or false, and getLastOperationResult() says why.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/utilities-guide#graceful-fallback-handling">A soft fallback when you want one</a><span class="kl-chip-d">autoWithTransactionFallback() keeps the value in memory for this transaction when Platform Cache has no space.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/utilities-guide#testing-cache-availability">Ask before you rely on it</a><span class="kl-chip-d">isAvailable and isAllocated say whether a cache is there and has space.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Less code</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/utilities-guide#use-consistent-key-naming">Any key works</a><span class="kl-chip-d">A key that is long or holds other characters is turned into one the platform accepts.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/utilities-guide#automatic-compression">Large values zipped</a><span class="kl-chip-d">A value over about 4KB of JSON is zipped before it is stored; JSON shrinks by 80 to 90%.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/utilities-guide#session-cache-user-scoped">A key per user</a><span class="kl-chip-d">withUserScope(true) keeps each user's values apart without building the key yourself.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/utilities-guide#pattern-4-bulk-cache-operations">Many keys in one call</a><span class="kl-chip-d">putAll and getAll store and read a map of values together.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/utilities-guide#automatic-ttl-enforcement">Lifetimes under five minutes</a><span class="kl-chip-d">The platform keeps a value at least 300 seconds; the store honours a shorter lifetime by checking it on read.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Set up</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/utilities-guide#architecture">A partition that ships</a><span class="kl-chip-d">The Library partition comes with the package; isAvailable() and isAllocated() say whether it has space.</span><span class="kl-chip-s"><code>kern.Library</code> · <a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/utilities-guide#using-custom-partitions">Your own partition, or none</a><span class="kl-chip-d">Point the store at a partition of yours, or keep values in memory for one transaction with no Platform Cache.</span><span class="kl-chip-s"><a href="/reference/apex/util-cache">kern.UTIL_Cache</a></span></div>
</div>

</template>

</CodeCompare>

<CodeCompare id="consoles" title="Find what failed overnight from a screen, not a pile of queries" link="/administration-tools-guide" linkText="Administration Tools Guide →" beforeLabel="Plain Apex and other tools" afterLabel="KernDX: App Launcher, then Kern" wrote="0 lines" caps="10" capsLabel="screens and actions you didn't build">

<template #lead>

**Why:** the Kern app watches your KernDX integrations, events and background chains (not your whole org) and puts the tools to act on them in one place: no Postman, no throwaway anonymous Apex, no streaming client of your own.

</template>

<template #before>

```apex
// Something failed overnight. In anonymous Apex:
List<kern__LogEntry__c> errors = [
	SELECT kern__ShortMessage__c, CreatedDate FROM kern__LogEntry__c
	WHERE kern__LogLevel__c = 'ERROR' AND CreatedDate = TODAY
];
System.debug(errors.size()); // thousands of rows, mostly one error
// Which step of the chain broke? Read job records by hand.
// Replay the call? Postman. Watch events? Your own streaming client.
// Which fields hold sensitive data? A hand-written audit.
```

</template>

<template #after>

```text
Kern Home
  Health Check             is the org set up right? many fixes in one click
  Log Console              repeats grouped into problems; one run, one timeline
  Chain Monitor            which step broke and how far it got; retry or abort
  API Test Harness         fire a real callout or endpoint, with Safe Mode
  Streaming Event Monitor  watch platform events arrive as they happen
  Data Masking Advisor     build a masking configuration from a scan
```

</template>

<template #footprint>

**You write:** nothing. **You configure:** a KernDX permission set for each user, such as Kern Administrator or Kern Read Only.

</template>

<template #ledger>

<div class="kl-cat">
<p class="kl-cat-h">Troubleshoot</p>
<div class="kl-ledger-chip hero"><a class="kl-chip-t" href="/administration-tools-guide#log-console">Problems, not rows</a><span class="kl-chip-d">The Log Console folds repeats into "this error, N times" and lays one run out on a timeline.</span><span class="kl-chip-s"><code>kern/logConsole</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/administration-tools-guide#chain-monitor">The step that broke</a><span class="kl-chip-d">The Chain Monitor shows each step's status and error, and offers retry or abort to the users you allow.</span><span class="kl-chip-s"><code>kern/chainMonitor</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/async-processing-guide#stopping-a-chain-from-the-chain-monitor">Stop, retry or restart a chain</a><span class="kl-chip-d">From the Chain Monitor, stop a chain, retry it from the failed step, or start it again.</span><span class="kl-chip-s"><code>kern/chainMonitor</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/administration-tools-guide#triage-and-retry-failed-integration-calls">Retry a failed call from its record</a><span class="kl-chip-d">Retry on an API issue runs the original call again; Retry Selected does many at once.</span><span class="kl-chip-s"><a href="/reference/objects/apiissue-c">kern__ApiIssue__c</a></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/administration-tools-guide#api-test-harness">Fire a call from a form</a><span class="kl-chip-d">The API Test Harness runs a real callout or endpoint; Safe Mode rolls back every save.</span><span class="kl-chip-s"><code>kern/apiTestHarnessForm</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h">Monitor and set up</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/administration-tools-guide#is-your-org-set-up-correctly-health-check">Is the org ready?</a><span class="kl-chip-d">The Health Check banner on Kern Home sorts checks into action required, review and passing.</span><span class="kl-chip-s"><code>kern/healthCheck</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/administration-tools-guide#streaming-event-monitor">Events as they arrive</a><span class="kl-chip-d">The Streaming Event Monitor subscribes, publishes test events and shows each payload.</span><span class="kl-chip-s"><code>kern/streamingMonitor</code></span></div>
<div class="kl-ledger-chip more"><a class="kl-chip-t" href="/lwc-guide#scheduledjobdetail-scheduled-job-detail">Each scheduled job on its record</a><span class="kl-chip-d">The job page shows the last outcome, Run now and View log.</span><span class="kl-chip-s"><code>kern/scheduledJobDetail</code></span></div>
</div>

<div class="kl-cat">
<p class="kl-cat-h" data-cat="governance">Governance</p>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/administration-tools-guide#data-masking-advisor">Masking from a scan</a><span class="kl-chip-d">The Data Masking Advisor builds a masking configuration you can deploy, instead of a hand audit.</span><span class="kl-chip-s"><code>kern/dataMaskingAdvisor</code></span></div>
<div class="kl-ledger-chip"><a class="kl-chip-t" href="/administration-tools-guide#data-masking-advisor">A list of regulated fields</a><span class="kl-chip-d">Export every field and its masking as CSV or JSON, or only the sensitive ones.</span><span class="kl-chip-s"><code>kern/dataMaskingAdvisor</code></span></div>
</div>

</template>

</CodeCompare>

</FeatureGroup>

</template>

</KernLanding>
