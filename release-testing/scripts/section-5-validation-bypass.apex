// ============================================================================
// Section 5: Validation Bypass Mechanisms
// ============================================================================
// Tests the three levels of programmatic validation bypass: object-level,
// group-level, and rule-level. Also verifies clearAllBypasses resets state.
//
// All bypasses are wrapped in try/finally to guarantee cleanup, preventing
// leftover bypass state from affecting subsequent scripts.
//
// Prerequisites:
//   - TRG_Account trigger deployed with kern.TRG_Dispatcher
//   - kern.TRG_ExecuteValidationRules at Order 50 (BeforeInsert + BeforeUpdate)
//   - ValidationRuleGroup 'AccountValidation' (Strategy=Accumulate)
//   - ValidationRules: RequireAccountIndustry, PhoneOrWebsiteRequired
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f scripts/section-5-validation-bypass.apex
// ============================================================================

List<Id> cleanupIds = new List<Id>();

try
{
	// -----------------------------------------------------------------------
	// Test 5a: Object-level bypass — bypassObject / clearBypass
	// -----------------------------------------------------------------------
	{
		// Phase 1: Bypass active — insert without Industry should succeed
		kern.UTIL_ValidationRule.bypassObject('Account');
		try
		{
			Account account = new Account(Name = 'Test 5a Bypassed', Phone = '555-0501');
			insert account;
			cleanupIds.add(account.Id);

			System.assert(account.Id != null, '5a FAIL: Insert should succeed with object bypass active');
			System.debug('5a Phase 1 PASS: Object bypass allows insert without Industry');
		}
		finally
		{
			kern.UTIL_ValidationRule.clearBypass('Account');
		}

		// Phase 2: Bypass cleared — insert without Industry should fail
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(Name = 'Test 5a No Bypass', Phone = '555-0502');
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('Industry is required'),
					'5a FAIL: Wrong error after clearing bypass: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '5a FAIL: Should have thrown DmlException after bypass cleared');
		System.debug('5a Phase 2 PASS: Validation fires again after clearBypass');
		System.debug('5a PASS: Object-level bypass and clearBypass work correctly');
	}

	// -----------------------------------------------------------------------
	// Test 5b: Group-level bypass — bypassGroup / clearBypass
	// -----------------------------------------------------------------------
	{
		kern.UTIL_ValidationRule.bypassGroup('AccountValidation');
		try
		{
			// All rules in AccountValidation group bypassed — no Industry, no Phone, no Website
			Account account = new Account(Name = 'Test 5b Group Bypass');
			insert account;
			cleanupIds.add(account.Id);

			System.assert(account.Id != null, '5b FAIL: Insert should succeed with group bypass active');
			System.debug('5b Phase 1 PASS: Group bypass allows insert without Industry, Phone, or Website');
		}
		finally
		{
			kern.UTIL_ValidationRule.clearBypass('AccountValidation');
		}

		// Verify bypass is cleared
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(Name = 'Test 5b No Bypass', Phone = '555-0503');
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('Industry is required'),
					'5b FAIL: Wrong error after clearing group bypass: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '5b FAIL: Should have thrown DmlException after group bypass cleared');
		System.debug('5b PASS: Group-level bypass and clearBypass work correctly');
	}

	// -----------------------------------------------------------------------
	// Test 5c: Rule-level bypass — bypassRule / clearBypass
	// -----------------------------------------------------------------------
	// Bypass only RequireAccountIndustry; PhoneOrWebsiteRequired still active,
	// so Phone must be set to satisfy it.
	{
		kern.UTIL_ValidationRule.bypassRule('RequireAccountIndustry');
		try
		{
			Account account = new Account(Name = 'Test 5c Rule Bypass', Phone = '555-0504');
			insert account;
			cleanupIds.add(account.Id);

			System.assert(account.Id != null, '5c FAIL: Insert should succeed with rule bypass (Phone satisfies PhoneOrWebsite)');
			System.debug('5c Phase 1 PASS: Rule bypass skips RequireAccountIndustry while other rules still fire');
		}
		finally
		{
			kern.UTIL_ValidationRule.clearBypass('RequireAccountIndustry');
		}

		// Verify bypass is cleared — Industry still required
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(Name = 'Test 5c No Bypass', Phone = '555-0505');
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('Industry is required'),
					'5c FAIL: Wrong error after clearing rule bypass: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '5c FAIL: Should have thrown DmlException after rule bypass cleared');
		System.debug('5c PASS: Rule-level bypass and clearBypass work correctly');
	}

	// -----------------------------------------------------------------------
	// Test 5d: clearAllBypasses — resets all bypass types at once
	// -----------------------------------------------------------------------
	{
		// Set multiple bypass levels simultaneously
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.UTIL_ValidationRule.bypassGroup('AccountValidation');
		kern.UTIL_ValidationRule.bypassRule('RequireAccountIndustry');

		// Verify all three are active
		System.assert(kern.UTIL_ValidationRule.isBypassed('Account'), '5d FAIL: Object bypass should be active');
		System.assert(kern.UTIL_ValidationRule.isBypassed('AccountValidation'), '5d FAIL: Group bypass should be active');
		System.assert(kern.UTIL_ValidationRule.isBypassed('RequireAccountIndustry'), '5d FAIL: Rule bypass should be active');

		// Clear everything at once
		kern.UTIL_ValidationRule.clearAllBypasses();

		// Verify all three are cleared
		System.assert(!kern.UTIL_ValidationRule.isBypassed('Account'), '5d FAIL: Object bypass should be cleared');
		System.assert(!kern.UTIL_ValidationRule.isBypassed('AccountValidation'), '5d FAIL: Group bypass should be cleared');
		System.assert(!kern.UTIL_ValidationRule.isBypassed('RequireAccountIndustry'), '5d FAIL: Rule bypass should be cleared');

		// Verify validation fires again after clearAll
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(Name = 'Test 5d After ClearAll', Phone = '555-0506');
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.assert(
					e.getMessage().contains('Industry is required'),
					'5d FAIL: Wrong error after clearAllBypasses: ' + e.getMessage()
			);
		}
		System.assert(exceptionThrown, '5d FAIL: Should have thrown DmlException after clearAllBypasses');
		System.debug('5d PASS: clearAllBypasses resets all bypass types and validation fires again');
	}

	System.debug('=== Section 5 COMPLETE: All validation bypass tests passed ===');
}
finally
{
	// Safety net: always clear all validation bypasses regardless of test outcome
	kern.UTIL_ValidationRule.clearAllBypasses();

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
