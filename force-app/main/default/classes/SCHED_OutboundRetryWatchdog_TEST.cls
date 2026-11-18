// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class to check behavior of SCHED_OutboundRetryWatchdog. Calls at Retry and at Retrying are real
 * saved rows. The background jobs and the time a call was last saved are scripted answers (TST_Mock), because a test
 * cannot create a running job of another class or move a save time into the past. One test of a refused save scripts
 * the read, so it returns a call that is not in the database beside a saved one. The other runs a trigger action of
 * its own that refuses the change of one saved call.
 *
 * @see SCHED_OutboundRetryWatchdog
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=false)
private class SCHED_OutboundRetryWatchdog_TEST
{
	/**
	 * @description The service the test calls belong to.
	 */
	private static final String SERVICE_NAME = API_PostExample.class.getName();

	/**
	 * @description How long ago, in minutes, the retry of a stale call was due: more than the default limit of 60 minutes.
	 */
	private static final Integer STALE_MINUTES_AGO = -90;

	/**
	 * @description How long ago, in minutes, the retry of a call was due when it is not stale yet: less than 60 minutes.
	 */
	private static final Integer RECENT_MINUTES_AGO = -30;

	/**
	 * @description How long ago, in minutes, a live background job was created in the tests that need one.
	 */
	private static final Integer LIVE_JOB_MINUTES_AGO = -30;

	/**
	 * @description How long ago, in hours, the retry of a call was due in the test of the one-day limit.
	 */
	private static final Integer MORE_THAN_A_DAY_HOURS_AGO = -25;

	/**
	 * @description The number of whole hours a call waited after its retry was due 90 minutes ago.
	 */
	private static final Integer ONE_HOUR = 1;

	/**
	 * @description The number of whole hours a call waited after its retry was due 25 hours ago.
	 */
	private static final Integer TWENTY_FIVE_HOURS = 25;

	/**
	 * @description The number of times each test call at Retry or Retrying was already sent.
	 */
	private static final Integer RETRIES_SO_FAR = 1;

	/**
	 * @description The error text each test call carries before the watchdog runs.
	 */
	private static final String EARLIER_ERROR = 'The external system did not answer.';

	/**
	 * @description The shortest wait, in minutes, a call gets when its retry time is moved forward.
	 */
	private static final Integer FIFTEEN_MINUTES = 15;

	/**
	 * @description A last wait of 60 minutes, from the call's last save to its retry time.
	 */
	private static final Integer SIXTY_MINUTES = 60;

	/**
	 * @description The wait a call gets when its last wait was 60 minutes: twice as long.
	 */
	private static final Integer ONE_HUNDRED_TWENTY_MINUTES = 120;

	/**
	 * @description How far, in milliseconds, a new retry time may be from the expected time.
	 */
	private static final Long ONE_MINUTE_IN_MILLISECONDS = 60000;

	/**
	 * @description The batch size given in the test where more calls are stale than one run looks at.
	 */
	private static final String SMALL_BATCH_SIZE = '2';

	/**
	 * @description The number of stale calls in the test where more calls are stale than one run looks at.
	 */
	private static final Integer MORE_THAN_THE_SMALL_BATCH = 3;

	/**
	 * @description A batch size above the most calls one run may look at.
	 */
	private static final String BATCH_SIZE_ABOVE_THE_MAXIMUM = '60';

	/**
	 * @description The most calls of one kind one run looks at.
	 */
	private static final Integer MAXIMUM_BATCH_SIZE = 50;

	/**
	 * @description The length of the random text that is repeated to fill a request or a response to its full length.
	 */
	private static final Integer BODY_PART_LENGTH = 1024;

	/**
	 * @description How long ago, in minutes, the retry of the earlier of two stale calls was due, in the tests with two
	 * calls at Retrying.
	 */
	private static final Integer EARLIER_STALE_MINUTES_AGO = -120;

	/**
	 * @description How long ago, in minutes, an older live job was created: after the earlier retry time (120 minutes
	 * ago) and before the later one (90 minutes ago).
	 */
	private static final Integer BETWEEN_THE_RETRY_TIMES_MINUTES_AGO = -100;

	/**
	 * @description The error the test trigger action puts on a call whose change it refuses.
	 */
	private static final String REFUSAL_MESSAGE = 'This change was refused by the test.';

	/**
	 * @description The Ids of the calls whose changes the test trigger action refuses.
	 */
	private static final Set<Id> REFUSED_CALL_IDS = new Set<Id>();

