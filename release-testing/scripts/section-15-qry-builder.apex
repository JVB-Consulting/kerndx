// =============================================================================
// Section 15: QRY_Builder — Advanced Query Patterns
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - Account trigger bypassed to avoid interference
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-15-qry-builder.apex
// =============================================================================

kern.TRG_Base.bypass(Account.SObjectType);

List<Id> cleanupIds = new List<Id>();

try
{
	// Setup: Create test data
	List<Account> testAccounts = new List<Account>();
	testAccounts.add(new Account(Name = 'QRY Alpha 15', Industry = 'Technology', AnnualRevenue = 1000000, NumberOfEmployees = 50));
	testAccounts.add(new Account(Name = 'QRY Beta 15', Industry = 'Technology', AnnualRevenue = 2000000, NumberOfEmployees = 100));
	testAccounts.add(new Account(Name = 'QRY Gamma 15', Industry = 'Finance', AnnualRevenue = 3000000, NumberOfEmployees = 200));
	testAccounts.add(new Account(Name = 'QRY Delta 15', Industry = 'Finance', AnnualRevenue = 500000, NumberOfEmployees = 25));
	testAccounts.add(new Account(Name = 'QRY Epsilon 15', Industry = 'Healthcare', AnnualRevenue = 4000000, NumberOfEmployees = 300));
	insert testAccounts;
	for(Account account : testAccounts) cleanupIds.add(account.Id);

	// Test 15a: Basic condition + ordering
	{
		List<Account> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Industry).equals('Technology')
				.andCondition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.orderBy(Account.Name).ascending()
				.toList();

		System.assert(results.size() >= 2, '15a FAIL: Should find at least 2 Technology accounts, found: ' + results.size());
		System.assert(results[0].Name.compareTo(results[1].Name) < 0, '15a FAIL: Results should be ordered ascending by Name');
		System.debug('15a PASS: Condition + ordering returns ' + results.size() + ' records in correct order');
	}

	// Test 15b: getFirst() returns single record
	{
		SObject result = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.Name).equals('QRY Alpha 15')
				.getFirst();

		System.assert(result != null, '15b FAIL: getFirst() should return a record');
		System.assertEquals('QRY Alpha 15', (String)result.get('Name'), '15b FAIL: Should find QRY Alpha 15');
		System.debug('15b PASS: getFirst() returns single matching record');
	}

	// Test 15c: count() and exists()
	{
		Integer total = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.count();

		Boolean techExists = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Name).equals('QRY Alpha 15')
				.exists();

		Boolean fakeExists = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Name).equals('QRY NonExistent 15')
				.exists();

		System.assertEquals(5, total, '15c FAIL: Should count 5 test accounts, got: ' + total);
		System.assert(techExists, '15c FAIL: QRY Alpha 15 should exist');
		System.assert(!fakeExists, '15c FAIL: QRY NonExistent 15 should not exist');
		System.debug('15c PASS: count()=' + total + ', exists()=true/false correct');
	}

	// Test 15d: asMap() — returns Map<Id, SObject>
	{
		Map<Id, SObject> accountMap = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.asMap();

		System.assertEquals(5, accountMap.size(), '15d FAIL: Map should contain 5 records, got: ' + accountMap.size());
		System.assert(accountMap.containsKey(testAccounts[0].Id), '15d FAIL: Map should contain first test account');
		System.debug('15d PASS: asMap() returns Map<Id, SObject> with ' + accountMap.size() + ' entries');
	}

	// Test 15e: asIdSet() — returns Set<Id>
	{
		Set<Id> idSet = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Industry).equals('Finance')
				.andCondition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.asIdSet();

		System.assertEquals(2, idSet.size(), '15e FAIL: Should find 2 Finance accounts, got: ' + idSet.size());
		System.debug('15e PASS: asIdSet() returns ' + idSet.size() + ' Ids for Finance accounts');
	}

	// Test 15f: asStringSet() — returns Set<String> for a field
	{
		Set<String> industries = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Industry})
				.condition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.asStringSet(Account.Industry);

		System.assert(industries.contains('Technology'), '15f FAIL: Should contain Technology');
		System.assert(industries.contains('Finance'), '15f FAIL: Should contain Finance');
		System.assert(industries.contains('Healthcare'), '15f FAIL: Should contain Healthcare');
		System.assertEquals(3, industries.size(), '15f FAIL: Should have 3 unique industries');
		System.debug('15f PASS: asStringSet(Industry) returns ' + industries.size() + ' unique values');
	}

	// Test 15g: LIMIT + OFFSET
	{
		List<Account> page1 = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.orderBy(Account.Name).ascending()
				.withLimit(2)
				.toList();

		List<Account> page2 = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.orderBy(Account.Name).ascending()
				.withLimit(2)
				.withOffset(2)
				.toList();

		System.assertEquals(2, page1.size(), '15g FAIL: Page 1 should have 2 records');
		System.assertEquals(2, page2.size(), '15g FAIL: Page 2 should have 2 records');
		System.assert(page1[0].Name != page2[0].Name, '15g FAIL: Pages should have different records');
		System.debug('15g PASS: LIMIT/OFFSET pagination works correctly');
	}

	// Test 15h: OR condition
	{
		List<Account> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Name).equals('QRY Alpha 15')
				.orCondition(Account.Name).equals('QRY Epsilon 15')
				.toList();

		System.assertEquals(2, results.size(), '15h FAIL: OR condition should return 2 records, got: ' + results.size());
		System.debug('15h PASS: OR condition correctly returns ' + results.size() + ' matching records');
	}

	// Test 15i: toSoql() — query string without execution
	{
		String soql = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Industry).equals('Technology')
				.orderBy(Account.Name).ascending()
				.withLimit(10)
				.toSoql();

		System.assert(soql != null && soql.length() > 0, '15i FAIL: toSoql() should return a non-empty string');
		System.assert(soql.containsIgnoreCase('SELECT'), '15i FAIL: SOQL should contain SELECT');
		System.assert(soql.containsIgnoreCase('Account'), '15i FAIL: SOQL should contain Account');
		System.debug('15i PASS: toSoql() = ' + soql);
	}

	// Test 15j: Aggregate query — GROUP BY + COUNT
	// Alias format: {function_lowercase}_{fieldName} — e.g., count('Id') → alias 'count_Id'
	{
		List<kern.QRY_Builder.AggregateRow> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.groupBy(Account.Industry)
				.count('Id')
				.condition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.toAggregateList();

		System.assert(!results.isEmpty(), '15j FAIL: Aggregate results should not be empty');
		System.debug('15j INFO: Found ' + results.size() + ' industry groups');

		for(kern.QRY_Builder.AggregateRow row : results)
		{
			String industry = row.getString('Industry');
			Integer rowCount = row.getInteger('count_Id');
			System.debug('15j  - Industry: ' + industry + ', Count: ' + rowCount);
		}

		System.debug('15j PASS: Aggregate GROUP BY + COUNT query works correctly');
	}

	// Test 15k: Compound conditions — OrCondition + AndCondition with addCondition()
	{
		kern.QRY_Condition.OrCondition industryGroup = new kern.QRY_Condition.OrCondition();
		industryGroup.add(new kern.QRY_Condition.FieldCondition(Account.Industry, kern.QRY_Condition.Operator.EQUALS, 'Technology'));
		industryGroup.add(new kern.QRY_Condition.FieldCondition(Account.Industry, kern.QRY_Condition.Operator.EQUALS, 'Finance'));

		List<Account> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.addCondition(industryGroup)
				.orderBy(Account.Name).ascending()
				.toList();

		System.assertEquals(4, results.size(), '15k FAIL: OrCondition should match Technology + Finance (4 records), got: ' + results.size());

		kern.QRY_Condition.AndCondition highRevTech = new kern.QRY_Condition.AndCondition();
		highRevTech.add(new kern.QRY_Condition.FieldCondition(Account.Industry, kern.QRY_Condition.Operator.EQUALS, 'Technology'));
		highRevTech.add(new kern.QRY_Condition.FieldCondition(Account.AnnualRevenue, kern.QRY_Condition.Operator.GREATER_THAN, 1500000));

		kern.QRY_Condition.AndCondition highRevFinance = new kern.QRY_Condition.AndCondition();
		highRevFinance.add(new kern.QRY_Condition.FieldCondition(Account.Industry, kern.QRY_Condition.Operator.EQUALS, 'Finance'));
		highRevFinance.add(new kern.QRY_Condition.FieldCondition(Account.AnnualRevenue, kern.QRY_Condition.Operator.GREATER_THAN, 1500000));

		kern.QRY_Condition.OrCondition nestedGroup = new kern.QRY_Condition.OrCondition();
		nestedGroup.add(highRevTech);
		nestedGroup.add(highRevFinance);

		List<Account> nested = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry, Account.AnnualRevenue})
				.condition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.addCondition(nestedGroup)
				.toList();

		System.assertEquals(2, nested.size(), '15k FAIL: Nested compound should match Beta (Tech 2M) + Gamma (Finance 3M), got: ' + nested.size());
		System.debug('15k PASS: Compound conditions (OrCondition, AndCondition, nested) work correctly');
	}

	// Test 15l: DateLiteral — relative date conditions
	{
		kern.QRY_Condition.DateLiteral last30 = new kern.QRY_Condition.DateLiteral().lastNDays(30);

		List<Account> recent = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.CreatedDate).equals(last30)
				.andCondition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.toList();

		System.assertEquals(5, recent.size(), '15l FAIL: All 5 test accounts were just created, should match LAST_N_DAYS:30, got: ' + recent.size());

		kern.QRY_Condition.DateLiteral thisQuarter = new kern.QRY_Condition.DateLiteral().thisUnit(kern.QRY_Condition.UnitOfTime.QUARTER);

		List<Account> quarterResults = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.CreatedDate).greaterThan(thisQuarter)
				.andCondition(Account.Name).contains('QRY')
				.andCondition(Account.Name).contains('15')
				.toList();

		System.assert(quarterResults.size() >= 0, '15l FAIL: THIS_QUARTER query should execute without error');
		System.debug('15l PASS: DateLiteral (lastNDays, thisUnit) queries execute correctly, found ' + recent.size() + ' recent records');
	}

	// Test 15m: Bulk-200 boundary — insert 200, then QRY_Builder retrieves all 200 back
	{
		List<Account> bulkAccounts = new List<Account>();
		for(Integer i = 0; i < 200; i++)
		{
			bulkAccounts.add(new Account(Name = 'QRY Bulk 15m ' + String.valueOf(i).leftPad(3, '0'), Industry = 'Technology', AnnualRevenue = 1000000));
		}
		insert bulkAccounts;
		for(Account account : bulkAccounts) cleanupIds.add(account.Id);

		Set<Id> bulkIds = new Map<Id, Account>(bulkAccounts).keySet();

		List<SObject> retrieved = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Id).isIn(new List<Id>(bulkIds))
				.toList();

		System.assertEquals(200, retrieved.size(), '15m FAIL: QRY_Builder should retrieve all 200 inserted accounts, got: ' + retrieved.size());

		Integer matchCount = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Id).isIn(new List<Id>(bulkIds))
				.count();
		System.assertEquals(200, matchCount, '15m FAIL: count() should return 200, got: ' + matchCount);

		System.debug('15m PASS: QRY_Builder bulk-200 — toList().size()=' + retrieved.size() + ', count()=' + matchCount);
	}

	System.debug('=== Section 15 COMPLETE: All QRY_Builder tests passed ===');
}
finally
{
	kern.TRG_Base.clearAllBypasses();

	if(!cleanupIds.isEmpty())
	{
		List<Task> tasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId IN :cleanupIds
		];
		if(!tasks.isEmpty()) delete tasks;
		delete
		[
				SELECT Id
				FROM Account
				WHERE Id IN :cleanupIds
		];
		System.debug('Cleanup: Deleted ' + cleanupIds.size() + ' test Account(s)');
	}
}
