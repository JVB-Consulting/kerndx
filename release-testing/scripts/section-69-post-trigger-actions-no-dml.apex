// =============================================================================
// Section 69: Post-Trigger Actions — No-DML Contract Guard
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 67 prerequisites (base post-action CMDT + TST_PostAction* classes)
//   - Run the dml-active fixture deploy BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js dml-active
//   - Run the postaction-disabled fixture deploy AFTER this script:
//       node release-testing/runner/cmdt-deployer.js postaction-disabled
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-69-post-trigger-actions-no-dml.apex
//
// Section list (2 PASS expected):
//   69a — the no-DML guard throws naming synchronous DML and the offending action class
//   69b — the originating DML rolls back when the no-DML guard fires
// (PostActionDmlException is public, not global, so assert on the message text, never widen global.)
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	System.assert(kern.UTIL_FeatureFlag.isEnabled('EnablePostActionReleaseTest'),
			'69 setup FAIL: EnablePostActionReleaseTest must be on — dml-active fixture deploy missing?');

	Boolean threw = false;
	String message = '';
	try
	{
		Account account = new Account(Name = 'Section 69 No DML', Industry = 'Technology', Phone = '5550100');
		insert account;
	}
	catch(Exception error)
	{
		threw = true;
		message = error.getMessage();
	}

	System.assert(threw, '69a FAIL: the no-DML guard should throw when a post-action performs synchronous DML');
	System.assert(message.contains('synchronous DML'), '69a FAIL: exception should mention synchronous DML, got: ' + message);
	System.assert(message.contains('TST_PostActionDml'), '69a FAIL: exception should name the offending post-action class, got: ' + message);
	System.debug('69a PASS: the no-DML contract guard throws naming synchronous DML and the offending action');

	Integer surviving =
	[
			SELECT COUNT()
			FROM Account
			WHERE Name = 'Section 69 No DML'
	];
	System.assertEquals(0, surviving, '69b FAIL: the originating DML must roll back when the no-DML guard fires');
	System.debug('69b PASS: the originating DML rolls back when the no-DML guard fires');

	System.debug('========================================');
	System.debug('Section 69: All tests completed (2/2)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
