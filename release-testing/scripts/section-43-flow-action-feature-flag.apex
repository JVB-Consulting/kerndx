// =============================================================================
// Section 43: Flow-as-Trigger-Action — RequiredFeatureFlag Gating (flow-as-trigger-action work)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 41 prerequisites
//   - Run section-flow-flag-disabled fixture deploy BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js section-flow-flag-disabled
//   - Run section-flow-flag-default fixture deploy AFTER this script:
//       node release-testing/runner/cmdt-deployer.js section-flow-flag-default
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-43-flow-action-feature-flag.apex
//
// Section list (1 PASS expected):
//   43a — RequiredFeatureFlag__c gate disables flow action when flag is off; additional flow row still fires
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	// 43a: Per-action RequiredFeatureFlag__c gating. Primary CMDT row references
	// EnableSubscriberFlowAction; flag is now disabled. The dispatcher's
	// SEL_TriggerAction.shouldExecute filters out the primary row before invocation, so
	// TST_SubscriberFlow_SetDefaults does NOT run on insert. The additional CMDT row has
	// no flag binding and still runs.
	{
		System.assert(!kern.UTIL_FeatureFlag.isEnabled('EnableSubscriberFlowAction'),
				'43a FAIL: EnableSubscriberFlowAction must be disabled — fixture deploy missing?');

		Account account = new Account(Name = 'Section 43a Flag Disabled', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account result =
		[
				SELECT Description,
						AccountSource,
						NumberOfEmployees
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Default', result.Description, '43a FAIL: Description should reflect TRG_SetAccountDefaults default - feature-flag-gated primary flow should not override');
		System.assertEquals('Subscriber Trigger', result.AccountSource, '43a FAIL: AccountSource should reflect TRG_StampAccountSource default - feature-flag-gated primary flow should not override');
		System.assertEquals(42, result.NumberOfEmployees, '43a FAIL: Additional flow without flag binding should still run');

		System.debug('43a PASS: RequiredFeatureFlag__c off → primary flow gated; additional flow row unaffected');
		delete account;
	}

	System.debug('========================================');
	System.debug('Section 43: All tests completed (1/1)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
