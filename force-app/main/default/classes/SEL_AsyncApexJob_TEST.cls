// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for the SEL_AsyncApexJob selector. Proves the real query path against a live
 * AsyncApexJob row once, and the scheduled-Apex finder against real System.schedule registrations;
 * the liveness branch matrix lives in UTIL_AsyncChainRecovery_TEST via TST_Mock. Runs serially:
 * System.schedule performs DML on CronJobDetail, which the platform forbids in parallel test runs.
 *
 * @see SEL_AsyncApexJob
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class SEL_AsyncApexJob_TEST
{
	/**
	 * @description A cron expression pinned to the last year the platform accepts, so a job scheduled
	 * with it never fires during the test — the registration row itself is the fixture.
	 */
	private static final String FAR_FUTURE_CRON_EXPRESSION = '0 0 0 1 1 ? 2099';

	/**
	 * @description Prefix for the uniquely named scheduled jobs these tests register, so a registration
	 * left behind by an interrupted run never collides on the org-wide unique scheduled-job name.
	 */
	private static final String SCHEDULED_JOB_NAME_PREFIX = SEL_AsyncApexJob_TEST.class.getName() + UTIL_String.SPACE;

	/**
	 * @description Tests that findById retrieves a real AsyncApexJob row through the selector's
	 * SYSTEM_MODE query path: enqueues a no-operation queueable, then reads its job row back with
	 * both projected fields populated.
	 */
	@IsTest
	private static void shouldFindRealJobRowById()
	{
		Test.startTest();
		Id enqueuedJobId = System.enqueueJob(new NoOperationQueueable());
		Test.stopTest();

		AsyncApexJob foundJob = (AsyncApexJob)new SEL_AsyncApexJob().findById(enqueuedJobId);

		Assert.isNotNull(foundJob, 'The selector must find the enqueued queueable job row');
		Assert.areEqual(enqueuedJobId, foundJob.Id, 'The selector must return the requested job row');
		Assert.isNotNull(foundJob.Status, 'The Status projection must be populated on the real row');
	}

	/**
	 * @description Tests that the selector declares exactly the Status field — the minimal read the
	 * watchdog's liveness probe needs. Id is not declared here because the query builder projects
	 * it on every query by default; the real-row test proves it arrives populated.
	 */
	@IsTest
	private static void shouldProjectExactlyStatus()
	{
		List<SObjectField> projectedFields = new SEL_AsyncApexJob().getFields();

		Assert.areEqual(new List<SObjectField> {AsyncApexJob.Status}, projectedFields, 'The liveness selector must declare exactly Status; Id is projected by default');
	}

	/**
	 * @description Tests that findLiveScheduledApexByApexClassId sees a real System.schedule
	 * registration: scheduling the watchdog adds exactly one live scheduled-Apex row for its class.
	 * Counting against a pre-schedule baseline keeps the test honest in orgs where a watchdog schedule
	 * already exists, because platform job rows are visible to tests regardless of data isolation. The
	 * mock-Id negative control pins the ApexClassId condition itself: without it, an unfiltered query
	 * would satisfy every baseline-delta assertion in this class.
	 */
	@IsTest
	private static void shouldFindLiveScheduledApexJobByApexClassId()
	{
		Id watchdogApexClassId = findWatchdogApexClassId();
		Integer liveJobCountBeforeScheduling = new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogApexClassId).size();

		System.schedule(SCHEDULED_JOB_NAME_PREFIX + UTIL_Random.randomUUID(), FAR_FUTURE_CRON_EXPRESSION, new SCHED_ChainWatchdog());

		List<AsyncApexJob> liveJobs = new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogApexClassId);
		Assert.areEqual(liveJobCountBeforeScheduling + 1, liveJobs.size(), 'The finder must count the new schedule registration as exactly one live scheduled-Apex row');
		for(AsyncApexJob liveJob : liveJobs)
		{
			Assert.isNotNull(liveJob.Status, 'The Status projection must be populated on every live row');
		}
		List<AsyncApexJob> otherClassJobs = new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(UTIL_Random.randomId(ApexClass.SObjectType));
		Assert.areEqual(0, otherClassJobs.size(), 'A different class Id must match nothing — the finder filters by the requested class');
	}

	/**
	 * @description Tests that an aborted schedule registration never reads as live: the finder's status
	 * filter admits only waiting or executing rows, so leftovers from an aborted schedule cannot make
	 * the watchdog look scheduled.
	 */
	@IsTest
	private static void shouldNotCountAbortedScheduledApexJobAsLive()
	{
		Id watchdogApexClassId = findWatchdogApexClassId();
		Integer liveJobCountBeforeScheduling = new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogApexClassId).size();

		String scheduledCronTriggerId = System.schedule(SCHEDULED_JOB_NAME_PREFIX + UTIL_Random.randomUUID(), FAR_FUTURE_CRON_EXPRESSION, new SCHED_ChainWatchdog());
		System.abortJob(scheduledCronTriggerId);

		Integer liveJobCountAfterAbort = new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogApexClassId).size();
		Assert.areEqual(liveJobCountBeforeScheduling, liveJobCountAfterAbort, 'An aborted schedule registration must not count as a live scheduled-Apex row');
	}

	/**
	 * @description Resolves the ApexClass row Id for SCHED_ChainWatchdog through the same selector
	 * lookup the Health Check's platform probe applies, so the finder is exercised with the real class
	 * Id in both namespaced and unmanaged deployments.
	 *
	 * @return The Id of the SCHED_ChainWatchdog ApexClass row.
	 */
	private static Id findWatchdogApexClassId()
	{
		return new SEL_ApexClass().findByQualifiedName(SCHED_ChainWatchdog.class.getName()).Id;
	}

	/**
	 * @description Minimal queueable whose only purpose is producing a real AsyncApexJob row for
	 * the selector test. A test fixture this small needs no Finalizer.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock,PMD.QueueableWithoutFinalizer')
	private class NoOperationQueueable implements Queueable
	{
		/**
		 * @description Performs no work — the enqueue itself creates the AsyncApexJob row under test.
		 *
		 * @param context The queueable context supplied by the platform.
		 */
		public void execute(QueueableContext context)
		{
			// The enqueue itself is the fixture: the selector test only needs the AsyncApexJob row.
		}
	}
}
