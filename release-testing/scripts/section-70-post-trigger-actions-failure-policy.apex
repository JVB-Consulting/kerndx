// =============================================================================
// Section 70: Post-Trigger Actions — Failure-Action Policy, LogAndContinue leg
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 67 prerequisites (base post-action CMDT + TST_PostAction* classes)
//   - Run the failing-logandcontinue fixture deploy BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js failing-logandcontinue
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-70-post-trigger-actions-failure-policy.apex
//
// Section list (2 PASS expected — paired with section-70b for the BlockDml leg):
//   70a — LogAndContinue swallows the post-action exception so the DML succeeds
//   70b — the originating DML commits under LogAndContinue despite the post-action failure
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	System.assert(kern.UTIL_FeatureFlag.isEnabled('EnablePostActionReleaseTest'),
			'70 setup FAIL: EnablePostActionReleaseTest must be on — failing-logandcontinue fixture deploy missing?');

	Boolean threw = false;
	Account account = new Account(Name = 'Section 70 LogAndContinue', Industry = 'Technology', Phone = '5550100');
	try
	{
		insert account;
	}
	catch(Exception error)
	{
		threw = true;
	}

	System.assert(!threw, '70a FAIL: LogAndContinue should swallow the post-action exception so the DML succeeds');
	System.debug('70a PASS: LogAndContinue swallows the post-action failure and lets the DML commit');

	Integer surviving =
	[
			SELECT COUNT()
			FROM Account
			WHERE Name = 'Section 70 LogAndContinue'
	];
	System.assertEquals(1, surviving, '70b FAIL: the originating record should persist under LogAndContinue');
	System.debug('70b PASS: the originating DML commits under LogAndContinue despite the post-action failure');

	delete
	[
			SELECT Id
			FROM Account
			WHERE Name = 'Section 70 LogAndContinue'
	];

	System.debug('========================================');
	System.debug('Section 70 (LogAndContinue): leg completed (2/4)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
