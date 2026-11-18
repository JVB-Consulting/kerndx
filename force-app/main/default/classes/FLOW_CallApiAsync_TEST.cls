// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class to check behavior of FLOW_CallApiAsync
 *
 * @see FLOW_CallApiAsync
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=false)
private class FLOW_CallApiAsync_TEST
{
	/**
	 * @description The message Salesforce gives when a test starts a job from inside a running job, as the error text
	 * of a call gives it. It is the reason the refused start is given in these tests. Salesforce ends the message with a
	 * full stop; the error text leaves that full stop out, because the text puts its own full stop after the reason.
	 */
	private static final String STACK_DEPTH_REASON = 'Maximum stack depth has been reached';

	/**
	 * @description The message Salesforce gives when it refuses a job at the 24-hour limit. It ends with a full stop.
	 */
	private static final String LIMIT_REFUSED_MESSAGE = 'Rate Limiting Exception : AsyncApexExecutions Limit exceeded.';

	/**
	 * @description The same message as the error text of a call gives it: without its last full stop.
	 */
	private static final String LIMIT_REFUSED_REASON = 'Rate Limiting Exception : AsyncApexExecutions Limit exceeded';

	/**
	 * @description Two full stops in a row, which the error text of a call must never hold.
	 */
	private static final String DOUBLE_FULL_STOP = '..';

	/**
	 * @description The number of times a call at Retry was already tried before the refused start.
	 */
	private static final Integer RETRIES_BEFORE_REFUSAL = 1;

	/**
	 * @description How far, in milliseconds, a new retry time may be from the expected time.
	 */
	private static final Long ONE_MINUTE_IN_MILLISECONDS = 60000;

	/**
	 * @description The message of the error handed to the method that schedules refused calls.
	 */
	private static final String REFUSED_MESSAGE = 'refused';

	/**
	 * @description The number of calls handed to the launcher in the partly refused test.
	 */
	private static final Integer PARTLY_REFUSED_CALL_COUNT = 4;

	/**
	 * @description The position of the first call that was not started in the partly refused test.
	 */
	private static final Integer FIRST_UNSENT_POSITION = 2;

	/**
	 * @description A wait of 15 minutes: the shortest wait, and the first step of the doubling.
	 */
	private static final Integer FIFTEEN_MINUTES = 15;

	/**
	 * @description A wait of 30 minutes.
	 */
	private static final Integer THIRTY_MINUTES = 30;

	/**
	 * @description A wait of 60 minutes.
	 */
	private static final Integer SIXTY_MINUTES = 60;

	/**
	 * @description A wait of 120 minutes.
	 */
	private static final Integer ONE_HUNDRED_TWENTY_MINUTES = 120;

	/**
	 * @description A wait of 240 minutes: the longest wait.
	 */
	private static final Integer TWO_HUNDRED_FORTY_MINUTES = 240;

	/**
	 * @description A NextRetry__c ten minutes before the last save: a wait that cannot be read.
	 */
	private static final Integer TEN_MINUTES_EARLIER = -10;

	/**
	 * @description The retry count of a call that was never tried.
	 */
	private static final Integer NO_RETRIES = 0;

	/**
	 * @description The number of calls in a refusal that names one saved call and one call that is not saved yet.
	 */
	private static final Integer SAVED_AND_UNSAVED_CALL_COUNT = 2;

	/**
	 * @description The number of calls that are not saved yet in a refusal that names only such calls.
	 */
	private static final Integer UNSAVED_CALL_COUNT = 3;

	/**
	 * @description A service name length one longer than the 100 characters the service name field holds, so the database
	 * refuses to save the call.
	 */
	private static final Integer TOO_LONG_SERVICE_NAME_LENGTH = 101;

	/**
	 * @description The number of times the same saved call is handed to the action in one list.
	 */
	private static final Integer TIMES_GIVEN = 2;

	/**
	 * @description Verifies the default job size stays within the callout governor limit.
	 */
	@IsTest
	private static void shouldDefaultJobSizeWithinCalloutLimit()
	{
		Assert.isTrue(
				FLOW_CallApiAsync.DEFAULT_JOB_SIZE <= FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE,
				'Default job size must not exceed MAXIMUM_CALLOUT_JOB_SIZE'
		);
	}

	/**
	 * @description Verifies MAXIMUM_CALLOUT_JOB_SIZE equals the Salesforce governor limit for callouts per transaction.
	 */
	@IsTest
	private static void shouldMaximumCalloutJobSizeMatchGovernorLimit()
	{
		Assert.areEqual(
				UTIL_Limits.callouts().maximum(),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE,
				'MAXIMUM_CALLOUT_JOB_SIZE should equal the governor callout limit'
		);
	}

