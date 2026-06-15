// =============================================================================
// Section 68b: Post-Trigger Actions — Required-Feature-Flag Gate, ON leg
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 67 prerequisites (base post-action CMDT + TST_PostAction* classes)
//   - Run the postaction-enabled fixture deploy BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js postaction-enabled
//   - Run the postaction-disabled fixture deploy AFTER this script:
//       node release-testing/runner/cmdt-deployer.js postaction-disabled
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-68b-post-trigger-actions-flag-gate.apex
//
// Section list (1 PASS expected — paired with section-68 for the OFF leg):
//   68b — required-feature-flag gate enables post-actions when the flag is on
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	System.assert(kern.UTIL_FeatureFlag.isEnabled('EnablePostActionReleaseTest'),
			'68b FAIL: EnablePostActionReleaseTest must be on — postaction-enabled fixture deploy missing?');

	TST_PostActionRecorder.reset();
	Account account = new Account(Name = 'Section 68b Flag On', Industry = 'Technology', Phone = '5550100');
	insert account;

	System.assert(TST_PostActionRecorder.executionOrder.contains('Recorder'),
			'68b FAIL: post-actions should fire when the required feature flag is on');
	System.debug('68b PASS: required-feature-flag gate enables post-actions when the flag is on');

	delete account;

	System.debug('========================================');
	System.debug('Section 68 (flag on): leg completed (2/2)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
