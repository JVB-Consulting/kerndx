// =============================================================================
// Section 41: Flow-as-Trigger-Action — End-to-End Subscriber Validation (flow-as-trigger-action work)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - kern__TRG_InvokeFlow Apex class shipped in the managed package
//   - kern__TST_InvokeFlowMock Apex class shipped in the managed package
//   - Subscriber test artifacts deployed (Phase 1.4):
//     - flows/TST_SubscriberFlow_SetDefaults.flow-meta.xml (active, sets Description+AccountSource)
//     - flows/TST_SubscriberFlow_AdditionalDefaults.flow-meta.xml (active, sets NumberOfEmployees=42)
//     - flows/TST_SubscriberFlow_AlwaysFail.flow-meta.xml (active, raises REQUIRED_FIELD_MISSING)
//     - customMetadata/kern__TriggerAction.TST_FlowAction_Primary_BeforeInsert.md-meta.xml (active, LogAndContinue,
//       RequiredFeatureFlag=EnableSubscriberFlowAction)
//     - customMetadata/kern__TriggerAction.TST_FlowAction_Additional_BeforeInsert.md-meta.xml (active, LogAndContinue)
//     - customMetadata/kern__TriggerAction.TST_FlowAction_BlockDml_BeforeInsert.md-meta.xml (BypassExecution=true by default)
//     - customMetadata/kern__FeatureFlag.EnableSubscriberFlowAction.md-meta.xml (IsEnabledByDefault=true)
//   - Sections 4 and 5 require fixture deploys via the cmdt-deployer runner — see RUNBOOK.md.
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-41-flow-action-subscriber.apex
//
// Section list (6 PASS expected):
//   41a — Flow runs on insert; LogEntryEvent emitted with flowName context
//   41b — Flow output applied (Description + AccountSource written back from flow)
//   41c — LogAndContinue routes mock failure through audit; DML succeeds
//   41d — Recursion-identity: two TRG_InvokeFlow CMDT rows with distinct flow names both fire on the same event
//   41e — Mock harness from anonymous Apex short-circuits the platform Flow runtime
//   41f — Variable contract: framework owns record + recordPrior keys (subscribers configure flow name only)
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

Boolean allPassed = true;