	/**
	 * @description Verifies a metadata override above 100 is capped at MAXIMUM_CALLOUT_JOB_SIZE.
	 */
	@IsTest
	private static void shouldCapMetadataOverrideAtCalloutLimit()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 150);

		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		Assert.areEqual(FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE, jobSize, 'Job size of 150 should be capped at callout limit');
	}

	/**
	 * @description Verifies a metadata override below the callout limit is used as-is.
	 */
	@IsTest
	private static void shouldAllowMetadataOverrideBelowCalloutLimit()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 50);

		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		Assert.areEqual(50, jobSize, 'Job size of 50 should be used as-is');
	}

	/**
	 * @description Verifies a metadata override at exactly 100 is accepted without capping.
	 */
	@IsTest
	private static void shouldAcceptJobSizeAtExactCalloutLimit()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 100);

		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		Assert.areEqual(100, jobSize, 'Job size at exactly the callout limit should be accepted');
	}

	/**
	 * @description Verifies the job size can be overridden via AsynchronousJobSetting__mdt.
	 */
	@IsTest
	private static void shouldReadJobSizeFromMetadata()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 15);

		Integer jobSize = SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE);

		Assert.areEqual(15, jobSize, 'Should read job size from AsynchronousJobSetting__mdt');
	}

	/**
	 * @description Verifies that items are chunked across multiple Queueable jobs when the job size
	 * is smaller than the total item count. Five items with a job size of 2 should produce 3 Queueables.
	 */
	@IsTest
	private static void shouldChunkItemsAcrossMultipleQueueables()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 2);

		insertOutboundCalls(SEL_ApiCall.STATUS_BATCHED, 3);

		Test.startTest();

		FLOW_CallApiAsync.invokeApiCallAsynchronously(new SEL_ApiCall().findByBatchedOutbound());

		Assert.areEqual(2, UTIL_Limits.queueableJobs().used(), 'Three items with job size 2 should produce 2 Queueable jobs');

		Test.stopTest();
	}

	/**
	 * @description Will check that any batched APIs are run via a Queueable job
	 *
	 * @see FLOW_CallApiAsync.invokeApiCallAsynchronously
	 */
	@IsTest
	private static void runQueueable()
	{
		insertBatchedCall();

		Test.startTest();

		FLOW_CallApiAsync.invokeApiCallAsynchronously(new SEL_ApiCall().findByBatchedOutbound());

		Assert.areEqual(1, UTIL_Limits.queueableJobs().used(), 'Expected a Queueable job to have run');

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(API_PostExample.class.getName());
	}

	/**
	 * @description A call at Retry that last waited 15 minutes and is refused again waits 30 minutes. It stays at Retry
	 * with a new time, its Retries__c does not change, the error text says why, no API issue is raised, and one warning
	 * counts it. This is the first step of the doubling, from the shortest wait.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldWaitThirtyMinutesWhenTheLastWaitWasFifteen()
	{
		assertRefusedRetryCallWaits(FIFTEEN_MINUTES, THIRTY_MINUTES);
	}

	/**
	 * @description A call at Retry that last waited 30 minutes and is refused again waits 60 minutes.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldWaitSixtyMinutesWhenTheLastWaitWasThirty()
	{
		assertRefusedRetryCallWaits(THIRTY_MINUTES, SIXTY_MINUTES);
	}

	/**
	 * @description A call at Retry that last waited 60 minutes and is refused again waits 120 minutes.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldWaitOneHundredTwentyMinutesWhenTheLastWaitWasSixty()
	{
		assertRefusedRetryCallWaits(SIXTY_MINUTES, ONE_HUNDRED_TWENTY_MINUTES);
	}

	/**
	 * @description A call at Retry that last waited 120 minutes and is refused again waits 240 minutes.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldWaitTwoHundredFortyMinutesWhenTheLastWaitWasOneHundredTwenty()
	{
		assertRefusedRetryCallWaits(ONE_HUNDRED_TWENTY_MINUTES, TWO_HUNDRED_FORTY_MINUTES);
	}

	/**
	 * @description A call at Retry that last waited 240 minutes and is refused again waits 240 minutes, not 480: the
	 * wait never grows past the longest wait.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldKeepTheWaitAtTwoHundredFortyMinutesWhenTheLastWaitWasTwoHundredForty()
	{
		assertRefusedRetryCallWaits(TWO_HUNDRED_FORTY_MINUTES, TWO_HUNDRED_FORTY_MINUTES);
	}

	/**
	 * @description A Queued call whose send Salesforce refuses to start waits 15 minutes at Retry, the shortest wait,
	 * because it was not waiting before. The call is handed to the action from inside a running job, so the start is
	 * refused, and the action does not fail.
	 */
	@IsTest
	private static void shouldWaitFifteenMinutesWhenAQueuedCallIsRefused()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c queuedCall = insertBatchedCall();
		queuedCall.Status__c = SEL_ApiCall.STATUS_QUEUED;

		runActionInsideARunningJob(new List<ApiCall__c> {queuedCall});

		ApiCall__c call = SEL_ApiCall.assertServiceRetrying(API_PostExample.class.getName())[0];
		assertWaitingAfterRefusal(call, FIFTEEN_MINUTES, NO_RETRIES);
		Assert.areEqual(0, new SEL_ApiIssue().count(), 'Expected no API issue for a request that was never sent.');
		assertOneWarning(1, 0);
	}

	/**
	 * @description When Salesforce refuses to start the send, the action saves the call at Retry and writes its own
	 * warning. The action tells the launcher that it handles a refused start, so no error log entry is written for it.
	 *
	 * The call is handed to the action from inside a running job, so the start is refused.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldWriteNoErrorEntryForARefusalTheCallerHandles()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c queuedCall = insertBatchedCall();
		queuedCall.Status__c = SEL_ApiCall.STATUS_QUEUED;

		runActionInsideARunningJob(new List<ApiCall__c> {queuedCall});

		assertOneWarning(1, 0);
		assertNoErrorEntry();
	}

	/**
	 * @description One direct call of the action with calls at Retry and at Queued, refused to start. Each call at Retry
	 * waits twice its last wait, and each call at Queued waits 15 minutes. A subscriber can call the action like this.
	 */
	@IsTest
	private static void shouldWaitByStatusWhenOneLaunchMixesQueuedAndRetryCalls()
	{
		LOG_Builder.ignoreTestMode = true;
		Datetime lastSave = Datetime.now();
		ApiCall__c retryCall = insertRetryCall(lastSave, THIRTY_MINUTES);
		ApiCall__c queuedCall = insertBatchedCall();
		queuedCall.Status__c = SEL_ApiCall.STATUS_QUEUED;
		runActionInsideARunningJob(new List<ApiCall__c> {withLastSave(retryCall, lastSave), queuedCall});

		assertWaitingAfterRefusal((ApiCall__c)new SEL_ApiCall().findById(retryCall.Id), SIXTY_MINUTES, RETRIES_BEFORE_REFUSAL);
		ApiCall__c earliestCall = (ApiCall__c)new SEL_ApiCall().findById(queuedCall.Id);
		assertWaitingAfterRefusal(earliestCall, FIFTEEN_MINUTES, NO_RETRIES);
		LogEntry__c warning = assertOneWarning(2, 0);
		Assert.isTrue
				(
						warning.Message__c.contains(UTIL_Date.toIso8601(earliestCall.NextRetry__c)),
						'Expected the warning text to give the earliest retry time as ISO 8601 text.'
				);
	}

	/**
	 * @description A call at Retry whose last wait cannot be read waits 15 minutes: a NextRetry__c that is empty, one
	 * that is before the last save, and a call given without its last save time. An administrator's edit or a call a
	 * subscriber built can leave a call like this.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldStartTheLadderWhenTheLastWaitCannotBeRead()
	{
		LOG_Builder.ignoreTestMode = true;
		Datetime lastSave = Datetime.now();
		ApiCall__c callWithoutTime = insertRetryCall(lastSave, null);
		ApiCall__c callWithEarlierTime = insertRetryCall(lastSave, TEN_MINUTES_EARLIER);
		ApiCall__c callWithoutLastSave = insertRetryCall(lastSave, SIXTY_MINUTES);
		runActionInsideARunningJob(new List<ApiCall__c> {withLastSave(callWithoutTime, lastSave), withLastSave(callWithEarlierTime, lastSave), callWithoutLastSave});

		for(SObject call : new SEL_ApiCall().findById(new Set<Id> {callWithoutTime.Id, callWithEarlierTime.Id, callWithoutLastSave.Id}))
		{
			assertWaitingAfterRefusal((ApiCall__c)call, FIFTEEN_MINUTES, RETRIES_BEFORE_REFUSAL);
		}
		assertOneWarning(3, 0);
	}

	/**
	 * @description A refusal that names no call changes no call and writes one warning. Salesforce refuses the start
	 * of a job for an empty list from inside a running job, so the refusal names nothing.
	 */
	@IsTest
	private static void shouldChangeNothingWhenTheRefusalNamesNoCall()
	{
		LOG_Builder.ignoreTestMode = true;
		runActionInsideARunningJob(new List<ApiCall__c>());

		LogEntry__c warning = assertOneWarning(0, 0);
		Assert.isNull(SEL_LogEntry.parseContextDataForTest(warning).get(FLOW_CallApiAsync.CONTEXT_FIRST_WAITING_CALL_ID), 'Expected no waiting call to be named.');
		Assert.areEqual(0, new SEL_ApiCall().count(), 'Expected no call to be written.');
	}

	/**
	 * @description A call at Retry is saved at Retrying before its job starts, so the Retry Outbound Api Call flow does
	 * not pick it up again. After the job has run, the call carries the outcome of the send.
	 */
	@IsTest
	private static void shouldWriteRetryingBeforeTheLaunch()
	{
		API_MockFactory.forService(API_PostExample.class.getName()).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		Datetime lastSave = Datetime.now();
		ApiCall__c retryCall = insertRetryCall(lastSave, FIFTEEN_MINUTES);

		Test.startTest();

		FLOW_CallApiAsync.invokeApiCallAsynchronously(new List<ApiCall__c> {withLastSave(retryCall, lastSave)});

		ApiCall__c beforeTheSend = (ApiCall__c)new SEL_ApiCall().findById(retryCall.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_RETRYING, beforeTheSend.Status__c, 'Expected the call to be at Retrying before its job runs.');

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(API_PostExample.class.getName());
	}

	/**
	 * @description A call at Queued is not changed before its job starts. The call is saved at Queued, so the Invoke
	 * Outbound Api Call flow hands it to the action. Only calls at Retry are saved at Retrying.
	 */
	@IsTest
	private static void shouldLeaveQueuedCallsAtQueuedBeforeTheLaunch()
	{
		Test.startTest();

		ApiCall__c queuedCall = insertQueuedCall();

		ApiCall__c beforeTheSend = (ApiCall__c)new SEL_ApiCall().findById(queuedCall.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_QUEUED, beforeTheSend.Status__c, 'Expected the call to stay at Queued before its job runs.');
		Assert.areEqual(1, UTIL_Limits.queueableJobs().used(), 'Expected the flow to have started one job for the call.');

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(API_PostExample.class.getName());
	}

	/**
	 * @description When Salesforce started the jobs of the first calls and refused the rest, only the calls that were
	 * not started wait at Retry. The calls that were started are left to their jobs, so their request is never sent
	 * twice. The refusal is built by hand, because the action always starts its jobs the same way and cannot be made
	 * to start only some of them.
	 */
	@IsTest
	private static void shouldScheduleOnlyTheCallsThatWereNotStarted()
	{
		LOG_Builder.ignoreTestMode = true;
		List<ApiCall__c> calls = new List<ApiCall__c>();
		List<Object> unsentCalls = new List<Object>();
		for(Integer index = 0; index < PARTLY_REFUSED_CALL_COUNT; index++)
		{
			ApiCall__c call = insertBatchedCall();
			calls.add(call);
			if(index >= FIRST_UNSENT_POSITION)
			{
				unsentCalls.add(call);
			}
		}
		UTIL_Exceptions.LaunchRefusedException refused = new UTIL_Exceptions.LaunchRefusedException(new RefusedException(REFUSED_MESSAGE), unsentCalls);

		Test.startTest();
		FLOW_CallApiAsync.scheduleRefusedCallsForRetry(calls, refused);
		Test.stopTest();
		Test.getEventBus().deliver();

		for(Integer index = 0; index < PARTLY_REFUSED_CALL_COUNT; index++)
		{
			ApiCall__c call = (ApiCall__c)new SEL_ApiCall().findById(calls[index].Id);
			if(index < FIRST_UNSENT_POSITION)
			{
				Assert.areEqual(SEL_ApiCall.STATUS_BATCHED, call.Status__c, 'Expected a started call to be left alone, at position ' + index);
				Assert.isNull(call.NextRetry__c, 'Expected a started call to get no retry time, at position ' + index);
			}
			else
			{
				assertWaitingAfterRefusal(call, FIFTEEN_MINUTES, NO_RETRIES, REFUSED_MESSAGE);
			}
		}
		LogEntry__c warning = assertOneWarning(PARTLY_REFUSED_CALL_COUNT - FIRST_UNSENT_POSITION, FIRST_UNSENT_POSITION, RefusedException.class.getName());
		Assert.areEqual
				(
						String.valueOf(calls[FIRST_UNSENT_POSITION].Id),
						String.valueOf(SEL_LogEntry.parseContextDataForTest(warning).get(FLOW_CallApiAsync.CONTEXT_FIRST_WAITING_CALL_ID)),
						'Expected the warning to name the first call that waits.'
				);
	}

	/**
	 * @description A refused call that was not saved yet, and not at Retry, is saved as a new call at Retry. Its retry
	 * time is 15 minutes on and its error text gives the reason, so it is still sent later. A subscriber can hand the
	 * action calls that are not saved yet.
	 *
	 * The new call keeps the fields it was given: the direction, the triggering record, the request parameters and the
	 * retry count. The saved call of the same refusal also waits at Retry. The calls are handed to the action from inside
	 * a running job, so Salesforce refuses the start.
	 */
	@IsTest
	private static void shouldSaveAnUnsavedCallAtRetryWhenTheStartIsRefused()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c savedCall = insertBatchedCall();
		ApiCall__c unsavedCall = buildUnsavedCall(SEL_ApiCall.STATUS_BATCHED);

		runActionInsideARunningJob(new List<ApiCall__c> {unsavedCall, savedCall});

		List<ApiCall__c> waitingCalls = SEL_ApiCall.assertServiceRetrying(API_PostExample.class.getName());
		Assert.areEqual(SAVED_AND_UNSAVED_CALL_COUNT, waitingCalls.size(), 'Expected the saved call and a new call for the unsaved one to wait at Retry.');
		ApiCall__c newCall;
		Boolean savedCallFound = false;
		for(ApiCall__c call : waitingCalls)
		{
			if(call.Id == savedCall.Id)
			{
				savedCallFound = true;
				assertWaitingAfterRefusal(call, FIFTEEN_MINUTES, NO_RETRIES);
			}
			else
			{
				newCall = call;
			}
		}
		Assert.isTrue(savedCallFound, 'Expected the saved call to wait at Retry, not a copy of it.');
		assertWaitingAfterRefusal(newCall, FIFTEEN_MINUTES, RETRIES_BEFORE_REFUSAL);
		Assert.areEqual(SEL_ApiCall.TYPE_OUTBOUND, newCall.Direction__c, 'Expected the new call to be outbound, so the Retry Outbound Api Call flow sends it.');
		Assert.areEqual(UserInfo.getUserId(), newCall.TriggeringRecordId__c, 'Expected the new call to keep the triggering record it was given.');
		Assert.areEqual(unsavedCall.RequestParameters__c, newCall.RequestParameters__c, 'Expected the new call to keep the request parameters it was given.');
		Assert.areEqual(0, new SEL_ApiIssue().count(), 'Expected no API issue for a request that was never sent.');
		assertOneWarning(SAVED_AND_UNSAVED_CALL_COUNT, 0);
	}

	/**
	 * @description When every call handed to the action was not saved yet and Salesforce refuses the start, each call is
	 * saved as a new call at Retry. The warning counts the new calls, gives the earliest retry time and names one of the
	 * new calls.
	 *
	 * The calls are given at Retry with no Id. A call with no Id is left out of the save that marks calls as Retrying, so
	 * no save fails. No error log entry is written at all: not for a save, and not for the refused start, which the
	 * action handles.
	 *
	 * The calls are handed to the action from inside a running job, so Salesforce refuses the start.
	 */
	@IsTest
	private static void shouldCountTheUnsavedCallsInTheWaitingWarning()
	{
		LOG_Builder.ignoreTestMode = true;
		List<ApiCall__c> unsavedCalls = new List<ApiCall__c>();
		for(Integer index = 0; index < UNSAVED_CALL_COUNT; index++)
		{
			unsavedCalls.add(buildUnsavedCall(SEL_ApiCall.STATUS_RETRY));
		}

		runActionInsideARunningJob(unsavedCalls);

		List<ApiCall__c> waitingCalls = SEL_ApiCall.assertServiceRetrying(API_PostExample.class.getName());
		Assert.areEqual(UNSAVED_CALL_COUNT, waitingCalls.size(), 'Expected a new call at Retry for each unsaved call, and no other call.');
		Datetime earliestNextRetry;
		for(ApiCall__c call : waitingCalls)
		{
			assertWaitingAfterRefusal(call, FIFTEEN_MINUTES, RETRIES_BEFORE_REFUSAL);
			earliestNextRetry = earliestNextRetry == null || call.NextRetry__c < earliestNextRetry ? call.NextRetry__c : earliestNextRetry;
		}
		LogEntry__c warning = assertOneWarning(UNSAVED_CALL_COUNT, 0);
		assertNoErrorEntry();
		Assert.isTrue
				(
						warning.Message__c.contains(UTIL_Date.toIso8601(earliestNextRetry)),
						'Expected the warning text to give the earliest retry time as ISO 8601 text: ' + warning.Message__c
				);
		Set<Id> waitingCallIds = new Map<Id, ApiCall__c>(waitingCalls).keySet();
		Object firstWaitingCallId = SEL_LogEntry.parseContextDataForTest(warning).get(FLOW_CallApiAsync.CONTEXT_FIRST_WAITING_CALL_ID);
		Assert.isTrue(waitingCallIds.contains((Id)firstWaitingCallId), 'Expected the warning to name one of the new calls, got ' + firstWaitingCallId);
	}

	/**
	 * @description Salesforce's reason for a refused start often ends with a full stop, as the message for the 24-hour
	 * limit does. The error text of the call puts its own full stop after the reason, so the reason's full stop is left
	 * out and the text never holds two full stops in a row.
	 */
	@IsTest
	private static void shouldLeaveOutTheFullStopThatEndsTheReason()
	{
		ApiCall__c call = insertBatchedCall();
		UTIL_Exceptions.LaunchRefusedException refused =
				new UTIL_Exceptions.LaunchRefusedException(new RefusedException(LIMIT_REFUSED_MESSAGE), new List<Object> {call});

		Test.startTest();
		FLOW_CallApiAsync.scheduleRefusedCallsForRetry(new List<ApiCall__c> {call}, refused);
		Test.stopTest();

		ApiCall__c waitingCall = (ApiCall__c)new SEL_ApiCall().findById(call.Id);
		assertWaitingAfterRefusal(waitingCall, FIFTEEN_MINUTES, NO_RETRIES, LIMIT_REFUSED_REASON);
		Assert.isFalse(waitingCall.ErrorMessages__c.contains(DOUBLE_FULL_STOP), 'Expected no two full stops in a row in the error text: ' + waitingCall.ErrorMessages__c);
	}

	/**
	 * @description A call at Retry that the running user cannot edit is still saved at Retrying before its job starts.
	 * API calls are Private, so a Standard User with no permission set cannot edit a call another user saved. The Retry
	 * Outbound Api Call flow can run as such a user, so the save must ignore record sharing. The status is read before
	 * the job runs, because the job writes the outcome of the send.
	 */
	@IsTest
	private static void shouldMarkRetryingACallTheRunningUserCannotEdit()
	{
		API_MockFactory.forService(API_PostExample.class.getName()).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		User runningUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		Datetime lastSave = Datetime.now();
		ApiCall__c retryCall = insertRetryCall(lastSave, FIFTEEN_MINUTES);

		Test.startTest();

		System.runAs(runningUser)
		{
			FLOW_CallApiAsync.invokeApiCallAsynchronously(new List<ApiCall__c> {withLastSave(retryCall, lastSave)});
		}

		ApiCall__c beforeTheSend = (ApiCall__c)new SEL_ApiCall().findById(retryCall.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_RETRYING, beforeTheSend.Status__c, 'Expected the call to be at Retrying before its job runs, though the user cannot edit it.');

		Test.stopTest();
	}

	/**
	 * @description A call that the running user cannot edit, and whose send Salesforce refuses to start, still waits at
	 * Retry with a retry time, and the warning counts it. API calls are Private, so a Standard User with no permission
	 * set cannot edit a call another user saved. The call is handed to the action from inside a running job, so the start
	 * is refused.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldScheduleARefusedCallTheRunningUserCannotEdit()
	{
		LOG_Builder.ignoreTestMode = true;
		User runningUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		ApiCall__c queuedCall = insertBatchedCall();
		queuedCall.Status__c = SEL_ApiCall.STATUS_QUEUED;

		System.runAs(runningUser)
		{
			runActionInsideARunningJob(new List<ApiCall__c> {queuedCall});
		}

		ApiCall__c call = SEL_ApiCall.assertServiceRetrying(API_PostExample.class.getName())[0];
		assertWaitingAfterRefusal(call, FIFTEEN_MINUTES, NO_RETRIES);
		assertOneWarning(1, 0);
	}

	/**
	 * @description A call at Retry whose save to Retrying is refused is not sent. It still shows Retry, so sending it
	 * could send it twice. The refusal is real: the call is not in the database, so the database refuses its save. The
	 * other call at Retry is sent, and its start is refused, so it waits at Retry.
	 *
	 * Only the call that was saved at Retrying reaches the launcher, so the warning about the refused start counts one
	 * call that was not sent, not two. A second warning names the call that was left out. Only one error log entry is
	 * written: the one for the refused save to Retrying.
	 */
	@IsTest
	private static void shouldNotSendACallWhoseRetryingSaveWasRefused()
	{
		LOG_Builder.ignoreTestMode = true;
		Datetime lastSave = Datetime.now();
		ApiCall__c callNotInTheDatabase = buildCallNotInTheDatabase(SEL_ApiCall.STATUS_RETRY);
		ApiCall__c retryCall = insertRetryCall(lastSave, FIFTEEN_MINUTES);

		runActionInsideARunningJob(new List<ApiCall__c> {callNotInTheDatabase, withLastSave(retryCall, lastSave)});

		assertWaitingAfterRefusal((ApiCall__c)new SEL_ApiCall().findById(retryCall.Id), THIRTY_MINUTES, RETRIES_BEFORE_REFUSAL);
		LogEntry__c warning = assertOneWarning(1, 0);
		Assert.areEqual
				(
						String.valueOf(1),
						String.valueOf(SEL_LogEntry.parseContextDataForTest(warning).get(FLOW_CallApiAsync.CONTEXT_UNSENT_CALL_COUNT)),
						'Expected only the call saved at Retrying to reach the launcher, so one call was not sent.'
				);
		assertNotSentWarning(callNotInTheDatabase.Id);
		List<LogEntry__c> errorEntries = new SEL_LogEntry().findByLogLevel(LoggingLevel.ERROR.name());
		Assert.areEqual(1, errorEntries.size(), 'Expected one error entry, for the refused save to Retrying only, got ' + errorEntries);
	}

	/**
	 * @description When calls are given and the save to Retrying is refused for every one of them, no call is left to
	 * send, so no job is started and no warning about a refused start is written. The one warning names the call that
	 * was left out.
	 *
	 * The call is not in the database, so the database refuses its save. The action runs inside a running job, where
	 * any start would be refused and logged.
	 */
	@IsTest
	private static void shouldStartNoJobWhenEveryRetryingSaveWasRefused()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c callNotInTheDatabase = buildCallNotInTheDatabase(SEL_ApiCall.STATUS_RETRY);

		runActionInsideARunningJob(new List<ApiCall__c> {callNotInTheDatabase});

		List<LogEntry__c> warnings = findWarningsWithContextKey(FLOW_CallApiAsync.CONTEXT_WAITING_CALL_COUNT);
		Assert.isTrue(warnings.isEmpty(), 'Expected no job start, so no warning about a refused start, got ' + warnings);
		assertNotSentWarning(callNotInTheDatabase.Id);
	}

	/**
	 * @description A call at Retry given twice in one list is saved at Retrying once, and the action does not fail. A
	 * subscriber can hand the action the same call twice.
	 */
	@IsTest
	private static void shouldMarkACallGivenTwiceAsRetrying()
	{
		API_MockFactory.forService(API_PostExample.class.getName()).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		Datetime lastSave = Datetime.now();
		ApiCall__c givenCall = withLastSave(insertRetryCall(lastSave, FIFTEEN_MINUTES), lastSave);

		Test.startTest();

		FLOW_CallApiAsync.invokeApiCallAsynchronously(new List<ApiCall__c> {givenCall, givenCall});

		ApiCall__c beforeTheSend = (ApiCall__c)new SEL_ApiCall().findById(givenCall.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_RETRYING, beforeTheSend.Status__c, 'Expected the call given twice to be at Retrying before its job runs.');

		Test.stopTest();
	}

	/**
	 * @description A call whose save at Retry is refused is not counted as waiting, and the warning lists its Id. The
	 * refusal is real: the call is not in the database, so the database refuses its save. The other call is saved at
	 * Retry. The warning counts that call as the one waiting call, out of the two calls that were not sent, and names it
	 * as the first waiting call. The refused save writes an error log entry.
	 *
	 * The calls are handed to the action from inside a running job, so Salesforce refuses the start.
	 */
	@IsTest
	private static void shouldLeaveACallTheSaveRefusedOutOfTheWaitingWarning()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c callNotInTheDatabase = buildCallNotInTheDatabase(SEL_ApiCall.STATUS_BATCHED);
		ApiCall__c savedCall = insertBatchedCall();
		savedCall.Status__c = SEL_ApiCall.STATUS_QUEUED;

		runActionInsideARunningJob(new List<ApiCall__c> {callNotInTheDatabase, savedCall});

		assertWaitingAfterRefusal((ApiCall__c)new SEL_ApiCall().findById(savedCall.Id), FIFTEEN_MINUTES, NO_RETRIES);
		LogEntry__c warning = assertOneWarning(1, 0);
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warning);
		Assert.areEqual
				(
						String.valueOf(savedCall.Id),
						String.valueOf(context.get(FLOW_CallApiAsync.CONTEXT_FIRST_WAITING_CALL_ID)),
						'Expected the first waiting call to be the saved call, not the refused one.'
				);
		Assert.areEqual(String.valueOf(SAVED_AND_UNSAVED_CALL_COUNT), String.valueOf(context.get(FLOW_CallApiAsync.CONTEXT_UNSENT_CALL_COUNT)), 'Expected two calls not sent.');
		Assert.areEqual
				(
						String.valueOf(callNotInTheDatabase.Id),
						String.valueOf(context.get(FLOW_CallApiAsync.CONTEXT_NOT_SAVED_CALL_IDS)),
						'Expected the warning to name the call whose save at Retry was refused.'
				);
		Assert.isFalse(new SEL_LogEntry().findByLogLevel(LoggingLevel.ERROR.name()).isEmpty(), 'Expected an error entry for the refused save.');
	}

	/**
	 * @description When the save at Retry is refused for every call that was not started, the warning counts no waiting
	 * call and gives no retry time. The refusal is real: the call is not in the database, so the database refuses its
	 * save, and the save writes an error log entry.
	 *
	 * The call is handed to the action from inside a running job, so
	 * Salesforce refuses the start.
	 */
	@IsTest
	private static void shouldCountNoWaitingCallWhenEverySaveWasRefused()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c callNotInTheDatabase = buildCallNotInTheDatabase(SEL_ApiCall.STATUS_BATCHED);

		runActionInsideARunningJob(new List<ApiCall__c> {callNotInTheDatabase});

		LogEntry__c warning = assertOneWarning(0, 0);
		Assert.isNull(SEL_LogEntry.parseContextDataForTest(warning).get(FLOW_CallApiAsync.CONTEXT_FIRST_WAITING_CALL_ID), 'Expected no waiting call to be named.');
		Assert.isFalse(new SEL_LogEntry().findByLogLevel(LoggingLevel.ERROR.name()).isEmpty(), 'Expected an error entry for the refused save.');
	}

	/**
	 * @description A new call that has no Id and whose save is refused for real, because its service name is too long for
	 * the field. The start is refused too. The action returns normally, writes its warning, and names no call that was not
	 * saved, because a call that was never saved has no Id to name.
	 */
	@IsTest
	private static void shouldReturnNormallyWhenTheSaveOfANewCallWasRefused()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c newCall = buildUnsavedCall(SEL_ApiCall.STATUS_BATCHED);
		newCall.ServiceName__c = 'x'.repeat(TOO_LONG_SERVICE_NAME_LENGTH);

		runActionInsideARunningJob(new List<ApiCall__c> {newCall});

		LogEntry__c warning = assertOneWarning(0, 0);
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warning);
		Assert.isTrue(String.isEmpty((String)context.get(FLOW_CallApiAsync.CONTEXT_NOT_SAVED_CALL_IDS)), 'Expected no call to be named, because the new call has no Id.');
		Assert.isFalse(new SEL_LogEntry().findByLogLevel(LoggingLevel.ERROR.name()).isEmpty(), 'Expected an error entry for the refused save.');
	}

	/**
	 * @description The same saved call handed to the action twice, when the start is refused. The action returns normally,
	 * writes its warning, and the call waits at Retry.
	 */
	@IsTest
	private static void shouldReturnNormallyWhenTheSameSavedCallIsGivenTwice()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c savedCall = insertBatchedCall();
		savedCall.Status__c = SEL_ApiCall.STATUS_QUEUED;

		runActionInsideARunningJob(new List<ApiCall__c> {savedCall, savedCall});

		LogEntry__c warning = assertOneWarning(TIMES_GIVEN, 0);
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warning);
		Assert.isTrue(String.isEmpty((String)context.get(FLOW_CallApiAsync.CONTEXT_NOT_SAVED_CALL_IDS)), 'Expected no call to be named, because every save was accepted.');
		assertWaitingAfterRefusal((ApiCall__c)new SEL_ApiCall().findById(savedCall.Id), FIFTEEN_MINUTES, NO_RETRIES);
	}

	/**
	 * @description Finds the warnings the action filed under its own location that carry a given context key. The action
	 * files its warnings under one location, so the key tells them apart.
	 *
	 * @param contextKey The context key the warnings must have.
	 *
	 * @return The warnings with that key.
	 */
	private static List<LogEntry__c> findWarningsWithContextKey(String contextKey)
	{
		List<LogEntry__c> warnings = new List<LogEntry__c>();
		for(LogEntry__c entry : new SEL_LogEntry().findAllByMethod(FLOW_CallApiAsync.LOG_LOCATION))
		{
			if(SEL_LogEntry.parseContextDataForTest(entry).containsKey(contextKey))
			{
				warnings.add(entry);
			}
		}
		return warnings;
	}

	/**
	 * @description Checks that the action wrote one warning that names the one call left out of the send, because its
	 * save to Retrying was refused.
	 *
	 * @param expectedCallId The Id of the call that was left out.
	 */
	private static void assertNotSentWarning(Id expectedCallId)
	{
		List<LogEntry__c> warnings = findWarningsWithContextKey(FLOW_CallApiAsync.CONTEXT_NOT_SENT_CALL_IDS);
		Assert.areEqual(1, warnings.size(), 'Expected one warning about the calls left out of the send, got ' + warnings);
		Assert.areEqual(LoggingLevel.WARN.name(), warnings[0].LogLevel__c, 'Expected the entry to be a warning.');
		Assert.areEqual
				(
						String.valueOf(expectedCallId),
						String.valueOf(SEL_LogEntry.parseContextDataForTest(warnings[0]).get(FLOW_CallApiAsync.CONTEXT_NOT_SENT_CALL_IDS)),
						'Expected the warning to name the call left out of the send.'
				);
		Assert.isTrue(warnings[0].Message__c.contains(expectedCallId), 'Expected the warning text to give the Id of the call left out: ' + warnings[0].Message__c);
	}

	/**
	 * @description Builds an outbound call of the example service that has an Id but is not in the database, so the
	 * database refuses any save of it.
	 *
	 * @param status The status the call is built with.
	 *
	 * @return The call.
	 */
	private static ApiCall__c buildCallNotInTheDatabase(String status)
	{
		return (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withOverrides(buildOutboundCallFields(status)).withoutInsertion(true).build();
	}

	/**
	 * @description Inserts one call at Retry, saves it, and runs the action on it from inside a running job, so the start
	 * is refused. Then checks the new wait, the unchanged retry count, the error text, that no API issue was raised, and
	 * the one warning.
	 *
	 * @param lastWaitMinutes The wait the call was last given, from its last save to its NextRetry__c.
	 * @param expectedWaitMinutes The wait the call should now get.
	 */
	private static void assertRefusedRetryCallWaits(Integer lastWaitMinutes, Integer expectedWaitMinutes)
	{
		LOG_Builder.ignoreTestMode = true;
		Datetime lastSave = Datetime.now();
		ApiCall__c retryCall = insertRetryCall(lastSave, lastWaitMinutes);
		runActionInsideARunningJob(new List<ApiCall__c> {withLastSave(retryCall, lastSave)});

		ApiCall__c call = SEL_ApiCall.assertServiceRetrying(API_PostExample.class.getName())[0];
		assertWaitingAfterRefusal(call, expectedWaitMinutes, RETRIES_BEFORE_REFUSAL);
		Assert.areEqual(0, new SEL_ApiIssue().count(), 'Expected no API issue for a request that was never sent.');
		assertOneWarning(1, 0);
	}

	/**
	 * @description Runs the action on the given calls from inside a running job, then delivers the log events. In a
	 * test, Salesforce refuses to start a job from inside a running job.
	 *
	 * @param calls The calls to hand to the action.
	 */
	@SuppressWarnings('PMD.KernNoRawEnqueueJob')
	private static void runActionInsideARunningJob(List<ApiCall__c> calls)
	{
		Test.startTest();
		System.enqueueJob(new RefusedLaunchJob(calls));
		Test.stopTest();
		Test.getEventBus().deliver();
	}

	/**
	 * @description Checks that a call waits at Retry after a refused start that Salesforce gave for a running job.
	 *
	 * @param call The call as read after the refusal.
	 * @param expectedWaitMinutes The wait the call should have, from now.
	 * @param expectedRetries The retry count the call should still have.
	 */
	private static void assertWaitingAfterRefusal(ApiCall__c call, Integer expectedWaitMinutes, Decimal expectedRetries)
	{
		assertWaitingAfterRefusal(call, expectedWaitMinutes, expectedRetries, STACK_DEPTH_REASON);
	}

	/**
	 * @description Checks that a call waits at Retry with a new time, the same retry count, and the error text that names
	 * the reason and the new time.
	 *
	 * @param call The call as read after the refusal.
	 * @param expectedWaitMinutes The wait the call should have, from now.
	 * @param expectedRetries The retry count the call should still have.
	 * @param causeMessage The reason Salesforce gave for the refusal, without the full stop that may end it.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void assertWaitingAfterRefusal(ApiCall__c call, Integer expectedWaitMinutes, Decimal expectedRetries, String causeMessage)
	{
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, call.Status__c, 'Expected the call to wait at Retry: ' + call.Id);
		Assert.isNotNull(call.NextRetry__c, 'Expected the call to have a retry time: ' + call.Id);
		Long expectedTime = Datetime.now().addMinutes(expectedWaitMinutes).getTime();
		Assert.isTrue
				(
						Math.abs(call.NextRetry__c.getTime() - expectedTime) <= ONE_MINUTE_IN_MILLISECONDS,
						'Expected the retry time to be ' + expectedWaitMinutes + ' minutes from now, got ' + call.NextRetry__c
				);
		Assert.areEqual(expectedRetries, call.Retries__c, 'Expected the retry count not to change, because nothing was sent.');
		Assert.areEqual
				(
						String.format(System.Label.OutboundCall_LaunchRefused, new List<Object> {causeMessage, UTIL_Date.toIso8601(call.NextRetry__c)}),
						call.ErrorMessages__c,
						'Expected the error text to give the reason and the new time.'
				);
	}

	/**
	 * @description Checks that the action wrote one warning for a start that Salesforce refused for a running job.
	 *
	 * @param expectedWaitingCount The number of calls that should wait at Retry.
	 * @param expectedStartedCount The number of calls whose job should have started.
	 *
	 * @return The warning.
	 */
	private static LogEntry__c assertOneWarning(Integer expectedWaitingCount, Integer expectedStartedCount)
	{
		return assertOneWarning(expectedWaitingCount, expectedStartedCount, AsyncException.class.getName());
	}

	/**
	 * @description Checks that the action wrote one warning, with the counts and the type of the error in its context.
	 *
	 * @param expectedWaitingCount The number of calls that should wait at Retry.
	 * @param expectedStartedCount The number of calls whose job should have started.
	 * @param expectedCauseType The type name of the error Salesforce raised.
	 *
	 * @return The warning.
	 */
	private static LogEntry__c assertOneWarning(Integer expectedWaitingCount, Integer expectedStartedCount, String expectedCauseType)
	{
		List<LogEntry__c> warnings = findWarningsWithContextKey(FLOW_CallApiAsync.CONTEXT_WAITING_CALL_COUNT);
		Assert.areEqual(1, warnings.size(), 'Expected one warning for the refused start.');
		LogEntry__c warning = warnings[0];
		Assert.areEqual(LoggingLevel.WARN.name(), warning.LogLevel__c, 'Expected the entry to be a warning.');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warning);
		Assert.areEqual
				(
						String.valueOf(expectedWaitingCount),
						String.valueOf(context.get(FLOW_CallApiAsync.CONTEXT_WAITING_CALL_COUNT)),
						'Expected the warning to count the waiting calls.'
				);
		Assert.areEqual
				(
						String.valueOf(expectedStartedCount),
						String.valueOf(context.get(FLOW_CallApiAsync.CONTEXT_STARTED_CALL_COUNT)),
						'Expected the warning to count the started calls.'
				);
		Assert.areEqual(expectedCauseType, context.get(FLOW_CallApiAsync.CONTEXT_CAUSE_TYPE), 'Expected the warning to name the type of the error.');
		Assert.areEqual(expectedWaitingCount > 0, context.get(FLOW_CallApiAsync.CONTEXT_EARLIEST_NEXT_RETRY) != null, 'Expected an earliest time only when a call waits.');
		return warning;
	}

	/**
	 * @description Checks that no error log entry was written at all: not for the refused start, and not for a failed
	 * save.
	 */
	private static void assertNoErrorEntry()
	{
		List<LogEntry__c> errorEntries = new SEL_LogEntry().findByLogLevel(LoggingLevel.ERROR.name());
		Assert.isTrue(errorEntries.isEmpty(), 'Expected no error log entry, got ' + errorEntries);
	}

	/**
	 * @description Inserts an outbound call at Retry that was tried once, with NextRetry__c a number of minutes after the
	 * given last save time.
	 *
	 * @param lastSave The time the test treats as the call's last save.
	 * @param lastWaitMinutes The minutes from the last save to NextRetry__c, or null for no NextRetry__c.
	 *
	 * @return The inserted call.
	 */
	private static ApiCall__c insertRetryCall(Datetime lastSave, Integer lastWaitMinutes)
	{
		Map<SObjectField, Object> fields = buildOutboundCallFields(SEL_ApiCall.STATUS_RETRY);
		fields.put(ApiCall__c.Retries__c, RETRIES_BEFORE_REFUSAL);
		fields.put(ApiCall__c.NextRetry__c, lastWaitMinutes == null ? null : lastSave.addMinutes(lastWaitMinutes));
		return (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withOverrides(fields).build();
	}

	/**
	 * @description Inserts an outbound call at Batched, a status no flow acts on.
	 *
	 * @return The inserted call.
	 */
	private static ApiCall__c insertBatchedCall()
	{
		return insertOutboundCall(SEL_ApiCall.STATUS_BATCHED);
	}

	/**
	 * @description Inserts an outbound call at Queued, so the Invoke Outbound Api Call flow hands it to the action.
	 *
	 * @return The inserted call.
	 */
	private static ApiCall__c insertQueuedCall()
	{
		return insertOutboundCall(SEL_ApiCall.STATUS_QUEUED);
	}

	/**
	 * @description Inserts an outbound call of the example service at the given status.
	 *
	 * @param status The status to insert the call at.
	 *
	 * @return The inserted call.
	 */
	private static ApiCall__c insertOutboundCall(String status)
	{
		return insertOutboundCalls(status, 1)[0];
	}

	/**
	 * @description Inserts outbound calls of the example service at the given status, never tried before.
	 *
	 * @param status The status to insert the calls at.
	 * @param count The number of calls to insert.
	 *
	 * @return The inserted calls.
	 */
	private static List<ApiCall__c> insertOutboundCalls(String status, Integer count)
	{
		List<ApiCall__c> calls = new List<ApiCall__c>();
		for(SObject call : TST_Builder.of(ApiCall__c.SObjectType).withOverrides(buildOutboundCallFields(status)).withCount(count).buildList())
		{
			calls.add((ApiCall__c)call);
		}
		return calls;
	}

	/**
	 * @description Builds the field values of an outbound call of the example service at the given status, never tried
	 * before.
	 *
	 * @param status The status of the call.
	 *
	 * @return The field values, by field.
	 */
	private static Map<SObjectField, Object> buildOutboundCallFields(String status)
	{
		return new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
				ApiCall__c.TriggeringRecordId__c => UserInfo.getUserId(),
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
				ApiCall__c.Status__c => status,
				ApiCall__c.Retries__c => NO_RETRIES
		};
	}

	/**
	 * @description Builds an outbound call of the example service that is not saved, as a subscriber can hand it to the
	 * action. Its retry count and its request parameters are not the values a new call gets on its own, so a test can
	 * see that the new call saved for it keeps them.
	 *
	 * @param status The status the call is built with.
	 *
	 * @return The call, with no Id.
	 */
	private static ApiCall__c buildUnsavedCall(String status)
	{
		Map<SObjectField, Object> fields = buildOutboundCallFields(status);
		fields.put(ApiCall__c.Retries__c, RETRIES_BEFORE_REFUSAL);
		fields.put(ApiCall__c.RequestParameters__c, UTIL_Random.randomUUID());
		ApiCall__c unsavedCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withOverrides(fields).withoutInsertion(true).build();
		unsavedCall.Id = null;
		return unsavedCall;
	}

	/**
	 * @description Returns a copy of a call that also carries a last save time (LastModifiedDate), as a call read by the
	 * Retry Outbound Api Call flow does. LastModifiedDate cannot be set on a record in Apex, so the copy is made through
	 * JSON.
	 *
	 * @param call The call to copy.
	 * @param lastSave The last save time the copy carries.
	 *
	 * @return The copy with LastModifiedDate set.
	 */
	private static ApiCall__c withLastSave(ApiCall__c call, Datetime lastSave)
	{
		Map<String, Object> fields = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(call));
		fields.put(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.LastModifiedDate), lastSave);
		return (ApiCall__c)JSON.deserialize(JSON.serialize(fields), ApiCall__c.class);
	}

	/**
	 * @description The error handed to the method that schedules refused calls, in place of the one Salesforce raises.
	 */
	private class RefusedException extends Exception
	{
	}

	/**
	 * @description A job that runs the action on the calls it holds. In a test, Salesforce refuses any job started from
	 * inside a running job, so the action's start is refused.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	private class RefusedLaunchJob implements Queueable
	{
		/**
		 * @description The calls to hand to the action.
		 */
		private final List<ApiCall__c> calls;

		/**
		 * @description Keeps the calls to hand to the action when the job runs.
		 *
		 * @param calls The calls to hand to the action.
		 */
		private RefusedLaunchJob(List<ApiCall__c> calls)
		{
			this.calls = calls;
		}

		/**
		 * @description Hands the calls to the action.
		 *
		 * @param context The context Salesforce gives the running job.
		 */
		public void execute(QueueableContext context)
		{
			FLOW_CallApiAsync.invokeApiCallAsynchronously(calls);
		}
	}
}