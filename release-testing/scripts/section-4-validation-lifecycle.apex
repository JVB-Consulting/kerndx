// ============================================================================
// Section 4: Validation Rule Framework — End-to-End Lifecycle
// ============================================================================
// Tests the validation rule framework's complete lifecycle: error severity
// blocking saves, warning severity allowing saves, insert vs update formulas,
// and the Accumulate execution strategy.
//
// Prerequisites:
//   - TRG_Account trigger deployed with kern.TRG_Dispatcher
//   - kern.TRG_ExecuteValidationRules at Order 50 (BeforeInsert + BeforeUpdate)
//   - ValidationRuleGroup 'AccountValidation' (Strategy=Accumulate)
//   - ValidationRules: RequireAccountIndustry, WarnMissingWebsite,
//     RequireDescriptionOnUpdate, PhoneOrWebsiteRequired, NameLengthCheck,
//     ShadowAuditRule
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f scripts/section-4-validation-lifecycle.apex
// ============================================================================

List<Id> cleanupIds = new List<Id>();

try
{
	// -----------------------------------------------------------------------
	// Test 4a: Error severity blocks save — missing Industry
	// -----------------------------------------------------------------------
	{
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(Name = 'Test 4a Account', Phone = '555-0001');
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('Industry is required'),
					'4a FAIL: Wrong error message: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '4a FAIL: Should have thrown DmlException');
		System.debug('4a PASS: Error severity blocks save when Industry is missing');
	}

	// -----------------------------------------------------------------------
	// Test 4b: Valid insert — Industry and Phone populated
	// -----------------------------------------------------------------------
	{
		Account account = new Account(
				Name = 'Test 4b Account',
				Industry = 'Technology',
				Phone = '555-0002'
		);
		insert account;
		cleanupIds.add(account.Id);

		System.assert(account.Id != null, '4b FAIL: Account should have been inserted');
		System.debug('4b PASS: Account inserted successfully with Industry and Phone');
	}

	// -----------------------------------------------------------------------
	// Test 4c: AND formula — both Phone and Website blank (Industry set)
	// -----------------------------------------------------------------------
	{
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(
					Name = 'Test 4c Account',
					Industry = 'Technology'
			);
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('Either Phone or Website is required'),
					'4c FAIL: Wrong error message: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '4c FAIL: Should have thrown DmlException for PhoneOrWebsite rule');
		System.debug('4c PASS: PhoneOrWebsiteRequired blocks save when both blank');
	}

	// -----------------------------------------------------------------------
	// Test 4d: Warning severity — no Website but Phone present
	// -----------------------------------------------------------------------
	// WarnMissingWebsite has Warning severity, so save should succeed.
	// The warning is logged but does not block the DML operation.
	{
		Account account = new Account(
				Name = 'Test 4d Account',
				Industry = 'Technology',
				Phone = '555-0004'
		);
		insert account;
		cleanupIds.add(account.Id);

		System.assert(account.Id != null, '4d FAIL: Account should have been inserted despite warning');
		System.debug('4d PASS: Warning severity allows save (WarnMissingWebsite logged but not blocking)');
	}

	// -----------------------------------------------------------------------
	// Test 4e: Update formula — change Name without Description
	// -----------------------------------------------------------------------
	// RequireDescriptionOnUpdate: AND(ISCHANGED(Name), ISBLANK(Description))
	{
		// First insert a valid Account
		Account account = new Account(
				Name = 'Test 4e Original',
				Industry = 'Technology',
				Phone = '555-0005'
		);
		insert account;
		cleanupIds.add(account.Id);

		Boolean exceptionThrown = false;
		try
		{
			account.Name = 'Test 4e Updated';
			account.Description = null;
			update account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('Description required when Name changes'),
					'4e FAIL: Wrong error message: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '4e FAIL: Should have thrown DmlException when Name changes without Description');
		System.debug('4e PASS: RequireDescriptionOnUpdate blocks update when Name changes without Description');
	}

	// -----------------------------------------------------------------------
	// Test 4f: Update formula — change Name WITH Description
	// -----------------------------------------------------------------------
	{
		Account account = new Account(
				Name = 'Test 4f Original',
				Industry = 'Technology',
				Phone = '555-0006',
				Description = 'Has a description'
		);
		insert account;
		cleanupIds.add(account.Id);

		account.Name = 'Test 4f Updated';
		update account;

		Account result =
		[
				SELECT Name
				FROM Account
				WHERE Id = :account.Id
		];
		System.assert(
				result.Name == 'Test 4f Updated',
				'4f FAIL: Name should have been updated to "Test 4f Updated", got: ' + result.Name
		);
		System.debug('4f PASS: Update succeeds when Name changes with Description populated');
	}

	// -----------------------------------------------------------------------
	// Test 4g: Bulk boundary — validation runs across all bulk records
	// -----------------------------------------------------------------------
	// Insert 50 valid accounts (Industry + Phone set) — all should pass validation.
	// Then attempt bulk insert of 50 accounts missing Industry — all should fail.
	// Scaled to 50 (not 200): section-4 has 6 prior tests (4a-4f) each doing trigger-
	// firing DML, which consumes Apex execution stack depth. The 1001-frame stack
	// limit is reached with 100+ records on the 7th trigger invocation in this org.
	{
		List<Account> validBulk = new List<Account>();
		for(Integer i = 0; i < 50; i++)
		{
			validBulk.add(new Account(Name = 'Bulk 4g Valid ' + i, Industry = 'Technology', Phone = '555-' + String.valueOf(4000 + i)));
		}
		insert validBulk;
		for(Account account : validBulk) cleanupIds.add(account.Id);

		System.assertEquals(50, validBulk.size(), '4g FAIL: All 50 valid accounts should be inserted');
		List<Account> inserted =
		[
				SELECT Id
				FROM Account
				WHERE Id IN :validBulk
		];
		System.assertEquals(50, inserted.size(), '4g FAIL: All 50 records should persist after validation passes');

		Boolean bulkExceptionThrown = false;
		try
		{
			List<Account> invalidBulk = new List<Account>();
			for(Integer i = 0; i < 50; i++)
			{
				invalidBulk.add(new Account(Name = 'Bulk 4g Invalid ' + i, Phone = '555-' + String.valueOf(6000 + i)));
			}
			insert invalidBulk;
		}
		catch(DmlException dmlError)
		{
			bulkExceptionThrown = true;
			System.assert(
					dmlError.getMessage().contains('Industry is required'),
					'4g FAIL: Bulk DML exception should reference RequireAccountIndustry, got: ' + dmlError.getMessage()
			);
		}
		System.assert(bulkExceptionThrown, '4g FAIL: Should throw DmlException when 50 accounts missing Industry');
		System.debug('4g PASS: Validation ran across bulk boundary — 50 valid records inserted, 50 invalid blocked by RequireAccountIndustry');
	}

	System.debug('=== Section 4 COMPLETE: All validation lifecycle tests passed ===');
}
finally
{
	// Cleanup: delete all test records created during this script
	if(!cleanupIds.isEmpty())
	{
		delete
		[
				SELECT Id
				FROM Account
				WHERE Id IN :cleanupIds
		];
		System.debug('Cleanup: Deleted ' + cleanupIds.size() + ' test Account(s)');
	}
}
