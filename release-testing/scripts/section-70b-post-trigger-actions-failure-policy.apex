// =============================================================================
// Section 70b: Post-Trigger Actions — Failure-Action Policy, BlockDml leg
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 67 prerequisites (base post-action CMDT + TST_PostAction* classes)
//   - Run the failing-blockdml fixture deploy BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js failing-blockdml
//   - Run the postaction-disabled fixture deploy AFTER this script:
//       node release-testing/runner/cmdt-deployer.js postaction-disabled
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-70b-post-trigger-actions-failure-policy.apex
//
// Section list (2 PASS expected — paired with section-70 for the LogAndContinue leg):
//   70c — BlockDml rethrows the post-action failure to the caller
//   70d — the originating DML rolls back under BlockDml
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	System.assert(kern.UTIL_FeatureFlag.isEnabled('EnablePostActionReleaseTest'),
			'70 setup FAIL: EnablePostActionReleaseTest must be on — failing-blockdml fixture deploy missing?');

	Boolean threw = false;
	String message = '';
	Account account = new Account(Name = 'Section 70 BlockDml', Industry = 'Technology', Phone = '5550100');
	try
	{
		insert account;
	}
	catch(Exception error)
	{
		threw = true;
		message = error.getMessage();
	}

	System.assert(threw, '70c FAIL: BlockDml should rethrow the post-action exception to the caller');
	System.assert(message.contains(TST_PostActionFailing.FAILURE_MESSAGE),
			'70c FAIL: the rethrown exception should surface the post-action failure message, got: ' + message);
	System.debug('70c PASS: BlockDml rethrows the post-action failure to the caller');

	Integer surviving =
	[
			SELECT COUNT()
			FROM Account
			WHERE Name = 'Section 70 BlockDml'
	];
	System.assertEquals(0, surviving, '70d FAIL: the originating DML must roll back under BlockDml');
	System.debug('70d PASS: the originating DML rolls back under BlockDml');

	System.debug('========================================');
	System.debug('Section 70 (BlockDml): leg completed (4/4)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
