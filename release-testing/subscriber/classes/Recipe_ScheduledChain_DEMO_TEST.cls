// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Proof tests for the recurring-chain composition pattern: the ScheduledJob__c
 * record schedules the class through the packaged trigger, the schedulable's typed parameter
 * flows into the chain context, and the deduplication key hands back the active run instead
 * of doubling up on overlap.
 *
 * @see Recipe_ScheduledChain_DEMO
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class Recipe_ScheduledChain_DEMO_TEST
{
	/**
	 * @description Chain name the pattern uses; queried to count run rows.
	 */
	private static final String CHAIN_NAME = 'Nightly Order Export';

	/**
	 * @description Verifies the declarative leg: inserting an active ScheduledJob__c row makes
	 * the packaged trigger schedule the class (ScheduledJobId__c populated).
	 */
	@IsTest
	private static void shouldScheduleFromDeclarativeRecord()
	{
		kern__ScheduledJob__c job = new kern__ScheduledJob__c(
				kern__SchedulerName__c = 'Nightly Order Export',
				kern__ClassName__c = 'Recipe_ScheduledChain_DEMO',
				kern__CronExpression__c = '0 0 3 * * ?',
				kern__IsActive__c = true,
				kern__Parameters__c = new kern.DTO_NameValues(new Map<String, String>{ 'batchLimit' => '200' }).serialize()
		);

		Test.startTest();
		kern.DML_Builder.newTransaction().doInsert(job).execute();
		Test.stopTest();

		kern__ScheduledJob__c scheduled =
		[
				SELECT kern__ScheduledJobId__c
				FROM kern__ScheduledJob__c
				WHERE Id = :job.Id
		];
		Assert.isNotNull(scheduled.kern__ScheduledJobId__c,
				'The packaged trigger should schedule the class and stamp the job Id');
	}

	/**
	 * @description Verifies the schedulable entry point runs the chain with the typed parameter
	 * flowing from the record's Parameters__c into the chain context.
	 */
	@IsTest
	private static void shouldRunChainFromSchedulableExecute()
	{
		Recipe_ScheduledChain_DEMO scheduler = new Recipe_ScheduledChain_DEMO();
		scheduler.setParameterValues(new kern.DTO_NameValues(new Map<String, String>{ 'batchLimit' => '25' }));

		Test.startTest();
		scheduler.execute(null);
		Test.stopTest();

		kern__AsyncChainExecution__c run = queryRun();
		Assert.areEqual('Completed', run.kern__Status__c, 'The scheduled chain should complete');
		Assert.areEqual('25', String.valueOf(parseContext(run).get('batchLimit')),
				'The typed parameter should flow into the chain context');
	}

	/**
	 * @description Verifies the overlap semantics the deduplication key buys: a second start
	 * while the first run is active returns the SAME run Id, and exactly one run row exists.
	 */
	@IsTest
	private static void shouldHandBackActiveRunOnOverlap()
	{
		Test.startTest();
		String firstRunId = Recipe_ScheduledChain_DEMO.startExport(50);
		String secondRunId = Recipe_ScheduledChain_DEMO.startExport(50);
		Test.stopTest();

		Assert.areEqual(firstRunId, secondRunId,
				'An overlapping start should hand back the active run instead of doubling up');

		List<kern__AsyncChainExecution__c> runs =
		[
				SELECT Id,
						kern__Status__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = :CHAIN_NAME
		];
		Assert.areEqual(1, runs.size(), 'Exactly one run row should exist for the overlapping starts');
		Assert.areEqual('Completed', runs[0].kern__Status__c, 'The single run should complete');
	}

	/**
	 * @description Queries the single run row for the pattern's chain name.
	 *
	 * @return The queried execution record.
	 */
	private static kern__AsyncChainExecution__c queryRun()
	{
		return
		[
				SELECT kern__Status__c,
						kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = :CHAIN_NAME
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
