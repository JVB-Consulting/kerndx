/**
 * Section 53: QRY_Builder — Edge Cases
 *
 * Closes gaps in QRY_Builder capability coverage beyond section-15 (which already
 * exercises basic conditions, ordering, limit/offset, getFirst/count/exists, asMap,
 * asIdSet, asStringSet, OR conditions, toSoql, GROUP BY+COUNT, compound conditions
 * and DateLiteral). Covers ten edge scenarios that section-15 does not touch:
 * parent-with-child subselect, semi-join via builder, anti-join via builder,
 * QueryLocator iteration, Database.Cursor fetch, getPage with full metadata,
 * ROLLUP with grouping(), 2-axis CUBE, havingSumOf filter, and stripInaccessible
 * post-processing.
 *
 * Deferrals to Subscriber_QryEdges_TEST.cls (Task 1.15) — assertions that anon-Apex
 * structurally cannot make:
 *   - .withUserMode() returning null for an FLS-restricted field as a Standard User
 *     (anon-Apex cannot impersonate; needs runAs).
 *   - Namespace-prefix SOQL shape verification when running as a subscriber-namespace
 *     user (this script runs as admin in the kern-installed scratch org, where SOQL
 *     uses the kern__ prefix; the subscriber-context shape needs a runAs harness).
 *   - Scenario 53j .stripInaccessible() — this script verifies the chain works and
 *     returns records (the *removal* logic), but the *was-restricted* portion (a
 *     non-admin user actually losing access to a field) requires runAs.
 *
 * Run-isolation: self-contained — does not depend on prior section state, does not
 * leave persistent state for subsequent sections (cleanup deletes everything created
 * in the current day by the running user).
 *
 * Implementation note: anon-Apex in this subscriber org has a parser quirk where
 * `List<kern__Foobar__c>` declarations combined with `kern.X.Y()` chained method
 * calls trigger a spurious "Unexpected token '<'" compile failure. Workaround:
 * the script uses `Object` as an opaque carrier and casts to `(List<SObject>)`
 * at the moment of use.
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-53-edge-qry-builder.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 53: QRY_Builder Edge Cases ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
// Scenarios 53b/53c use Account + Contact (one-time exception — SOQL forbids semi-join
// inner+outer queries on the same object, and Foobar__c only has a self-referential
// Lookup, so semi-join cannot be exercised on Foobar→Foobar). The subscriber org has
// Account-trigger actions configured (CreateAccountTask, DetectNameChange,
// SetAccountDefaults, StampAccountSource, ExecuteValidationRules), so bypass them
// during this section.
kern.TRG_Base.bypass(Account.SObjectType);
kern.TRG_Base.bypass(Contact.SObjectType);

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP = String.valueOf(Datetime.now().getTime());
final String CHILD_RELATIONSHIP = 'kern__Foobars__r';

List<Id> accountCleanupIds53 = new List<Id>();
List<Id> contactCleanupIds53 = new List<Id>();

// Scenario 53a — parent .subselect(childBuilder, 'kern__Foobars__r') with 5 children
try
{
	kern__Foobar__c parent53a = (kern__Foobar__c)kern.TST_Builder.of('kern__Foobar__c')
			.withOverride(kern__Foobar__c.Name, 'Parent53a-' + RUN_STAMP)
			.build();

	Object children53aObj = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(5)
			.withOverride(kern__Foobar__c.kern__Lookup__c, parent53a.Id)
			.withOverride(kern__Foobar__c.Name, 'Child53a-' + RUN_STAMP)
			.buildList();
	List<SObject> children53a = (List<SObject>)children53aObj;
	Assert.areEqual(5, children53a.size(), '53a: setup should have inserted 5 child records');

	kern.QRY_Builder.Builder childQuery53a = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.fields(new List<SObjectField> {kern__Foobar__c.Name});

	String soql53a = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.fields(new List<SObjectField> {kern__Foobar__c.Name})
			.subselect(childQuery53a, CHILD_RELATIONSHIP)
			.condition(kern__Foobar__c.Id).equals(parent53a.Id)
			.toSoql();
	Assert.isTrue(soql53a.containsIgnoreCase('(SELECT'), '53a: SOQL should contain a nested SELECT for the subselect');
	Assert.isTrue(soql53a.containsIgnoreCase('FROM ' + CHILD_RELATIONSHIP), '53a: SOQL should reference the kern__Foobars__r child relationship');

	kern.QRY_Builder.Builder childQuery53aExec = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.fields(new List<SObjectField> {kern__Foobar__c.Name});

	List<SObject> parentResults53a = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.fields(new List<SObjectField> {kern__Foobar__c.Name})
			.subselect(childQuery53aExec, CHILD_RELATIONSHIP)
			.condition(kern__Foobar__c.Id).equals(parent53a.Id)
			.toList();

	Assert.areEqual(1, parentResults53a.size(), '53a: should return exactly 1 parent record');
	kern__Foobar__c parentResult53a = (kern__Foobar__c)parentResults53a[0];
	List<SObject> childResults53a = parentResult53a.getSObjects(CHILD_RELATIONSHIP);
	Assert.isNotNull(childResults53a, '53a: child relationship kern__Foobars__r should be populated');
	Assert.areEqual(5, childResults53a.size(), '53a: parent should have 5 children via subselect');
	System.debug(LoggingLevel.INFO, '53a PASS: subselect returned 1 parent with 5 nested children');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53b — semi-join .condition(field).isIn(builder) — uses Account + Contact
// (SOQL forbids semi-joins where inner+outer queries are the same object type)
try
{
	Account techAccount53b = new Account(Name = 'TechAccount53b-' + RUN_STAMP, Industry = 'Technology');
	Account financeAccount53b = new Account(Name = 'FinanceAccount53b-' + RUN_STAMP, Industry = 'Finance');
	insert new List<Account> {techAccount53b, financeAccount53b};
	accountCleanupIds53.add(techAccount53b.Id);
	accountCleanupIds53.add(financeAccount53b.Id);

	List<Contact> contacts53b = new List<Contact>();
	for(Integer i = 0; i < 3; i++)
	{
		contacts53b.add(new Contact(LastName = 'TechContact53b-' + RUN_STAMP + '-' + i, AccountId = techAccount53b.Id));
	}
	contacts53b.add(new Contact(LastName = 'FinanceContact53b-' + RUN_STAMP, AccountId = financeAccount53b.Id));
	insert contacts53b;
	for(Contact contact : contacts53b)
	{
		contactCleanupIds53.add(contact.Id);
	}

	kern.QRY_Builder.Builder techAccountSubquery53b = kern.QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField> {Account.Id})
			.condition(Account.Industry).equals('Technology')
			.andCondition(Account.Name).startsWith('TechAccount53b-')
			.andCondition(Account.Name).endsWith(RUN_STAMP);

	String soql53b = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.fields(new List<SObjectField> {Contact.LastName})
			.condition(Contact.AccountId).isIn(techAccountSubquery53b)
			.andCondition(Contact.LastName).contains('53b-' + RUN_STAMP)
			.toSoql();
	Assert.isTrue(soql53b.containsIgnoreCase('IN (SELECT'), '53b: SOQL should contain "IN (SELECT" for semi-join, got: ' + soql53b);

	kern.QRY_Builder.Builder techAccountSubqueryExec53b = kern.QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField> {Account.Id})
			.condition(Account.Industry).equals('Technology')
			.andCondition(Account.Name).startsWith('TechAccount53b-')
			.andCondition(Account.Name).endsWith(RUN_STAMP);

	List<SObject> semiJoinResults53b = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.fields(new List<SObjectField> {Contact.LastName})
			.condition(Contact.AccountId).isIn(techAccountSubqueryExec53b)
			.andCondition(Contact.LastName).contains('53b-' + RUN_STAMP)
			.toList();
	Assert.areEqual(3, semiJoinResults53b.size(), '53b: semi-join should return only the 3 contacts of the Technology account');
	System.debug(LoggingLevel.INFO, '53b PASS: semi-join via .isIn(builder) returned 3 of 4 candidate Contacts');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53c — anti-join .condition(field).notIn(builder) — uses Account + Contact;
// must be NOT IN (SELECT ...) shape, not a NOT IN (value-list) shape
try
{
	Account techAccount53c = new Account(Name = 'TechAccount53c-' + RUN_STAMP, Industry = 'Technology');
	Account financeAccount53c = new Account(Name = 'FinanceAccount53c-' + RUN_STAMP, Industry = 'Finance');
	insert new List<Account> {techAccount53c, financeAccount53c};
	accountCleanupIds53.add(techAccount53c.Id);
	accountCleanupIds53.add(financeAccount53c.Id);

	List<Contact> contacts53c = new List<Contact>();
	for(Integer i = 0; i < 2; i++)
	{
		contacts53c.add(new Contact(LastName = 'TechContact53c-' + RUN_STAMP + '-' + i, AccountId = techAccount53c.Id));
	}
	for(Integer i = 0; i < 3; i++)
	{
		contacts53c.add(new Contact(LastName = 'FinanceContact53c-' + RUN_STAMP + '-' + i, AccountId = financeAccount53c.Id));
	}
	insert contacts53c;
	for(Contact contact : contacts53c)
	{
		contactCleanupIds53.add(contact.Id);
	}

	kern.QRY_Builder.Builder techAccountSubquery53c = kern.QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField> {Account.Id})
			.condition(Account.Industry).equals('Technology')
			.andCondition(Account.Name).startsWith('TechAccount53c-')
			.andCondition(Account.Name).endsWith(RUN_STAMP);

	String soql53c = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.fields(new List<SObjectField> {Contact.LastName})
			.condition(Contact.AccountId).notIn(techAccountSubquery53c)
			.andCondition(Contact.LastName).contains('53c-' + RUN_STAMP)
			.toSoql();
	Assert.isTrue(soql53c.containsIgnoreCase('NOT IN (SELECT'), '53c: SOQL should contain "NOT IN (SELECT" for anti-join (not a value-list NOT IN), got: ' + soql53c);

	kern.QRY_Builder.Builder techAccountSubqueryExec53c = kern.QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField> {Account.Id})
			.condition(Account.Industry).equals('Technology')
			.andCondition(Account.Name).startsWith('TechAccount53c-')
			.andCondition(Account.Name).endsWith(RUN_STAMP);

	List<SObject> antiJoinResults53c = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.fields(new List<SObjectField> {Contact.LastName})
			.condition(Contact.AccountId).notIn(techAccountSubqueryExec53c)
			.andCondition(Contact.LastName).contains('53c-' + RUN_STAMP)
			.toList();
	Assert.areEqual(3, antiJoinResults53c.size(), '53c: anti-join should return only the 3 Contacts whose Account is NOT Technology');
	System.debug(LoggingLevel.INFO, '53c PASS: anti-join via .notIn(builder) returned 3 of 5 candidate Contacts, SOQL shape verified as anti-join');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53d — .toQueryLocator() iterated via QueryLocatorIterator pattern
try
{
	Object setupObj53d = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(7)
			.withOverride(kern__Foobar__c.Name, 'Locator53d-' + RUN_STAMP)
			.buildList();
	List<SObject> setup53d = (List<SObject>)setupObj53d;
	Assert.areEqual(7, setup53d.size(), '53d: setup should have inserted 7 records');

	Database.QueryLocator locator53d = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.fields(new List<SObjectField> {kern__Foobar__c.Name})
			.condition(kern__Foobar__c.Name).equals('Locator53d-' + RUN_STAMP)
			.toQueryLocator();
	Assert.isNotNull(locator53d, '53d: toQueryLocator() should return a non-null QueryLocator');

	Integer iterated53d = 0;
	Database.QueryLocatorIterator iterator53d = locator53d.iterator();
	while(iterator53d.hasNext())
	{
		SObject record = iterator53d.next();
		Assert.isNotNull(record.Id, '53d: iterated record should have an Id');
		iterated53d++;
	}
	Assert.areEqual(7, iterated53d, '53d: should have iterated all 7 inserted records');
	System.debug(LoggingLevel.INFO, '53d PASS: toQueryLocator() returned a QueryLocator yielding 7 records via iterator');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53d: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53e — .toCursor() with .fetch(0, 50)
try
{
	Object setupObj53e = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(60)
			.withOverride(kern__Foobar__c.Name, 'Cursor53e-' + RUN_STAMP)
			.buildList();
	List<SObject> setup53e = (List<SObject>)setupObj53e;
	Assert.areEqual(60, setup53e.size(), '53e: setup should have inserted 60 records');

	Database.Cursor cursor53e = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.fields(new List<SObjectField> {kern__Foobar__c.Name})
			.condition(kern__Foobar__c.Name).equals('Cursor53e-' + RUN_STAMP)
			.orderBy(kern__Foobar__c.CreatedDate).ascending()
			.toCursor();
	Assert.isNotNull(cursor53e, '53e: toCursor() should return a non-null Database.Cursor');
	Assert.areEqual(60, cursor53e.getNumRecords(), '53e: cursor should report 60 total matching records');

	List<SObject> firstPage53e = cursor53e.fetch(0, 50);
	Assert.areEqual(50, firstPage53e.size(), '53e: first page should yield exactly 50 records');
	for(SObject record : firstPage53e)
	{
		Assert.isNotNull(record.Id, '53e: each fetched record should have an Id');
	}
	System.debug(LoggingLevel.INFO, '53e PASS: toCursor() returned cursor with 60 total records, .fetch(0, 50) yielded 50');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53e: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53f — .getPage(2, 50) with full QueryPage metadata assertions
try
{
	Object setupObj53f = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(125)
			.withOverride(kern__Foobar__c.Name, 'Page53f-' + RUN_STAMP)
			.buildList();
	List<SObject> setup53f = (List<SObject>)setupObj53f;
	Assert.areEqual(125, setup53f.size(), '53f: setup should have inserted 125 records');

	kern.QRY_Builder.QueryPage page53f = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.fields(new List<SObjectField> {kern__Foobar__c.Name})
			.condition(kern__Foobar__c.Name).equals('Page53f-' + RUN_STAMP)
			.orderBy(kern__Foobar__c.CreatedDate).ascending()
			.getPage(2, 50);

	Assert.isNotNull(page53f, '53f: getPage should return a non-null QueryPage');
	Assert.isNotNull(page53f.records, '53f: page.records should be non-null');
	Assert.areEqual(50, page53f.records.size(), '53f: page 2 of 50 should contain exactly 50 records');
	Assert.areEqual(125, page53f.totalRecords, '53f: page.totalRecords should be 125');
	Assert.areEqual(3, page53f.totalPages, '53f: 125 records / 50 per page = 3 pages (ceil)');
	Assert.areEqual(2, page53f.pageNumber, '53f: page.pageNumber should echo back 2');
	Assert.areEqual(50, page53f.pageSize, '53f: page.pageSize should echo back 50');
	Assert.isTrue(page53f.hasMorePages, '53f: page 2 of 3 should report hasMorePages=true');
	Assert.isTrue(page53f.hasPriorPages, '53f: page 2 of 3 should report hasPriorPages=true');
	Assert.isNotNull(page53f.deletedRecords, '53f: deletedRecords metadata should be populated (>=0)');
	System.debug(LoggingLevel.INFO, '53f PASS: getPage(2, 50) returned 50 records, totalRecords=125, totalPages=3, hasMore=true, hasPrior=true');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53f FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53f: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53g — .rollup() + .grouping(field) — subtotal row has GROUPING() flag = 1
try
{
	Object hotObj53g = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(3)
			.withOverride(kern__Foobar__c.kern__Picklist__c, 'Hot')
			.withOverride(kern__Foobar__c.Name, 'Rollup53g-' + RUN_STAMP)
			.buildList();
	List<SObject> hotRecords53g = (List<SObject>)hotObj53g;
	Assert.areEqual(3, hotRecords53g.size(), '53g: setup should have inserted 3 Hot records');

	Object coldObj53g = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(2)
			.withOverride(kern__Foobar__c.kern__Picklist__c, 'Cold')
			.withOverride(kern__Foobar__c.Name, 'Rollup53g-' + RUN_STAMP)
			.buildList();
	List<SObject> coldRecords53g = (List<SObject>)coldObj53g;
	Assert.areEqual(2, coldRecords53g.size(), '53g: setup should have inserted 2 Cold records');

	List<kern.QRY_Builder.AggregateRow> rollupRows53g = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.condition(kern__Foobar__c.Name).equals('Rollup53g-' + RUN_STAMP)
			.groupBy(kern__Foobar__c.kern__Picklist__c)
			.grouping(kern__Foobar__c.kern__Picklist__c)
			.count('Id')
			.rollup()
			.toAggregateList();

	Assert.areEqual(3, rollupRows53g.size(), '53g: ROLLUP over 2 picklist groups should yield 2 data rows + 1 subtotal = 3 rows');

	Integer subtotalRowCount53g = 0;
	Integer dataRowCount53g = 0;
	Integer subtotalTotalCount53g = 0;
	for(kern.QRY_Builder.AggregateRow row : rollupRows53g)
	{
		// Salesforce auto-aliases the unaliased GROUPING() expression in SELECT to expr0
		Integer groupingFlag = row.getInteger('expr0');
		if(groupingFlag == 1)
		{
			subtotalRowCount53g++;
			subtotalTotalCount53g = row.getInteger('count_Id');
		}
		else
		{
			dataRowCount53g++;
		}
	}
	Assert.areEqual(1, subtotalRowCount53g, '53g: ROLLUP should produce exactly 1 subtotal row (GROUPING flag=1)');
	Assert.areEqual(2, dataRowCount53g, '53g: ROLLUP should produce 2 data rows (GROUPING flag=0) for Hot/Cold');
	Assert.areEqual(5, subtotalTotalCount53g, '53g: subtotal row should sum to 5 (3 Hot + 2 Cold)');
	System.debug(LoggingLevel.INFO, '53g PASS: rollup() + grouping() produced 2 data rows + 1 subtotal row, subtotal count=5');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53g FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53g: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53h — .cube() 2-axis aggregate
try
{
	Object hotChecked53h = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(2)
			.withOverride(kern__Foobar__c.kern__Picklist__c, 'Hot')
			.withOverride(kern__Foobar__c.kern__Checkbox__c, true)
			.withOverride(kern__Foobar__c.Name, 'Cube53h-' + RUN_STAMP)
			.buildList();
	Assert.areEqual(2, ((List<SObject>)hotChecked53h).size(), '53h: setup should have inserted 2 Hot+true records');

	Object hotUnchecked53h = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(1)
			.withOverride(kern__Foobar__c.kern__Picklist__c, 'Hot')
			.withOverride(kern__Foobar__c.kern__Checkbox__c, false)
			.withOverride(kern__Foobar__c.Name, 'Cube53h-' + RUN_STAMP)
			.buildList();
	Assert.areEqual(1, ((List<SObject>)hotUnchecked53h).size(), '53h: setup should have inserted 1 Hot+false record');

	Object coldChecked53h = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(1)
			.withOverride(kern__Foobar__c.kern__Picklist__c, 'Cold')
			.withOverride(kern__Foobar__c.kern__Checkbox__c, true)
			.withOverride(kern__Foobar__c.Name, 'Cube53h-' + RUN_STAMP)
			.buildList();
	Assert.areEqual(1, ((List<SObject>)coldChecked53h).size(), '53h: setup should have inserted 1 Cold+true record');

	List<kern.QRY_Builder.AggregateRow> cubeRows53h = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.condition(kern__Foobar__c.Name).equals('Cube53h-' + RUN_STAMP)
			.groupBy(kern__Foobar__c.kern__Picklist__c)
			.groupBy(kern__Foobar__c.kern__Checkbox__c)
			.count('Id')
			.cube()
			.toAggregateList();

	// 2 picklist values * 2 checkbox values = 4 leaf cells, but only 3 are present (Hot+T, Hot+F, Cold+T).
	// CUBE adds: per-axis subtotals + grand total; missing cells are absent. Expected rows include
	// at least the 3 leaves + 2 picklist subtotals + 2 checkbox subtotals + 1 grand total = 8.
	// We assert "more than just the leaves" as the lower bound, plus structural grand-total checks.
	Assert.isTrue(cubeRows53h.size() > 3, '53h: CUBE should produce more rows than the 3 leaf data cells (subtotals + grand total)');

	Integer leafSum53h = 0;
	Boolean foundGrandTotal53h = false;
	Integer grandTotal53h = 0;
	for(kern.QRY_Builder.AggregateRow row : cubeRows53h)
	{
		Object picklistValue = row.get('kern__Picklist__c');
		Object checkboxValue = row.get('kern__Checkbox__c');
		Integer rowCount = row.getInteger('count_Id');
		if(picklistValue == null && checkboxValue == null)
		{
			foundGrandTotal53h = true;
			grandTotal53h = rowCount;
		}
		else if(picklistValue != null && checkboxValue != null)
		{
			leafSum53h += rowCount;
		}
	}
	Assert.isTrue(foundGrandTotal53h, '53h: CUBE result should contain a grand total row (both axis values null)');
	Assert.areEqual(4, grandTotal53h, '53h: grand total should equal 4 (2 + 1 + 1 inserted)');
	Assert.areEqual(4, leafSum53h, '53h: leaf cells (both axis non-null) should sum to 4');
	System.debug(LoggingLevel.INFO, '53h PASS: cube() produced ' + cubeRows53h.size() + ' rows including a grand total of 4');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53h FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53h: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53i — .havingSumOf(field).greaterThan(value) aggregate filter
try
{
	Object hotRecords53i = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(3)
			.withOverride(kern__Foobar__c.kern__Picklist__c, 'Hot')
			.withOverride(kern__Foobar__c.kern__NumberInteger__c, 100)
			.withOverride(kern__Foobar__c.Name, 'Having53i-' + RUN_STAMP)
			.buildList();
	Assert.areEqual(3, ((List<SObject>)hotRecords53i).size(), '53i: setup should have inserted 3 Hot records of 100');

	Object coldRecords53i = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(3)
			.withOverride(kern__Foobar__c.kern__Picklist__c, 'Cold')
			.withOverride(kern__Foobar__c.kern__NumberInteger__c, 50)
			.withOverride(kern__Foobar__c.Name, 'Having53i-' + RUN_STAMP)
			.buildList();
	Assert.areEqual(3, ((List<SObject>)coldRecords53i).size(), '53i: setup should have inserted 3 Cold records of 50');

	Object warmRecords53i = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(2)
			.withOverride(kern__Foobar__c.kern__Picklist__c, 'Warm')
			.withOverride(kern__Foobar__c.kern__NumberInteger__c, 25)
			.withOverride(kern__Foobar__c.Name, 'Having53i-' + RUN_STAMP)
			.buildList();
	Assert.areEqual(2, ((List<SObject>)warmRecords53i).size(), '53i: setup should have inserted 2 Warm records of 25');

	List<kern.QRY_Builder.AggregateRow> havingRows53i = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.condition(kern__Foobar__c.Name).equals('Having53i-' + RUN_STAMP)
			.groupBy(kern__Foobar__c.kern__Picklist__c)
			.sum(kern__Foobar__c.kern__NumberInteger__c)
			.havingSumOf(kern__Foobar__c.kern__NumberInteger__c).greaterThan(100)
			.toAggregateList();

	Assert.areEqual(2, havingRows53i.size(), '53i: HAVING SUM > 100 should match 2 groups (Hot=300, Cold=150) but exclude Warm=50');
	Set<String> matchedGroups53i = new Set<String>();
	for(kern.QRY_Builder.AggregateRow row : havingRows53i)
	{
		matchedGroups53i.add(row.getString('kern__Picklist__c'));
	}
	Assert.isTrue(matchedGroups53i.contains('Hot'), '53i: matched groups should include Hot (sum=300)');
	Assert.isTrue(matchedGroups53i.contains('Cold'), '53i: matched groups should include Cold (sum=150)');
	Assert.isFalse(matchedGroups53i.contains('Warm'), '53i: matched groups should NOT include Warm (sum=50, fails HAVING)');
	System.debug(LoggingLevel.INFO, '53i PASS: havingSumOf().greaterThan(100) filtered to 2 of 3 groups (Hot, Cold)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53i FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53i: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 53j — .stripInaccessible() chain — admin-context invocation returns records intact
try
{
	Object setupObj53j = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(4)
			.withOverride(kern__Foobar__c.Name, 'Strip53j-' + RUN_STAMP)
			.withOverride(kern__Foobar__c.kern__Text__c, 'sensitive-value')
			.buildList();
	List<SObject> setup53j = (List<SObject>)setupObj53j;
	Assert.areEqual(4, setup53j.size(), '53j: setup should have inserted 4 records');

	List<SObject> stripped53j = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
			.fields(new List<SObjectField> {kern__Foobar__c.Name, kern__Foobar__c.kern__Text__c})
			.condition(kern__Foobar__c.Name).equals('Strip53j-' + RUN_STAMP)
			.stripInaccessible()
			.toList();

	Assert.areEqual(4, stripped53j.size(), '53j: admin-context stripInaccessible() should return all 4 records (no fields stripped for admin)');
	for(SObject record : stripped53j)
	{
		Assert.isNotNull(record.Id, '53j: each stripped record should retain Id');
		Assert.areEqual('Strip53j-' + RUN_STAMP, (String)record.get(kern__Foobar__c.Name), '53j: Name should be readable for admin');
		Assert.areEqual('sensitive-value', (String)record.get(kern__Foobar__c.kern__Text__c), '53j: kern__Text__c should be readable for admin (no FLS restriction)');
	}
	System.debug(LoggingLevel.INFO, '53j PASS: stripInaccessible() chain executed cleanly, admin retained all field access; FLS-restricted-user case deferred to Subscriber_QryEdges_TEST.cls (Task 1.15)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '53j FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('53j: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — bounded to stay under the 10K DML row governor.
// Section 53 inserts roughly 220 Foobar rows + 4 Accounts + 9 Contacts across scenarios
// (5+5+7+60+125+5+4+8+4 ≈ 223 Foobars), leaving ~9700 rows of headroom on the Foobar
// purge; capping at 9000 keeps a safety margin without leaking. If the script is re-run
// many times in one day and CreatedDate=TODAY accumulates beyond 9000, the next
// invocation's cleanup will skip the overflow — manually purge with a one-shot delete
// repeated until the count drops to zero.
if(!contactCleanupIds53.isEmpty())
{
	delete
	[
			SELECT Id
			FROM Contact
			WHERE Id IN :contactCleanupIds53
	];
}
if(!accountCleanupIds53.isEmpty())
{
	delete
	[
			SELECT Id
			FROM Account
			WHERE Id IN :accountCleanupIds53
	];
}
delete
[
		SELECT Id
		FROM kern__Foobar__c
		WHERE CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
];

kern.TRG_Base.clearAllBypasses();

// Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 53: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 53 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 53 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 53 COMPLETE: All scenarios passed ===');
}
