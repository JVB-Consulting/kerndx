// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Proof tests for the pause-for-approval composition pattern: two independent
 * chain runs joined by the waiting record, with the continuation started through the
 * flow-facing invocable and its single-request guard enforced. Each run keeps its own
 * correlation identifier (a chain run owns its correlation exclusively).
 *
 * @see Recipe_ApprovalHandOff_DEMO
 * @see Recipe_ApprovalContinuation_DEMO
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false)
private class Recipe_ApprovalHandOff_DEMO_TEST
{
	/**
	 * @description Continuation chain name, queried to find the second leg's run row.
	 */
	private static final String CONTINUATION_CHAIN_NAME = 'Order Approval - Continuation';

	/**
	 * @description Verifies both legs complete as independent runs joined by the record: each
	 * carries the record through its context, and each keeps its own distinct correlation
	 * identifier (the run row owns its correlation exclusively, so the legs can never share one).
	 */
	@IsTest
	private static void shouldRunBothLegsAsIndependentRunsJoinedByRecord()
	{
		Id waitingRecordId = fakeRecordId();

		Test.startTest();
		String firstLegId = Recipe_ApprovalHandOff_DEMO.startFirstLeg(waitingRecordId);

		Recipe_ApprovalContinuation_DEMO.Request request = new Recipe_ApprovalContinuation_DEMO.Request();
		request.recordId = waitingRecordId;
		Recipe_ApprovalContinuation_DEMO.start(new List<Recipe_ApprovalContinuation_DEMO.Request>{ request });
		Test.stopTest();

		kern__AsyncChainExecution__c firstLeg = queryExecutionById(firstLegId);
		Assert.areEqual('Completed', firstLeg.kern__Status__c, 'The preparation leg should complete');

		kern__AsyncChainExecution__c secondLeg = queryExecutionByChainName(CONTINUATION_CHAIN_NAME);
		Assert.areEqual('Completed', secondLeg.kern__Status__c, 'The continuation leg should complete');

		Assert.isTrue(String.isNotBlank(firstLeg.kern__CorrelationId__c)
				&& String.isNotBlank(secondLeg.kern__CorrelationId__c),
				'Each leg should carry its own correlation identifier');
		Assert.areNotEqual(firstLeg.kern__CorrelationId__c, secondLeg.kern__CorrelationId__c,
				'The legs are independent runs; a chain run owns its correlation exclusively');

		Assert.areEqual(String.valueOf(waitingRecordId), String.valueOf(parseContext(firstLeg).get('recordId')),
				'The first leg should carry the waiting record through its context');
		Assert.areEqual(String.valueOf(waitingRecordId), String.valueOf(parseContext(secondLeg).get('recordId')),
				'The continuation should carry the same record: the record is the join between the legs');
	}

	/**
	 * @description Verifies the invocable's single-request guard: a bulk invocation is refused
	 * before any chain starts.
	 */
	@IsTest
	private static void shouldRefuseBulkInvocation()
	{
		List<Recipe_ApprovalContinuation_DEMO.Request> requests =
				new List<Recipe_ApprovalContinuation_DEMO.Request>();
		for(Integer index = 0; index < 2; index++)
		{
			Recipe_ApprovalContinuation_DEMO.Request request = new Recipe_ApprovalContinuation_DEMO.Request();
			request.recordId = fakeRecordId();
			requests.add(request);
		}

		try
		{
			Recipe_ApprovalContinuation_DEMO.start(requests);
			Assert.fail('A two-request invocation should be refused');
		}
		catch(IllegalArgumentException expected)
		{
			Assert.isTrue(expected.getMessage().contains('one request per invocation'),
					'The guard should explain the single-request contract; got: ' + expected.getMessage());
		}

		List<kern__AsyncChainExecution__c> runs =
		[
				SELECT Id
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = :CONTINUATION_CHAIN_NAME
		];
		Assert.areEqual(0, runs.size(), 'A refused invocation should start no chain');
	}

	/**
	 * @description Builds a syntactically valid but non-existent record Id to stand in for the
	 * waiting record. Raw describe is an acceptable independent oracle in a _TEST class.
	 *
	 * @return A Foobar-prefixed Id that resolves to no record.
	 */
	private static Id fakeRecordId()
	{
		String keyPrefix = kern__Foobar__c.SObjectType.getDescribe().getKeyPrefix();
		return Id.valueOf(keyPrefix + '000000000001');
	}

	/**
	 * @description Queries an AsyncChainExecution__c record by Id.
	 *
	 * @param executionId The execution record Id.
	 *
	 * @return The queried execution record.
	 */
	private static kern__AsyncChainExecution__c queryExecutionById(String executionId)
	{
		return
		[
				SELECT kern__Status__c,
						kern__CorrelationId__c,
						kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE Id = :executionId
		];
	}

	/**
	 * @description Queries the single AsyncChainExecution__c record for a chain name.
	 *
	 * @param chainName The chain name to look up.
	 *
	 * @return The queried execution record.
	 */
	private static kern__AsyncChainExecution__c queryExecutionByChainName(String chainName)
	{
		return
		[
				SELECT kern__Status__c,
						kern__CorrelationId__c,
						kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = :chainName
		];
	}

	/**
	 * @description Parses context data JSON from an execution record.
	 *
	 * @param execution The execution record.
	 *
	 * @return Deserialized context data map.
	 */
	private static Map<String, Object> parseContext(kern__AsyncChainExecution__c execution)
	{
		return String.isNotBlank(execution.kern__ContextData__c)
				? (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c)
				: new Map<String, Object>();
	}
}
