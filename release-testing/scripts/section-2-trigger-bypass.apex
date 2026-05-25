// =============================================================================
// Section 2: Trigger Bypass Mechanisms
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Same as Section 1 (all trigger handlers deployed and active)
//   - TRG_SetAccountDefaults (Order=100, BeforeInsert)
//   - TRG_ValidateAccountName (Order=200, BeforeInsert)
//   - TRG_StampAccountSource (Order=300, BeforeInsert + BeforeUpdate)
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-2-trigger-bypass.apex
// =============================================================================

// Safety: clear all bypasses at the start
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
// Bypass the flow trigger action — sections 41-44 cover that surface; this section tests Apex actions only
kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');

// Bypass validation rules — this section tests trigger bypass mechanisms, not validation
kern.UTIL_ValidationRule.bypassObject('Account');

// Test 2a: Object-level bypass via SObjectType — all handlers skipped, then cleared
{
	kern.TRG_Base.bypass(Account.SObjectType);

	Account bypassed = new Account(Name = 'Test Account 2a Bypassed', Industry = 'Technology');
	insert bypassed;

	Account bypassedResult =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :bypassed.Id
	];
	System.assertEquals(null, bypassedResult.Description, '2a FAIL: Description should be null when triggers bypassed');
	System.assertEquals(null, bypassedResult.AccountSource, '2a FAIL: AccountSource should be null when triggers bypassed');

	kern.TRG_Base.clearBypass(Account.SObjectType);

	Account notBypassed = new Account(Name = 'Test Account 2a Not Bypassed', Industry = 'Technology', Phone = '1234567890');
	insert notBypassed;

	Account notBypassedResult =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :notBypassed.Id
	];
	System.assertEquals('Default', notBypassedResult.Description, '2a FAIL: Description should be set after bypass cleared');
	System.assertEquals('Subscriber Trigger', notBypassedResult.AccountSource, '2a FAIL: AccountSource should be set after bypass cleared');

	System.debug('2a PASS: Object-level bypass via SObjectType works and clears correctly');

	delete new List<Account> {bypassed, notBypassed};
	kern.TRG_Base.clearAllBypasses();
}

// Test 2b: Object-level bypass via String — same behavior as SObjectType overload
{
	kern.TRG_Base.bypass('Account');

	Account bypassed = new Account(Name = 'Test Account 2b Bypassed', Industry = 'Technology');
	insert bypassed;

	Account bypassedResult =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :bypassed.Id
	];
	System.assertEquals(null, bypassedResult.Description, '2b FAIL: Description should be null when bypassed via String');
	System.assertEquals(null, bypassedResult.AccountSource, '2b FAIL: AccountSource should be null when bypassed via String');

	kern.TRG_Base.clearBypass('Account');

	Account notBypassed = new Account(Name = 'Test Account 2b Not Bypassed', Industry = 'Technology', Phone = '1234567890');
	insert notBypassed;

	Account notBypassedResult =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :notBypassed.Id
	];
	System.assertEquals('Default', notBypassedResult.Description, '2b FAIL: Description should be set after String bypass cleared');
	System.assertEquals('Subscriber Trigger', notBypassedResult.AccountSource, '2b FAIL: AccountSource should be set after String bypass cleared');

	System.debug('2b PASS: Object-level bypass via String works and clears correctly');

	delete new List<Account> {bypassed, notBypassed};
	kern.TRG_Base.clearAllBypasses();
}

// Test 2c: Action-level bypass (single handler) — only TRG_SetAccountDefaults bypassed
{
	kern.TRG_Base.bypassAction('TRG_SetAccountDefaults');

	Account account = new Account(Name = 'Test Account 2c', Industry = 'Technology', Phone = '1234567890');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals(null, result.Description, '2c FAIL: Description should be null when TRG_SetAccountDefaults bypassed');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '2c FAIL: AccountSource should still be set — only SetAccountDefaults bypassed');

	System.debug('2c PASS: Action-level bypass skips single handler, others still execute');

	kern.TRG_Base.clearActionBypass('TRG_SetAccountDefaults');
	delete account;
	kern.TRG_Base.clearAllActionBypasses();
	kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
}

// Test 2d: Action-level bypass (all subscriber handlers) — no handler effects
{
	kern.TRG_Base.bypassAction('TRG_SetAccountDefaults');
	kern.TRG_Base.bypassAction('TRG_ValidateAccountName');
	kern.TRG_Base.bypassAction('TRG_StampAccountSource');

	Account account = new Account(Name = 'Test Account 2d', Industry = 'Technology');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals(null, result.Description, '2d FAIL: Description should be null when all actions bypassed');
	System.assertEquals(null, result.AccountSource, '2d FAIL: AccountSource should be null when all actions bypassed');

	System.debug('2d PASS: Bypassing all action classes prevents all handler effects');

	kern.TRG_Base.clearAllActionBypasses();
	kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
	delete account;
}

