// =============================================================================
// Section 42: Flow-as-Trigger-Action — BlockDml Strategy (flow-as-trigger-action work)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 41 prerequisites
//   - Run section-flow-blockdml-active fixture deploy BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js section-flow-blockdml-active
//   - Run section-flow-blockdml-default fixture deploy AFTER this script:
//       node release-testing/runner/cmdt-deployer.js section-flow-blockdml-default
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-42-flow-action-blockdml.apex
//
// Section list (1 PASS expected):
//   42a — BlockDml strategy halts DML and surfaces the flow runtime error to the caller
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	// 42a: BlockDml — TST_FlowAction_BlockDmlGuard CMDT row is now active (BypassExecution=false).
	// It binds TST_SubscriberFlow_AlwaysFail (the deliberate-fault flow that creates a Contact
	// without LastName) under FailureAction__c=BlockDml. On insert, the flow runtime raises
	// REQUIRED_FIELD_MISSING; the framework's `catch(Exception runtimeError)` catches it, routes
	// through BlockDml, calls `record.addError(...)`, and the platform rolls back the DML.
	{
		Boolean dmlBlocked = false;
		String capturedMessage = '';

		try
		{
			Account account = new Account(Name = 'Section 42a BlockDml', Industry = 'Technology', Phone = '555-0100');
			insert account;
		}
		catch(DmlException blocked)
		{
			dmlBlocked = true;
			capturedMessage = blocked.getMessage();
		}

		System.assert(dmlBlocked, '42a FAIL: BlockDml strategy should reject DML when bound flow throws at runtime');
		System.assert(capturedMessage.contains('TST_SubscriberFlow_AlwaysFail') || capturedMessage.contains('FIELD_REQUIRED') || capturedMessage.contains('LastName') || capturedMessage.contains('required'),
				'42a FAIL: Surfaced error should reference the flow name or the underlying REQUIRED_FIELD_MISSING. Got: ' + capturedMessage);

		System.debug('42a PASS: BlockDml halted DML and surfaced flow error: ' + capturedMessage.left(160));
	}

	System.debug('========================================');
	System.debug('Section 42: All tests completed (1/1)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