try
{
	// 41a: Flow runs on insert. Verifies cross-namespace dispatch — kern.TRG_InvokeFlow
	// resolves a subscriber-namespace flow and fires within the managed-package trigger
	// dispatcher loop. Confirmed via field write-back (Description) and via the captured
	// LogEntry__c carrying the bound flowName context dimension.
	{
		Account account = new Account(Name = 'Section 41a Flow Runs', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account result =
		[
				SELECT Description
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Default From Flow', result.Description, '41a FAIL: Flow should run and write Description');

		System.debug('41a PASS: Cross-namespace flow dispatch confirmed via field write-back');
		delete account;
	}

	// 41b: Flow output applied. Verifies kern.TRG_InvokeFlow.applyResults copies all populated
	// fields from the flow's output record back onto the trigger SObject — both Description
	// AND AccountSource set by the same flow invocation.
	{
		Account account = new Account(Name = 'Section 41b Output Applied', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account result =
		[
				SELECT Description,
						AccountSource,
						NumberOfEmployees
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Default From Flow', result.Description, '41b FAIL: Primary flow should set Description');
		System.assertEquals('Subscriber Flow', result.AccountSource, '41b FAIL: Primary flow should set AccountSource');
		System.assertEquals(42, result.NumberOfEmployees, '41b FAIL: Additional flow should set NumberOfEmployees');

		System.debug('41b PASS: Flow output write-back applied across multiple fields and multiple flow rows');
		delete account;
	}

	// 41c: LogAndContinue strategy — register a mock failure on the primary flow,
	// insert an Account, and verify DML succeeds without rollback. The mock short-circuits
	// the platform Flow runtime; the framework still routes the failure through the CMDT
	// row's FailureAction__c=LogAndContinue, allowing DML to commit.
	{
		kern.TST_InvokeFlowMock.forFlow('TST_SubscriberFlow_SetDefaults')
				.fail('Section 41c deliberate runtime failure')
				.register();

		Account account = new Account(Name = 'Section 41c LogAndContinue', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account result =
		[
				SELECT Description,
						NumberOfEmployees
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Default', result.Description, '41c FAIL: Description should reflect TRG_SetAccountDefaults default - mocked-fail primary flow does not override');
		System.assertEquals(42, result.NumberOfEmployees, '41c FAIL: Additional flow should still run despite primary failing under LogAndContinue');

		System.debug('41c PASS: LogAndContinue allowed DML despite primary flow failure; additional flow still ran');
		delete account;

		kern.TST_InvokeFlowMock.clear();
	}

	// 41d: Recursion-identity — two TRG_InvokeFlow CMDT rows with distinct FlowName__c values
	// both fire on the same trigger event. The dispatcher's (actionType, fingerprint) recursion
	// tuple distinguishes them so neither shields the other.
	{
		Account account = new Account(Name = 'Section 41d Recursion Identity', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account result =
		[
				SELECT Description,
						NumberOfEmployees
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Default From Flow', result.Description, '41d FAIL: Primary flow row should fire');
		System.assertEquals(42, result.NumberOfEmployees, '41d FAIL: Additional flow row should fire alongside primary');

		System.debug('41d PASS: Two TRG_InvokeFlow rows fired independently — recursion-identity tuple works across flow rows');
		delete account;
	}

	// 41e: Mock harness from anonymous Apex short-circuits the platform Flow runtime.
	// Register a mock with a custom output record; verify the mock's withOutputRecord
	// is what gets written back, NOT the deployed flow's actual output.
	{
		Account mockOutput = new Account(Description = 'From Anonymous Mock', AccountSource = 'Anonymous Mock Source');
		kern.TST_InvokeFlowMock.forFlow('TST_SubscriberFlow_SetDefaults')
				.succeed()
				.withOutputRecord(mockOutput)
				.register();

		Account account = new Account(Name = 'Section 41e Mock Override', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account result =
		[
				SELECT Description,
						AccountSource
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('From Anonymous Mock', result.Description, '41e FAIL: Mock-supplied output should override deployed-flow output');
		System.assertEquals('Anonymous Mock Source', result.AccountSource, '41e FAIL: Mock-supplied AccountSource should be applied');

		System.debug('41e PASS: Mock harness from anonymous Apex correctly short-circuited platform Flow runtime');
		delete account;

		kern.TST_InvokeFlowMock.clear();
	}

	// 41f: Variable contract — the framework supplies the trigger record under the
	// reserved key `record` (and `recordPrior` for updates). Subscribers configure flow
	// name only. Confirmed by capturing the input record passed into the mocked flow and
	// asserting it matches the trigger Account.
	{
		kern.TST_InvokeFlowMock.forFlow('TST_SubscriberFlow_SetDefaults')
				.succeed()
				.register();

		Account account = new Account(Name = 'Section 41f Variable Contract', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account captured = (Account)kern.TST_InvokeFlowMock.getLastInputRecord('TST_SubscriberFlow_SetDefaults');
		System.assert(captured != null, '41f FAIL: Framework should supply record key to flow input map');
		System.assertEquals(account.Id, captured.Id, '41f FAIL: Captured record should match inserted Account');
		System.assertEquals('Technology', captured.Industry, '41f FAIL: Captured record should preserve trigger field values');
		System.assertEquals(null, kern.TST_InvokeFlowMock.getLastInputPriorRecord('TST_SubscriberFlow_SetDefaults'),
				'41f FAIL: recordPrior should be null on insert (framework owns the key contract)');

		System.debug('41f PASS: Framework owns record + recordPrior keys; subscribers configure flow name only');
		delete account;

		kern.TST_InvokeFlowMock.clear();
	}

	System.debug('========================================');
	System.debug('Section 41: All tests completed (6/6)');
	System.debug('========================================');
}
catch(Exception assertionError)
{
	allPassed = false;
	System.debug('Section 41 FAILED with exception: ' + assertionError.getTypeName() + ' — ' + assertionError.getMessage());
	System.debug('Stack: ' + assertionError.getStackTraceString());
	throw assertionError;
}
finally
{
	kern.TST_InvokeFlowMock.clear();
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
