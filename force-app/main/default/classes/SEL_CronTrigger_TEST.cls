// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for SEL_CronTrigger, the selector behind the Job Runner Running, Job Runner Integrity and
 * slot dimensions. Runs serially: the real-path tests schedule a job, and System.schedule performs DML on CronJobDetail,
 * which the platform forbids in parallel test runs.
 *
 * @see SEL_CronTrigger
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date September 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_CronTrigger_TEST
{
	/**
	 * @description A cron expression set to the last year the platform accepts, so a job scheduled with it never
	 * fires during the test. The row the platform creates for the schedule is the test data.
	 */
	private static final String FAR_FUTURE_CRON_EXPRESSION = '0 0 0 1 1 ? 2099';

	/**
	 * @description The quote a SOQL query writes a text value in, so the job type is looked for as a value rather than
	 * as a stray digit anywhere in the query.
	 */
	private static final String SOQL_VALUE_QUOTE = '\'';

	/**
	 * @description The filter the slot count must carry, written out as SOQL: only Scheduled Apex jobs take one of the
	 * org's 100 slots.
	 */
	private static final String SCHEDULED_APEX_CONDITION = 'CronJobDetail.JobType = ' + SOQL_VALUE_QUOTE + SEL_CronTrigger.JOB_TYPE_SCHEDULED_APEX + SOQL_VALUE_QUOTE;

	/**
	 * @description Prefix for the uniquely named scheduled jobs these tests register, so a registration left behind by
	 * an interrupted run never collides on the org-wide unique scheduled-job name.
	 */
	private static final String SCHEDULED_JOB_NAME_PREFIX = SEL_CronTrigger_TEST.class.getName() + UTIL_String.SPACE;

	/**
	 * @description Tests that the selector selects every field and parent field the job runner's dimensions read, by
	 * reading the SOQL the shipped query property builds.
	 */
	@IsTest
	private static void theQuerySelectsEveryFieldTheDimensionsRead()
	{
		String soql = new SEL_CronTrigger().query.toSoql();

		Assert.isTrue(soql.contains('State'), 'the state decides whether the job will still fire: ' + soql);
		Assert.isTrue(soql.contains('NextFireTime'), 'the next fire time shows whether the schedule still advances: ' + soql);
		Assert.isTrue(soql.contains('PreviousFireTime'), 'the previous fire time shows whether it ever ran: ' + soql);
		Assert.isTrue(soql.contains('OwnerId'), 'the owner is who the runner runs as: ' + soql);
		Assert.isTrue(soql.contains('TimesTriggered'), 'the trigger count shows how often it has run: ' + soql);
		Assert.isTrue(soql.contains('CronJobDetail.Name'), 'the job name identifies the registration: ' + soql);
		Assert.isTrue(soql.contains('CronJobDetail.JobType'), 'the job type decides whether it costs a Scheduled Apex slot: ' + soql);
	}

	/**
	 * @description Tests that findByIds reads the state and the owner of a real scheduled job: the two values the
	 * runner's dimensions decide on, read back from the platform's own row rather than a mock.
	 */
	@IsTest
	private static void findByIdsReadsTheStateAndOwnerOfARealScheduledJob()
	{
		Id cronTriggerId = System.schedule(SCHEDULED_JOB_NAME_PREFIX + UTIL_Random.randomUUID(), FAR_FUTURE_CRON_EXPRESSION, new SCHED_ChainWatchdog());

		List<CronTrigger> found = new SEL_CronTrigger().findByIds(new Set<Id> {cronTriggerId});

		Assert.areEqual(1, found.size(), 'the scheduled job is found by its id');
		Assert.areEqual(cronTriggerId, found[0].Id, 'and it is the one scheduled');
		Assert.isTrue(SEL_CronTrigger.isLive(found[0]), 'a job scheduled and not yet fired is live, in state ' + found[0].State);
		Assert.areEqual(UserInfo.getUserId(), found[0].OwnerId, 'the owner is read, because the owner is who the runner runs as');
	}

	/**
	 * @description Tests that an empty id set never reaches the platform.
	 */
	@IsTest
	private static void findByIdsWithNoIdsReadsNothing()
	{
		Assert.isTrue(new SEL_CronTrigger().findByIds(new Set<Id>()).isEmpty(), 'an empty id set never queries');
	}

	/**
	 * @description Tests the still-fires predicate at both edges: a finished or deleted job will not fire again, an
	 * acquired one still will.
	 */
	@IsTest
	private static void deletedAndCompleteStatesAreNotLive()
	{
		Assert.isFalse(SEL_CronTrigger.isLive(mockTriggerInState(SEL_CronTrigger.CronTriggerState.DELETED)), 'DELETED is not live');
		Assert.isFalse(SEL_CronTrigger.isLive(mockTriggerInState(SEL_CronTrigger.CronTriggerState.COMPLETE)), 'COMPLETE is not live');
		Assert.isFalse(SEL_CronTrigger.isLive(mockTriggerInState(SEL_CronTrigger.CronTriggerState.ERROR)), 'ERROR is not live');
		Assert.isTrue(SEL_CronTrigger.isLive(mockTriggerInState(SEL_CronTrigger.CronTriggerState.ACQUIRED)), 'ACQUIRED is live');
		Assert.isFalse(SEL_CronTrigger.isLive(null), 'a missing row is not live');
		Assert.isFalse(SEL_CronTrigger.isLive(mockTriggerInState(null)), 'a row with no state is not live');
	}

	/**
	 * @description Builds a scheduled job row in the given state. CronTrigger.State is read only, and the platform will
	 * not put a row into a finished state on demand, so these rows come from the mock layer, which writes read-only
	 * fields the way the platform returns them.
	 *
	 * @param state The state to put the row in; null leaves the row without a state.
	 *
	 * @return The row.
	 */
	private static CronTrigger mockTriggerInState(SEL_CronTrigger.CronTriggerState state)
	{
		String platformValue = state?.name();
		return (CronTrigger)TST_Mock.of(CronTrigger.SObjectType).withOverride(CronTrigger.State, platformValue).build();
	}

	/**
	 * @description Tests the slot count against the real org: a job scheduled here is among the rows it returns, and the
	 * query the count runs keeps out every other kind of scheduled job, which is what makes it a slot count. The filter
	 * is read from the SOQL, because a test org holds no job of any other type for a returned row to show.
	 */
	@IsTest
	private static void findScheduledApexCountsANewlyScheduledApexJob()
	{
		Id cronTriggerId = System.schedule(SCHEDULED_JOB_NAME_PREFIX + UTIL_Random.randomUUID(), FAR_FUTURE_CRON_EXPRESSION, new SCHED_ChainWatchdog());

		List<CronTrigger> scheduledApexJobs = new SEL_CronTrigger().findScheduledApex();
		String soql = new SEL_CronTrigger().buildScheduledApexRead().toSoql();

		Assert.isTrue(new Map<Id, CronTrigger>(scheduledApexJobs).containsKey(cronTriggerId), 'the scheduled Apex job costs a slot, so it is counted');
		Assert.isTrue(soql.contains(SCHEDULED_APEX_CONDITION), 'the count keeps only Scheduled Apex jobs: ' + soql);
		for(CronTrigger scheduledApexJob : scheduledApexJobs)
		{
			Assert.areEqual(SEL_CronTrigger.JOB_TYPE_SCHEDULED_APEX, scheduledApexJob.CronJobDetail.JobType, 'only Scheduled Apex jobs cost a slot');
		}
	}
}
