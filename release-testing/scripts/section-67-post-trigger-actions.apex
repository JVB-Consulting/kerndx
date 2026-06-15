// =============================================================================
// Section 67: Post-Trigger Actions — Core Behaviour (post-trigger-action work)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Base post-action CMDT deployed (subscriber/customMetadata/kern__PostTriggerAction.*,
//     kern__FeatureFlag.EnablePostActionReleaseTest) + the six TST_PostAction* subscriber classes
//   - Run the postaction-enabled fixture deploy BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js postaction-enabled
//   - Run the postaction-disabled fixture deploy AFTER this script:
//       node release-testing/runner/cmdt-deployer.js postaction-disabled
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-67-post-trigger-actions.apex
//
// Section list (6 PASS expected):
//   67a — post-actions fire in Order ascending (Recorder before Second)
//   67b — fires once per dispatch (insert 3 in one DML → count 2 = before+after), not per record
//   67c — PostActionContext carries the touched SObject type (Account)
//   67d — firing count is dispatch-scoped (2), invariant to DML batch size
//   67e — object-scope filter skips Account-scoped post-actions on a non-Account dispatch (Foobar)
//   67f — entry-criteria evaluator skips the gated post-action while ungated actions still fire
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

try
{
	// 67a + 67b + 67c: one DML inserting three Accounts
	{
		TST_PostActionRecorder.reset();
		List<Account> accounts = new List<Account>();
		for(Integer i = 0; i < 3; i++)
		{
			accounts.add(new Account(Name = 'Section 67 ' + i, Industry = 'Technology', Phone = '5550100'));
		}
		insert accounts;

		System.assertEquals('Recorder', TST_PostActionRecorder.executionOrder[0], '67a FAIL: recorder should fire before second');
		System.assertEquals('Second', TST_PostActionRecorder.executionOrder[1], '67a FAIL: second should fire after recorder');
		System.debug('67a PASS: post-actions fire in Order ascending (Recorder before Second)');

		System.assertEquals(2, TST_PostActionRecorder.invocationCounts.get('Recorder'),
				'67b FAIL: recorder should fire once per dispatch (before+after insert = 2), not once per record');
		System.debug('67b PASS: inserting 3 records in one DML fires the post-action per dispatch (2), not per record (6)');

		System.assert(TST_PostActionRecorder.touchedTypeNames.contains('Account'), '67c FAIL: touched types should contain Account');
		System.debug('67c PASS: PostActionContext carries the touched SObject type (Account)');

		delete accounts;
	}

	// 67d: firing count is dispatch-scoped, invariant to batch size (one Account)
	{
		TST_PostActionRecorder.reset();
		Account single = new Account(Name = 'Section 67 single', Industry = 'Technology', Phone = '5550100');
		insert single;

		System.assertEquals(2, TST_PostActionRecorder.invocationCounts.get('Recorder'),
				'67d FAIL: firing count should be dispatch-scoped (2) regardless of batch size');
		System.debug('67d PASS: post-action firing count is dispatch-scoped (2), invariant to DML batch size');

		delete single;
	}

	// 67e: object-scope filter — a non-Account dispatch must not fire Account-scoped post-actions
	{
		TST_PostActionRecorder.reset();
		kern__Foobar__c foobar = new kern__Foobar__c(Name = 'Section 67 Foobar');
		insert foobar;

		System.assert(TST_PostActionRecorder.executionOrder.isEmpty(),
				'67e FAIL: Account-scoped post-actions must not fire when only Foobar was touched');
		System.debug('67e PASS: object-scope filter skips Account-scoped post-actions on a non-Account dispatch (Foobar)');

		delete foobar;
	}

	// 67f: entry-criteria evaluator skips the gated post-action; ungated actions still fire
	{
		TST_PostActionRecorder.reset();
		Account account = new Account(Name = 'Section 67 criteria', Industry = 'Technology', Phone = '5550100');
		insert account;

		System.assert(!TST_PostActionRecorder.executionOrder.contains('EntryGated'),
				'67f FAIL: an always-deny entry criteria should skip the gated post-action');
		System.assert(TST_PostActionRecorder.executionOrder.contains('Recorder'),
				'67f FAIL: ungated post-actions should still fire (proves the pipeline ran)');
		System.debug('67f PASS: entry-criteria evaluator skips the gated post-action while ungated actions still fire');

		delete account;
	}

	System.debug('========================================');
	System.debug('Section 67: All tests completed (6/6)');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