	/**
	 * @description Tests that the watchdog declares its two optional number parameters with their defaults: 60 minutes
	 * before a call counts as stale, and 50 calls of each kind in one run.
	 *
	 * @see SCHED_OutboundRetryWatchdog.getParameterDefinitions
	 */
	@IsTest
	private static void shouldDeclareTheTwoNumberParameters()
	{
		List<DTO_ScheduledParameterDefinition> parameters = new SCHED_OutboundRetryWatchdog().getParameterDefinitions();

		Assert.areEqual(2, parameters.size(), 'Expected two parameter definitions.');
		Assert.areEqual(SCHED_OutboundRetryWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES, parameters[0].name, 'Expected the stale limit first.');
		Assert.areEqual(DTO_ScheduledParameterDefinition.DataType.NUMERIC.name(), parameters[0].dataType, 'Expected the stale limit to be a number.');
		Assert.areEqual('60', parameters[0].defaultValue, 'Expected the stale limit to default to 60 minutes.');
		Assert.isFalse(parameters[0].isRequired, 'Expected the stale limit to be optional.');
		Assert.isNotNull(parameters[0].description, 'Expected the stale limit to be described.');
		Assert.areEqual(SCHED_OutboundRetryWatchdog.PARAMETER_BATCH_SIZE, parameters[1].name, 'Expected the batch size second.');
		Assert.areEqual(DTO_ScheduledParameterDefinition.DataType.NUMERIC.name(), parameters[1].dataType, 'Expected the batch size to be a number.');
		Assert.areEqual('50', parameters[1].defaultValue, 'Expected the batch size to default to 50.');
		Assert.isFalse(parameters[1].isRequired, 'Expected the batch size to be optional.');
		Assert.isNotNull(parameters[1].description, 'Expected the batch size to be described.');
	}

