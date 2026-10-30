// SPDX-License-Identifier: Apache-2.0
/**
 * @description Proof tests for the transactional-outbox composition pattern. Stage B artifact:
 * the action class uses retryOn (1.7 surface), so this suite runs at the beta install, not on
 * the 1.6 line. Witnesses: one chain per transaction with one step per closed case, delivery
 * through the mocked service, no start on a non-transition, the idempotency regression, and
 * the no-ghost-call rollback guarantee.
 *
 * @see Recipe_CommittedDelivery_DEMO
 * @see Recipe_CaseDelivery_SERVICE
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false)
private class Recipe_CommittedDelivery_DEMO_TEST
{
	/**
	 * @description How many cases the bulk witness closes in one DML.
	 */
	private static final Integer CLOSED_CASE_COUNT = 3;

	/**
	 * @description Verifies the bulk posture: closing N cases in one DML starts exactly ONE
	 * chain with N steps, the chain completes through the mocked service, and every step's
	 * call carries the record-grain idempotency key (the D5 regression witness).
	 */
	@IsTest
	private static void shouldStartOneChainWithOneStepPerClosedCase()
	{
		List<Case> cases = insertOpenCases(CLOSED_CASE_COUNT);

		Test.startTest();
		for(Case openCase : cases)
		{
			openCase.Status = Recipe_CommittedDelivery_DEMO.STATUS_CLOSED;
		}
		kern.DML_Builder.newTransaction().doUpdate(cases).execute();
		Test.stopTest();

		List<kern__AsyncChainExecution__c> runs = queryRuns();
		Assert.areEqual(1, runs.size(), 'One transaction should start exactly one delivery chain');
		Assert.areEqual('Completed', runs[0].kern__Status__c, 'The delivery chain should complete');
		Assert.areEqual(CLOSED_CASE_COUNT, runs[0].kern__TotalSteps__c,
				'The chain should carry one step per closed case');

		List<kern__ApiCall__c> calls =
		[
				SELECT kern__IdempotencyKey__c,
						kern__TriggeringRecordId__c
				FROM kern__ApiCall__c
				WHERE kern__TriggeringRecordId__c IN :new Map<Id, Case>(cases).keySet()
		];
		Assert.areEqual(CLOSED_CASE_COUNT, calls.size(), 'Each closed case should get one delivery call');
		for(kern__ApiCall__c call : calls)
		{
			Assert.areEqual(Recipe_CaseDelivery_SERVICE.IDEMPOTENCY_KEY_PREFIX + call.kern__TriggeringRecordId__c,
					call.kern__IdempotencyKey__c, 'Each delivery should carry its record-grain idempotency key');
		}
	}

	/**
	 * @description Verifies a non-transition update (already-closed case saved again) starts
	 * nothing.
	 */
	@IsTest
	private static void shouldStartNothingWithoutTransition()
	{
		List<Case> cases = insertOpenCases(1);
		cases[0].Status = Recipe_CommittedDelivery_DEMO.STATUS_CLOSED;
		kern.DML_Builder.newTransaction().doUpdate(cases).execute();

		List<kern__AsyncChainExecution__c> runsAfterClose = queryRuns();

		Test.startTest();
		cases[0].Subject = 'Touched without a status transition';
		kern.DML_Builder.newTransaction().doUpdate(cases).execute();
		Test.stopTest();

		Assert.areEqual(runsAfterClose.size(), queryRuns().size(),
				'An update without the closed transition should start no new chain');
	}

	/**
	 * @description Verifies the no-ghost-call guarantee: when the closing save rolls back, the
	 * enqueue rolls back with it and no chain run exists.
	 */
	@IsTest
	private static void shouldEnqueueNothingWhenSaveRollsBack()
	{
		List<Case> cases = insertOpenCases(1);

		Test.startTest();
		Savepoint beforeClose = Database.setSavepoint();
		cases[0].Status = Recipe_CommittedDelivery_DEMO.STATUS_CLOSED;
		kern.DML_Builder.newTransaction().doUpdate(cases).execute();
		Database.rollback(beforeClose);
		Test.stopTest();

		Assert.areEqual(0, queryRuns().size(),
				'A rolled-back save should leave no delivery chain: the ghost call never happens');
	}

	/**
	 * @description Inserts open cases for the witnesses.
	 *
	 * @param caseCount How many cases to insert.
	 *
	 * @return The inserted cases.
	 */
	private static List<Case> insertOpenCases(Integer caseCount)
	{
		List<Case> cases = new List<Case>();
		for(Integer index = 0; index < caseCount; index++)
		{
			cases.add(new Case(Subject = 'Outbox witness ' + index));
		}
		kern.DML_Builder.newTransaction().doInsert(cases).execute();
		return cases;
	}

	/**
	 * @description Queries the delivery chain runs.
	 *
	 * @return The run rows for the pattern's chain name.
	 */
	private static List<kern__AsyncChainExecution__c> queryRuns()
	{
		return
		[
				SELECT kern__Status__c,
						kern__TotalSteps__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = :Recipe_CommittedDelivery_DEMO.CHAIN_NAME
		];
	}
}
