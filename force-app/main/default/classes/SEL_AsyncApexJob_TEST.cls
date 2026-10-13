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
 * @date July 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SEL_AsyncApexJob_TEST
{
	/**
	 * @description A cron expression set to the last year the platform accepts, so a job scheduled
	 * with it never fires during the test. The row the platform creates for the schedule is the test data.
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
		Assert.isNotNull(foundJob.Status, 'The Status field must be populated on the real row');
	}

	/**
	 * @description Tests that the selector declares exactly the Status field. That is the only field the
	 * watchdog needs to tell whether a job is live. Id is not declared here because the query builder selects
	 * it on every query by default; the real-row test proves it arrives populated.
	 */
	@IsTest
	private static void shouldDeclareExactlyStatus()
	{
		List<SObjectField> declaredFields = new SEL_AsyncApexJob().getFields();

		Assert.areEqual(new List<SObjectField> {AsyncApexJob.Status}, declaredFields, 'The liveness selector must declare exactly Status; Id is selected by default');
	}

	/**
	 * @description Tests that findLiveScheduledApexByApexClassId sees a real System.schedule
	 * registration: scheduling the watchdog adds exactly one live scheduled-Apex row for its class.
	 * Counting against a pre-schedule baseline keeps the test honest in orgs where a watchdog schedule
	 * already exists, because platform job rows are visible to tests regardless of data isolation. The
	 * check with a made-up class Id proves the ApexClassId condition itself: without it, an unfiltered query
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
			Assert.isNotNull(liveJob.Status, 'The Status field must be populated on every live row');
		}
		List<AsyncApexJob> otherClassJobs = new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(UTIL_Random.randomId(ApexClass.SObjectType));
		Assert.areEqual(0, otherClassJobs.size(), 'A different class Id must match nothing, because the finder filters by the requested class');
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
	 * @description Tests that the job runner's overlap read returns only the live rows among the ids it is given, and
	 * that an empty id list never reaches the platform.
	 */
	@IsTest
	private static void findLiveByIdsReturnsOnlyTheMockedLiveRows()
	{
		String liveStatus = SEL_AsyncApexJob.AsyncApexJobStatus.Processing.name();
		AsyncApexJob liveJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType).withOverride(AsyncApexJob.Status, liveStatus).build();

		List<AsyncApexJob> live = new SEL_AsyncApexJob().findLiveByIds(new List<Id> {liveJob.Id});

		Assert.areEqual(1, live.size(), 'the live row is returned');
		Assert.areEqual(liveJob.Id, live[0].Id, 'by id');
		Assert.isTrue(new SEL_AsyncApexJob().findLiveByIds(new List<Id>()).isEmpty(), 'no ids, no query');
	}

	/**
	 * @description Tests the overlap read against real platform rows on both sides of its status filter: a schedule
	 * registration reads as live by id while it is waiting and stops reading as live once it is aborted, and a queueable
	 * that has finished is excluded even though its row is still there. The finished row is read back by id first, so
	 * the exclusion is provably the status filter and not a missing row.
	 */
	@IsTest
	private static void findLiveByIdsExcludesJobsThatAreNoLongerLive()
	{
		Test.startTest();
		Id finishedJobId = System.enqueueJob(new NoOperationQueueable());
		Test.stopTest();
		Id watchdogApexClassId = findWatchdogApexClassId();
		Map<Id, AsyncApexJob> liveBeforeScheduling = new Map<Id, AsyncApexJob>(new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogApexClassId));

		String scheduledCronTriggerId = System.schedule(SCHEDULED_JOB_NAME_PREFIX + UTIL_Random.randomUUID(), FAR_FUTURE_CRON_EXPRESSION, new SCHED_ChainWatchdog());
		Map<Id, AsyncApexJob> liveAfterScheduling = new Map<Id, AsyncApexJob>(new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogApexClassId));
		Set<Id> scheduledJobIds = new Set<Id>(liveAfterScheduling.keySet());
		scheduledJobIds.removeAll(liveBeforeScheduling.keySet());
		List<Id> newlyScheduledJobIds = new List<Id>(scheduledJobIds);

		Assert.areEqual(1, newlyScheduledJobIds.size(), 'the schedule added exactly one live registration');
		Assert.areEqual(1, new SEL_AsyncApexJob().findLiveByIds(newlyScheduledJobIds).size(), 'a waiting registration reads as live by id');
		Assert.isNotNull(new SEL_AsyncApexJob().findById(finishedJobId), 'the finished job row is still there, so the status filter is what excludes it');
		Assert.isTrue(new SEL_AsyncApexJob().findLiveByIds(new List<Id> {finishedJobId}).isEmpty(), 'a finished queueable is not live');

		System.abortJob(scheduledCronTriggerId);

		Assert.isTrue(new SEL_AsyncApexJob().findLiveByIds(newlyScheduledJobIds).isEmpty(), 'an aborted registration is not live');
	}

	/**
	 * @description Tests that the read the batch-error listener uses returns a finished job by id together with the
	 * name and namespace of the class it ran, read against a real job row so the link to the class is proven, and that
	 * an empty list of ids reads nothing. The namespace is empty on an org without one and the package's own namespace
	 * in a packaged build, so comparing it with the class's own row holds in both.
	 */
	@IsTest
	private static void findByIdsReturnsTheJobWithTheNameOfItsClass()
	{
		Test.startTest();
		Id finishedJobId = System.enqueueJob(new NoOperationQueueable());
		Test.stopTest();
		ApexClass testClass = new SEL_ApexClass().findByQualifiedName(SEL_AsyncApexJob_TEST.class.getName());

		List<AsyncApexJob> jobs = new SEL_AsyncApexJob().findByIds(new List<Id> {finishedJobId});

		Assert.areEqual(1, jobs.size(), 'The finished job must be found by its id, whatever its status');
		Assert.areEqual(finishedJobId, jobs[0].Id, 'The requested job must be returned');
		Assert.areEqual(testClass.Id, jobs[0].ApexClassId, 'The job must carry the id of the class it ran');
		Assert.areEqual(testClass.Name, jobs[0].ApexClass.Name, 'The job must carry the name of the class it ran');
		Assert.areEqual(testClass.NamespacePrefix, jobs[0].ApexClass.NamespacePrefix, 'The job must carry the namespace of the class it ran');
		Integer queriesBeforeEmptyRead = UTIL_Limits.soqlQueries().used();
		Assert.isTrue(new SEL_AsyncApexJob().findByIds(new List<Id>()).isEmpty(), 'An empty list of ids must return no rows');
		Assert.areEqual(queriesBeforeEmptyRead, UTIL_Limits.soqlQueries().used(), 'An empty list of ids must not reach the database');
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
		 * @description Performs no work. The enqueue itself creates the AsyncApexJob row under test.
		 *
		 * @param context The queueable context supplied by the platform.
		 */
		public void execute(QueueableContext context)
		{
			// The enqueue itself is the fixture: the selector test only needs the AsyncApexJob row.
		}
	}
}