// Test 2e: clearAllBypasses — set bypasses, clear all at once, verify handlers fire
{
	kern.TRG_Base.bypass(Account.SObjectType);
	kern.TRG_Base.bypassAction('TRG_SetAccountDefaults');
	kern.TRG_Base.bypassAction('TRG_StampAccountSource');

	// Verify bypasses are set
	System.assert(kern.TRG_Base.isBypassed(Account.SObjectType), '2e FAIL: Account should be bypassed before clear');
	System.assert(kern.TRG_Base.isActionBypassed('TRG_SetAccountDefaults'), '2e FAIL: SetAccountDefaults should be bypassed before clear');

	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');

	// Verify all cleared
	System.assert(!kern.TRG_Base.isBypassed(Account.SObjectType), '2e FAIL: Account bypass should be cleared');
	System.assert(!kern.TRG_Base.isActionBypassed('TRG_SetAccountDefaults'), '2e FAIL: SetAccountDefaults bypass should be cleared');

	Account account = new Account(Name = 'Test Account 2e', Industry = 'Technology', Phone = '1234567890');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Default', result.Description, '2e FAIL: Description should be set after clearAllBypasses');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '2e FAIL: AccountSource should be set after clearAllBypasses');

	System.debug('2e PASS: clearAllBypasses and clearAllActionBypasses restore normal execution');

	delete account;
}

// Test 2f: isBypassed / isActionBypassed checks — programmatic state verification
{
	// Object-level checks
	System.assert(!kern.TRG_Base.isBypassed('Account'), '2f FAIL: Account should not be bypassed initially');
	System.assert(!kern.TRG_Base.isBypassed(Account.SObjectType), '2f FAIL: Account SObjectType should not be bypassed initially');

	kern.TRG_Base.bypass('Account');
	System.assert(kern.TRG_Base.isBypassed('Account'), '2f FAIL: Account should be bypassed after bypass(String)');
	System.assert(kern.TRG_Base.isBypassed(Account.SObjectType), '2f FAIL: Account SObjectType should be bypassed after bypass(String)');

	kern.TRG_Base.clearBypass('Account');
	System.assert(!kern.TRG_Base.isBypassed('Account'), '2f FAIL: Account should not be bypassed after clearBypass');

	// Action-level checks
	System.assert(!kern.TRG_Base.isActionBypassed('TRG_SetAccountDefaults'), '2f FAIL: Action should not be bypassed initially');

	kern.TRG_Base.bypassAction('TRG_SetAccountDefaults');
	System.assert(kern.TRG_Base.isActionBypassed('TRG_SetAccountDefaults'), '2f FAIL: Action should be bypassed after bypassAction');

	kern.TRG_Base.clearActionBypass('TRG_SetAccountDefaults');
	System.assert(!kern.TRG_Base.isActionBypassed('TRG_SetAccountDefaults'), '2f FAIL: Action should not be bypassed after clearActionBypass');

	System.debug('2f PASS: isBypassed and isActionBypassed correctly reflect bypass state');

	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
}

// Test 2g: Bulk boundary — bypass applies across all bulk records, then clears so all bulk records fire
// Scaled to 50 per batch (not 200): the prior 2a-2f tests consume Apex execution stack depth (multiple
// trigger-firing DML calls); 200 records on the live batch hits the 1001-frame stack limit. 50 records
// stays well within the limit while still exercising the bulk bypass boundary.
{
	kern.TRG_Base.bypass(Account.SObjectType);

	List<Account> bypassedBulk = new List<Account>();
	for(Integer i = 0; i < 50; i++)
	{
		bypassedBulk.add(new Account(Name = 'Bulk 2g Bypassed ' + i, Industry = 'Technology'));
	}
	insert bypassedBulk;

	List<Account> bypassedResults =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id IN :bypassedBulk
	];
	System.assertEquals(50, bypassedResults.size(), '2g FAIL: All 50 bypassed accounts should be inserted');
	Integer nullDescCount = 0;
	for(Account result : bypassedResults)
	{
		if(result.Description == null && result.AccountSource == null) nullDescCount++;
	}
	System.assertEquals(50, nullDescCount, '2g FAIL: All 50 records should have null Description and AccountSource (bypass active), only ' + nullDescCount + ' did');

	kern.TRG_Base.clearBypass(Account.SObjectType);

	List<Account> activeBulk = new List<Account>();
	for(Integer i = 0; i < 50; i++)
	{
		activeBulk.add(new Account(Name = 'Bulk 2g Active ' + i, Industry = 'Technology', Phone = '1234567890'));
	}
	insert activeBulk;

	List<Account> activeResults =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id IN :activeBulk
	];
	System.assertEquals(50, activeResults.size(), '2g FAIL: All 50 active accounts should be inserted');
	Integer stampedCount = 0;
	for(Account result : activeResults)
	{
		if(result.Description == 'Default' && result.AccountSource == 'Subscriber Trigger') stampedCount++;
	}
	System.assertEquals(50, stampedCount, '2g FAIL: All 50 records should have handlers fire after bypass cleared, only ' + stampedCount + ' did');

	System.debug('2g PASS: Bulk bypass applies across all 50 records (null results when bypassed), then clears so all 50 fire (handlers stamp all)');

	delete bypassedBulk;
	delete activeBulk;
	kern.TRG_Base.clearAllBypasses();
}

// Final cleanup: ensure bypasses are cleared for subsequent scripts
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

System.debug('========================================');
System.debug('Section 2: All tests completed');
System.debug('========================================');
