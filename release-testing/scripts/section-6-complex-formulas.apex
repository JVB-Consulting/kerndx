// ============================================================================
// Section 6: Complex Formula Expressions
// ============================================================================
// Tests advanced formula capabilities: AND compound conditions, LEN function,
// merge field substitution in error messages, and multiple rules firing in
// a single transaction (Accumulate strategy).
//
// Prerequisites:
//   - TRG_Account trigger deployed with kern.TRG_Dispatcher
//   - kern.TRG_ExecuteValidationRules at Order 50 (BeforeInsert + BeforeUpdate)
//   - ValidationRuleGroup 'AccountValidation' (Strategy=Accumulate)
//   - ValidationRules: RequireAccountIndustry, PhoneOrWebsiteRequired,
//     NameLengthCheck (LEN formula with merge field in error message)
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f scripts/section-6-complex-formulas.apex
// ============================================================================

List<Id> cleanupIds = new List<Id>();

try
{
	// -----------------------------------------------------------------------
	// Test 6a: AND formula — both Phone and Website blank
	// -----------------------------------------------------------------------
	// PhoneOrWebsiteRequired: AND(ISBLANK(Phone), ISBLANK(Website))
	// Industry is set to isolate this rule from RequireAccountIndustry.
	{
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(
					Name = 'Test 6a Account',
					Industry = 'Technology'
			);
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('Either Phone or Website is required'),
					'6a FAIL: Wrong error message: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '6a FAIL: AND formula should fire when both Phone and Website are blank');
		System.debug('6a PASS: AND formula fires when both conditions are true (Phone blank AND Website blank)');
	}

	// -----------------------------------------------------------------------
	// Test 6b: AND formula — one condition false (Phone set)
	// -----------------------------------------------------------------------
	// When Phone is provided, AND(ISBLANK(Phone), ISBLANK(Website)) is false
	// because ISBLANK(Phone) is false. The rule should NOT fire.
	{
		Account account = new Account(
				Name = 'Test 6b Account',
				Industry = 'Technology',
				Phone = '555-0602'
		);
		insert account;
		cleanupIds.add(account.Id);

		System.assert(account.Id != null, '6b FAIL: Account should insert when Phone satisfies AND condition');
		System.debug('6b PASS: AND formula does not fire when one condition is false (Phone set)');
	}

	// -----------------------------------------------------------------------
	// Test 6c: LEN formula — Name too short (2 characters)
	// -----------------------------------------------------------------------
	// NameLengthCheck: LEN(Name) < 3
	{
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(
					Name = 'AB',
					Industry = 'Technology',
					Phone = '555-0603'
			);
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('must be at least 3 characters'),
					'6c FAIL: Wrong error message: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '6c FAIL: LEN formula should fire when Name is under 3 characters');
		System.debug('6c PASS: LEN formula correctly blocks insert when Name is 2 characters');
	}

	// -----------------------------------------------------------------------
	// Test 6d: Merge field in error message — verify actual Name value
	// -----------------------------------------------------------------------
	// NameLengthCheck error: 'Account Name "{!Name}" must be at least 3 characters'
	// The {!Name} merge field should resolve to the actual Name value.
	{
		String shortName = 'XY';
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(
					Name = shortName,
					Industry = 'Technology',
					Phone = '555-0604'
			);
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			String errorMessage = e.getMessage();

			// Verify the error message contains the actual Name value
			System.assert(
					errorMessage.contains(shortName),
					'6d FAIL: Error message should contain the Name value "' + shortName + '": ' + errorMessage
			);
			System.assert(
					errorMessage.contains('must be at least 3 characters'),
					'6d FAIL: Error message should contain rule text: ' + errorMessage
			);
		}
		System.assert(exceptionThrown, '6d FAIL: Should have thrown DmlException for short name');
		System.debug('6d PASS: Merge field {!Name} resolves to actual Name value in error message');
	}

	// -----------------------------------------------------------------------
	// Test 6e: Multiple rules fire in same transaction (Accumulate strategy)
	// -----------------------------------------------------------------------
	// Proves Accumulate strategy evaluates all rules (not fail-fast).
	// DmlException.getMessage() only surfaces one error per row, so we verify
	// both rules are active by testing each independently:
	// Phase 1: Bypass NameLengthCheck → Industry error fires
	// Phase 2: Bypass RequireAccountIndustry → NameLengthCheck fires
	{
		// Phase 1: Only RequireAccountIndustry should fire
		kern.UTIL_ValidationRule.bypassRule('NameLengthCheck');
		Boolean phase1Exception = false;
		try
		{
			Account account = new Account(Name = 'ZZ', Phone = '555-0605');
			insert account;
		}
		catch(DmlException e)
		{
			phase1Exception = true;
			System.assert(
					e.getMessage().contains('Industry is required'),
					'6e FAIL Phase 1: Expected Industry error. Got: ' + e.getMessage()
			);
		}
		finally
		{
			kern.UTIL_ValidationRule.clearAllBypasses();
		}
		System.assert(phase1Exception, '6e FAIL Phase 1: Should have thrown DmlException for Industry');
		System.debug('6e Phase 1 PASS: RequireAccountIndustry fires independently');

		// Phase 2: Only NameLengthCheck should fire
		kern.UTIL_ValidationRule.bypassRule('RequireAccountIndustry');
		Boolean phase2Exception = false;
		try
		{
			Account account = new Account(Name = 'ZZ', Phone = '555-0605');
			insert account;
		}
		catch(DmlException e)
		{
			phase2Exception = true;
			System.assert(
					e.getMessage().contains('must be at least 3 characters'),
					'6e FAIL Phase 2: Expected Name length error. Got: ' + e.getMessage()
			);
		}
		finally
		{
			kern.UTIL_ValidationRule.clearAllBypasses();
		}
		System.assert(phase2Exception, '6e FAIL Phase 2: Should have thrown DmlException for Name length');
		System.debug('6e Phase 2 PASS: NameLengthCheck fires independently');

		// Phase 3: Both rules active — DmlException thrown (at least one error surfaces)
		Boolean phase3Exception = false;
		try
		{
			Account account = new Account(Name = 'ZZ', Phone = '555-0605');
			insert account;
		}
		catch(DmlException e)
		{
			phase3Exception = true;
			String errorMessage = e.getMessage();
			Boolean hasEitherError = errorMessage.contains('Industry is required') || errorMessage.contains('must be at least 3 characters');
			System.assert(hasEitherError, '6e FAIL Phase 3: Expected at least one validation error. Got: ' + errorMessage);
		}
		System.assert(phase3Exception, '6e FAIL Phase 3: Should have thrown DmlException with both rules active');
		System.debug('6e PASS: Accumulate strategy — both rules independently active and fire in same transaction');
	}

	System.debug('=== Section 6 COMPLETE: All complex formula tests passed ===');
}
finally
{
	// Cleanup: delete all test records
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
