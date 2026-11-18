// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class to check behavior of SCHED_PerformBatchedCallouts
 *
 * @see SCHED_PerformBatchedCallouts
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SCHED_PerformBatchedCallouts_TEST
{
	/**
	 * @description A request text set only on the call that the read returns. The database does not hold it.
	 */
	private static final String REQUEST_PARAMETERS_NOT_IN_THE_DATABASE = 'Set on the call that was read, not in the database';

	/**
	 * @description Test method to test the Schedule job
	 */
	@IsTest
	private static void runSchedule()
	{
		insertBatchedCall();

		Test.startTest();

		ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(SCHED_PerformBatchedCallouts.class.getName());

		scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

		Test.stopTest();

		Assert.isNotNull(scheduler.ScheduledJobId__c, SCHED_PerformBatchedCallouts.class.getName() + ' was not started');
	}

	/**
	 * @description A run by a user who cannot edit a Batched call still moves it to Queued. API calls are Private, so a
	 * Standard User with no permission set cannot edit a call another user saved. The job runs as the user who scheduled
	 * it, so its save must ignore record sharing. The status is read before the send runs, because the send writes the
	 * outcome.
	 */
	@IsTest
	private static void shouldQueueABatchedCallTheRunningUserCannotEdit()
	{
		registerServiceMock();
		User runningUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		ApiCall__c batchedCall = insertBatchedCall();

		Test.startTest();

		System.runAs(runningUser)
		{
			new SCHED_PerformBatchedCallouts().execute(null);
		}

		Assert.areEqual(SEL_ApiCall.STATUS_QUEUED, readCall(batchedCall.Id).Status__c, 'Expected the call to be at Queued, though the user cannot edit it.');

		Test.stopTest();
	}

	/**
	 * @description A Batched call whose save is refused stays at Batched and is counted in one warning. The read returns
	 * two calls: first a call that does not exist in the database, so the database refuses its update, then a saved
	 * call. The saved call is moved to Queued. The refused save keeps its own error log entry. The test also checks that
	 * the save writes only the status: a field changed on the call that was read keeps its value in the database.
	 */
	@IsTest
	private static void shouldCountARefusedCallInTheWarning()
	{
		LOG_Builder.ignoreTestMode = true;
		registerServiceMock();
		ApiCall__c callNotInTheDatabase = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withOverrides(buildBatchedCallFields()).withoutInsertion(true).build();
		ApiCall__c batchedCall = readCall(insertBatchedCall().Id);
		String requestParametersInTheDatabase = batchedCall.RequestParameters__c;
		batchedCall.RequestParameters__c = REQUEST_PARAMETERS_NOT_IN_THE_DATABASE;
		TST_Mock.registerNext(ApiCall__c.SObjectType, new List<SObject> {callNotInTheDatabase, batchedCall});

		Test.startTest();

		new SCHED_PerformBatchedCallouts().execute(null);

		ApiCall__c savedCall = readCall(batchedCall.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_QUEUED, savedCall.Status__c, 'Expected the call the save accepted to be at Queued.');
		Assert.areEqual
				(
						requestParametersInTheDatabase,
						savedCall.RequestParameters__c,
						'Expected the save to write only the status, so a field changed on the call that was read is not saved.'
				);

		Test.stopTest();
		Test.getEventBus().deliver();

		List<LogEntry__c> warnings = new SEL_LogEntry().findAllByMethod(SCHED_PerformBatchedCallouts.LOG_LOCATION);
		Assert.areEqual(1, warnings.size(), 'Expected one warning for the call that was not moved to Queued, got ' + warnings);
		Assert.areEqual(LoggingLevel.WARN.name(), warnings[0].LogLevel__c, 'Expected the entry to be a warning.');
		Assert.areEqual
				(
						String.valueOf(1),
						String.valueOf(SEL_LogEntry.parseContextDataForTest(warnings[0]).get(SCHED_PerformBatchedCallouts.CONTEXT_NOT_QUEUED_CALL_COUNT)),
						'Expected the warning to count the one call that was not moved to Queued.'
				);
		Assert.isFalse(new SEL_LogEntry().findByLogLevel(LoggingLevel.ERROR.name()).isEmpty(), 'Expected an error entry for the refused save.');
	}

	/**
	 * @description Registers a successful answer for the example service, so the send that follows the move to Queued
	 * makes no real request.
	 */
	private static void registerServiceMock()
	{
		API_MockFactory.forService(API_PostExample.class.getName()).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
	}

	/**
	 * @description Inserts an outbound call of the example service at Batched.
	 *
	 * @return The inserted call.
	 */
	private static ApiCall__c insertBatchedCall()
	{
		return (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withOverrides(buildBatchedCallFields()).build();
	}

	/**
	 * @description Builds the field values of an outbound call of the example service at Batched.
	 *
	 * @return The field values, by field.
	 */
	private static Map<SObjectField, Object> buildBatchedCallFields()
	{
		return new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
				ApiCall__c.TriggeringRecordId__c => UserInfo.getUserId(),
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
				ApiCall__c.Status__c => SEL_ApiCall.STATUS_BATCHED
		};
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
}