	/**
	 * @description Tests that the job runner can start the watchdog from its class name: saving an active scheduled job
	 * record for it schedules it, and its run at the end of the test ends without an error.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldScheduleThroughTheJobRunner()
	{
		Test.startTest();

		ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(SCHED_OutboundRetryWatchdog.class.getName(), new Map<String, String>
		{
				SCHED_OutboundRetryWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES => String.valueOf(SIXTY_MINUTES),
				SCHED_OutboundRetryWatchdog.PARAMETER_BATCH_SIZE => SMALL_BATCH_SIZE
		});
		scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

		Test.stopTest();

		Assert.isNotNull(scheduler.ScheduledJobId__c, 'Expected the job runner to start the watchdog.');
	}

	/**
	 * @description Tests that a call at Retry whose retry was due more than 60 minutes ago gets a new retry time, so the
	 * Retry Outbound Api Call flow sends it again. Its last wait cannot be read (it was saved after its retry time), so
	 * it waits 15 minutes. It stays at Retry, its retry count and its error text do not change, no API issue is raised,
	 * and one warning says the time was moved. A call whose retry was due 30 minutes ago is not stale yet and is left
	 * as it is.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldMoveTheRetryTimeOfAStaleRetryCallForward()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c staleCall = insertCall(SEL_ApiCall.STATUS_RETRY, Datetime.now().addMinutes(STALE_MINUTES_AGO));
		Datetime recentRetryTime = Datetime.now().addMinutes(RECENT_MINUTES_AGO);
		ApiCall__c recentCall = insertCall(SEL_ApiCall.STATUS_RETRY, recentRetryTime);
		ApiCall__c savedStaleCall = readCall(staleCall.Id);

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		ApiCall__c movedCall = readCall(staleCall.Id);
		assertRetryTimeMovedForward(movedCall, FIFTEEN_MINUTES);
		ApiCall__c untouchedCall = readCall(recentCall.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, untouchedCall.Status__c, 'Expected the call that is not stale yet to stay at Retry.');
		Assert.areEqual(recentRetryTime.getTime() / 1000, untouchedCall.NextRetry__c.getTime() / 1000, 'Expected the call that is not stale yet to keep its time.');
		Assert.areEqual(0, new SEL_ApiIssue().count(), 'Expected no API issue for a call that waits for its retry.');
		List<LogEntry__c> entries = findWatchdogEntries();
		Assert.areEqual(1, entries.size(), 'Expected one log entry, got ' + entries);
		Assert.areEqual(LoggingLevel.WARN.name(), entries[0].LogLevel__c, 'Expected the entry to be a warning.');
		Assert.areEqual(movedCall.Id, entries[0].RecordId__c, 'Expected the warning to name the call.');
		Assert.areEqual(formatMovedMessage(savedStaleCall, movedCall), entries[0].Message__c, 'Expected the warning to say the retry time was moved.');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entries[0]);
		Assert.areEqual
				(
						JSON.serialize(savedStaleCall.NextRetry__c),
						context.get(SCHED_OutboundRetryWatchdog.CONTEXT_PREVIOUS_NEXT_RETRY),
						'Expected the warning to carry the retry time the call had before the run.'
				);
		Assert.areEqual
				(
						JSON.serialize(movedCall.NextRetry__c),
						context.get(SCHED_OutboundRetryWatchdog.CONTEXT_NEXT_RETRY),
						'Expected the warning to carry the new retry time of the call.'
				);
		Assert.areEqual
				(
						String.valueOf(movedCall.Id),
						context.get(SCHED_OutboundRetryWatchdog.CONTEXT_API_CALL_ID),
						'Expected the warning to carry the Id of the call.'
				);
	}

	/**
	 * @description Tests that a stale call at Retry whose last wait can be read waits twice as long: a call saved 60
	 * minutes before its retry time now waits 120 minutes. The read gives the call its last save time, so the watchdog
	 * can work out the last wait.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldDoubleTheLastWaitWhenItMovesTheRetryTimeForward()
	{
		Datetime staleRetryTime = Datetime.now().addMinutes(STALE_MINUTES_AGO);
		ApiCall__c staleCall = insertCall(SEL_ApiCall.STATUS_RETRY, staleRetryTime);
		ApiCall__c readWithLastSave = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.Id => staleCall.Id,
						ApiCall__c.ServiceName__c => SERVICE_NAME,
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
						ApiCall__c.Status__c => SEL_ApiCall.STATUS_RETRY,
						ApiCall__c.NextRetry__c => staleRetryTime,
						ApiCall__c.Retries__c => RETRIES_SO_FAR,
						ApiCall__c.LastModifiedDate => staleRetryTime.addMinutes(-SIXTY_MINUTES)
				})
				.withoutInsertion()
				.build();
		TST_Mock.registerNext(ApiCall__c.SObjectType, readWithLastSave);

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		assertRetryTimeMovedForward(readCall(staleCall.Id), ONE_HUNDRED_TWENTY_MINUTES);
	}

	/**
	 * @description Tests that a call at Retry with no retry time is left as it is: nothing would ever send it, but the
	 * watchdog does not judge a call in that shape. No log entry is written for it.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldLeaveARetryCallWithNoRetryTimeAlone()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c call = insertCall(SEL_ApiCall.STATUS_RETRY, null);

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		ApiCall__c untouchedCall = readCall(call.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, untouchedCall.Status__c, 'Expected the call to stay at Retry.');
		Assert.isNull(untouchedCall.NextRetry__c, 'Expected the call to get no retry time.');
		Assert.areEqual(EARLIER_ERROR, untouchedCall.ErrorMessages__c, 'Expected the error text not to change.');
		Assert.isTrue(findWatchdogEntries().isEmpty(), 'Expected no log entry.');
	}

	/**
	 * @description Tests that a call at Retrying whose retry was due more than 60 minutes ago, with no live background
	 * job created after that time, is marked Failed. Its retry time is cleared, its retry count does not change, and
	 * its error text says the request may have been sent. Its service logs issues, so one API issue is raised, and the
	 * issue says the external system may have acted on the request. One warning says the call was given up.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldMarkALostRetryingCallFailedAndRaiseAnIssue()
	{
		LOG_Builder.ignoreTestMode = true;
		registerApiSetting(true);
		ApiCall__c call = insertCall(SEL_ApiCall.STATUS_RETRYING, Datetime.now().addMinutes(STALE_MINUTES_AGO));
		TST_Mock.registerNext(AsyncApexJob.SObjectType, new List<SObject>());

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		ApiCall__c failedCall = assertMarkedLost(call.Id, ONE_HOUR);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findByField(ApiIssue__c.ApiCall__c, call.Id);
		Assert.areEqual(1, issues.size(), 'Expected one API issue for the call, got ' + issues);
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted on the request.');
		Assert.areEqual(failedCall.ErrorMessages__c, issues[0].ErrorMessages__c, 'Expected the issue to carry the text of the call.');
		Assert.areEqual(SEL_ApiIssue.DIRECTION_OUTBOUND, issues[0].Direction__c, 'Expected an outbound issue.');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, issues[0].Status__c, 'Expected the issue to be open.');
		assertOneEntry(LoggingLevel.WARN, failedCall.ErrorMessages__c, call.Id);
	}

	/**
	 * @description Tests that a lost call at Retrying is marked Failed with no API issue when its service does not log
	 * issues.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldRaiseNoIssueWhenTheServiceDoesNotLogIssues()
	{
		registerApiSetting(false);
		ApiCall__c call = insertCall(SEL_ApiCall.STATUS_RETRYING, Datetime.now().addMinutes(STALE_MINUTES_AGO));
		TST_Mock.registerNext(AsyncApexJob.SObjectType, new List<SObject>());

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		assertMarkedLost(call.Id, ONE_HOUR);
		Assert.areEqual(0, new SEL_ApiIssue().count(), 'Expected no API issue, because the service does not log issues.');
	}

	/**
	 * @description Tests that a stale call at Retrying is left as it is while a background job of the class that sends
	 * calls is waiting or running and was created after the call's retry time: that job may still send it. One
	 * information entry says the call was left for the next run.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldLeaveAStaleRetryingCallWhileAJobThatMaySendItIsLive()
	{
		LOG_Builder.ignoreTestMode = true;
		registerApiSetting(true);
		Datetime staleRetryTime = Datetime.now().addMinutes(STALE_MINUTES_AGO);
		ApiCall__c call = insertCall(SEL_ApiCall.STATUS_RETRYING, staleRetryTime);
		registerLiveJob(Datetime.now().addMinutes(LIVE_JOB_MINUTES_AGO));

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		ApiCall__c untouchedCall = readCall(call.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_RETRYING, untouchedCall.Status__c, 'Expected the call to stay at Retrying.');
		Assert.areEqual(staleRetryTime.getTime() / 1000, untouchedCall.NextRetry__c.getTime() / 1000, 'Expected the call to keep its retry time.');
		Assert.areEqual(EARLIER_ERROR, untouchedCall.ErrorMessages__c, 'Expected the error text not to change.');
		Assert.areEqual(0, new SEL_ApiIssue().count(), 'Expected no API issue for a call a job may still send.');
		assertOneEntry(LoggingLevel.INFO, SCHED_OutboundRetryWatchdog.MESSAGE_LEFT_FOR_LIVE_JOB, call.Id);
	}

	/**
	 * @description Tests that a live job created before the call's retry time does not keep the call waiting: that job
	 * started before the retry was due, so it is not the one sending it. The call is marked Failed.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldNotWaitForAJobCreatedBeforeTheRetryTime()
	{
		registerApiSetting(false);
		Datetime staleRetryTime = Datetime.now().addMinutes(STALE_MINUTES_AGO);
		ApiCall__c call = insertCall(SEL_ApiCall.STATUS_RETRYING, staleRetryTime);
		registerLiveJob(staleRetryTime.addMinutes(RECENT_MINUTES_AGO));

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		assertMarkedLost(call.Id, ONE_HOUR);
	}

	/**
	 * @description Tests that the watchdog compares the calls at Retrying with the newest live job, not an older one.
	 * Two calls are stale: the retry of the first was due 120 minutes ago, and of the second 90 minutes ago. Two live
	 * jobs are scripted, the older one first: one created 100 minutes ago, between the two retry times, and one created
	 * 30 minutes ago, after both. The newer job may still send both calls, so both stay at Retrying. A check against the
	 * older job would mark the second call Failed.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldWaitForTheNewestLiveJob()
	{
		registerApiSetting(false);
		ApiCall__c earlierCall = insertCall(SEL_ApiCall.STATUS_RETRYING, Datetime.now().addMinutes(EARLIER_STALE_MINUTES_AGO));
		ApiCall__c laterCall = insertCall(SEL_ApiCall.STATUS_RETRYING, Datetime.now().addMinutes(STALE_MINUTES_AGO));
		registerLiveJob(Datetime.now().addMinutes(BETWEEN_THE_RETRY_TIMES_MINUTES_AGO));
		registerLiveJob(Datetime.now().addMinutes(LIVE_JOB_MINUTES_AGO));

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		Assert.areEqual(SEL_ApiCall.STATUS_RETRYING, readCall(earlierCall.Id).Status__c, 'Expected the earlier call to stay at Retrying.');
		Assert.areEqual
				(
						SEL_ApiCall.STATUS_RETRYING,
						readCall(laterCall.Id).Status__c,
						'Expected the later call to stay at Retrying, because the newest live job was created after its retry time.'
				);
	}

	/**
	 * @description Tests that a call at Retrying whose retry was due more than a day ago is marked Failed even while a
	 * job that may send it is live. Any job of that class in the org keeps a call waiting, so the wait stops after one
	 * day. The error text gives the 25 hours the call waited.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldMarkARetryingCallFailedAfterOneDayEvenWhileAJobIsLive()
	{
		registerApiSetting(false);
		ApiCall__c call = insertCall(SEL_ApiCall.STATUS_RETRYING, Datetime.now().addHours(MORE_THAN_A_DAY_HOURS_AGO));
		registerLiveJob(Datetime.now().addMinutes(LIVE_JOB_MINUTES_AGO));

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		assertMarkedLost(call.Id, TWENTY_FIVE_HOURS);
	}

	/**
	 * @description Tests that a call at Queued that has not changed for more than 60 minutes is only reported: one
	 * warning names it, and nothing is saved. Its send may never have started, but only an administrator can tell.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldOnlyReportAStaleQueuedCall()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c queuedCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => SERVICE_NAME,
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
						ApiCall__c.Status__c => SEL_ApiCall.STATUS_QUEUED,
						ApiCall__c.Name => UTIL_Random.randomName(),
						ApiCall__c.LastModifiedDate => Datetime.now().addMinutes(STALE_MINUTES_AGO)
				})
				.withoutInsertion(true)
				.build();
		TST_Mock.registerNext(ApiCall__c.SObjectType, new List<SObject>());
		TST_Mock.registerNext(ApiCall__c.SObjectType, new List<SObject>());
		TST_Mock.registerNext(ApiCall__c.SObjectType, queuedCall);

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		List<LogEntry__c> entries = findWatchdogEntries();
		Assert.areEqual(1, entries.size(), 'Expected one log entry, got ' + entries);
		Assert.areEqual(LoggingLevel.WARN.name(), entries[0].LogLevel__c, 'Expected the entry to be a warning.');
		Assert.isTrue(entries[0].Message__c.contains(queuedCall.Name), 'Expected the warning to name the call, got ' + entries[0].Message__c);
		Assert.areEqual(0, new SEL_ApiCall().count(), 'Expected no call to be saved.');
	}

	/**
	 * @description Tests that when more calls are stale than one run looks at, the run handles as many as its batch size
	 * allows, oldest retry time first, and leaves the rest for the next run without an error.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldHandleOnlyTheBatchSizeAndLeaveTheRestForTheNextRun()
	{
		List<ApiCall__c> calls = new List<ApiCall__c>();
		for(Integer index = 0; index < MORE_THAN_THE_SMALL_BATCH; index++)
		{
			calls.add(insertCall(SEL_ApiCall.STATUS_RETRY, Datetime.now().addMinutes(STALE_MINUTES_AGO - index)));
		}
		DTO_NameValues parameters = new DTO_NameValues();
		parameters.add(SCHED_OutboundRetryWatchdog.PARAMETER_BATCH_SIZE, SMALL_BATCH_SIZE);
		SCHED_OutboundRetryWatchdog watchdog = new SCHED_OutboundRetryWatchdog();
		watchdog.setParameterValues(parameters);

		runWatchdog(watchdog);

		Assert.isTrue(readCall(calls[0].Id).NextRetry__c < Datetime.now(), 'Expected the call with the newest retry time to wait for the next run.');
		assertRetryTimeMovedForward(readCall(calls[1].Id), FIFTEEN_MINUTES);
		assertRetryTimeMovedForward(readCall(calls[2].Id), FIFTEEN_MINUTES);
	}

	/**
	 * @description Tests that a batch size above 50 is lowered to 50: with 51 stale calls at Retry and a batch size of
	 * 60, one run moves the retry time of 50 calls.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldLowerABatchSizeAboveTheMaximum()
	{
		Datetime staleRetryTime = Datetime.now().addMinutes(STALE_MINUTES_AGO);
		TST_Builder.of(ApiCall__c.SObjectType).withOverrides(buildCallFields(SEL_ApiCall.STATUS_RETRY, staleRetryTime)).withCount(MAXIMUM_BATCH_SIZE + 1).buildList();
		DTO_NameValues parameters = new DTO_NameValues();
		parameters.add(SCHED_OutboundRetryWatchdog.PARAMETER_BATCH_SIZE, BATCH_SIZE_ABOVE_THE_MAXIMUM);
		SCHED_OutboundRetryWatchdog watchdog = new SCHED_OutboundRetryWatchdog();
		watchdog.setParameterValues(parameters);

		runWatchdog(watchdog);

		Integer movedCount = 0;
		for(SObject call : new SEL_ApiCall().findByServiceName(SERVICE_NAME))
		{
			movedCount += ((ApiCall__c)call).NextRetry__c > Datetime.now() ? 1 : 0;
		}
		Assert.areEqual(MAXIMUM_BATCH_SIZE, movedCount, 'Expected one run to move the retry time of 50 calls only.');
	}

	/**
	 * @description Tests that a run by a user who cannot edit a stale call at Retry still gives it a new retry time.
	 * API calls are Private, so a Standard User with no permission set cannot edit a call another user saved. The
	 * watchdog reads the calls of every user, so it must also save them whoever runs it.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldMoveTheRetryTimeOfACallTheRunningUserCannotEdit()
	{
		User runningUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		ApiCall__c call = insertCall(SEL_ApiCall.STATUS_RETRY, Datetime.now().addMinutes(STALE_MINUTES_AGO));

		System.runAs(runningUser)
		{
			runWatchdog(new SCHED_OutboundRetryWatchdog());
		}

		assertRetryTimeMovedForward(readCall(call.Id), FIFTEEN_MINUTES);
	}

	/**
	 * @description Tests that a run by a user who cannot edit a lost call at Retrying still marks it Failed and raises
	 * its API issue. API calls are Private, so a Standard User with no permission set cannot edit a call another user
	 * saved.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldMarkALostCallFailedWhenTheRunningUserCannotEditIt()
	{
		registerApiSetting(true);
		User runningUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		ApiCall__c call = insertCall(SEL_ApiCall.STATUS_RETRYING, Datetime.now().addMinutes(STALE_MINUTES_AGO));
		TST_Mock.registerNext(AsyncApexJob.SObjectType, new List<SObject>());

		System.runAs(runningUser)
		{
			runWatchdog(new SCHED_OutboundRetryWatchdog());
		}

		assertMarkedLost(call.Id, ONE_HOUR);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findByField(ApiIssue__c.ApiCall__c, call.Id);
		Assert.areEqual(1, issues.size(), 'Expected one API issue for the call, got ' + issues);
	}

	/**
	 * @description Tests that a stale call at Retry whose change the save refuses is not reported as moved. The read
	 * returns two calls: first a call that does not exist in the database, so its update is refused, then a saved call.
	 * Only the saved call gets a new retry time and a warning.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldLogNoWarningForACallTheSaveRefused()
	{
		LOG_Builder.ignoreTestMode = true;
		Datetime staleRetryTime = Datetime.now().addMinutes(STALE_MINUTES_AGO);
		ApiCall__c savedCall = readCall(insertCall(SEL_ApiCall.STATUS_RETRY, staleRetryTime).Id);
		ApiCall__c refusedCall = buildCallNotInTheDatabase(SEL_ApiCall.STATUS_RETRY, staleRetryTime);
		TST_Mock.registerNext(ApiCall__c.SObjectType, new List<SObject> {refusedCall, savedCall});

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		assertRetryTimeMovedForward(readCall(savedCall.Id), FIFTEEN_MINUTES);
		List<LogEntry__c> entries = findWatchdogEntries();
		Assert.areEqual(1, entries.size(), 'Expected one warning, for the saved call only, got ' + entries);
		Assert.areEqual(savedCall.Id, entries[0].RecordId__c, 'Expected the warning to name the saved call.');
	}

	/**
	 * @description Tests that a lost call at Retrying whose change the save refuses gets no API issue, though its issue
	 * could be saved. Both calls are real saved calls. A trigger action that runs only in this test refuses the change
	 * of the first call, as a validation rule would. The first call stays at Retrying with no API issue; the second
	 * call is marked Failed with one API issue. The trigger framework in this test runs only that action, so no log
	 * entry is written; shouldLogNoWarningForACallTheSaveRefused checks that a refused call gets no warning.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@IsTest
	private static void shouldRaiseNoIssueForALostCallTheSaveRefused()
	{
		registerApiSetting(true);
		registerCallUpdateRefusal();
		ApiCall__c refusedCall = insertCall(SEL_ApiCall.STATUS_RETRYING, Datetime.now().addMinutes(EARLIER_STALE_MINUTES_AGO));
		ApiCall__c savedCall = insertCall(SEL_ApiCall.STATUS_RETRYING, Datetime.now().addMinutes(STALE_MINUTES_AGO));
		REFUSED_CALL_IDS.add(refusedCall.Id);
		TST_Mock.registerNext(AsyncApexJob.SObjectType, new List<SObject>());

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		assertMarkedLost(savedCall.Id, ONE_HOUR);
		Assert.areEqual(SEL_ApiCall.STATUS_RETRYING, readCall(refusedCall.Id).Status__c, 'Expected the refused call to stay at Retrying.');
		Assert.isTrue(new SEL_ApiIssue().findByField(ApiIssue__c.ApiCall__c, refusedCall.Id).isEmpty(), 'Expected no API issue for the refused call.');
		Assert.areEqual(1, new SEL_ApiIssue().findByField(ApiIssue__c.ApiCall__c, savedCall.Id).size(), 'Expected the API issue of the saved call.');
	}

	/**
	 * @description Tests that the watchdog changes calls whose request and response are as long as the fields allow: a
	 * stale call at Retry gets a new retry time, and a lost call at Retrying is marked Failed. The reads leave out that
	 * text, so long bodies do not change what a run does.
	 *
	 * @see SCHED_OutboundRetryWatchdog.execute
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldChangeCallsWhoseBodiesAreFullLength()
	{
		registerApiSetting(false);
		Datetime staleRetryTime = Datetime.now().addMinutes(STALE_MINUTES_AGO);
		ApiCall__c retryCall = insertCallWithFullLengthBodies(SEL_ApiCall.STATUS_RETRY, staleRetryTime);
		ApiCall__c retryingCall = insertCallWithFullLengthBodies(SEL_ApiCall.STATUS_RETRYING, staleRetryTime);
		TST_Mock.registerNext(AsyncApexJob.SObjectType, new List<SObject>());

		runWatchdog(new SCHED_OutboundRetryWatchdog());

		assertRetryTimeMovedForward(readCall(retryCall.Id), FIFTEEN_MINUTES);
		assertMarkedLost(retryingCall.Id, ONE_HOUR);
	}

	/**
	 * @description Runs the watchdog once inside the test's own limits, then delivers the log events so the entries
	 * can be read.
	 *
	 * @param watchdog The watchdog to run.
	 */
	private static void runWatchdog(SCHED_OutboundRetryWatchdog watchdog)
	{
		Test.startTest();
		watchdog.execute(null);
		Test.stopTest();
		Test.getEventBus().deliver();
	}

