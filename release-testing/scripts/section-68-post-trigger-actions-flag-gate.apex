// =============================================================================
// Section 68: Post-Trigger Actions — Required-Feature-Flag Gate, OFF leg
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 67 prerequisites (base post-action CMDT + TST_PostAction* classes)
//   - Run the postaction-disabled fixture deploy BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js postaction-disabled
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-68-post-trigger-actions-flag-gate.apex
//
// Section list (1 PASS expected — paired with section-68b for the ON leg):
//   68a — required-feature-flag gate keeps post-actions dormant when the flag is off
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	System.assert(!kern.UTIL_FeatureFlag.isEnabled('EnablePostActionReleaseTest'),
			'68a FAIL: EnablePostActionReleaseTest must be off — postaction-disabled fixture deploy missing?');

	TST_PostActionRecorder.reset();
	Account account = new Account(Name = 'Section 68a Flag Off', Industry = 'Technology', Phone = '5550100');
	insert account;

	System.assert(TST_PostActionRecorder.executionOrder.isEmpty(),
			'68a FAIL: post-actions must not fire when the required feature flag is off');
	System.debug('68a PASS: required-feature-flag gate keeps post-actions dormant when the flag is off');

	delete account;

	System.debug('========================================');
	System.debug('Section 68 (flag off): leg completed (1/2)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
