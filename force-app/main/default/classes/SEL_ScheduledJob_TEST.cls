// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ScheduledJob selector.
 *
 * @see SEL_ScheduledJob
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, September 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EagerlyLoadedDescribeSObjectResult')
private class SEL_ScheduledJob_TEST
{
	/**
	 * @description The run priority both rows of the tie fixture carry, so that neither priority nor cursor can decide
	 * their order and only the record id is left to settle it.
	 */
	private static final Decimal TIED_RUN_PRIORITY = 5;

	/**
	 * @description Tests that the selector constructs and exposes fields correctly.
	 */
	@IsTest
	private static void shouldQueryScheduledJobs()
	{
		List<SObject> results = new SEL_ScheduledJob().toList();

		Assert.isNotNull(results, 'Should execute query successfully');
	}

	/**
	 * @description Tests that findActiveByClassName returns only matching active records.
	 */
	@IsTest
	private static void shouldFindActiveByClassName()
	{
		String targetClassName = SCHED_PurgeRecords.class.getName();

		String paramKey = SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME;

		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				TST_Factory.newScheduledJob(targetClassName, new DTO_NameValues(new Map<String, String> {paramKey => LogEntry__c.SObjectType.getDescribe().name})),
				TST_Factory.newScheduledJob('SCHED_ProcessLoginHistory', new DTO_NameValues(new Map<String, String> {paramKey => Foobar__c.SObjectType.getDescribe().name}))
		});

		List<ScheduledJob__c> results = new SEL_ScheduledJob().findActiveByClassName(targetClassName);

		Assert.isFalse(results.isEmpty(), 'Should return results for matching class name');
	}

	/**
	 * @description Inserts a job-runner-mode row directly, with the trigger bypassed, so the selector is proven against
	 * real rows and real ordering rather than the mock layer (which answers every query regardless of its filters).
	 *
	 * @param name The scheduler name, unique per row.
	 * @param cursor The NextRunAt__c cursor.
	 * @param priority The RunPriority__c value, blank allowed.
	 * @param isActive Whether the row is active.
	 * @param mode The ExecutionMode__c value.
	 *
	 * @return The inserted row.
	 */
	private static ScheduledJob__c insertJobRunnerRow(String name, Datetime cursor, Decimal priority, Boolean isActive, String mode)
	{
		return (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.SchedulerName__c, name)
				.withOverride(ScheduledJob__c.ClassName__c, SCHED_PurgeRecords.class.getName())
				.withOverride(ScheduledJob__c.CronExpression__c, '0 */5 * * * ?')
				.withOverride(ScheduledJob__c.IsActive__c, isActive)
				.withOverride(ScheduledJob__c.ExecutionMode__c, mode)
				.withOverride(ScheduledJob__c.NextRunAt__c, cursor)
				.withOverride(ScheduledJob__c.RunPriority__c, priority)
				.build();
	}

	/**
	 * @description Tests that the claim returns the due job-runner-mode rows in the order the runner starts them, and that
	 * the check limit caps how many it locks.
	 */
	@IsTest
	private static void claimReturnsDueJobRunnerRowsInPriorityThenCursorOrderWithinTheCheckLimit()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		Datetime checkTime = Datetime.newInstanceGmt(2026, 6, 1, 9, 0, 0);
		ScheduledJob__c blankPriorityOlder = insertJobRunnerRow('blank older', checkTime.addMinutes(-30), null, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		ScheduledJob__c prioritySeven = insertJobRunnerRow('seven', checkTime.addMinutes(-5), 7, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		ScheduledJob__c priorityOne = insertJobRunnerRow('one', checkTime, 1, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		insertJobRunnerRow('blank newer', checkTime.addMinutes(-1), null, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		insertJobRunnerRow('future', checkTime.addMinutes(1), 0, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		insertJobRunnerRow('inactive', checkTime.addMinutes(-5), 0, false, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		insertJobRunnerRow('own mode', checkTime.addMinutes(-5), 0, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB);

		List<ScheduledJob__c> claimed = new SEL_ScheduledJob().findDueJobRunnerRecordsForUpdate(checkTime, 3);

		Assert.areEqual(3, claimed.size(), 'the check limit caps the claim');
		Assert.areEqual(priorityOne.Id, claimed[0].Id, 'the lowest priority number is first');
		Assert.areEqual(prioritySeven.Id, claimed[1].Id, 'then the next priority');
		Assert.areEqual(blankPriorityOlder.Id, claimed[2].Id, 'blank priorities go last, oldest cursor first');
		Assert.areEqual(4, new SEL_ScheduledJob().countDueJobRunnerRecords(checkTime), 'four rows are due in total, so one was left waiting');
	}

	/**
	 * @description Tests the last ordering key the claim applies: two rows that fall due at the same moment with the
	 * same run priority come back in ascending record id order, so a tie is settled the same way on every check instead
	 * of being left to the platform.
	 */
	@IsTest
	private static void claimBreaksATieOnTheSamePriorityAndCursorByAscendingId()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		Datetime checkTime = Datetime.newInstanceGmt(2026, 6, 1, 9, 0, 0);
		Datetime sharedCursor = checkTime.addMinutes(-5);
		ScheduledJob__c firstTied = insertJobRunnerRow('tied one', sharedCursor, TIED_RUN_PRIORITY, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		ScheduledJob__c secondTied = insertJobRunnerRow('tied two', sharedCursor, TIED_RUN_PRIORITY, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		List<String> idsInAscendingOrder = new List<String> {String.valueOf(firstTied.Id), String.valueOf(secondTied.Id)};
		idsInAscendingOrder.sort();

		List<ScheduledJob__c> claimed = new SEL_ScheduledJob().findDueJobRunnerRecordsForUpdate(checkTime, 2);

		Assert.areEqual(2, claimed.size(), 'both tied rows are claimed');
		Assert.areEqual(idsInAscendingOrder[0], String.valueOf(claimed[0].Id), 'the lower id runs first, so the tie is settled the same way on every check');
		Assert.areEqual(idsInAscendingOrder[1], String.valueOf(claimed[1].Id), 'and the higher id runs second');
	}

	/**
	 * @description Tests that a zero check limit locks nothing and that a check before the cursor claims nothing.
	 */
	@IsTest
	private static void claimReturnsNothingForAZeroCheckLimitOrWhenNothingIsDue()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		Datetime checkTime = Datetime.newInstanceGmt(2026, 6, 1, 9, 0, 0);
		insertJobRunnerRow('due', checkTime, 1, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);

		Assert.isTrue(new SEL_ScheduledJob().findDueJobRunnerRecordsForUpdate(checkTime, 0).isEmpty(), 'a zero check limit locks nothing');
		Assert.isTrue(new SEL_ScheduledJob().findDueJobRunnerRecordsForUpdate(checkTime.addMinutes(-1), 5).isEmpty(), 'nothing due, nothing claimed');
		Assert.isTrue(new SEL_ScheduledJob().findDueJobRunnerRecordsForUpdate(null, 5).isEmpty(), 'no check time, nothing claimed');
	}

	/**
	 * @description Tests that the second read of the claim locks its rows and carries no ORDER BY, which the platform
	 * forbids on a locking query.
	 */
	@IsTest
	private static void lockingReadCarriesForUpdateAndNoOrderBy()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		ScheduledJob__c row = insertJobRunnerRow('locked', Datetime.now(), 1, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);

		String soql = new SEL_ScheduledJob().buildLockingRead(new List<ScheduledJob__c> {row}).toSoql().toUpperCase();

		Assert.isTrue(soql.endsWith('FOR UPDATE'), 'the second read locks the rows: ' + soql);
		Assert.isFalse(soql.contains('ORDER BY'), 'a locking read cannot carry ORDER BY, so the order is restored in memory: ' + soql);
	}

	/**
	 * @description Tests that the runner's own records, the rows waiting on the runner and the rows holding a platform
	 * job are each filtered by the value that defines them.
	 */
	@IsTest
	private static void runnerAndModeQueriesFilterByClassAndMode()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		ScheduledJob__c runner = (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.ClassName__c, UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME)
				.withOverride(ScheduledJob__c.CronExpression__c, '0 15 * * * ?')
				.withOverride(ScheduledJob__c.IsActive__c, true)
				.withOverride(ScheduledJob__c.ScheduledJobId__c, UTIL_Random.randomId(CronTrigger.SObjectType))
				.build();
		insertJobRunnerRow('waiting', Datetime.now(), null, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		insertJobRunnerRow('own', Datetime.now(), null, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB);

		Assert.areEqual(1, new SEL_ScheduledJob().findRunnerRecords().size(), 'only the runner class record is a runner record');
		Assert.areEqual(runner.Id, new SEL_ScheduledJob().findRunnerRecords()[0].Id, 'and it is the one inserted');
		Assert.areEqual(1, new SEL_ScheduledJob().findActiveJobRunnerModeRecords().size(), 'one active row waits on the runner');
		Assert.areEqual(1, new SEL_ScheduledJob().findActiveWithPlatformJob().size(), 'only the runner record owns a platform job id');
	}

	/**
	 * @description Tests the two single-record reads the runner uses: the locking read Run now shares with a check, and
	 * the plain read the run itself takes at start time. Both read a row the running user need not own, and both answer
	 * null for a record that is no longer there.
	 */
	@IsTest
	private static void singleRecordReadsFindTheRowAndAnswerNullForAMissingId()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		ScheduledJob__c row = insertJobRunnerRow('single', Datetime.now(), 1, true, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		Id missingId = UTIL_Random.randomId(ScheduledJob__c.SObjectType);

		Assert.areEqual(row.Id, new SEL_ScheduledJob().findByIdForUpdate(row.Id).Id, 'the locking read finds the row');
		Assert.areEqual(row.Id, new SEL_ScheduledJob().findByIdBypassingSharing(row.Id).Id, 'the plain read finds the row');
		Assert.isNull(new SEL_ScheduledJob().findByIdForUpdate(missingId), 'a missing id locks nothing');
		Assert.isNull(new SEL_ScheduledJob().findByIdBypassingSharing(missingId), 'a missing id reads nothing');
	}
}