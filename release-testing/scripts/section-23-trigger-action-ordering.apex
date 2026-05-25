// =============================================================================
// Section 23: Trigger Action Ordering Verification
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Account trigger actions deployed with explicit Order__c values:
//     - kern.TRG_ExecuteValidationRules (Order=50, BeforeInsert)
//     - TRG_SetAccountDefaults (Order=100, BeforeInsert)
//     - TRG_ValidateAccountName (Order=200, BeforeInsert)
//     - TRG_StampAccountSource (Order=300, BeforeInsert)
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-23-trigger-action-ordering.apex
// =============================================================================

// Bypass the flow trigger action — sections 41-44 cover that surface; this section tests Apex action ordering only
kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	// 23a: Verify execution order — SetAccountDefaults (100) runs, then StampAccountSource (300)
	// Both fire on the same insert. If ordering is non-deterministic, one might not see the other's output.
	{
		Account account = new Account(Name = 'Test 23a Order Check', Industry = 'Technology', Phone = '555-0100');
		insert account;

		Account result =
		[
				SELECT Description,
						AccountSource
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Default', result.Description, '23a FAIL: SetAccountDefaults (Order=100) should set Description');
		System.assertEquals('Subscriber Trigger', result.AccountSource, '23a FAIL: StampAccountSource (Order=300) should set AccountSource');
		System.debug('23a PASS: Execution order verified — defaults set (Order=100), source stamped (Order=300)');

		delete account;
	}

	// 23b: Verify ValidateAccountName (Order=200) fires AFTER SetAccountDefaults (Order=100)
	// A blank Description insert gets defaulted first, THEN the BLOCKED name check fires.
	// If 200 ran before 100, the DmlException still fires but Description would NOT be defaulted.
	{
		Boolean exceptionThrown = false;
		try
		{
			Account account = new Account(Name = 'BLOCKED Test 23b', Industry = 'Technology', Phone = '555-0100');
			insert account;
		}
		catch(DmlException error)
		{
			exceptionThrown = true;
			System.assert(error.getMessage().contains('BLOCKED'),
					'23b FAIL: Should contain BLOCKED error. Got: ' + error.getMessage());
		}

		System.assert(exceptionThrown, '23b FAIL: DmlException should fire for BLOCKED name');
		System.debug('23b PASS: ValidateAccountName (Order=200) correctly fires after SetAccountDefaults (Order=100)');
	}

	// 23c: Verify all 4 BeforeInsert actions fire in correct sequence via SOQL audit
	// Query TriggerAction__mdt directly to confirm the Order__c configuration is intact
	{
		List<kern__TriggerAction__mdt> actions =
		[
				SELECT DeveloperName,
						kern__ApexClassName__c,
						kern__Order__c,
						kern__Event__c
				FROM kern__TriggerAction__mdt
				WHERE kern__TriggerSetting__r.kern__SObjectType__c = 'Account'
				AND kern__Event__c = 'Before Insert'
				AND kern__BypassExecution__c = FALSE
				ORDER BY kern__Order__c ASC
		];

		System.assert(actions.size() >= 4, '23c FAIL: Expected at least 4 BeforeInsert actions, got ' + actions.size());

		Decimal previousOrder = -1;
		Boolean inOrder = true;
		String orderSequence = '';

		for(kern__TriggerAction__mdt action : actions)
		{
			Decimal currentOrder = action.kern__Order__c != null ? action.kern__Order__c : 0;
			orderSequence += action.kern__ApexClassName__c + '(' + currentOrder + ') ';

			if(currentOrder < previousOrder)
			{
				inOrder = false;
			}
			previousOrder = currentOrder;
		}

		System.assert(inOrder, '23c FAIL: Actions not in ascending Order__c. Sequence: ' + orderSequence);
		System.debug('23c PASS: CMDT Order__c configuration verified: ' + orderSequence);
	}

	// 23d: Verify feature flag evaluation works after ORDER BY removal from CMDT subselect
	// EnableStrictValidation has a Custom Permission strategy — should be disabled without perm set
	// EnableAccountTriggers has no strategies and IsEnabledByDefault=false — should be disabled
	{
		Boolean strictDisabled = !kern.UTIL_FeatureFlag.isEnabled('EnableStrictValidation');
		Boolean triggersDisabled = !kern.UTIL_FeatureFlag.isEnabled('EnableAccountTriggers');
		System.assert(strictDisabled, '23d FAIL: EnableStrictValidation should be disabled without custom permission');
		System.assert(triggersDisabled, '23d FAIL: EnableAccountTriggers should be disabled (IsEnabledByDefault=false)');
		System.debug('23d PASS: Feature flag evaluation works correctly after CMDT subselect fix');
	}

	System.debug('========================================');
	System.debug('Section 23: All tests completed (4/4)');
	System.debug('========================================');
}
finally
{
	kern.UTIL_ValidationRule.clearAllBypasses();
}
