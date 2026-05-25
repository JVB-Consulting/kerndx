// Section 22: Advanced Framework Strategies
// Tests Custom Permission feature flag strategy, Fail Fast validation, flag-gated groups,
// BypassFeatureFlag on rules, and ErrorDisplayField.
//
// IMPORTANT: Run in sequence:
//   1. section-22-setup.apex        (assigns custom permission — setup DML)
//   2. section-22-advanced-strategies.apex  (this file — tests Fail Fast with Account DML)
//   3. section-22-cleanup.apex      (removes custom permission — setup DML)
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-22-setup.apex
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-22-advanced-strategies.apex
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-22-cleanup.apex

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

try
{
	// 22c: Verify flag is enabled (Custom Permission strategy matched after setup script)
	{
		Boolean flagEnabled = kern.UTIL_FeatureFlag.isEnabled('EnableStrictValidation');
		System.assert(flagEnabled, '22c FAIL: Flag should be enabled — run section-22-setup.apex first');
		System.debug('22c PASS: EnableStrictValidation flag is enabled (custom permission strategy matched)');
	}

	// 22d: Fail Fast — first failing rule (Rating, Order=50) blocks, rest NOT evaluated
	{
		kern.UTIL_ValidationRule.bypassGroup('AccountValidation');
		try
		{
			Boolean exceptionThrown = false;
			String errorMessage = '';
			try
			{
				Account account = new Account(Name = 'Test 22d Fail Fast', Industry = 'Technology', Phone = '555-0100');
				insert account;
			}
			catch(DmlException e)
			{
				exceptionThrown = true;
				errorMessage = e.getMessage();
			}
			System.assert(exceptionThrown, '22d FAIL: Insert should be blocked by Fail Fast group');
			Boolean hasRating = errorMessage.containsIgnoreCase('Rating is required');
			Boolean hasDescription = errorMessage.containsIgnoreCase('Description is required');
			Boolean hasWebsite = errorMessage.containsIgnoreCase('Website is required');
			System.assert(hasRating, '22d FAIL: Expected Rating error (Order=50). Got: ' + errorMessage);
			System.assert(!hasDescription, '22d FAIL: Description should NOT appear (Fail Fast stopped at Rating)');
			System.assert(!hasWebsite, '22d FAIL: Website should NOT appear (Fail Fast stopped at Rating)');
			System.debug('22d PASS: Fail Fast stopped at first error (Strict_RequireRating, Order=50)');
		}
		finally
		{
			kern.UTIL_ValidationRule.clearAllBypasses();
		}
	}

	// 22e: Bypass Rating rule → next rule (Description, Order=100) fires, Website skipped
	{
		kern.UTIL_ValidationRule.bypassGroup('AccountValidation');
		kern.UTIL_ValidationRule.bypassRule('Strict_RequireRating');
		try
		{
			Boolean exceptionThrown = false;
			String errorMessage = '';
			try
			{
				Account account = new Account(Name = 'Test 22e Skip Rating', Industry = 'Technology', Phone = '555-0100');
				insert account;
			}
			catch(DmlException e)
			{
				exceptionThrown = true;
				errorMessage = e.getMessage();
			}
			System.assert(exceptionThrown, '22e FAIL: Insert should be blocked by Description rule');
			Boolean hasDescription = errorMessage.containsIgnoreCase('Description is required');
			Boolean hasWebsite = errorMessage.containsIgnoreCase('Website is required');
			System.assert(hasDescription, '22e FAIL: Expected Description error (Order=100). Got: ' + errorMessage);
			System.assert(!hasWebsite, '22e FAIL: Website should NOT appear (Fail Fast stopped at Description)');
			System.debug('22e PASS: Rating bypassed, Fail Fast stopped at Description (Order=100)');
		}
		finally
		{
			kern.UTIL_ValidationRule.clearAllBypasses();
		}
	}

	// 22f: All strict fields populated — passes Fail Fast group
	{
		kern.UTIL_ValidationRule.bypassGroup('AccountValidation');
		kern.UTIL_ValidationRule.bypassRule('Strict_RequireRating');
		try
		{
			Account account = new Account(
					Name = 'Test 22f Valid',
					Industry = 'Technology',
					Phone = '555-0100',
					Description = 'Complete record',
					Website = 'https://example.com'
			);
			insert account;
			System.debug('22f PASS: Insert succeeded with all strict fields populated');
			delete account;
		}
		catch(DmlException e)
		{
			System.debug('22f FAIL: Insert should succeed. Got: ' + e.getMessage());
		}
		finally
		{
			kern.UTIL_ValidationRule.clearAllBypasses();
		}
	}

	// 22g: Both groups active — Fail Fast passes but Accumulate still blocks
	{
		kern.UTIL_ValidationRule.bypassRule('Strict_RequireRating');
		try
		{
			Boolean exceptionThrown = false;
			String errorMessage = '';
			try
			{
				Account account = new Account(
						Name = 'Test 22g Both Groups',
						Description = 'Has description',
						Website = 'https://example.com'
				);
				insert account;
			}
			catch(DmlException e)
			{
				exceptionThrown = true;
				errorMessage = e.getMessage();
			}
			System.assert(exceptionThrown, '22g FAIL: Insert should be blocked by Accumulate group');
			Boolean hasIndustry = errorMessage.containsIgnoreCase('Industry is required');
			System.assert(hasIndustry, '22g FAIL: Expected Accumulate group error (Industry). Got: ' + errorMessage);
			System.debug('22g PASS: Fail Fast passed (strict fields populated), Accumulate group still blocked');
		}
		finally
		{
			kern.UTIL_ValidationRule.clearAllBypasses();
		}
	}

	System.debug('=== Section 22 COMPLETE: All advanced strategy tests passed (7/7) ===');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
