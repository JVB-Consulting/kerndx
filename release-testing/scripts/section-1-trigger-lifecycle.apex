// =============================================================================
// Section 1: Trigger Handler Lifecycle
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - TRG_Account trigger deployed on Account (before insert, before update)
//   - TRG_SetAccountDefaults (Order=100, BeforeInsert) — sets Description='Default' when blank
//   - TRG_ValidateAccountName (Order=200, BeforeInsert) — addError if Name contains 'BLOCKED'
//   - TRG_StampAccountSource (Order=300, BeforeInsert + BeforeUpdate) — sets AccountSource='Subscriber Trigger'
//   - kern.TRG_ExecuteValidationRules (Order=50, BeforeInsert + BeforeUpdate) — formula validation rules
//   - All TriggerAction__mdt records active (BypassExecution__c = false)
//   - TriggerSetting__mdt 'Account' active (BypassExecution__c = false, no RequiredPermission)
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-1-trigger-lifecycle.apex
// =============================================================================

// Bypass the flow trigger action — sections 41-44 cover that surface; this section tests Apex actions only
kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
// Bypass validation rules — this section tests triggers, not validation
kern.UTIL_ValidationRule.bypassObject('Account');

// Test 1a: Basic handler fires on insert — blank Description gets default, AccountSource stamped
{
	Account account = new Account(Name = 'Test Account 1a', Industry = 'Technology', Phone = '1234567890');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Default', result.Description, '1a FAIL: Description should be set to Default when blank');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '1a FAIL: AccountSource should be set to Subscriber Trigger');
	System.debug('1a PASS: Basic handler fires on insert — Description defaulted, AccountSource stamped');

	delete account;
}

// Test 1b: Pre-populated Description is NOT overwritten, AccountSource still stamped
{
	Account account = new Account(Name = 'Test Account 1b', Description = 'Custom Description', Industry = 'Technology', Phone = '1234567890');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Custom Description', result.Description, '1b FAIL: Pre-populated Description should not be overwritten');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '1b FAIL: AccountSource should still be stamped');
	System.debug('1b PASS: Pre-populated Description preserved, AccountSource stamped');

	delete account;
}

// Test 1c: Update Account Name triggers BeforeUpdate handler — AccountSource re-stamped
{
	Account account = new Account(Name = 'Test Account 1c', Industry = 'Technology', Phone = '1234567890');
	insert account;

	// Clear AccountSource to verify it gets re-stamped on Name change
	account.AccountSource = null;
	account.Name = 'Test Account 1c Updated';
	update account;

	Account result =
	[
			SELECT Name,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Test Account 1c Updated', result.Name, '1c FAIL: Name should be updated');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '1c FAIL: AccountSource should be re-stamped on Name change');
	System.debug('1c PASS: Update with Name change re-stamps AccountSource');

	delete account;
}

// Test 1d: Update non-Name field does NOT re-stamp AccountSource (triggerOldMap check)
{
	Account account = new Account(Name = 'Test Account 1d', Industry = 'Technology', Phone = '1234567890');
	insert account;

	// AccountSource is 'Subscriber Trigger' after insert — clear it, then update Description only
	account.AccountSource = 'Other Source';
	account.Description = 'Updated Description';
	update account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Updated Description', result.Description, '1d FAIL: Description should be updated');
	System.assertEquals('Other Source', result.AccountSource, '1d FAIL: AccountSource should NOT be re-stamped when Name unchanged');
	System.debug('1d PASS: Non-Name update does not re-stamp AccountSource');

	delete account;
}

// Test 1e: Insert with BLOCKED in Name throws DML exception via addError
{
	Boolean exceptionThrown = false;
	Account account;

	try
	{
		account = new Account(Name = 'BLOCKED Account 1e', Industry = 'Technology', Phone = '1234567890');
		insert account;
	}
	catch(DmlException error)
	{
		exceptionThrown = true;
		System.assert(error.getMessage().contains('Account Name cannot contain BLOCKED'),
				'1e FAIL: Error message should contain the addError text, got: ' + error.getMessage());
	}

	System.assert(exceptionThrown, '1e FAIL: DmlException should have been thrown for BLOCKED name');
	System.debug('1e PASS: BLOCKED name correctly prevented insert via addError');

	// No cleanup needed — record was not inserted
}

kern.UTIL_ValidationRule.clearBypass('Account');

// Test 1f: Bulk-100 boundary — all 100 accounts receive default Description and AccountSource stamp
// Scaled to 100 (not 200): TRG_Dispatcher's deep dispatch chain (handler instantiation + execution × 5 handlers)
// consumes Apex execution stack depth. Combined with prior 1a-1e DML, 200 records hits the 1001-frame
// stack depth limit; 100 records stays comfortably within the limit across the full section run.
{
	List<Account> bulkAccounts = new List<Account>();
	for(Integer i = 0; i < 100; i++)
	{
		bulkAccounts.add(new Account(Name = 'Bulk 1f Account ' + i, Industry = 'Technology', Phone = '1234567890'));
	}
	insert bulkAccounts;

	List<Account> bulkResults =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id IN :bulkAccounts
	];
	System.assertEquals(100, bulkResults.size(), '1f FAIL: All 100 accounts should have been inserted');
	Integer defaultedCount = 0;
	Integer stampedCount = 0;
	for(Account result : bulkResults)
	{
		if(result.Description == 'Default') defaultedCount++;
		if(result.AccountSource == 'Subscriber Trigger') stampedCount++;
	}
	System.assertEquals(100, defaultedCount, '1f FAIL: All 100 accounts should have Description=Default, only ' + defaultedCount + ' did');
	System.assertEquals(100, stampedCount, '1f FAIL: All 100 accounts should have AccountSource=Subscriber Trigger, only ' + stampedCount + ' did');
	System.debug('1f PASS: TRG_Dispatcher fired on all 100 records — ' + defaultedCount + ' defaulted, ' + stampedCount + ' stamped');

	delete bulkAccounts;
}

System.debug('========================================');
System.debug('Section 1: All tests completed');
System.debug('========================================');
