// Section 34: Async Chain Orchestration
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - SubscriberChainSteps deployed
//   - FeatureFlag.AsyncChain exists and is active
//
// NOTE: Chains execute asynchronously via Queueable. This script launches
// chains and immediately queries their initial state. The chains will
// complete after this script finishes. Run section-34b to verify results.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-34-async-chain.apex 2>&1 | grep USER_DEBUG
//   (wait 10 seconds for chains to complete)
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-34b-async-chain-verify.apex 2>&1 | grep USER_DEBUG

try
{
	// Test 34a: Single-step chain — launches and records execution ID
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34a_SingleStep')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();

		System.assert(String.isNotBlank(executionId), '34a FAIL: executionId should not be blank');
		kern__AsyncChainExecution__c execution =
		[
				SELECT kern__Status__c,
						kern__TotalSteps__c
				FROM kern__AsyncChainExecution__c
				WHERE Id = :executionId
		];
		System.assert(execution.kern__TotalSteps__c == 1, '34a FAIL: TotalSteps should be 1');
		System.debug('34a PASS: Single-step chain launched — ' + executionId + ' (status: ' + execution.kern__Status__c + ')');
	}

	// Test 34b: Multi-step chain with context flow
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34b_MultiStep')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.then(new SubscriberChainSteps.UpdateFoobarStep())
				.execute();

		kern__AsyncChainExecution__c execution =
		[
				SELECT kern__Status__c,
						kern__TotalSteps__c
				FROM kern__AsyncChainExecution__c
				WHERE Id = :executionId
		];
		System.assert(execution.kern__TotalSteps__c == 2, '34b FAIL: TotalSteps should be 2');
		System.debug('34b PASS: Multi-step chain launched — ' + executionId + ' (status: ' + execution.kern__Status__c + ')');
	}

	// Test 34c: Chain with failing step
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34c_Failing')
				.then(new SubscriberChainSteps.FailingStep())
				.execute();

		System.assert(String.isNotBlank(executionId), '34c FAIL: executionId should not be blank');
		System.debug('34c PASS: Failing chain launched — ' + executionId);
	}

	// Test 34d: Chain with onError handler
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34d_ErrorHandler')
				.then(new SubscriberChainSteps.FailingStep())
				.onError(new SubscriberChainSteps.ErrorHandlerStep())
				.execute();

		System.debug('34d PASS: Chain with error handler launched — ' + executionId);
	}

	// Test 34e: Chain with onComplete handler
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34e_CompletionHandler')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.onComplete(new SubscriberChainSteps.CompletionHandlerStep())
				.execute();

		System.debug('34e PASS: Chain with completion handler launched — ' + executionId);
	}

	// Test 34f: getStatus() returns valid map
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34f_Status')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();

		Map<String, Object> status = kern.UTIL_AsyncChain.getStatus(executionId);
		System.assert(status != null, '34f FAIL: Status map should not be null');
		System.assert(status.get('executionId') == executionId, '34f FAIL: executionId should match');
		System.assert(status.get('chainName') == 'Test34f_Status', '34f FAIL: chainName should match');
		System.assert(status.containsKey('status'), '34f FAIL: Should contain status key');
		System.assert(status.containsKey('totalSteps'), '34f FAIL: Should contain totalSteps key');
		System.debug('34f PASS: getStatus() returned valid map — status: ' + status.get('status'));
	}

	// Test 34g: Chain with continueOnError
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34g_ContinueOnError')
				.then(new SubscriberChainSteps.OptionalFailingStep(), true)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();

		kern__AsyncChainExecution__c execution =
		[
				SELECT kern__TotalSteps__c
				FROM kern__AsyncChainExecution__c
				WHERE Id = :executionId
		];
		System.assert(execution.kern__TotalSteps__c == 2, '34g FAIL: TotalSteps should be 2');
		System.debug('34g PASS: ContinueOnError chain launched — ' + executionId);
	}

	// Test 34h: Handler callout isolation — DML step + callout in onComplete handler
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34h_HandlerCallout')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.onComplete(new SubscriberChainSteps.CallApiStep())
				.execute();

		System.assert(String.isNotBlank(executionId), '34h FAIL: executionId should not be blank');
		System.debug('34h PASS: DML step + callout handler chain launched — ' + executionId);
	}

	// Test 34i: ApiStep bridge — wraps API_Outbound handler as chain step
	{
		kern__Foobar__c record = new kern__Foobar__c(Name = 'ApiStep Bridge Test');
		kern.DML_Builder.newTransaction().doInsert(record).execute();

		String executionId = kern.UTIL_AsyncChain.newChain('Test34i_ApiStep')
				.then(new kern.UTIL_AsyncChain.ApiStep(kern.UTIL_System.getTypeForClassName('API_PostExample'))
						.triggeringRecord(record.Id)
						.withParameter('foo', 'bridgeValue'))
				.execute();

		System.assert(String.isNotBlank(executionId), '34i FAIL: executionId should not be blank');
		kern__AsyncChainExecution__c execution =
		[
				SELECT kern__TotalSteps__c
				FROM kern__AsyncChainExecution__c
				WHERE Id = :executionId
		];
		System.assert(execution.kern__TotalSteps__c == 1, '34i FAIL: TotalSteps should be 1');
		System.debug('34i PASS: ApiStep bridge chain launched — ' + executionId);
	}

	// Test 34j: Chain with initial context
	{
		String executionId = kern.UTIL_AsyncChain.newChain('Test34j_InitialContext')
				.withInitialContext('testKey', 'testValue')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();

		kern__AsyncChainExecution__c execution =
		[
				SELECT kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE Id = :executionId
		];
		System.assert(execution.kern__ContextData__c.contains('testKey'), '34j FAIL: Initial context should be persisted');
		System.debug('34j PASS: Chain with initial context launched — ' + executionId);
	}

	// Test 34k: Bulk boundary — launch 5 minimal single-step chains and assert all get execution records
	// Scaled to 5 (not 200) because each execute() enqueues one Queueable job; platform governor is 50 per
	// transaction and this script already enqueues 9 chains above (34a-34j), leaving ~40 slots.
	// 5 chains verifies the loop-launch pattern without breaching the Queueable governor.
	{
		List<String> bulkExecutionIds = new List<String>();
		for(Integer i = 0; i < 5; i++)
		{
			String executionId = kern.UTIL_AsyncChain.newChain('Test34k_Bulk_' + i)
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.execute();
			System.assert(String.isNotBlank(executionId), '34k FAIL: executionId should not be blank for chain ' + i);
			bulkExecutionIds.add(executionId);
		}

		System.assertEquals(5, bulkExecutionIds.size(), '34k FAIL: Should have launched 5 chains');

		List<kern__AsyncChainExecution__c> executions =
		[
				SELECT kern__Status__c,
						kern__TotalSteps__c
				FROM kern__AsyncChainExecution__c
				WHERE Id IN :bulkExecutionIds
		];
		System.assertEquals(5, executions.size(), '34k FAIL: All 5 chains should have AsyncChainExecution records, found: ' + executions.size());
		Integer singleStepCount = 0;
		for(kern__AsyncChainExecution__c execution : executions)
		{
			if(execution.kern__TotalSteps__c == 1) singleStepCount++;
		}
		System.assertEquals(5, singleStepCount, '34k FAIL: All 5 chains should have TotalSteps=1, only ' + singleStepCount + ' did');
		System.debug('34k PASS: Bulk-5 chain launch (scaled from 200 — Queueable governor 50/tx) — all 5 chains have execution records with TotalSteps=1');
	}
}
catch(Exception error)
{
	System.debug('UNEXPECTED ERROR: ' + error.getMessage() + ' | ' + error.getStackTraceString());
}
