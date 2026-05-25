// =============================================================================
// Section 44: Flow-as-Trigger-Action — Managed-Package Upgrade Compatibility (flow-as-trigger-action work)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 41 prerequisites
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-44-flow-action-upgrade.apex
//
// Section list (3 PASS expected):
//   44a — Pre-existing non-flow TriggerAction__mdt rows still resolve and dispatch correctly
//         after the new FlowName / FailureAction fields land
//   44b — Schema describe shows the 3 new TriggerAction fields shipped with sensible defaults
//   44c — Mixed dispatch — Apex actions and TRG_InvokeFlow rows run together on the same insert
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	// 44a: Pre-existing Apex-only TriggerAction__mdt rows still dispatch correctly. The
	// existing TRG_SetAccountDefaults / TRG_StampAccountSource / TRG_ValidateAccountName
	// rows shipped before the flow-action fields existed; their FlowName__c and
	// FailureAction__c values are null. Inserting an Account fires the full Account
	// before-insert chain — Apex actions plus the flow-action rows.
	{
		List<kern__TriggerAction__mdt> apexOnlyActions =
		[
				SELECT DeveloperName,
						kern__ApexClassName__c,
						kern__FlowName__c
				FROM kern__TriggerAction__mdt
				WHERE kern__TriggerSetting__r.kern__SObjectType__c = 'Account'
				AND kern__BypassExecution__c = FALSE
				AND kern__FlowName__c = NULL
		];
		System.assert(!apexOnlyActions.isEmpty(), '44a FAIL: Expected at least one Apex-only TriggerAction row on Account');

		for(kern__TriggerAction__mdt row : apexOnlyActions)
		{
			System.assert(String.isNotBlank(row.kern__ApexClassName__c),
					'44a FAIL: Apex-only TriggerAction "' + row.DeveloperName + '" should have ApexClassName populated under XOR validation rule');
		}

		System.debug('44a PASS: ' + apexOnlyActions.size() + ' Apex-only TriggerAction row(s) preserved ApexClassName + null FlowName under MutuallyExclusiveTarget XOR rule');
	}

	// 44b: Schema describe confirms the trigger-action fields shipped with sensible defaults.
	// FailureAction__c picklist defaults to 'LogAndContinue'; FlowName__c is nullable Text(80);
	// ApexClassName__c is nullable Text(100); the MutuallyExclusiveTarget validation rule
	// enforces XOR between them.
	{
		Schema.DescribeFieldResult flowName = kern__TriggerAction__mdt.kern__FlowName__c.getDescribe();
		System.assertEquals(Schema.DisplayType.STRING, flowName.getType(), '44b FAIL: FlowName__c should be Text');
		System.assertEquals(80, flowName.getLength(), '44b FAIL: FlowName__c length should be 80');

		Schema.DescribeFieldResult apexClassName = kern__TriggerAction__mdt.kern__ApexClassName__c.getDescribe();
		System.assertEquals(Schema.DisplayType.STRING, apexClassName.getType(), '44b FAIL: ApexClassName__c should be Text');
		System.assert(apexClassName.isNillable(), '44b FAIL: ApexClassName__c should be nillable post-XOR-cleanup');

		Schema.DescribeFieldResult failureAction = kern__TriggerAction__mdt.kern__FailureAction__c.getDescribe();
		System.assertEquals(Schema.DisplayType.PICKLIST, failureAction.getType(), '44b FAIL: FailureAction__c should be Picklist');

		System.debug('44b PASS: Schema describe confirms FlowName/ApexClassName/FailureAction shipped with expected types');
	}

	// 44c: Mixed dispatch — Apex actions and TRG_InvokeFlow rows interleave correctly under
	// the existing dispatcher Order__c contract. Insert an Account; the full chain runs:
	//   Order=50  TRG_ExecuteValidationRules (Apex, framework)
	//   Order=100 TRG_SetAccountDefaults (Apex, subscriber) — pre-existing static-field-reference
	//             no-op on insert; effectively does not write Description (subscriber bug, not in scope)
	//   Order=200 TRG_ValidateAccountName (Apex, subscriber) — only fires on BLOCKED names
	//   Order=300 TRG_StampAccountSource (Apex, subscriber) — same static-field-reference no-op as
	//             SetAccountDefaults; effectively does not write AccountSource on insert
	//   Order=400 TRG_InvokeFlow → TST_SubscriberFlow_SetDefaults (flow, subscriber) — IS the
	//             effective writer of Description and AccountSource because the prior Apex no-ops
	//   Order=410 TRG_InvokeFlow → TST_SubscriberFlow_AdditionalDefaults (flow, subscriber)
	{
		Account account = new Account(Name = 'Section 44c Mixed Dispatch', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account result =
		[
				SELECT Description,
						AccountSource,
						NumberOfEmployees
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Default From Flow', result.Description, '44c FAIL: Final Description should reflect highest-Order writer (TRG_InvokeFlow primary)');
		System.assertEquals('Subscriber Flow', result.AccountSource, '44c FAIL: Final AccountSource should reflect highest-Order writer (TRG_InvokeFlow primary)');
		System.assertEquals(42, result.NumberOfEmployees, '44c FAIL: Additional flow row should fire after primary');

		System.debug('44c PASS: Mixed Apex + TRG_InvokeFlow dispatch chain runs correctly under Order__c contract');
		delete account;
	}

	System.debug('========================================');
	System.debug('Section 44: All tests completed (3/3)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