	/**
	 * @description Builds the fields of an outbound test call that was sent once and failed.
	 *
	 * @param status The status of the call.
	 * @param nextRetry The retry time of the call, or null for none.
	 *
	 * @return The fields to save the call with.
	 */
	private static Map<SObjectField, Object> buildCallFields(String status, Datetime nextRetry)
	{
		return new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => SERVICE_NAME,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
				ApiCall__c.Status__c => status,
				ApiCall__c.NextRetry__c => nextRetry,
				ApiCall__c.Retries__c => RETRIES_SO_FAR,
				ApiCall__c.ErrorMessages__c => EARLIER_ERROR,
				ApiCall__c.TriggeringRecordId__c => UTIL_Random.randomId(Foobar__c.SObjectType)
		};
	}

	/**
	 * @description Saves an outbound test call with the given status and retry time.
	 *
	 * @param status The status of the call.
	 * @param nextRetry The retry time of the call, or null for none.
	 *
	 * @return The saved call.
	 */
	private static ApiCall__c insertCall(String status, Datetime nextRetry)
	{
		return (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withOverrides(buildCallFields(status, nextRetry)).build();
	}

	/**
	 * @description Saves an outbound test call with the given status and retry time, whose request and response are
	 * as long as the fields allow.
	 *
	 * @param status The status of the call.
	 * @param nextRetry The retry time of the call.
	 *
	 * @return The saved call.
	 */
	private static ApiCall__c insertCallWithFullLengthBodies(String status, Datetime nextRetry)
	{
		Map<SObjectField, Object> fields = buildCallFields(status, nextRetry);
		fields.put(ApiCall__c.Request__c, buildRandomText(SEL_ApiCall.REQUEST_LENGTH));
		fields.put(ApiCall__c.Response__c, buildRandomText(SEL_ApiCall.RESPONSE_LENGTH));
		return (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withOverrides(fields).build();
	}

	/**
	 * @description Builds random text of the given length, by repeating a shorter random text.
	 *
	 * @param length The length of the text.
	 *
	 * @return The text.
	 */
	private static String buildRandomText(Integer length)
	{
		return UTIL_Random.randomAlphanumeric(BODY_PART_LENGTH).repeat(length / BODY_PART_LENGTH + 1).left(length);
	}

	/**
	 * @description Builds an outbound test call that is not saved, with an Id no record in the database has, so the
	 * database refuses any update of it.
	 *
	 * @param status The status of the call.
	 * @param nextRetry The retry time of the call.
	 *
	 * @return The call, not saved.
	 */
	private static ApiCall__c buildCallNotInTheDatabase(String status, Datetime nextRetry)
	{
		return (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withOverrides(buildCallFields(status, nextRetry)).withoutInsertion(true).build();
	}

	/**
	 * @description Reads a call back from the database.
	 *
	 * @param callId The Id of the call.
	 *
	 * @return The call.
	 */
	private static ApiCall__c readCall(Id callId)
	{
		return (ApiCall__c)new SEL_ApiCall().findById(callId);
	}

	/**
	 * @description Sets the API setting every read of the settings returns: the setting of the test service, with
	 * issue logging on or off.
	 *
	 * @param logsIssues Whether the service logs issues.
	 */
	private static void registerApiSetting(Boolean logsIssues)
	{
		TST_Mock.of(ApiSetting__mdt.SObjectType)
				.withOverride(ApiSetting__mdt.ClassName__c, SERVICE_NAME)
				.withOverride(ApiSetting__mdt.LogIssues__c, logsIssues)
				.build();
	}

	/**
	 * @description Sets a running background job as the answer to every read of the background jobs.
	 *
	 * @param createdDate The time the job was created.
	 */
	private static void registerLiveJob(Datetime createdDate)
	{
		TST_Mock.of(AsyncApexJob.SObjectType)
				.withOverride(AsyncApexJob.Status, SEL_AsyncApexJob.AsyncApexJobStatus.Processing.name())
				.withOverride(AsyncApexJob.CreatedDate, createdDate)
				.build();
	}

	/**
	 * @description Makes the trigger framework run one action on API calls in this test: RefuseCallUpdateAction, before
	 * an update. Call it before the first save of the test, because the framework reads its actions once per test. The
	 * framework then runs no other action in the test, on any object.
	 */
	private static void registerCallUpdateRefusal()
	{
		String objectName = TRG_Base.resolveSObjectName(new List<SObject> {new ApiCall__c()}, null);
		TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(objectName, new Map<SObjectField, Object> {TriggerSetting__mdt.ObjectApiNameOverride__c => objectName});
		TriggerAction__mdt refusal = TST_Factory.newTriggerActionForContext(RefuseCallUpdateAction.class.getName(), setting, TriggerOperation.BEFORE_UPDATE);
		TST_Mock.register(TriggerSetting__mdt.SObjectType, TST_Factory.newTriggerSettingWithActions(setting, new List<TriggerAction__mdt> {refusal}));
	}

	/**
	 * @description Checks that a call waits at Retry with a new retry time, the given number of minutes from now, and
	 * that its retry count and error text did not change.
	 *
	 * @param call The call as read after the run.
	 * @param expectedWaitMinutes The wait the call should have, from now.
	 */
	private static void assertRetryTimeMovedForward(ApiCall__c call, Integer expectedWaitMinutes)
	{
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, call.Status__c, 'Expected the call to stay at Retry: ' + call.Id);
		Assert.isNotNull(call.NextRetry__c, 'Expected the call to have a retry time: ' + call.Id);
		Long expectedTime = Datetime.now().addMinutes(expectedWaitMinutes).getTime();
		Assert.isTrue
				(
						Math.abs(call.NextRetry__c.getTime() - expectedTime) <= ONE_MINUTE_IN_MILLISECONDS,
						'Expected the retry time to be ' + expectedWaitMinutes + ' minutes from now, got ' + call.NextRetry__c
				);
		Assert.areEqual(RETRIES_SO_FAR, call.Retries__c, 'Expected the retry count not to change, because nothing was sent.');
		Assert.areEqual(EARLIER_ERROR, call.ErrorMessages__c, 'Expected the error text not to change.');
	}

	/**
	 * @description Checks that a call was marked Failed because no job finished sending it: no retry time, the same
	 * retry count, and the error text that gives the hours it waited.
	 *
	 * @param callId The Id of the call.
	 * @param expectedHours The whole hours the call waited after its retry was due.
	 *
	 * @return The call as read after the run.
	 */
	private static ApiCall__c assertMarkedLost(Id callId, Integer expectedHours)
	{
		ApiCall__c call = readCall(callId);
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, call.Status__c, 'Expected the call to be marked Failed.');
		Assert.isNull(call.NextRetry__c, 'Expected the call to have no retry time.');
		Assert.areEqual(RETRIES_SO_FAR, call.Retries__c, 'Expected the retry count not to change.');
		Assert.areEqual
				(
						String.format(System.Label.OutboundRetryWatchdog_LostJob, new List<Object> {expectedHours}),
						call.ErrorMessages__c,
						'Expected the error text to say the request may have been sent.'
				);
		return call;
	}

	/**
	 * @description Checks that the watchdog wrote exactly one log entry, at the given level, with the given text, for
	 * the given call.
	 *
	 * @param level The level the entry should have.
	 * @param message The text the entry should have.
	 * @param callId The call the entry should name.
	 */
	private static void assertOneEntry(LoggingLevel level, String message, Id callId)
	{
		List<LogEntry__c> entries = findWatchdogEntries();
		Assert.areEqual(1, entries.size(), 'Expected one log entry, got ' + entries);
		Assert.areEqual(level.name(), entries[0].LogLevel__c, 'Expected the entry at level ' + level.name());
		Assert.areEqual(message, entries[0].Message__c, 'Expected the text of the entry.');
		Assert.areEqual(callId, entries[0].RecordId__c, 'Expected the entry to name the call.');
	}

	/**
	 * @description Builds the warning text written when the retry time of a call was moved forward.
	 *
	 * @param before The call as it was saved before the run.
	 * @param after The call as read after the run.
	 *
	 * @return The expected warning text.
	 */
	private static String formatMovedMessage(ApiCall__c before, ApiCall__c after)
	{
		return String.format(System.Label.OutboundRetryWatchdog_RetryTimeMoved,
				new List<Object> {UTIL_Date.toIso8601(before.NextRetry__c), UTIL_Date.toIso8601(after.NextRetry__c)});
	}

	/**
	 * @description Reads the log entries the watchdog wrote.
	 *
	 * @return The entries.
	 */
	private static List<LogEntry__c> findWatchdogEntries()
	{
		return new SEL_LogEntry().findAllByMethod(SCHED_OutboundRetryWatchdog.LOG_LOCATION);
	}

	/**
	 * @description A trigger action used only in this test. Before an update of API calls, it refuses the change of
	 * each call whose Id is in REFUSED_CALL_IDS, as a validation rule would, so the save refuses a call that exists.
	 */
	public class RefuseCallUpdateAction implements IF_Trigger.BeforeUpdate
	{
		/**
		 * @description Puts an error on each call whose change this test refuses.
		 *
		 * @param newRecords The calls with their new values.
		 * @param oldRecords The calls as they were before the update; not read.
		 */
		public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
		{
			for(SObject record : newRecords)
			{
				if(REFUSED_CALL_IDS.contains(record.Id))
				{
					record.addError(REFUSAL_MESSAGE);
				}
			}
		}
	}
}
