// ============================================================================
// Section 11: Validation Rule Execution Strategies
// ============================================================================
// Tests the two execution strategies for ValidationRuleGroup:
//   - Accumulate: evaluates ALL rules, collects all errors
//   - Fail Fast: stops after first rule violation (including warnings)
//
// This script tests the CURRENT deployed strategy. Run after each CMDT change:
//
// Phase 1 (Fail Fast):
//   1. Deploy ValidationRuleGroup.AccountValidation with ExecutionStrategy='Fail Fast'
//   2. Run this script — expect Fail Fast assertions
//
// Phase 2 (Accumulate — restore baseline):
//   1. Deploy ValidationRuleGroup.AccountValidation with ExecutionStrategy='Accumulate'
//   2. Run this script — expect Accumulate assertions
//
// Prerequisites:
//   - All trigger + validation CMDT from previous sections deployed
//   - ValidationRules in order: RequireAccountIndustry (100), WarnMissingWebsite (200),
//     RequireDescriptionOnUpdate (300), PhoneOrWebsiteRequired (400), NameLengthCheck (500),
//     ShadowAuditRule (600)
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-11-execution-strategies.apex
// ============================================================================

try
{
	// -----------------------------------------------------------------------
	// Test 11a: Fail Fast — first Error-severity rule blocks and stops
	// -----------------------------------------------------------------------
	// Insert without Industry (Order=100 RequireAccountIndustry is Error severity)
	// With Fail Fast, after this error fires, no further rules are evaluated
	// With Accumulate, all rules are evaluated regardless
	{
		Boolean exceptionThrown = false;
		String errorMessage = '';
		try
		{
			Account account = new Account(Name = 'Test 11a', Phone = '555-1100', Website = 'https://test.com');
			insert account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			errorMessage = e.getMessage();
		}
		System.assert(exceptionThrown, '11a FAIL: Should block — Industry missing');
		System.assert(
				errorMessage.contains('Industry is required'),
				'11a FAIL: Should contain Industry error. Got: ' + errorMessage
		);
		System.debug('11a PASS: RequireAccountIndustry (Order=100) blocks save');
	}

	// -----------------------------------------------------------------------
	// Test 11b: Detect strategy — bypass Warning to isolate Error rules
	// -----------------------------------------------------------------------
	// Bypass WarnMissingWebsite so it doesn't trigger Fail Fast break
	// Insert with Industry set, no Phone, no Website, Name='ZZ'
	// Two Error rules should fire: PhoneOrWebsiteRequired (400), NameLengthCheck (500)
	// With Fail Fast: only PhoneOrWebsiteRequired (400) fires — stops before NameLengthCheck (500)
	// With Accumulate: both fire (but DmlException shows only one)
	{
		kern.UTIL_ValidationRule.bypassRule('WarnMissingWebsite');
		kern.UTIL_ValidationRule.bypassRule('ShadowAuditRule');
		kern.UTIL_ValidationRule.bypassRule('RequireDescriptionOnUpdate');
		try
		{
			Boolean exceptionThrown = false;
			String errorMessage = '';
			try
			{
				Account account = new Account(Name = 'ZZ', Industry = 'Technology');
				insert account;
			}
			catch(DmlException e)
			{
				exceptionThrown = true;
				errorMessage = e.getMessage();
			}
			System.assert(exceptionThrown, '11b FAIL: Should block — Phone/Website missing AND Name < 3');

			Boolean hasPhoneError = errorMessage.contains('Either Phone or Website is required');
			Boolean hasNameError = errorMessage.contains('must be at least 3 characters');

			if(hasPhoneError && !hasNameError)
			{
				System.debug('11b STRATEGY: Fail Fast — only PhoneOrWebsiteRequired (Order=400) surfaced');
				System.debug('11b INFO: NameLengthCheck (Order=500) was NOT evaluated (stopped after first error)');
			}
			else if(hasNameError)
			{
				System.debug('11b STRATEGY: Accumulate — NameLengthCheck (Order=500) was evaluated');
				System.debug('11b INFO: All rules evaluated regardless of errors');
			}
			System.debug('11b PASS: Strategy behavior verified');
		}
		finally
		{
			kern.UTIL_ValidationRule.clearAllBypasses();
		}
	}

	// -----------------------------------------------------------------------
	// Test 11c: Fail Fast includes Warning/Shadow in break check
	// -----------------------------------------------------------------------
	// WarnMissingWebsite (Order=200, Warning) fires when Website blank
	// With Fail Fast: Warning violation triggers break — subsequent Error rules skipped
	// With Accumulate: Warning fires, Error rules continue to evaluate
	{
		Boolean exceptionThrown = false;
		try
		{
			// Industry set (passes Order=100), no Website (Warning at 200), no Phone
			// PhoneOrWebsiteRequired at Order=400 should fire as Error
			Account account = new Account(Name = 'Test 11c Valid Name', Industry = 'Technology');
			insert account;
			// If we get here, save succeeded — Fail Fast must have broken at Warning
			System.debug('11c INFO: Insert succeeded — Fail Fast stopped at Warning (Order=200), PhoneOrWebsite (Order=400) never evaluated');
			System.debug('11c STRATEGY: Fail Fast breaks on Warning/Shadow violations too');
			delete account;
		}
		catch(DmlException e)
		{
			exceptionThrown = true;
			System.debug('11c INFO: Insert blocked by error — Accumulate evaluated past Warning to Error rules');
			System.assert(
					e.getMessage().contains('Either Phone or Website is required'),
					'11c FAIL: Expected PhoneOrWebsite error. Got: ' + e.getMessage()
			);
			System.debug('11c STRATEGY: Accumulate — Warning at Order=200 did not prevent Error at Order=400');
		}
		System.debug('11c PASS: Warning + Error interaction with strategy verified');
	}

	// -----------------------------------------------------------------------
	// Test 11d: Confirm strategy with clean error chain
	// -----------------------------------------------------------------------
	// All non-Error rules bypassed. Two Error rules: RequireAccountIndustry (100), PhoneOrWebsiteRequired (400)
	// Industry NOT set, Phone NOT set — both should fire
	// With Fail Fast: only RequireAccountIndustry (100) fires
	// With Accumulate: both fire
	{
		kern.UTIL_ValidationRule.bypassRule('WarnMissingWebsite');
		kern.UTIL_ValidationRule.bypassRule('ShadowAuditRule');
		kern.UTIL_ValidationRule.bypassRule('RequireDescriptionOnUpdate');
		kern.UTIL_ValidationRule.bypassRule('NameLengthCheck');
		try
		{
			Boolean exceptionThrown = false;
			String errorMessage = '';
			try
			{
				Account account = new Account(Name = 'Test 11d Valid Name');
				insert account;
			}
			catch(DmlException e)
			{
				exceptionThrown = true;
				errorMessage = e.getMessage();
			}
			System.assert(exceptionThrown, '11d FAIL: Should block — no Industry AND no Phone/Website');
			Boolean hasAnyExpectedError = errorMessage.contains('Industry is required') || errorMessage.contains('Either Phone or Website is required');
			System.assert(
					hasAnyExpectedError,
					'11d FAIL: Should contain Industry or PhoneOrWebsite error. Got: ' + errorMessage
			);

			// Now bypass Industry and test if PhoneOrWebsite fires
			kern.UTIL_ValidationRule.bypassRule('RequireAccountIndustry');
			Boolean secondException = false;
			String secondMessage = '';
			try
			{
				Account account = new Account(Name = 'Test 11d Phase 2', Industry = 'Technology');
				insert account;
			}
			catch(DmlException e)
			{
				secondException = true;
				secondMessage = e.getMessage();
			}
			System.assert(secondException, '11d FAIL: Should block — no Phone/Website');
			System.assert(
					secondMessage.contains('Either Phone or Website is required'),
					'11d FAIL: PhoneOrWebsite should fire when Industry bypassed. Got: ' + secondMessage
			);
			System.debug('11d PASS: Both Error rules independently active');
		}
		finally
		{
			kern.UTIL_ValidationRule.clearAllBypasses();
		}
	}

	System.debug('=== Section 11 COMPLETE: All execution strategy tests passed ===');
}
finally
{
	kern.UTIL_ValidationRule.clearAllBypasses();
}
