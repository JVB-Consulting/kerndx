// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests behaviour that belongs directly to `API_Outbound`, specifically the
 * framework-validation branches that are difficult to reach through subclass test helpers
 * because real `ApiSetting__mdt` records exist for every shipped subclass.
 * An "unkeyed" POST or PATCH is one sent without an Idempotency-Key header. With no key, the external system cannot tell
 * a repeat from a new request, so sending it again could do the work twice.
 *
 * @see API_Outbound
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date April 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssCount,PMD.NcssTypeCount')
@IsTest(seeAllData=false isParallel=true)
public class API_Outbound_TEST
{
	/**
	 * @description Service name pointing at the inner `TestableOutbound` class, chosen because
	 * no `ApiSetting__mdt` record ships for this name, so `setting == null` inside
	 * `performValidation()` is guaranteed to fire.
	 */
	private static final String SERVICE_NAME = API_Outbound_TEST.TestableOutbound.class.getName();

	/**
	 * @description Required input name declared by the inner `DeclaringOutbound` service, so the
	 * accessor is asserted against a value that can only come from the subscriber's override.
	 */
	private static final String REQUIRED_INPUT_NAME = 'password';

	/**
	 * @description The retry budget the mocked settings carry: enough attempts that a call the engine refuses to retry is
	 * refused by the engine, never by an exhausted budget.
	 */
	private static final Integer RETRY_BUDGET = 3;

	/**
	 * @description The retry wait the mocked settings carry, in seconds.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 30;

	/**
	 * @description The circuit breaker cool-off the open-circuit test's setting carries, in seconds; longer than the
	 * backoff, so the schedule proves the cool-off stretched the wait.
	 */
	private static final Integer CIRCUIT_TIMEOUT_SECONDS = 120;

	/**
	 * @description A circuit breaker cool-off of zero seconds. In a test the breaker reads a zero cool-off as passed once
	 * the clock has moved on by one millisecond, so a test can let the cool-off pass without waiting.
	 */
	private static final Integer IMMEDIATE_CIRCUIT_TIMEOUT_SECONDS = 0;

	/**
	 * @description A circuit breaker cool-off no test waits out, in seconds, so a half-open circuit that has used every
	 * trial request keeps refusing for the rest of the test.
	 */
	private static final Integer LONG_CIRCUIT_TIMEOUT_SECONDS = 60;

	/**
	 * @description How many trial requests a half-open circuit breaker lets through in one round when nothing sets
	 * another number. An API setting has no field for it, so a dispatched call always gets the breaker's default round of
	 * three, and the tests that use up a round rely on that default.
	 */
	private static final Integer HALF_OPEN_TRIAL_REQUESTS = 3;
	/**
	 * @description An HTTP method the call record's HttpMethod__c picklist does not hold.
	 */
	private static final String HEAD_METHOD = 'HEAD';

	/**
	 * @description A stored timestamp keeps whole seconds, so a read-back time is compared against a bound one second
	 * earlier than the capture.
	 */
	private static final Integer ONE_SECOND_TOLERANCE = 1;

	/**
	 * @description HTTP status code for an unauthorised request (401), a status the default never retries.
	 */
	private static final Integer HTTP_UNAUTHORIZED = 401;

	/**
	 * @description HTTP status code for a redirect (302), a 3xx the default never retries.
	 */
	private static final Integer HTTP_FOUND = 302;

	/**
	 * @description The message every throwing test handler of this class fails with.
	 */
	private static final String MESSAGE_HANDLER_THREW = 'the handler threw on purpose';

	/**
	 * @description The body marker the body-reading strategy treats as a permanent failure.
	 */
	private static final String PERMANENT_BODY_MARKER = 'PERMANENT';

	/**
	 * @description The phrase the platform's own message carries when it refuses a callout because the transaction has
	 * unsaved work pending.
	 */
	private static final String MESSAGE_UNCOMMITTED_WORK = 'uncommitted work pending';

	/**
	 * @description The phrase that opens the message of the transport failure a mock registered with
	 * withTransportFailure() throws at the send.
	 */
	private static final String MESSAGE_MOCKED_TRANSPORT_FAILURE = 'Simulated transport failure';

	/**
	 * @description How many times the counting handlers entered sendRequest in the running test.
	 */
	private static Integer sendCount = 0;

	/**
	 * @description How many times the counting handlers ran onSuccess in the running test.
	 */
	private static Integer successCount = 0;

	/**
	 * @description The Idempotency-Key the key-setting handler set on its request in the running test; null when it found a
	 * key already on the request and set none of its own.
	 */
	private static String keySetByTheHandler;

	/**
	 * @description The name of the record the lock-retry handler registers, read back to prove which attempt saved it.
	 */
	private static final String SAVED_RECORD_NAME = 'Saved after a lock retry';

	/**
	 * @description The lock refusal the stand-in throws when a test lets the refusal reach the call's error text. It names
	 * the platform's lock status code, which is what the commit retry reads, and leaves out the phrase the platform puts
	 * in front of row errors, because an exception built in a test carries no rows to read.
	 */
	private static final String ROWLESS_LOCK_REFUSAL = 'UNABLE_TO_LOCK_ROW, unable to obtain exclusive access to this record';

	/**
	 * @description An email value the platform refuses, so saving a record that carries it fails with a row error.
	 */
	private static final String INVALID_EMAIL = 'not-an-email';

	/**
	 * @description The phrase that opens the summary line of a DmlException the platform raises for refused rows.
	 */
	private static final String PLATFORM_SUMMARY_PHRASE = 'First exception on row';

	/**
	 * @description Saves the call rows the saved-row tests dispatch, in their own transaction, so each test's callout
	 * happens before anything in the test writes: one for the saved-row lock test, and one carrying the Idempotency-Key a
	 * first attempt recorded, for the test that retries it. Each row is one the scheduled retry would run again: it has an
	 * Id, the Retry status and a retry time.
	 */
	@TestSetup
	private static void insertTheSavedCallRowsTheTestsDispatch()
	{
		insertARowTheScheduledRetryRuns(SavedRowOutbound.class.getName(), null);
		insertARowTheScheduledRetryRuns(SavedKeySettingPostOutbound.class.getName(), UTIL_Random.randomName());
	}

	/**
	 * @description Saves one outbound call row the scheduled retry would run again.
	 *
	 * @param serviceName The handler class the row names.
	 * @param idempotencyKey The Idempotency-Key the row carries, or null for none.
	 */
	private static void insertARowTheScheduledRetryRuns(String serviceName, String idempotencyKey)
	{
		TST_Builder.of(ApiCall__c.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
				ApiCall__c.TriggeringRecordId__c => UserInfo.getUserId(),
				ApiCall__c.Status__c => SEL_ApiCall.STATUS_RETRY,
				ApiCall__c.NextRetry__c => Datetime.now(),
				ApiCall__c.IdempotencyKey__c => idempotencyKey
		}).build();
	}

	/**
	 * @description A row lock while saving a successful call's records retries the save once and never the callout: the
	 * first commit attempt is refused with the platform's lock refusal, the second saves the record, the call ends
	 * Completed on one row with no issue and a recorded commit time, and the request was sent exactly once. Whether a send
	 * a test mock responds to moves the callout counter is unmeasured, so the handler counts its own sends, which proves
	 * the single send either way.
	 */
	@IsTest
	private static void shouldRetryTheCommitOnceOnARowLockWithoutResendingTheCallout()
	{
		sendCount = 0;
		successCount = 0;
		String serviceName = RecordSavingOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		API_Base handler = dispatchWithLockRefusals(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()), new DML_ThrowingLockProxy_TEST(1));

		List<ApiCall__c> completed = SEL_ApiCall.assertServiceCompleted(serviceName);
		Assert.areEqual(1, completed.size(), 'Expected one call row after the retried commit, got ' + completed.size());
		Assert.areEqual(completed[0].Id, handler.apiCall.Id, 'Expected the handler to hold the saved row\'s Id, got ' + handler.apiCall.Id);
		Assert.areEqual(1, sendCount, 'Expected the request to go out once, got ' + sendCount);
		Assert.areEqual(1, successCount, 'Expected onSuccess() to run once, got ' + successCount);
		Integer issueCount = countIssuesFor(serviceName);
		Assert.areEqual(0, issueCount, 'Expected no issue for a call that completed, got ' + issueCount);
		Integer savedCount = new SEL_Foobar().findByField(Foobar__c.Name, SAVED_RECORD_NAME).size();
		Assert.areEqual(1, savedCount, 'Expected the record the handler registered to be saved on the second attempt, got ' + savedCount);
		Assert.isNotNull(handler.apiCall.CommitDurationMs__c, 'Expected a commit time on the call after the retried commit, got null');
	}

	/**
	 * @description The files that hold a call's data exist once after a commit that was retried, and are linked to the
	 * row the commit saved. The first commit attempt is refused for a row lock and saves nothing; the second saves the
	 * call row. With file storage switched on for every call, the saved row has files, each file exists once, and no file
	 * exists that is not linked to the saved row: the retried commit left neither a second copy nor a stray file behind.
	 */
	@IsTest
	private static void shouldCreateTheCallsFilesOnceWhenTheCommitIsRetriedOnARowLock()
	{
		API_Base.simulateStoreToFile = true;
		String serviceName = RecordSavingOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		dispatchWithLockRefusals(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()), new DML_ThrowingLockProxy_TEST(1));

		List<ApiCall__c> completed = SEL_ApiCall.assertServiceCompleted(serviceName);
		Assert.areEqual(1, completed.size(), 'Expected one call row after the retried commit, got ' + completed.size());
		List<String> fileTitles = new List<String>();
		for(ContentVersion file : new SEL_ContentVersion().findByFirstPublishLocationId(completed[0].Id))
		{
			fileTitles.add(file.Title);
		}
		Assert.isFalse(fileTitles.isEmpty(), 'Expected the call\'s files to be linked to the saved row, got none');
		Assert.areEqual(new Set<String>(fileTitles).size(), fileTitles.size(), 'Expected each of the call\'s files once, got ' + fileTitles);
		Integer filesInTheTest = new SEL_ContentVersion().getAll().size();
		Assert.areEqual(fileTitles.size(), filesInTheTest, 'Expected every file to be linked to the saved row, got ' + filesInTheTest + ' files in all');
	}

	/**
	 * @description The files that hold a call's data are created only after the commit attempt that succeeds. The call
	 * row was saved before the call, the kind the scheduled retry runs again, so its Id names a row that a refused attempt
	 * does not roll back. The first commit attempt is refused for a row lock, the second saves the records. With file
	 * storage switched on for every call, each file is linked to the saved row exactly once: files made after the
	 * refused attempt would also have been linked to that row, and would show up as a second copy.
	 */
	@IsTest
	private static void shouldCreateTheSavedRowsFilesOnlyAfterTheAttemptThatSucceeds()
	{
		API_Base.simulateStoreToFile = true;
		ApiCall__c savedRow = prepareSavedRowCall();

		dispatchWithLockRefusals(savedRow, new DML_ThrowingLockProxy_TEST(1));

		SEL_ApiCall.assertServiceCompleted(savedRow.ServiceName__c);
		List<String> fileTitles = new List<String>();
		for(ContentVersion file : new SEL_ContentVersion().findByFirstPublishLocationId(savedRow.Id))
		{
			fileTitles.add(file.Title);
		}
		Assert.isFalse(fileTitles.isEmpty(), 'Expected the call\'s files to be linked to the saved row, got none');
		Assert.areEqual(new Set<String>(fileTitles).size(), fileTitles.size(), 'Expected each of the call\'s files once, got ' + fileTitles);
	}

	/**
	 * @description When the lock holds through the one retried commit, the call fails at once as any failure after a
	 * success does: Failed on one row whose error text is the lock refusal, no time, the request sent once, one issue
	 * marked as one the external system acted on.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenTheLockHoldsOnTheRetriedCommit()
	{
		sendCount = 0;
		String serviceName = RecordSavingOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		dispatchWithLockRefusals(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()), new DML_ThrowingLockProxy_TEST(2, ROWLESS_LOCK_REFUSAL));

		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName);
		Assert.areEqual(1, failed.size(), 'Expected one call row after the commit failed for good, got ' + failed.size());
		String errorText = failed[0].ErrorMessages__c;
		Assert.isTrue(errorText.contains(ROWLESS_LOCK_REFUSAL), 'Expected the row\'s error text to be the lock refusal, got ' + errorText);
		Assert.isNull(failed[0].NextRetry__c, 'Expected a failure after a success to schedule nothing, got ' + failed[0].NextRetry__c);
		Assert.areEqual(1, sendCount, 'Expected the request to go out once, got ' + sendCount);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system acted before the save failed');
	}

	/**
	 * @description A row lock while saving the records of a call whose row was saved before, the kind the scheduled retry
	 * runs again, retries the save once and keeps the row: the same row ends Completed, no second row appears for the
	 * service, and the request was sent exactly once.
	 */
	@IsTest
	private static void shouldKeepTheSavedCallRowWhenItsCommitIsRetriedOnARowLock()
	{
		ApiCall__c savedRow = prepareSavedRowCall();
		Id savedRowId = savedRow.Id;

		dispatchWithLockRefusals(savedRow, new DML_ThrowingLockProxy_TEST(1));

		List<ApiCall__c> completed = SEL_ApiCall.assertServiceCompleted(savedRow.ServiceName__c);
		Assert.areEqual(1, completed.size(), 'Expected the one saved row and no second row for the service, got ' + completed.size());
		Assert.areEqual(savedRowId, completed[0].Id, 'Expected the row saved before the call to be the one completed, got ' + completed[0].Id);
		Assert.areEqual(1, sendCount, 'Expected the request to go out once, got ' + sendCount);
		Integer savedCount = new SEL_Foobar().findByField(Foobar__c.Name, SAVED_RECORD_NAME).size();
		Assert.areEqual(1, savedCount, 'Expected the record the handler registered to be saved on the second attempt, got ' + savedCount);
	}

	/**
	 * @description When the lock holds through the one retried commit of a call whose row was saved before, the same row
	 * records the failure: it ends Failed with no time, no second row appears for the service, the request was sent
	 * exactly once, and one issue is logged.
	 */
	@IsTest
	private static void shouldFailTheSavedCallRowItselfWhenTheLockHoldsOnTheRetriedCommit()
	{
		ApiCall__c savedRow = prepareSavedRowCall();
		Id savedRowId = savedRow.Id;

		dispatchWithLockRefusals(savedRow, new DML_ThrowingLockProxy_TEST(2, ROWLESS_LOCK_REFUSAL));

		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(savedRow.ServiceName__c, ROWLESS_LOCK_REFUSAL);
		Assert.areEqual(1, failed.size(), 'Expected the one saved row and no second row for the service, got ' + failed.size());
		Assert.areEqual(savedRowId, failed[0].Id, 'Expected the row saved before the call to be the one that failed, got ' + failed[0].Id);
		Assert.isNull(failed[0].NextRetry__c, 'Expected a failure after a success to schedule nothing, got ' + failed[0].NextRetry__c);
		Assert.areEqual(1, sendCount, 'Expected the request to go out once, got ' + sendCount);
		Integer issueCount = countIssuesFor(savedRow.ServiceName__c);
		Assert.areEqual(1, issueCount, 'Expected one issue for the failed call, got ' + issueCount);
	}

	/**
	 * @description In safe mode nothing is saved, and a call whose row was saved before still keeps that row's Id when its
	 * commit fails for good: the handler holds the saved row's Id, the row is left as it was, and no second row appears.
	 */
	@IsTest
	private static void shouldKeepTheSavedCallRowsIdWhenItsCommitFailsForGoodInSafeMode()
	{
		ApiCall__c savedRow = prepareSavedRowCall();
		Id savedRowId = savedRow.Id;
		API_Base.SafeModeContext safeMode = API_Base.enterSafeMode();
		API_Base handler;

		try
		{
			handler = dispatchWithLockRefusals(savedRow, new DML_ThrowingLockProxy_TEST(2, ROWLESS_LOCK_REFUSAL));
		}
		finally
		{
			safeMode.close();
		}

		Assert.areEqual(savedRowId, handler.apiCall.Id, 'Expected the handler to keep the saved row\'s Id, got ' + handler.apiCall.Id);
		List<ApiCall__c> rows = new SEL_ApiCall().findByServiceName(savedRow.ServiceName__c);
		Assert.areEqual(1, rows.size(), 'Expected the one saved row and no second row for the service, got ' + rows.size());
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, rows[0].Status__c, 'Expected safe mode to leave the saved row as it was, got ' + rows[0].Status__c);
		Assert.areEqual(1, sendCount, 'Expected the request to go out once, got ' + sendCount);
	}

	/**
	 * @description A DmlException a handler builds and throws itself carries no row errors, and the call records it by
	 * its own message: the row ends Failed with that message and no time, one issue is logged, and the batch's other call
	 * is saved Completed. The completing call goes first, so its callout runs before the failed call's log rows are saved.
	 */
	@IsTest
	private static void shouldRecordADmlExceptionTheHandlerBuiltByItsOwnMessage()
	{
		String throwingServiceName = HandlerBuiltDmlExceptionOutbound.class.getName();
		String completingServiceName = CompletingOutbound.class.getName();
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();
		for(String serviceName : new List<String> {completingServiceName, throwingServiceName})
		{
			registerRetryingSetting(serviceName);
			API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
			apiCalls.add(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		}

		Test.startTest();
		API_Dispatcher.execute(apiCalls);
		Test.stopTest();

		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(throwingServiceName, MESSAGE_HANDLER_THREW);
		Assert.areEqual(1, failed.size(), 'Expected one row for the throwing call, got ' + failed.size());
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time on the throwing call, got ' + failed[0].NextRetry__c);
		Integer issueCount = countIssuesFor(throwingServiceName);
		Assert.areEqual(1, issueCount, 'Expected one issue on the throwing call, got ' + issueCount);
		Integer completedCount = SEL_ApiCall.assertServiceCompleted(completingServiceName).size();
		Assert.areEqual(1, completedCount, 'Expected the batch\'s other call to be saved once, got ' + completedCount);
	}

	/**
	 * @description A record the platform refuses while the handler's records are saved is recorded by its row errors, as
	 * the platform words them for each row, without the summary line the platform puts in front of them.
	 */
	@IsTest
	private static void shouldRecordAPlatformRefusalByItsRowErrors()
	{
		String serviceName = RefusedRecordOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		String errorText = SEL_ApiCall.assertServiceFailed(serviceName)[0].ErrorMessages__c;
		Assert.isTrue(errorText.contains(INVALID_EMAIL), 'Expected the refused row\'s own error, which names the value, got ' + errorText);
		Assert.isFalse(errorText.contains(PLATFORM_SUMMARY_PHRASE), 'Expected the row errors without the platform\'s summary line, got ' + errorText);
	}

	/**
	 * @description A commit that succeeds first time records the commit time and the handler time on the call, each taken
	 * from a stopwatch that has stopped: the commit time is the commit stopwatch's final reading, and the handler time is
	 * the service stopwatch's final reading less the callout's.
	 */
	@IsTest
	private static void shouldRecordTheServiceAndCommitTimesOfACommitThatSucceedsFirstTime()
	{
		String serviceName = CompletingOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();
		API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(serviceName);
		Decimal commitTime = handler.apiCall.CommitDurationMs__c;
		Decimal handlerTime = handler.apiCall.HandlerDurationMs__c;
		Long expectedCommitTime = handler.commitProcessingTime.getTime();
		Long expectedHandlerTime = handler.serviceProcessingTime.getTime() - handler.calloutProcessingTime.getTime();
		Assert.areEqual(expectedCommitTime, commitTime?.longValue(), 'Expected the commit time to be the stopped stopwatch\'s ' + expectedCommitTime + ', got ' + commitTime);
		Assert.areEqual(expectedHandlerTime, handlerTime?.longValue(), 'Expected the handler time to be service less callout, ' + expectedHandlerTime + ', got ' + handlerTime);
	}

	/**
	 * @description Dispatching an outbound ApiCall__c whose ServiceName__c points at a handler
	 * class with no matching `ApiSetting__mdt` record aborts the call with the labelled line that says no API setting
	 * record was found for the service, from the framework's own validation in API_Outbound.performValidation().
	 */
	@IsTest
	private static void shouldAbortCallWhenApiSettingRecordIsMissing()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});

		Test.stopTest();

		Assert.areEqual(1, handlers.size(), 'Dispatcher should return a single handler');

		API_Base handler = handlers.iterator().next();
		String expectedError = String.format(System.Label.OutboundCall_ApiSettingNotFound, new List<Object> {SERVICE_NAME});
		Assert.isTrue(handler.result.errors.contains(expectedError), 'Expected the missing setting error "' + expectedError + '", got ' + handler.result.errors);
	}

	/**
	 * @description A call to a service that needs a triggering record, made without one, is refused with the message from
	 * the Custom Label.
	 */
	@IsTest
	private static void shouldRefuseCallWithoutTriggeringRecordIdUsingTheLabel()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME);
		apiCall.TriggeringRecordId__c = null;

		Test.startTest();
		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});
		Test.stopTest();

		List<String> errors = handlers.iterator().next().result.errors;
		Assert.isTrue(errors.contains(System.Label.OutboundCall_TriggeringRecordIdRequired), 'Expected the triggering record Id error, got ' + errors);
	}

	/**
	 * @description A call made without an input its service requires is refused with the message from the Custom Label,
	 * which lists the required input names.
	 */
	@IsTest
	private static void shouldRefuseCallWithoutRequiredInputUsingTheLabel()
	{
		String serviceName = DeclaringOutbound.class.getName();
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName);

		Test.startTest();
		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});
		Test.stopTest();

		String expectedError = String.format(System.Label.OutboundCall_RequiredParametersMissing, new List<Object> {JSON.serialize(new Set<String> {REQUIRED_INPUT_NAME})});
		List<String> errors = handlers.iterator().next().result.errors;
		Assert.isTrue(errors.contains(expectedError), 'Expected the missing input error "' + expectedError + '", got ' + errors);
	}

	/**
	 * @description A service that declares a required input and clears the triggering-record
	 * requirement in `configure()` must report both through the package-internal accessors.
	 */
	@IsTest
	private static void describeRequiredInputsReadsTheSubscriberOverride()
	{
		API_Outbound service = new DeclaringOutbound();

		Assert.areEqual(new Set<String> {REQUIRED_INPUT_NAME}, service.describeRequiredInputs(), 'The accessor must return exactly the overridden set.');
		Assert.isFalse(service.isTriggeringRecordRequired(), 'configure() set requiresTriggeringRecord = false; the accessor must reflect it.');
	}

	/**
	 * @description A service that overrides neither `getRequiredInputs()` nor `requiresTriggeringRecord`
	 * must report the base-class defaults: no required inputs and a required triggering record.
	 */
	@IsTest
	private static void accessorsReportTheBaseDefaultsWhenNothingIsOverridden()
	{
		API_Outbound service = new TestableOutbound();

		Assert.areEqual(new Set<String>(), service.describeRequiredInputs(), 'No override means no required inputs.');
		Assert.isTrue(service.isTriggeringRecordRequired(), 'The base configure() defaults requiresTriggeringRecord to true.');
	}

	/**
	 * @description An override that returns null must never reach the caller as null: the accessor
	 * substitutes an empty set so package callers can iterate without a guard.
	 */
	@IsTest
	private static void describeRequiredInputsNeverReturnsNull()
	{
		Assert.areEqual(new Set<String>(), new NullDeclaringOutbound().describeRequiredInputs(), 'A null override must read as an empty set.');
	}

	/**
	 * @description A callout that got no response on a GET is safe to repeat: the call stays at Retry with a time and one
	 * issue, and the circuit breaker counted one failure. The registered mock reaches the handler through Test.setMock on
	 * the platform's send branch (mocking is not enabled for the service), so this test proves the marker around that
	 * branch; shouldClassifyAThrowFromTheFrameworksOwnMockAsACallThatGotNoResponse proves the marker around the other.
	 * In an org whose org cache has no space set aside, the breaker cannot save the failure, so a new breaker for the
	 * service reads no failures.
	 */
	@IsTest
	private static void shouldRetryATransportFailureOnACallThatIsSafeToRepeat()
	{
		Integer expectedFailures = UTIL_Cache.isOrgAllocated() ? 1 : 0;
		String serviceName = RetryProbeOutbound.class.getName();
		registerRetryingSettingWithCircuitBreaker(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();
		UTIL_CircuitBreaker.monitor(serviceName).reset();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		List<ApiCall__c> retrying = SEL_ApiCall.assertServiceRetrying(serviceName);
		Assert.areEqual(1, countRetriesOf(retrying[0]), 'Expected one attempt spent, got ' + retrying[0].Retries__c);
		Integer issueCount = countIssuesFor(serviceName);
		Assert.areEqual(1, issueCount, 'Expected one issue for the attempt, got ' + issueCount);
		Integer failureCount = UTIL_CircuitBreaker.monitor(serviceName).getMetrics().failureCount;
		Assert.areEqual(expectedFailures, failureCount, 'Expected a new breaker to read ' + expectedFailures + ' failures, got ' + failureCount);
	}

	/**
	 * @description A DELETE is safe to repeat too. Its enum value is DELETION, not DELETE, so this test checks that the
	 * set of safe methods still holds it. The same transport failure on a DELETE handler stays at Retry with a next
	 * retry time.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldTreatADeleteRequestAsSafeToRepeat()
	{
		String serviceName = DeleteTransportOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(serviceName);
	}

	/**
	 * @description The denylist a handler puts in createRetryStrategy() reaches the decision: a transport failure whose
	 * type the strategy denylists ends Failed with no time and one issue, where the same call without the denylist stays
	 * at Retry (shouldRetryATransportFailureOnACallThatIsSafeToRepeat).
	 */
	@IsTest
	private static void shouldNotScheduleARetryForAFailureTheStrategyDenylists()
	{
		String serviceName = DenylistingGetOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName);
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time for a denylisted failure, got ' + failed[0].NextRetry__c);
		Integer issueCount = countIssuesFor(serviceName);
		Assert.areEqual(1, issueCount, 'Expected one issue, got ' + issueCount);
	}

	/**
	 * @description A status failure carries no exception, so an exception allowlist never stops it: a 500 under
	 * retryOnlyOnException({CalloutException}) still goes to Retry. This is the documented limit of the allowlist.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldStillScheduleAStatusFailureUnderAnExceptionAllowlist()
	{
		String serviceName = AllowlistingStatusOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.registerErrorMock(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(serviceName);
	}

	/**
	 * @description A POST that got no response and carried no Idempotency-Key fails at once: no time, no attempt spent,
	 * the labelled line saying the request was not repeated, and one issue marked as one the external system may have
	 * acted on.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldFailAtOnceWhenAPostWithoutAKeyGetsNoResponse()
	{
		String serviceName = PostTransportOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedAsNotRepeated(serviceName);
	}

	/**
	 * @description A PATCH that got no response and carried no Idempotency-Key fails at once the same way as a POST.
	 * It runs on its own, because a second callout after a failed call in the same test transaction would be refused by
	 * the platform for the first call's saved log rows, not by the mock.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldFailAtOnceWhenAPatchWithoutAKeyGetsNoResponse()
	{
		String serviceName = PatchTransportOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedAsNotRepeated(serviceName);
	}

	/**
	 * @description A callout the platform refuses before it leaves the org is never sent, so it is retried whatever the
	 * method: a POST without an Idempotency-Key dispatched after a save in the same transaction stays at Retry with a
	 * time and one attempt spent, the circuit breaker counts no failure, and its issue neither says the external system
	 * may have acted nor carries the not-repeated line. The same POST that really got no response fails at once
	 * (shouldFailAtOnceWhenAPostWithoutAKeyGetsNoResponse).
	 */
	@IsTest
	private static void shouldRetryAPostThePlatformRefusedBeforeItLeftTheOrg()
	{
		String serviceName = PostTransportOutbound.class.getName();
		registerRetryingSettingWithCircuitBreaker(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		UTIL_CircuitBreaker.monitor(serviceName).reset();

		Test.startTest();
		TST_Builder.of(Foobar__c.SObjectType).build();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c retrying = SEL_ApiCall.assertServiceRetrying(serviceName)[0];
		Assert.areEqual(1, countRetriesOf(retrying), 'Expected one attempt spent, got ' + retrying.Retries__c);
		assertNothingBlamesTheExternalSystem(serviceName);
	}

	/**
	 * @description A callout the platform refuses before it leaves the org still ends Failed when the setting allows no
	 * retries: no time, the platform's own message on the issue, and the issue neither says the external system may have
	 * acted nor carries the not-repeated line; the circuit breaker counts no failure.
	 */
	@IsTest
	private static void shouldFailWithoutBlamingTheExternalSystemWhenARefusedCalloutHasNoBudget()
	{
		String serviceName = PostTransportOutbound.class.getName();
		registerSettingWithoutRetryBudget(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		UTIL_CircuitBreaker.monitor(serviceName).reset();

		Test.startTest();
		TST_Builder.of(Foobar__c.SObjectType).build();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_UNCOMMITTED_WORK)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time without retry budget, got ' + failed.NextRetry__c);
		List<ApiIssue__c> issues = assertNothingBlamesTheExternalSystem(serviceName);
		Assert.isTrue(issues[0].ErrorMessages__c.contains(MESSAGE_UNCOMMITTED_WORK), 'Expected the issue to carry the platform\'s own message, got ' + issues[0].ErrorMessages__c);
	}

	/**
	 * @description Idempotency Enabled on the setting makes a POST without an Idempotency-Key safe to repeat: the same
	 * transport failure stays at Retry with a time.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAPostThatGotNoResponseWhenIdempotencyIsEnabled()
	{
		String serviceName = PostTransportOutbound.class.getName();
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET, ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS, ApiSetting__mdt.IdempotencyEnabled__c => true
		});
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(serviceName);
	}

	/**
	 * @description A key stamped on the call makes a POST safe to repeat: the same transport failure stays at Retry.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAPostThatGotNoResponseWhenAKeyIsStamped()
	{
		String serviceName = PostTransportOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();
		ApiCall__c stampedCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId());
		stampedCall.IdempotencyKey__c = UTIL_Random.randomName();

		Test.startTest();
		API_Dispatcher.execute(stampedCall);
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(serviceName);
	}

	/**
	 * @description A handler that lists System.CalloutException takes responsibility for a POST without an
	 * Idempotency-Key that got no response: the call stays at Retry.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAPostThatGotNoResponseWhenTheHandlerListsCalloutException()
	{
		String serviceName = PostOptingInCalloutOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(serviceName);
	}

	/**
	 * @description Only the statuses the external system asks a retry for are retried: on a GET, which is safe to repeat,
	 * 408, 425, 429, 500, 502, 503 and 504 stay at Retry with a time, one attempt spent and an issue that does not say the
	 * external system may have acted; 400, 401, 404, 302 and 409 end Failed at once with no attempt spent, one issue that
	 * does not say the external system may have acted, and no line saying the call was not sent again; 409 stays at
	 * Retry on a handler that adds it through getRetryableStatusCodes(). Each status has its own handler, because a
	 * registered mock response belongs to a service, and all the calls go in one batch, which makes every callout before
	 * any call is saved.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryOnlyTheStatusCodesTheExternalSystemAsksFor()
	{
		Map<String, Integer> retriedStatusByService = new Map<String, Integer>
		{
				RequestTimeoutOutbound.class.getName() => API_Base.HTTP_REQUEST_TIMEOUT,
				TooEarlyOutbound.class.getName() => API_Base.HTTP_TOO_EARLY,
				TooManyRequestsOutbound.class.getName() => API_Base.HTTP_TOO_MANY_REQUESTS,
				InternalServerErrorOutbound.class.getName() => API_Base.HTTP_INTERNAL_SERVER_ERROR,
				BadGatewayOutbound.class.getName() => API_Base.HTTP_BAD_GATEWAY,
				ServiceUnavailableOutbound.class.getName() => API_Base.HTTP_SERVICE_UNAVAILABLE,
				GatewayTimeoutOutbound.class.getName() => API_Base.HTTP_GATEWAY_TIMEOUT,
				ConflictRetryingOutbound.class.getName() => API_Base.HTTP_CONFLICT
		};
		Map<String, Integer> stoppedStatusByService = new Map<String, Integer>
		{
				BadRequestOutbound.class.getName() => API_Base.HTTP_BAD_REQUEST,
				UnauthorizedOutbound.class.getName() => HTTP_UNAUTHORIZED,
				NotFoundOutbound.class.getName() => API_Base.HTTP_NOT_FOUND,
				FoundOutbound.class.getName() => HTTP_FOUND,
				ConflictOutbound.class.getName() => API_Base.HTTP_CONFLICT
		};
		Map<String, Integer> statusByService = new Map<String, Integer>(retriedStatusByService);
		statusByService.putAll(stoppedStatusByService);
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();
		for(String serviceName : statusByService.keySet())
		{
			registerRetryingSetting(serviceName);
			API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(statusByService.get(serviceName)).register();
			apiCalls.add(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		}

		Test.startTest();
		API_Dispatcher.execute(apiCalls);
		Test.stopTest();

		for(String serviceName : retriedStatusByService.keySet())
		{
			assertRetryingAndNotFlagged(serviceName, retriedStatusByService.get(serviceName));
		}
		for(String serviceName : stoppedStatusByService.keySet())
		{
			assertFailedAndNotFlagged(serviceName, stoppedStatusByService.get(serviceName));
		}
	}

	/**
	 * @description A handler whose getRetryableStatusCodes() returns null retries no status: a 500 to its GET ends Failed at
	 * once with no time and no attempt spent, and with no decision failure logged, because a null set reads as the empty
	 * set. The request is a GET, so it is safe to repeat: its one issue does not say the external system may have acted and
	 * the row carries no line saying the call was not sent again.
	 */
	@IsTest
	private static void shouldReadANullStatusSetAsNoRetryableStatus()
	{
		String serviceName = NullStatusSetOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.registerErrorMock(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName)[0];
		String errors = failed.ErrorMessages__c ?? UTIL_String.EMPTY;
		String notRepeatedLine = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {serviceName, API_Base.HTTP_INTERNAL_SERVER_ERROR});
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time, got ' + failed.NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed), 'Expected no attempt spent, got ' + failed.Retries__c);
		Assert.isFalse(errors.contains(System.Label.OutboundCall_RetryDecisionFailed.substringBefore('{0}')),
				'Expected a null set to read as no retryable status, not a decision failure, got ' + errors);
		Assert.isFalse(errors.contains(notRepeatedLine), 'Expected no not-repeated line on a GET, got ' + errors);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isFalse(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue on a GET not to say the external system may have acted, got true');
	}

	/**
	 * @description A POST with no Idempotency-Key that gets a 500, 502 or 504 is not sent again: the external system may
	 * have processed it before the error. Each call ends Failed with no time and no attempt spent, carries the labelled
	 * line saying it was not sent again, and has one issue that says the external system may have acted. The setting has
	 * retry budget and a wait, so the refusal comes from the rule and never from a spent budget.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldNotSendAnUnkeyedPostAgainAfterAServerError()
	{
		Map<String, Integer> statusByService = new Map<String, Integer>
		{
				InternalServerErrorPostOutbound.class.getName() => API_Base.HTTP_INTERNAL_SERVER_ERROR,
				BadGatewayPostOutbound.class.getName() => API_Base.HTTP_BAD_GATEWAY,
				GatewayTimeoutPostOutbound.class.getName() => API_Base.HTTP_GATEWAY_TIMEOUT
		};

		dispatchOneCallPerService(statusByService);

		for(String serviceName : statusByService.keySet())
		{
			assertFailedAsServerErrorNotRepeated(serviceName, statusByService.get(serviceName));
		}
	}

	/**
	 * @description A 408, 425, 429 or 503 says the external system did not process the request, so a POST with no
	 * Idempotency-Key is still retried: each call stays at Retry with a time and one attempt spent, and its issue does not
	 * say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAnUnkeyedPostOnAStatusThatSaysTheRequestWasNotProcessed()
	{
		Map<String, Integer> statusByService = new Map<String, Integer>
		{
				RequestTimeoutPostOutbound.class.getName() => API_Base.HTTP_REQUEST_TIMEOUT,
				TooEarlyPostOutbound.class.getName() => API_Base.HTTP_TOO_EARLY,
				TooManyRequestsPostOutbound.class.getName() => API_Base.HTTP_TOO_MANY_REQUESTS,
				ServiceUnavailablePostOutbound.class.getName() => API_Base.HTTP_SERVICE_UNAVAILABLE
		};

		dispatchOneCallPerService(statusByService);

		for(String serviceName : statusByService.keySet())
		{
			assertRetryingAndNotFlagged(serviceName, statusByService.get(serviceName));
		}
	}

	/**
	 * @description A PATCH with no Idempotency-Key is no safer to repeat than a POST: a 504 ends it Failed with the
	 * labelled line and one issue that says the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldNotSendAnUnkeyedPatchAgainAfterAGatewayTimeout()
	{
		String serviceName = PatchTransportOutbound.class.getName();

		dispatchOneCallPerService(new Map<String, Integer> {serviceName => API_Base.HTTP_GATEWAY_TIMEOUT});

		assertFailedAsServerErrorNotRepeated(serviceName, API_Base.HTTP_GATEWAY_TIMEOUT);
	}

	/**
	 * @description A PATCH with no Idempotency-Key that gets a 500 or 502 is not sent again either: each call ends Failed
	 * with no time and no attempt spent, the labelled line and one issue that says the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldNotSendAnUnkeyedPatchAgainAfterAServerError()
	{
		Map<String, Integer> statusByService = new Map<String, Integer>
		{
				InternalServerErrorPatchOutbound.class.getName() => API_Base.HTTP_INTERNAL_SERVER_ERROR,
				BadGatewayPatchOutbound.class.getName() => API_Base.HTTP_BAD_GATEWAY
		};

		dispatchOneCallPerService(statusByService);

		for(String serviceName : statusByService.keySet())
		{
			assertFailedAsServerErrorNotRepeated(serviceName, statusByService.get(serviceName));
		}
	}

	/**
	 * @description A 408, 425, 429 or 503 says the external system did not process the request, so a PATCH with no
	 * Idempotency-Key is still retried: each call stays at Retry with a time and one attempt spent, and its issue does not
	 * say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAnUnkeyedPatchOnAStatusThatSaysTheRequestWasNotProcessed()
	{
		Map<String, Integer> statusByService = new Map<String, Integer>
		{
				RequestTimeoutPatchOutbound.class.getName() => API_Base.HTTP_REQUEST_TIMEOUT,
				TooEarlyPatchOutbound.class.getName() => API_Base.HTTP_TOO_EARLY,
				TooManyRequestsPatchOutbound.class.getName() => API_Base.HTTP_TOO_MANY_REQUESTS,
				ServiceUnavailablePatchOutbound.class.getName() => API_Base.HTTP_SERVICE_UNAVAILABLE
		};

		dispatchOneCallPerService(statusByService);

		for(String serviceName : statusByService.keySet())
		{
			assertRetryingAndNotFlagged(serviceName, statusByService.get(serviceName));
		}
	}

	/**
	 * @description Idempotency Enabled on the setting has the framework send a key, which makes a POST safe to repeat: a
	 * 502 or a 504 stays at Retry with a time and one attempt spent, and its issue does not say the external system may
	 * have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAPostAfterAServerErrorWhenIdempotencyIsEnabled()
	{
		Map<String, Integer> statusByService = new Map<String, Integer>
		{
				BadGatewayPostOutbound.class.getName() => API_Base.HTTP_BAD_GATEWAY,
				GatewayTimeoutPostOutbound.class.getName() => API_Base.HTTP_GATEWAY_TIMEOUT
		};

		dispatchOneCallPerService(statusByService, true);

		for(String serviceName : statusByService.keySet())
		{
			assertRetryingAndNotFlagged(serviceName, statusByService.get(serviceName));
		}
	}

	/**
	 * @description A PUT and a DELETE are safe to repeat: a 500, 502 or 504 to either stays at Retry with a time and one
	 * attempt spent, and its issue does not say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAPutOrDeleteAfterAServerError()
	{
		Map<String, Integer> statusByService = new Map<String, Integer>
		{
				InternalServerErrorPutOutbound.class.getName() => API_Base.HTTP_INTERNAL_SERVER_ERROR,
				BadGatewayPutOutbound.class.getName() => API_Base.HTTP_BAD_GATEWAY,
				GatewayTimeoutPutOutbound.class.getName() => API_Base.HTTP_GATEWAY_TIMEOUT,
				InternalServerErrorDeleteOutbound.class.getName() => API_Base.HTTP_INTERNAL_SERVER_ERROR,
				BadGatewayDeleteOutbound.class.getName() => API_Base.HTTP_BAD_GATEWAY,
				GatewayTimeoutDeleteOutbound.class.getName() => API_Base.HTTP_GATEWAY_TIMEOUT
		};

		dispatchOneCallPerService(statusByService);

		for(String serviceName : statusByService.keySet())
		{
			assertRetryingAndNotFlagged(serviceName, statusByService.get(serviceName));
		}
	}

	/**
	 * @description A key stamped on the call makes a POST safe to repeat: the same 504 stays at Retry with a time and one
	 * attempt spent, and its issue does not say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAKeyedPostAfterAGatewayTimeout()
	{
		String serviceName = PostTransportOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_GATEWAY_TIMEOUT).register();
		ApiCall__c stampedCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId());
		stampedCall.IdempotencyKey__c = UTIL_Random.randomName();

		Test.startTest();
		API_Dispatcher.execute(stampedCall);
		Test.stopTest();

		assertRetryingAndNotFlagged(serviceName, API_Base.HTTP_GATEWAY_TIMEOUT);
	}

	/**
	 * @description Whether a POST is safe to repeat is judged from the request that was sent: Idempotency Enabled has the
	 * framework work out a key, but the handler's createRequest() override sends a request without the Idempotency-Key
	 * header, so a 504 ends the call Failed with no time, no attempt spent, the labelled line and one issue that says the
	 * external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldNotSendAPostAgainAfterAGatewayTimeoutWhenItsRequestDropsTheKey()
	{
		String serviceName = KeyDroppingPostOutbound.class.getName();
		registerRetryingSettingWithIdempotency(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_GATEWAY_TIMEOUT).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedAsServerErrorNotRepeated(serviceName, API_Base.HTTP_GATEWAY_TIMEOUT);
	}

	/**
	 * @description The same POST whose request drops the Idempotency-Key header, getting no response, fails at once under
	 * Idempotency Enabled: no time, no attempt spent, the labelled not-repeated line and one issue that says the external
	 * system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldFailAtOnceWhenAPostWhoseRequestDropsTheKeyGetsNoResponse()
	{
		String serviceName = KeyDroppingPostOutbound.class.getName();
		registerRetryingSettingWithIdempotency(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedAsNotRepeated(serviceName);
	}

	/**
	 * @description A POST whose handler sets the Idempotency-Key header itself in createRequest(), with no key stamped on
	 * the call and Idempotency Enabled off, was sent with a key, so it is safe to repeat: a 504 stays at Retry with a time
	 * and one attempt spent, and its issue does not say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAPostAfterAGatewayTimeoutWhenItsHandlerSetsTheKeyItself()
	{
		String serviceName = KeySettingPostOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_GATEWAY_TIMEOUT).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertRetryingAndNotFlagged(serviceName, API_Base.HTTP_GATEWAY_TIMEOUT);
	}

	/**
	 * @description The key recorded is the key sent: Idempotency Enabled has the framework work out a key, but the request
	 * sent drops the header, so the call row and its issue carry no Idempotency-Key and the logged request headers show
	 * none, agreeing with the issue's flag that the external system may have acted.
	 */
	@IsTest
	private static void shouldRecordNoKeyWhenTheRequestSentDropsIt()
	{
		String serviceName = KeyDroppingPostOutbound.class.getName();
		registerRetryingSettingWithIdempotency(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_GATEWAY_TIMEOUT).register();

		Test.startTest();
		API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time, got ' + failed.NextRetry__c);
		Assert.isTrue(String.isBlank(failed.IdempotencyKey__c), 'Expected no key on the call row, got ' + failed.IdempotencyKey__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(String.isBlank(issues[0].IdempotencyKey__c), 'Expected no key on the issue, got ' + issues[0].IdempotencyKey__c);
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted, got false');
		String loggedKey = handler.result.requestHeaders.get(API_Base.HEADER_IDEMPOTENCY_KEY);
		Assert.isNull(loggedKey, 'Expected no Idempotency-Key among the logged request headers, got ' + loggedKey);
	}

	/**
	 * @description A key stamped on the call is cleared from the record when the request sent drops it: the call row and
	 * its issue carry no Idempotency-Key, and a 504 ends the call Failed with no time, the labelled line and one issue that
	 * says the external system may have acted, so the record never shows a key that did not leave the org.
	 */
	@IsTest
	private static void shouldClearAStampedKeyWhenTheRequestSentDropsIt()
	{
		String serviceName = KeyDroppingPostOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_GATEWAY_TIMEOUT).register();
		ApiCall__c stampedCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId());
		stampedCall.IdempotencyKey__c = UTIL_Random.randomName();

		Test.startTest();
		API_Dispatcher.execute(stampedCall);
		Test.stopTest();

		assertFailedAsServerErrorNotRepeated(serviceName, API_Base.HTTP_GATEWAY_TIMEOUT);
		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName)[0];
		Assert.isTrue(String.isBlank(failed.IdempotencyKey__c), 'Expected the stamped key cleared from the call row, got ' + failed.IdempotencyKey__c);
		ApiIssue__c issue = new SEL_ApiIssue().findUnresolvedByService(serviceName)[0];
		Assert.isTrue(String.isBlank(issue.IdempotencyKey__c), 'Expected no key on the issue, got ' + issue.IdempotencyKey__c);
	}

	/**
	 * @description The key recorded is the key sent: a key the handler set on the request itself, with none stamped on the
	 * call and Idempotency Enabled off, is the key on the call row, on its issue and among the logged request headers, so
	 * a retry of the call starts from it.
	 */
	@IsTest
	private static void shouldRecordTheKeyTheHandlerSetOnTheRequestSent()
	{
		String serviceName = KeySettingPostOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_GATEWAY_TIMEOUT).register();

		Test.startTest();
		API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		Assert.isNotNull(keySetByTheHandler, 'Expected the handler to set a key of its own, got none');
		ApiCall__c retrying = SEL_ApiCall.assertServiceRetrying(serviceName)[0];
		Assert.isNotNull(retrying.NextRetry__c, 'Expected a next retry time, got null');
		Assert.areEqual(keySetByTheHandler, retrying.IdempotencyKey__c, 'Expected the call row to carry the key sent, got ' + retrying.IdempotencyKey__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.areEqual(keySetByTheHandler, issues[0].IdempotencyKey__c, 'Expected the issue to carry the key sent, got ' + issues[0].IdempotencyKey__c);
		String loggedKey = handler.result.requestHeaders.get(API_Base.HEADER_IDEMPOTENCY_KEY);
		Assert.areEqual(keySetByTheHandler, loggedKey, 'Expected the logged request headers to show the key sent, got ' + loggedKey);
	}

	/**
	 * @description A retry of a call whose first attempt recorded a key sends that same key: the scheduled retry runs the
	 * saved row, which carries the key, the handler finds it on the request and sets none of its own, and the call
	 * completes on the same row with the same key on it and among the logged request headers.
	 */
	@IsTest
	private static void shouldSendTheRecordedKeyAgainWhenTheCallIsRetried()
	{
		String serviceName = SavedKeySettingPostOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		ApiCall__c savedRow = SEL_ApiCall.assertServiceRetrying(serviceName)[0];
		Assert.isFalse(String.isBlank(savedRow.IdempotencyKey__c), 'Expected the saved row to carry a recorded key, got none');

		Test.startTest();
		API_Base handler = API_Dispatcher.execute(savedRow);
		Test.stopTest();

		Assert.isNull(keySetByTheHandler, 'Expected the handler to keep the recorded key and set none of its own, got ' + keySetByTheHandler);
		String loggedKey = handler.result.requestHeaders.get(API_Base.HEADER_IDEMPOTENCY_KEY);
		Assert.areEqual(savedRow.IdempotencyKey__c, loggedKey, 'Expected the retry to send the recorded key, got ' + loggedKey);
		ApiCall__c completed = SEL_ApiCall.assertServiceCompleted(serviceName)[0];
		Assert.areEqual(savedRow.Id, completed.Id, 'Expected the retry to complete the saved row, got ' + completed.Id);
		Assert.areEqual(savedRow.IdempotencyKey__c, completed.IdempotencyKey__c, 'Expected the row to keep the recorded key, got ' + completed.IdempotencyKey__c);
		Assert.isNull(completed.NextRetry__c, 'Expected no next retry time on the completed call, got ' + completed.NextRetry__c);
	}

	/**
	 * @description A call that fails before the send records the key the framework worked out, because no request was
	 * sent to read one from: under Idempotency Enabled a handler that throws after the framework built the request ends
	 * Failed with no time, and the call row and its issue carry the same non-blank key. With no request sent, the row
	 * records the method the handler declares, POST.
	 */
	@IsTest
	private static void shouldRecordTheComputedKeyWhenTheCallFailsBeforeTheSend()
	{
		String serviceName = KeyComputedThenThrowingPostOutbound.class.getName();
		registerRetryingSettingWithIdempotency(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time, got ' + failed.NextRetry__c);
		Assert.isFalse(String.isBlank(failed.IdempotencyKey__c), 'Expected the call row to carry the computed key, got none');
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.areEqual(failed.IdempotencyKey__c, issues[0].IdempotencyKey__c, 'Expected the issue to carry the computed key, got ' + issues[0].IdempotencyKey__c);
		String recordedMethod = readRecordedHttpMethod(serviceName);
		Assert.areEqual(API_Base.toHttpString(API_Base.HttpMethod.POST), recordedMethod, 'Expected the declared method with nothing sent, got ' + recordedMethod);
	}

	/**
	 * @description The method is judged from the request sent too: a handler that says GET but sends a POST with no
	 * Idempotency-Key is not safe to repeat, so a 504 ends it Failed with no time, no attempt spent, the labelled line and
	 * one issue that says the external system may have acted. The call row records the method that was sent, POST.
	 */
	@IsTest
	private static void shouldJudgeTheMethodFromTheRequestSent()
	{
		String serviceName = MethodChangingOutbound.class.getName();

		dispatchOneCallPerService(new Map<String, Integer> {serviceName => API_Base.HTTP_GATEWAY_TIMEOUT});

		assertFailedAsServerErrorNotRepeated(serviceName, API_Base.HTTP_GATEWAY_TIMEOUT);
		String recordedMethod = readRecordedHttpMethod(serviceName);
		Assert.areEqual(API_Base.toHttpString(API_Base.HttpMethod.POST), recordedMethod, 'Expected the call row to record the method sent, got ' + recordedMethod);
	}

	/**
	 * @description A method sent in lower case is recorded the way the call record's restricted picklist holds it: a
	 * request sent as "post" saves its row Completed with POST.
	 */
	@IsTest
	private static void shouldRecordASentMethodInLowerCaseAsThePicklistValue()
	{
		String serviceName = LowerCaseMethodOutbound.class.getName();

		dispatchOneCallPerService(new Map<String, Integer> {serviceName => API_Base.HTTP_OK});

		SEL_ApiCall.assertServiceCompleted(serviceName);
		String recordedMethod = readRecordedHttpMethod(serviceName);
		Assert.areEqual(API_Base.toHttpString(API_Base.HttpMethod.POST), recordedMethod, 'Expected the picklist value POST, got ' + recordedMethod);
	}

	/**
	 * @description A method the call record's restricted picklist does not hold is not written to it: a handler that
	 * declares GET and sends HEAD saves its row Completed, recording the declared GET, instead of making the save fail.
	 */
	@IsTest
	private static void shouldRecordTheDeclaredMethodWhenTheSentMethodIsNotAPicklistValue()
	{
		String serviceName = HeadSendingOutbound.class.getName();

		dispatchOneCallPerService(new Map<String, Integer> {serviceName => API_Base.HTTP_OK});

		SEL_ApiCall.assertServiceCompleted(serviceName);
		String recordedMethod = readRecordedHttpMethod(serviceName);
		Assert.areEqual(API_Base.toHttpString(API_Base.HttpMethod.GET), recordedMethod, 'Expected the declared GET, got ' + recordedMethod);
	}

	/**
	 * @description A status the handler adds to getRetryableStatusCodes() is the handler's own choice, so it is retried
	 * whatever the method: a POST with no Idempotency-Key that gets a 409 stays at Retry with a time, and its issue does
	 * not say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAStatusTheHandlerAddsOnAnUnkeyedPost()
	{
		String serviceName = ConflictRetryingPostOutbound.class.getName();

		dispatchOneCallPerService(new Map<String, Integer> {serviceName => API_Base.HTTP_CONFLICT});

		assertRetryingAndNotFlagged(serviceName, API_Base.HTTP_CONFLICT);
	}

	/**
	 * @description Adding a status widens the set by that status only: the same handler that retries a 409 on a POST
	 * without an Idempotency-Key still ends a 504 Failed with the labelled line and the issue flag, because 504 is in
	 * the shared default and the handler did not add it.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldNotSendAnUnkeyedPostAgainAfterAGatewayTimeoutWhenTheHandlerAddsAnotherStatus()
	{
		String serviceName = ConflictRetryingPostOutbound.class.getName();

		dispatchOneCallPerService(new Map<String, Integer> {serviceName => API_Base.HTTP_GATEWAY_TIMEOUT});

		assertFailedAsServerErrorNotRepeated(serviceName, API_Base.HTTP_GATEWAY_TIMEOUT);
	}

	/**
	 * @description A handler that leaves 500 out of its retryable statuses refuses the retry itself, so the call does not
	 * get the line about a request that is not safe to repeat, whose advice (add an idempotency key) would not help. The
	 * issue still says the external system may have acted, because that is a fact about the 500 and the POST.
	 */
	@IsTest
	private static void shouldLeaveOutTheNotRepeatedLineWhenTheHandlerLeavesTheStatusOut()
	{
		String serviceName = ServerErrorExcludingPostOutbound.class.getName();

		dispatchOneCallPerService(new Map<String, Integer> {serviceName => API_Base.HTTP_INTERNAL_SERVER_ERROR});

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time, got ' + failed.NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed), 'Expected no attempt spent, got ' + failed.Retries__c);
		String notRepeatedLine = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {serviceName, API_Base.HTTP_INTERNAL_SERVER_ERROR});
		Assert.isFalse(failed.ErrorMessages__c?.contains(notRepeatedLine) == true, 'Expected no not-repeated line, got ' + failed.ErrorMessages__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted, got false');
	}

	/**
	 * @description A parseResponse() throw after a 200 fails at once: the external system acted, so a retry would repeat
	 * its side effect. StatusCode__c keeps the 200, onSuccess() does not run, one issue is marked as one the external
	 * system acted on and carries the labelled line.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenParsingFailsAfterASuccessfulResponse()
	{
		successCount = 0;
		String serviceName = ParseThrowingOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		String acceptedLine = String.format(System.Label.OutboundCall_ExternalSystemAcceptedBeforeFailure, new List<Object> {serviceName, String.valueOf(API_Base.HTTP_OK)});
		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName, acceptedLine);
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time, got ' + failed[0].NextRetry__c);
		Assert.areEqual(String.valueOf(API_Base.HTTP_OK), failed[0].StatusCode__c, 'Expected the row to keep the 200, got ' + failed[0].StatusCode__c);
		Assert.areEqual(0, successCount, 'Expected onSuccess() not to run after a parse failure, got ' + successCount + ' runs');
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system acted');
	}

	/**
	 * @description After a 2xx an opted-in exception type retries only on a request that is safe to repeat: the same
	 * parse throw with JSONException opted in stays at Retry on a GET and ends Failed on a POST without an
	 * Idempotency-Key. The POST ends with no time and no attempt spent, carries the exception's message, and has one
	 * issue that says the external system may have acted, because it answered with a success.
	 */
	@IsTest
	private static void shouldNotResendAfterASuccessfulResponseUnlessTheRequestIsSafeToRepeat()
	{
		String getServiceName = ParseThrowingOptedInGetOutbound.class.getName();
		String postServiceName = ParseThrowingOptedInPostOutbound.class.getName();
		registerRetryingSetting(getServiceName);
		registerRetryingSetting(postServiceName);
		API_MockFactory.forService(getServiceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.forService(postServiceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		List<ApiCall__c> apiCalls = new List<ApiCall__c>
		{
				TST_Factory.newOutboundApiCall(getServiceName, UserInfo.getUserId()), TST_Factory.newOutboundApiCall(postServiceName, UserInfo.getUserId())
		};

		Test.startTest();
		API_Dispatcher.execute(apiCalls);
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(getServiceName);
		ApiCall__c post = SEL_ApiCall.assertServiceFailed(postServiceName, MESSAGE_HANDLER_THREW)[0];
		String postErrors = post.ErrorMessages__c ?? UTIL_String.EMPTY;
		Assert.isTrue(postErrors.startsWith(MESSAGE_HANDLER_THREW), 'Expected the POST\'s errors to open with the exception\'s message, got ' + postErrors);
		Assert.isNull(post.NextRetry__c, 'Expected a POST without an Idempotency-Key never to be sent again after a 2xx, got ' + post.NextRetry__c);
		Assert.areEqual(0, countRetriesOf(post), 'Expected no attempt spent on the POST, got ' + post.Retries__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(postServiceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue on the POST, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue on the POST to say the external system may have acted, got false');
	}

	/**
	 * @description A throw in the handler's own code before the send (here a NullPointerException in prepareRequest())
	 * fails at once: no time, no attempt spent, one issue. The row must never read Retry with no time, a state the
	 * scheduled retry would never pick up.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenAHandlerThrowsBeforeTheSend()
	{
		String serviceName = PrepareThrowingOutbound.class.getName();
		registerRetryingSetting(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName);
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time, got ' + failed[0].NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed[0]), 'Expected no attempt spent, got ' + failed[0].Retries__c);
		Integer issueCount = countIssuesFor(serviceName);
		Assert.areEqual(1, issueCount, 'Expected one issue, got ' + issueCount);
	}

	/**
	 * @description A handler exception retries only when its exact type is opted in, and the budget still ends it: the
	 * first dispatch stays at Retry with one attempt spent, dispatching the same row again spends the second and the
	 * third, and the dispatch that finds the budget spent ends Failed with the count at the maximum, and no new retry is scheduled.
	 */
	@IsTest
	private static void shouldRetryAHandlerExceptionOnlyWhenItsTypeIsOptedIn()
	{
		String serviceName = PrepareThrowingOptedInOutbound.class.getName();
		registerRetryingSetting(serviceName);
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId());

		Test.startTest();
		for(Integer attempt = 1; attempt <= RETRY_BUDGET; attempt++)
		{
			API_Dispatcher.execute(apiCall);
			ApiCall__c retrying = SEL_ApiCall.assertServiceRetrying(serviceName)[0];
			Assert.areEqual(attempt, countRetriesOf(retrying), 'Expected dispatch ' + attempt + ' to leave ' + attempt + ' attempts spent, got ' + retrying.Retries__c);
		}
		API_Dispatcher.execute(apiCall);
		Test.stopTest();

		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName);
		Assert.areEqual(RETRY_BUDGET, countRetriesOf(failed[0]), 'Expected the retry count to stay at the budget and never start again, got ' + failed[0].Retries__c);
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time once the budget is spent, got ' + failed[0].NextRetry__c);
	}

	/**
	 * @description A CalloutException thrown by the handler's own code (an authorisation token fetch inside setHeaders())
	 * is a handler failure, not a callout that got no response: it fails at once on a GET, where a real transport failure
	 * would retry. The framework classifies by position, never by exception type.
	 */
	@IsTest
	private static void shouldTreatACalloutExceptionFromHandlerCodeAsAHandlerFailure()
	{
		String serviceName = TokenThrowingOutbound.class.getName();
		registerRetryingSetting(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time for a handler throw, whatever its type, got ' + failed.NextRetry__c);
	}

	/**
	 * @description UTIL_Exceptions.PermanentFailureException ends the call Failed with its own message, no next retry time
	 * and one issue from each place a handler can throw it: parseResponse() (onSuccess() skipped), prepareRequest() (the
	 * dispatcher's error path), onSuccess(), and createRetryStrategy() on a 500. Only the createRetryStrategy() row is a
	 * failure the framework would otherwise retry: there the throw is honoured as the refusal it means and is not logged
	 * as a failure of the decision. The other three would end Failed without the refusal too, so they prove the message
	 * and the issue, not the outranking; shouldLetTheRefusalOutrankTheOptIn proves the refusal wins over an opted-in
	 * type. The batch puts every call that makes a callout before the calls that fail through the dispatcher's error
	 * path, whose saved log rows would make the platform refuse a later callout in the same test transaction.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenTheHandlerRefusesTheRetry()
	{
		LOG_Builder.ignoreTestMode = true;
		successCount = 0;
		String strategyServiceName = RefusingStrategyOutbound.class.getName();
		List<String> serviceNames = new List<String>
		{
				RefusingParseOutbound.class.getName(), strategyServiceName, RefusingOnSuccessOutbound.class.getName(), RefusingPrepareOutbound.class.getName()
		};
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();
		for(String serviceName : serviceNames)
		{
			registerRetryingSetting(serviceName);
			apiCalls.add(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		}
		API_MockFactory.forService(RefusingParseOutbound.class.getName()).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.forService(RefusingOnSuccessOutbound.class.getName()).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.registerErrorMock(strategyServiceName);

		Test.startTest();
		API_Dispatcher.execute(apiCalls);
		Test.stopTest();

		for(String serviceName : serviceNames)
		{
			ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0];
			Assert.isNull(failed.NextRetry__c, 'Expected no next retry time for ' + serviceName + ', got ' + failed.NextRetry__c);
			Integer issueCount = countIssuesFor(serviceName);
			Assert.areEqual(1, issueCount, 'Expected one issue for ' + serviceName + ', got ' + issueCount);
		}
		Assert.areEqual(0, successCount, 'Expected onSuccess() not to run after a refusal in parseResponse(), got ' + successCount + ' runs');
		LogEntry__c decisionFailureEntry = new SEL_LogEntry().findByMethod(strategyServiceName + '/retry');
		Assert.isNull(decisionFailureEntry, 'Expected the refusal from createRetryStrategy() not to be logged as a decision failure, got ' + decisionFailureEntry);
	}

	/**
	 * @description UTIL_Exceptions.RequestRefusedException thrown from parseResponse() after a success status ends the call
	 * Failed with no next retry time and one issue whose External System May Have Acted box is clear: a refusal in the
	 * body means the external system did not act. Thrown from onSuccess() the same exception leaves the box ticked, because
	 * by then the external system has acted; and the plain PermanentFailureException from parseResponse() leaves it ticked
	 * too. The three calls are sent in one batch, all answered 200; the onSuccess() refusal goes last, because its throw
	 * leaves work pending that would make the platform refuse a later callout in the same test transaction.
	 */
	@IsTest
	private static void shouldClearTheFlagOnlyWhenParseResponseRefusesTheRequest()
	{
		LOG_Builder.ignoreTestMode = true;
		String parseRefusal = RefusingRequestInParseOutbound.class.getName();
		String onSuccessRefusal = RefusingRequestInOnSuccessOutbound.class.getName();
		String plainRefusal = RefusingParseOutbound.class.getName();
		List<String> serviceNames = new List<String> {parseRefusal, plainRefusal, onSuccessRefusal};
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();
		for(String serviceName : serviceNames)
		{
			registerRetryingSetting(serviceName);
			API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
			apiCalls.add(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		}

		Test.startTest();
		API_Dispatcher.execute(apiCalls);
		Test.stopTest();

		Assert.isFalse(readTheOneIssue(parseRefusal).ExternalSystemMayHaveActed__c, 'Expected a refusal read from a success body to leave the flag clear');
		Assert.isTrue(readTheOneIssue(onSuccessRefusal).ExternalSystemMayHaveActed__c, 'Expected a refusal thrown from onSuccess() to leave the flag set');
		Assert.isTrue(readTheOneIssue(plainRefusal).ExternalSystemMayHaveActed__c, 'Expected the plain permanent failure to leave the flag set');
		for(String serviceName : serviceNames)
		{
			ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0];
			Assert.isNull(failed.NextRetry__c, 'Expected no next retry time for ' + serviceName + ', got ' + failed.NextRetry__c);
		}
	}

	/**
	 * @description Reads the one open issue of a service, asserting there is exactly one.
	 *
	 * @param serviceName The service whose issue to read
	 *
	 * @return The issue
	 */
	private static ApiIssue__c readTheOneIssue(String serviceName)
	{
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue for ' + serviceName + ', got ' + issues.size());
		return issues.get(0);
	}

	/**
	 * @description The refusal outranks the opt-in: a UTIL_Exceptions.PermanentFailureException whose own type is listed in
	 * getRetryableExceptionTypes() still ends the call Failed.
	 */
	@IsTest
	private static void shouldLetTheRefusalOutrankTheOptIn()
	{
		String serviceName = RefusingOptedInOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected the refusal to win over the opt-in, got a next retry time ' + failed.NextRetry__c);
	}

	/**
	 * @description A UTIL_Exceptions.PermanentFailureException thrown from validation means Aborted, because a refusal in
	 * validation always does.
	 */
	@IsTest
	private static void shouldEndAbortedWhenTheRefusalComesFromValidation()
	{
		String serviceName = RefusingValidationOutbound.class.getName();
		registerRetryingSetting(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c aborted = SEL_ApiCall.assertServiceAborted(serviceName, MESSAGE_HANDLER_THREW)[0];
		Assert.isNull(aborted.NextRetry__c, 'Expected no next retry time on an aborted call, got ' + aborted.NextRetry__c);
	}

	/**
	 * @description createRetryStrategy() runs after the response has arrived, so it may read result.responseBody.
	 * Returning a strategy whose shouldRetry is false refuses a 500 whose body shows the failure is permanent. The GET
	 * ends Failed with no time and no attempt spent, and its one issue does not say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldLetTheStrategyRefuseAStatusFailureItReadsAsPermanent()
	{
		String serviceName = BodyReadingStrategyOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(PERMANENT_BODY_MARKER).statusCode(API_Base.HTTP_INTERNAL_SERVER_ERROR).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedAndNotFlagged(serviceName, API_Base.HTTP_INTERNAL_SERVER_ERROR);
	}

	/**
	 * @description An open circuit on a call whose setting allows retries never ends Aborted: with budget left the call
	 * is scheduled at the cool-off and spends one attempt; with the budget spent it ends Failed with one issue and the
	 * labelled line, as any failure whose retries are used up does. The breaker is forced open before the dispatch, so no
	 * send happens; each row is read back by its id. In an org whose org cache has no space set aside, the open state
	 * cannot be saved, so the breaker the handler builds would start CLOSED and no call could meet an open circuit: the
	 * test checks that a new breaker for the service starts CLOSED instead.
	 */
	@IsTest
	private static void shouldScheduleAtTheCoolOffWhenTheCircuitIsOpenAndBudgetRemains()
	{
		String serviceName = RetryProbeOutbound.class.getName();
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET, ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.LogIssues__c => true, ApiSetting__mdt.CircuitBreakerEnabled__c => true, ApiSetting__mdt.CircuitBreakerTimeout__c => CIRCUIT_TIMEOUT_SECONDS
		});
		ApiCall__c exhaustedCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId());
		exhaustedCall.Retries__c = RETRY_BUDGET;
		String circuitOpenLine = String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {serviceName});

		try
		{
			UTIL_CircuitBreaker.monitor(serviceName).forceOpen();
			if(!UTIL_Cache.isOrgAllocated())
			{
				assertTheNextBreakerStartsClosed(serviceName);
				return;
			}
			Datetime beforeDispatch = Datetime.now();

			Test.startTest();
			ApiCall__c scheduled = dispatch(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
			ApiCall__c failed = dispatch(exhaustedCall);
			Test.stopTest();

			Assert.areEqual(SEL_ApiCall.STATUS_RETRY, scheduled.Status__c, 'Expected the call to wait at Retry for the cool-off while budget remains, got ' + scheduled.Status__c);
			Assert.areEqual(1, countRetriesOf(scheduled), 'Expected one attempt spent waiting for the cool-off, got ' + scheduled.Retries__c);
			Datetime earliestRetry = beforeDispatch.addSeconds(CIRCUIT_TIMEOUT_SECONDS - ONE_SECOND_TOLERANCE);
			Assert.isTrue(scheduled.NextRetry__c >= earliestRetry, 'Expected a wait of at least the cool-off, got ' + scheduled.NextRetry__c);
			Assert.areEqual(SEL_ApiCall.STATUS_FAILED, failed.Status__c, 'Expected Failed, not Aborted, once the budget is spent, got ' + failed.Status__c);
			Assert.isNull(failed.NextRetry__c, 'Expected no next retry time once the budget is spent, got ' + failed.NextRetry__c);
			Assert.areEqual(RETRY_BUDGET, countRetriesOf(failed), 'Expected the count to stay at the maximum, with no new retry scheduled, got ' + failed.Retries__c);
			Assert.isTrue(failed.ErrorMessages__c.contains(circuitOpenLine), 'Expected the labelled open-circuit line, got ' + failed.ErrorMessages__c);
			Integer issueCount = countIssuesFor(serviceName);
			Assert.areEqual(2, issueCount, 'Expected one issue per attempt, the scheduled one and the failed one, got ' + issueCount);
		}
		finally
		{
			UTIL_CircuitBreaker.monitor(serviceName).reset();
		}
	}

	/**
	 * @description An open circuit on a call whose setting allows no retries ends Aborted with the labelled line, as every
	 * validation refusal does: there is no budget to wait with, so nothing is scheduled and the call never left the org.
	 * In an org whose org cache has no space set aside, the open state cannot be saved, so the test checks that a new
	 * breaker for the service starts CLOSED instead.
	 */
	@IsTest
	private static void shouldAbortAnOpenCircuitRefusalOnACallThatAllowsNoRetries()
	{
		String serviceName = RetryProbeOutbound.class.getName();
		registerSettingWithoutRetryBudget(serviceName);
		String circuitOpenLine = String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {serviceName});

		try
		{
			UTIL_CircuitBreaker.monitor(serviceName).forceOpen();
			if(!UTIL_Cache.isOrgAllocated())
			{
				assertTheNextBreakerStartsClosed(serviceName);
				return;
			}

			Test.startTest();
			ApiCall__c aborted = dispatch(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
			Test.stopTest();

			Assert.areEqual(SEL_ApiCall.STATUS_ABORTED, aborted.Status__c, 'Expected a call that allows no retries to end Aborted, got ' + aborted.Status__c);
			Assert.isNull(aborted.NextRetry__c, 'Expected no next retry time on an aborted call, got ' + aborted.NextRetry__c);
			Assert.isTrue(aborted.ErrorMessages__c.contains(circuitOpenLine), 'Expected the labelled open-circuit line, got ' + aborted.ErrorMessages__c);
		}
		finally
		{
			UTIL_CircuitBreaker.monitor(serviceName).reset();
		}
	}

	/**
	 * @description A half-open circuit whose trial calls were never sent recovers. The breaker is forced open and its zero
	 * cool-off passes, so the circuit is half-open when the calls arrive. Three calls dispatched after a save in the same
	 * transaction are let through as trial calls, refused by the platform before they leave the org, and stay at Retry
	 * with a time. Each of them uses exactly one trial request, when it is let through, and records neither a success nor
	 * a failure; scheduling its retry uses none. The three calls therefore use the round's three trial requests and no
	 * more. The later call arrives with no trial request left and the zero cool-off passed since the round began, so a
	 * new round starts and the call is let through: it gets a 200 response, completes, and its success closes the
	 * circuit. The calls that are never sent run before Test.startTest() and the call that is sent runs after it, because
	 * the platform allows a callout again from there.
	 */
	@IsTest
	private static void shouldLetALaterCallThroughWhenTheTrialCallsOfAHalfOpenCircuitWereNeverSent()
	{
		String serviceName = PostTransportOutbound.class.getName();
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET, ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS, ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.CircuitBreakerEnabled__c => true, ApiSetting__mdt.CircuitBreakerTimeout__c => IMMEDIATE_CIRCUIT_TIMEOUT_SECONDS,
				ApiSetting__mdt.CircuitBreakerSuccessThreshold__c => 1
		});
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		UTIL_CircuitBreaker.monitor(serviceName).forceOpen();
		TST_Builder.of(Foobar__c.SObjectType).build();
		List<ApiCall__c> neverSentCalls = dispatchOneCallPerTrialRequest(serviceName);

		Test.startTest();
		ApiCall__c completed = dispatch(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		for(ApiCall__c neverSent : neverSentCalls)
		{
			Assert.areEqual(SEL_ApiCall.STATUS_RETRY, neverSent.Status__c, 'Expected a call that was never sent to stay at Retry, got ' + neverSent.Status__c);
			Assert.isNotNull(neverSent.NextRetry__c, 'Expected a next retry time on a call that was never sent, got none');
			String errorText = neverSent.ErrorMessages__c;
			Assert.isTrue(errorText.contains(MESSAGE_UNCOMMITTED_WORK), 'Expected the platform\'s refusal on a trial call that was never sent, got ' + errorText);
		}
		String completedSummary = completed.Status__c + ': ' + completed.ErrorMessages__c;
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, completed.Status__c, 'Expected the later call to be let through and complete, got ' + completedSummary);
		UTIL_CircuitBreaker.State stateAfterTheSuccess = UTIL_CircuitBreaker.monitor(serviceName).getState();
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, stateAfterTheSuccess, 'Expected the completed call to close the circuit, got ' + stateAfterTheSuccess);
	}

	/**
	 * @description Working out the wait of a retry uses no trial request of a half-open circuit. The circuit is half-open
	 * with three trial requests and a cool-off that does not pass during the test, so no new round can start. Three calls
	 * are dispatched after a save in the same transaction, so the platform refuses each callout before it leaves the org.
	 * Each call uses one trial request when it is let through, and scheduling its retry uses none, so the third call is
	 * still let through by the circuit: like the first two it stays at Retry with a time and carries the platform's own
	 * message, never the open-circuit line. If scheduling a retry used a trial request, the first two calls would use
	 * all three and the circuit would refuse the third. In an org whose org cache has no space set aside, the half-open
	 * state cannot be saved, so the test checks that a new breaker for the service starts CLOSED instead.
	 */
	@IsTest
	private static void shouldLeaveTheTrialRequestsOfAHalfOpenCircuitAloneWhenARetryIsScheduled()
	{
		String serviceName = PostTransportOutbound.class.getName();
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET, ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS, ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.CircuitBreakerEnabled__c => true, ApiSetting__mdt.CircuitBreakerTimeout__c => LONG_CIRCUIT_TIMEOUT_SECONDS
		});
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		String circuitOpenLine = String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {serviceName});
		List<ApiCall__c> neverSentCalls;

		try
		{
			UTIL_CircuitBreaker.State stateBeforeTheCalls = moveTheCircuitToHalfOpen(serviceName);
			if(!UTIL_Cache.isOrgAllocated())
			{
				assertTheNextBreakerStartsClosed(serviceName);
				return;
			}
			Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, stateBeforeTheCalls, 'Expected the circuit to be half-open before the calls, got ' + stateBeforeTheCalls);

			Test.startTest();
			TST_Builder.of(Foobar__c.SObjectType).build();
			neverSentCalls = dispatchOneCallPerTrialRequest(serviceName);
			Test.stopTest();
		}
		finally
		{
			UTIL_CircuitBreaker.monitor(serviceName).reset();
		}

		for(Integer position = 0; position < HALF_OPEN_TRIAL_REQUESTS; position++)
		{
			ApiCall__c neverSent = neverSentCalls[position];
			String errorText = neverSent.ErrorMessages__c;
			String callName = 'call ' + (position + 1) + ' of ' + HALF_OPEN_TRIAL_REQUESTS;
			Assert.areEqual(SEL_ApiCall.STATUS_RETRY, neverSent.Status__c, 'Expected ' + callName + ' to stay at Retry, got ' + neverSent.Status__c);
			Assert.isNotNull(neverSent.NextRetry__c, 'Expected a next retry time on ' + callName + ', got none');
			Assert.isTrue(errorText.contains(MESSAGE_UNCOMMITTED_WORK), 'Expected ' + callName + ' to be refused by the platform, got ' + errorText);
			Assert.isFalse(errorText.contains(circuitOpenLine), 'Expected ' + callName + ' to be let through by the circuit, got the open-circuit line: ' + errorText);
		}
	}

	/**
	 * @description A call the half-open circuit refuses waits for the cool-off, as a call the open circuit refuses does.
	 * The circuit is half-open with three trial requests and a cool-off longer than the retry backoff that does not pass
	 * during the test. Three calls dispatched after a save use the three trial requests (the platform refuses each before
	 * it leaves the org); the fourth finds none left and is refused by the circuit with the labelled line. It stays at
	 * Retry with one attempt spent and a next retry time at or after the cool-off, not after the shorter backoff, and none
	 * of the four issues says the external system may have acted. In an org whose org cache has no space set aside, the
	 * half-open state cannot be saved, so the test checks that a new breaker for the service starts CLOSED instead.
	 */
	@IsTest
	private static void shouldWaitForTheCoolOffWhenAHalfOpenCircuitWithNoTrialLeftRefusesTheCall()
	{
		String serviceName = PostTransportOutbound.class.getName();
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET, ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS, ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.CircuitBreakerEnabled__c => true, ApiSetting__mdt.CircuitBreakerTimeout__c => LONG_CIRCUIT_TIMEOUT_SECONDS
		});
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		String circuitOpenLine = String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {serviceName});
		ApiCall__c refused;
		Datetime beforeTheRefusedCall;

		try
		{
			UTIL_CircuitBreaker.State stateBeforeTheCalls = moveTheCircuitToHalfOpen(serviceName);
			if(!UTIL_Cache.isOrgAllocated())
			{
				assertTheNextBreakerStartsClosed(serviceName);
				return;
			}
			Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, stateBeforeTheCalls, 'Expected the circuit to be half-open before the calls, got ' + stateBeforeTheCalls);

			Test.startTest();
			TST_Builder.of(Foobar__c.SObjectType).build();
			dispatchOneCallPerTrialRequest(serviceName);
			beforeTheRefusedCall = Datetime.now();
			refused = dispatch(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
			Test.stopTest();
		}
		finally
		{
			UTIL_CircuitBreaker.monitor(serviceName).reset();
		}

		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, refused.Status__c, 'Expected the refused call to wait at Retry, got ' + refused.Status__c);
		Assert.isTrue(refused.ErrorMessages__c.contains(circuitOpenLine), 'Expected the labelled open-circuit line, got ' + refused.ErrorMessages__c);
		Assert.areEqual(1, countRetriesOf(refused), 'Expected one attempt spent waiting for the cool-off, got ' + refused.Retries__c);
		Datetime earliestRetry = beforeTheRefusedCall.addSeconds(LONG_CIRCUIT_TIMEOUT_SECONDS - ONE_SECOND_TOLERANCE);
		Assert.isTrue(refused.NextRetry__c >= earliestRetry, 'Expected a next retry time at or after ' + earliestRetry + ', got ' + refused.NextRetry__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(HALF_OPEN_TRIAL_REQUESTS + 1, issues.size(), 'Expected one issue per call, got ' + issues.size());
		for(ApiIssue__c issue : issues)
		{
			Assert.isFalse(issue.ExternalSystemMayHaveActed__c, 'Expected no issue to say the external system may have acted, got true on ' + issue.Id);
		}
	}

	/**
	 * @description The send point has two branches: the framework's own mock responds when mocking is enabled for the
	 * service (API_MockFactory.enableMocking), and the platform's send otherwise, which in a unit test runs the registered
	 * mock through Test.setMock. Every other test of this class takes the second branch; this one takes the first, so a
	 * throw from the framework's own mock is classified as a callout that got no response too and the GET stays at Retry.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldClassifyAThrowFromTheFrameworksOwnMockAsACallThatGotNoResponse()
	{
		String serviceName = RetryProbeOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();
		API_MockFactory.enableMocking(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(serviceName);
	}

	/**
	 * @description The external system acted before a refusal from parseResponse(), and the issue says so: the flag
	 * follows the phase on every exit of the decision, the refusal included. This is the "200 whose body carries a
	 * business failure" recipe the guide teaches; the operator must see the box checked before pressing Retry.
	 */
	@IsTest
	private static void shouldMarkTheExternalSystemAsHavingActedWhenTheHandlerRefusesAfterASuccess()
	{
		String serviceName = RefusingParseOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time after the refusal, got ' + failed.NextRetry__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system acted before the refusal');
	}

	/**
	 * @description A handler whose self-retry scheduling is suppressed (the async chain's per-step retry owns the retry)
	 * still gets the fact onto its issue: a POST without an Idempotency-Key that got no response ends Failed with no
	 * time, and the issue says the external system may have acted, because the flag is derived before the suppression
	 * stops the decision.
	 */
	@IsTest
	private static void shouldMarkTheExternalSystemAsHavingActedWhenSelfRetrySchedulingIsSuppressed()
	{
		String serviceName = SuppressedPostOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected a suppressed handler to schedule nothing, got ' + failed.NextRetry__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted');
	}

	/**
	 * @description The breaker record on a callout that got no response is guarded: when the breaker itself fails, the
	 * transport failure still reaches the decision and the GET stays at Retry, and the breaker's failure is logged at
	 * warn under the handler's send method.
	 */
	@IsTest
	private static void shouldKeepTheTransportFailureWhenTheBreakerCannotRecordIt()
	{
		LOG_Builder.ignoreTestMode = true;
		API_Outbound.simulateCircuitBreakerFailure = true;
		String serviceName = RetryProbeOutbound.class.getName();
		registerRetryingSettingWithCircuitBreaker(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(serviceName);
		Assert.isNotNull(new SEL_LogEntry().findByMethod(serviceName + '/sendRequest'), 'Expected the breaker failure to be logged under the send');
	}

	/**
	 * @description A backoff of zero schedules nothing although budget remains: a zero wait never means "retry now", so
	 * the call ends Failed with no next retry time. A scheduled retry needs a wait.
	 */
	@IsTest
	private static void shouldNotScheduleWhenTheBackoffIsZero()
	{
		String serviceName = RetryProbeOutbound.class.getName();
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET, ApiSetting__mdt.RetryBackoffSeconds__c => 0
		});
		API_MockFactory.registerErrorMock(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected a zero wait to schedule nothing, got ' + failed.NextRetry__c);
	}

	/**
	 * @description A handler whose createRetryStrategy() throws costs its own call only: that row ends Failed with the
	 * labelled decision text and one issue, and the second call of the batch completes and is saved. A throw that escaped
	 * the dispatcher would leave no row of the batch saved.
	 */
	@IsTest
	private static void shouldKeepTheBatchWhenOneHandlersRetryStrategyThrows()
	{
		String throwingServiceName = ThrowingStrategyOutbound.class.getName();
		String completingServiceName = CompletingOutbound.class.getName();
		registerRetryingSetting(throwingServiceName);
		registerRetryingSetting(completingServiceName);
		API_MockFactory.registerErrorMock(throwingServiceName);
		API_MockFactory.forService(completingServiceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		List<ApiCall__c> apiCalls = new List<ApiCall__c>
		{
				TST_Factory.newOutboundApiCall(throwingServiceName, UserInfo.getUserId()), TST_Factory.newOutboundApiCall(completingServiceName, UserInfo.getUserId())
		};

		Test.startTest();
		API_Dispatcher.execute(apiCalls);
		Test.stopTest();

		String decisionFailedLine = String.format(System.Label.OutboundCall_RetryDecisionFailed, new List<Object> {throwingServiceName, MESSAGE_HANDLER_THREW});
		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(throwingServiceName, decisionFailedLine)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time on the throwing call, got ' + failed.NextRetry__c);
		Integer issueCount = countIssuesFor(throwingServiceName);
		Assert.areEqual(1, issueCount, 'Expected one issue on the throwing call, got ' + issueCount);
		ApiCall__c completed = SEL_ApiCall.assertServiceCompleted(completingServiceName)[0];
		Assert.isNull(completed.NextRetry__c, 'Expected no next retry time on the completed call, got ' + completed.NextRetry__c);
	}

	/**
	 * @description A handleError override that throws on the dispatcher's error path costs its own call only: the row
	 * ends Failed carrying both messages (the transport failure the call met and the one its error handling threw), with
	 * no next retry time and no issue, and the batch's other call completes. The completing call goes first, so its
	 * callout runs before the failed call's log rows are saved.
	 */
	@IsTest
	private static void shouldKeepTheBatchWhenAHandleErrorOverrideThrows()
	{
		String throwingServiceName = ThrowingHandleErrorOutbound.class.getName();
		String completingServiceName = CompletingOutbound.class.getName();
		registerRetryingSetting(throwingServiceName);
		registerRetryingSetting(completingServiceName);
		API_MockFactory.forService(throwingServiceName).withTransportFailure().register();
		API_MockFactory.forService(completingServiceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		List<ApiCall__c> apiCalls = new List<ApiCall__c>
		{
				TST_Factory.newOutboundApiCall(completingServiceName, UserInfo.getUserId()), TST_Factory.newOutboundApiCall(throwingServiceName, UserInfo.getUserId())
		};

		Test.startTest();
		API_Dispatcher.execute(apiCalls);
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(throwingServiceName, MESSAGE_HANDLER_THREW)[0];
		String errorText = failed.ErrorMessages__c;
		Assert.isTrue(errorText.contains(MESSAGE_MOCKED_TRANSPORT_FAILURE), 'Expected the row to keep the call\'s own failure beside the handler\'s, got ' + errorText);
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time on the throwing call, got ' + failed.NextRetry__c);
		Integer issueCount = countIssuesFor(throwingServiceName);
		Assert.areEqual(0, issueCount, 'Expected no issue, because building one runs the handler code that threw, got ' + issueCount);
		ApiCall__c completed = SEL_ApiCall.assertServiceCompleted(completingServiceName)[0];
		Assert.isNull(completed.NextRetry__c, 'Expected no next retry time on the completed call, got ' + completed.NextRetry__c);
	}

	/**
	 * @description Asserts that a call that got no response and could not be repeated ended Failed with no time, no attempt
	 * spent, the labelled not-repeated line, and one issue marked as one the external system may have acted on.
	 *
	 * @param serviceName The handler whose row and issue are read back.
	 */
	private static void assertFailedAsNotRepeated(String serviceName)
	{
		String notRepeatedLine = String.format(System.Label.OutboundCall_NoResponseNotRepeated, new List<Object> {serviceName});
		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, notRepeatedLine)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time on ' + serviceName + ', got ' + failed.NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed), 'Expected no attempt spent on ' + serviceName + ', got ' + failed.Retries__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue on ' + serviceName + ', got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue on ' + serviceName + ' to say the external system may have acted');
	}

	/**
	 * @description Asserts that a call the platform refused before it left the org left one issue that does not blame the
	 * external system: the box is unchecked, the not-repeated line is absent, and the circuit breaker counted no failure.
	 *
	 * @param serviceName The handler whose issue and breaker are read back.
	 *
	 * @return The service's open issues.
	 */
	private static List<ApiIssue__c> assertNothingBlamesTheExternalSystem(String serviceName)
	{
		String notRepeatedLine = String.format(System.Label.OutboundCall_NoResponseNotRepeated, new List<Object> {serviceName});
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue on ' + serviceName + ', got ' + issues.size());
		Assert.isFalse(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue not to say the external system may have acted: nothing was sent');
		Assert.isFalse(issues[0].ErrorMessages__c.contains(notRepeatedLine), 'Expected no not-repeated line on the issue, got ' + issues[0].ErrorMessages__c);
		Integer failureCount = UTIL_CircuitBreaker.monitor(serviceName).getMetrics().failureCount;
		Assert.areEqual(0, failureCount, 'Expected no circuit breaker failure for a callout that never left the org, got ' + failureCount);
		return issues;
	}

	/**
	 * @description Registers the retrying setting and a mocked response for each handler, then dispatches one call per
	 * handler in one batch, so every callout is made before any call is saved.
	 *
	 * @param statusByService The status each handler's mocked external system responds with, by handler class name.
	 */
	private static void dispatchOneCallPerService(Map<String, Integer> statusByService)
	{
		dispatchOneCallPerService(statusByService, false);
	}

	/**
	 * @description Registers the retrying setting, with or without Idempotency Enabled, and a mocked response for each
	 * handler, then dispatches one call per handler in one batch, so every callout is made before any call is saved.
	 *
	 * @param statusByService The status each handler's mocked external system responds with, by handler class name.
	 * @param isIdempotencyEnabled Whether the setting has the framework work out a key for each call.
	 */
	private static void dispatchOneCallPerService(Map<String, Integer> statusByService, Boolean isIdempotencyEnabled)
	{
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();
		for(String serviceName : statusByService.keySet())
		{
			if(isIdempotencyEnabled)
			{
				registerRetryingSettingWithIdempotency(serviceName);
			}
			else
			{
				registerRetryingSetting(serviceName);
			}
			API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(statusByService.get(serviceName)).register();
			apiCalls.add(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		}

		Test.startTest();
		API_Dispatcher.execute(apiCalls);
		Test.stopTest();
	}

	/**
	 * @description Asserts that a call whose request was not safe to repeat ended Failed after a server error: no time, no
	 * attempt spent, the labelled line saying it was not sent again on the row and on its issue, and one issue that says
	 * the external system may have acted.
	 *
	 * @param serviceName The handler whose row and issue are read back.
	 * @param statusCode The status the external system responded with.
	 */
	private static void assertFailedAsServerErrorNotRepeated(String serviceName, Integer statusCode)
	{
		String notRepeatedLine = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {serviceName, statusCode});
		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, notRepeatedLine)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time after status ' + statusCode + ', got ' + failed.NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed), 'Expected no attempt spent after status ' + statusCode + ', got ' + failed.Retries__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue after status ' + statusCode + ', got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue after status ' + statusCode + ' to say the external system may have acted, got false');
		Assert.isTrue(issues[0].ErrorMessages__c.contains(notRepeatedLine), 'Expected the issue to carry the not-repeated line, got ' + issues[0].ErrorMessages__c);
	}

	/**
	 * @description Asserts that a call stays at Retry with a time and one attempt spent, and that its one issue does not
	 * say the external system may have acted.
	 *
	 * @param serviceName The handler whose row and issue are read back.
	 * @param statusCode The status the external system responded with.
	 */
	private static void assertRetryingAndNotFlagged(String serviceName, Integer statusCode)
	{
		ApiCall__c retrying = SEL_ApiCall.assertServiceRetrying(serviceName)[0];
		Assert.isNotNull(retrying.NextRetry__c, 'Expected a next retry time after status ' + statusCode + ', got null');
		Assert.areEqual(1, countRetriesOf(retrying), 'Expected status ' + statusCode + ' to spend one attempt, got ' + retrying.Retries__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue after status ' + statusCode + ', got ' + issues.size());
		Assert.isFalse(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue after status ' + statusCode + ' not to say the external system may have acted, got true');
	}

	/**
	 * @description Asserts that a call ended Failed at once after a status: no time, no attempt spent, no line saying the
	 * call was not sent again, and one issue that does not say the external system may have acted.
	 *
	 * @param serviceName The handler whose row and issue are read back.
	 * @param statusCode The status the external system responded with.
	 */
	private static void assertFailedAndNotFlagged(String serviceName, Integer statusCode)
	{
		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName)[0];
		String errors = failed.ErrorMessages__c ?? UTIL_String.EMPTY;
		String serverErrorLine = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {serviceName, statusCode});
		String noResponseLine = String.format(System.Label.OutboundCall_NoResponseNotRepeated, new List<Object> {serviceName});
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time after status ' + statusCode + ', got ' + failed.NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed), 'Expected status ' + statusCode + ' to spend no attempt, got ' + failed.Retries__c);
		Assert.isFalse(errors.contains(serverErrorLine) || errors.contains(noResponseLine), 'Expected no not-repeated line after status ' + statusCode + ', got ' + errors);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue after status ' + statusCode + ', got ' + issues.size());
		Assert.isFalse(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue after status ' + statusCode + ' not to say the external system may have acted, got true');
	}

	/**
	 * @description Reads the HTTP method recorded on the service's saved call row. The call selector does not select that
	 * field, so the read goes through QRY_Builder.
	 *
	 * @param serviceName The handler whose row is read back.
	 *
	 * @return The recorded method.
	 */
	private static String readRecordedHttpMethod(String serviceName)
	{
		ApiCall__c saved = (ApiCall__c)QRY_Builder.selectFrom(ApiCall__c.SObjectType)
				.fields(new List<SObjectField> {ApiCall__c.HttpMethod__c})
				.condition(ApiCall__c.ServiceName__c).equals(serviceName)
				.getFirst();
		return saved?.HttpMethod__c;
	}

	/**
	 * @description Registers the mocked setting the dispatcher-created handler reads: retries on, a wait, issues logged.
	 * A test with several handlers registers one setting per handler with these same values, because the mock hands the
	 * first registered row to every setting lookup of the test.
	 *
	 * @param serviceName The handler class the setting names.
	 */
	private static void registerRetryingSetting(String serviceName)
	{
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET,
				ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.LogIssues__c => true
		});
	}

	/**
	 * @description Registers the retrying setting with Idempotency Enabled, so the framework works out a key for a POST.
	 *
	 * @param serviceName The handler class the setting names.
	 */
	private static void registerRetryingSettingWithIdempotency(String serviceName)
	{
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET, ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.LogIssues__c => true, ApiSetting__mdt.IdempotencyEnabled__c => true
		});
	}

	/**
	 * @description Registers the retrying setting with the circuit breaker turned on.
	 *
	 * @param serviceName The handler class the setting names.
	 */
	private static void registerRetryingSettingWithCircuitBreaker(String serviceName)
	{
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET, ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.LogIssues__c => true, ApiSetting__mdt.CircuitBreakerEnabled__c => true
		});
	}

	/**
	 * @description Registers a setting that allows no retries, with a wait, issues logged and the circuit breaker on.
	 *
	 * @param serviceName The handler class the setting names.
	 */
	private static void registerSettingWithoutRetryBudget(String serviceName)
	{
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => 0, ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.LogIssues__c => true, ApiSetting__mdt.CircuitBreakerEnabled__c => true
		});
	}

	/**
	 * @description Dispatches one new call of a service and reads the saved row back, so a test that dispatches several
	 * calls of one service asserts each row on its own.
	 *
	 * @param apiCall The call to dispatch.
	 *
	 * @return The saved row.
	 */
	private static ApiCall__c dispatch(ApiCall__c apiCall)
	{
		API_Base handler = API_Dispatcher.execute(apiCall);
		return (ApiCall__c)new SEL_ApiCall().findById(handler.apiCall.Id);
	}

	/**
	 * @description Dispatches one new call of a service for each trial request a half-open circuit lets through in one
	 * round, one call after the other, and reads each saved row back.
	 *
	 * @param serviceName The handler to dispatch.
	 *
	 * @return The saved rows, in dispatch order.
	 */
	private static List<ApiCall__c> dispatchOneCallPerTrialRequest(String serviceName)
	{
		List<ApiCall__c> savedCalls = new List<ApiCall__c>();
		for(Integer trial = 0; trial < HALF_OPEN_TRIAL_REQUESTS; trial++)
		{
			savedCalls.add(dispatch(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())));
		}
		return savedCalls;
	}

	/**
	 * @description Prepares a test that dispatches the call row the test setup saved: resets the send counter, registers
	 * the setting and a successful response for the row's service, and reads the row. Reading comes last and writes nothing,
	 * so the test's callout still happens before anything in the test writes.
	 *
	 * @return The saved call row.
	 */
	private static ApiCall__c prepareSavedRowCall()
	{
		sendCount = 0;
		String serviceName = SavedRowOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		return new SEL_ApiCall().findByServiceName(serviceName)[0];
	}

	/**
	 * @description Dispatches one call while a stand-in refuses the first statements of the handler's commit with a lock
	 * refusal, and takes the stand-in away again whatever happens. The stand-in is set after the test has started, so it
	 * refuses only the commit's statements.
	 *
	 * @param apiCall The call to dispatch.
	 * @param lockProxy The stand-in that refuses the statements.
	 *
	 * @return The handler that ran the call.
	 */
	private static API_Base dispatchWithLockRefusals(ApiCall__c apiCall, DML_ThrowingLockProxy_TEST lockProxy)
	{
		try
		{
			Test.startTest();
			DML_SharingProxy.sharingProxyForTest = lockProxy;
			API_Base handler = API_Dispatcher.execute(apiCall);
			Test.stopTest();
			return handler;
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}
	}

	/**
	 * @description Takes a service's circuit to half-open with no trial request used. One breaker opens the circuit; a
	 * second breaker for the same circuit, with a zero cool-off and built once the clock has moved on by a millisecond,
	 * reads the cool-off as passed and moves the circuit to half-open. That state is saved, so the breaker the handler
	 * builds from its setting finds the circuit half-open.
	 *
	 * @param serviceName The service whose circuit is taken to half-open.
	 *
	 * @return The state the circuit was left in, for the test to check.
	 */
	private static UTIL_CircuitBreaker.State moveTheCircuitToHalfOpen(String serviceName)
	{
		UTIL_CircuitBreaker.monitor(serviceName).forceOpen();
		Long openedAt = Datetime.now().getTime();
		Long currentTime = openedAt;
		while(currentTime == openedAt)
		{
			currentTime = Datetime.now().getTime();
		}
		return UTIL_CircuitBreaker.monitor(serviceName).withTimeout(IMMEDIATE_CIRCUIT_TIMEOUT_SECONDS).getState();
	}

	/**
	 * @description Checks what a circuit breaker does in an org whose org cache has no space set aside. A breaker keeps
	 * its state in the org cache only, so the state an earlier breaker set cannot be saved, and a new breaker for the
	 * service, like the one the handler builds from its setting, finds no state and starts CLOSED.
	 *
	 * @param serviceName The service whose circuit the test opened.
	 */
	private static void assertTheNextBreakerStartsClosed(String serviceName)
	{
		UTIL_CircuitBreaker.State stateOfTheNextBreaker = UTIL_CircuitBreaker.monitor(serviceName).getState();
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, stateOfTheNextBreaker, 'Expected a new breaker to start CLOSED with no org cache space, got ' + stateOfTheNextBreaker);
	}

	/**
	 * @description Counts the open issues of a service.
	 *
	 * @param serviceName The service.
	 *
	 * @return How many issues are open for it.
	 */
	private static Integer countIssuesFor(String serviceName)
	{
		return new SEL_ApiIssue().findUnresolvedByService(serviceName).size();
	}

	/**
	 * @description Reads a row's retry count as an integer, null counting as zero.
	 *
	 * @param item The row.
	 *
	 * @return The retry count.
	 */
	private static Integer countRetriesOf(ApiCall__c item)
	{
		return (item.Retries__c ?? 0).intValue();
	}

	/**
	 * @description A GET handler that registers one record for the commit, counting its sends and its successes, so a
	 * test can tell a retried commit from a re-sent callout.
	 */
	public virtual class RecordSavingOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Counts the send, then sends.
		 *
		 * @param requestObj The request.
		 */
		public override void sendRequest(HttpRequest requestObj)
		{
			sendCount++;
			super.sendRequest(requestObj);
		}

		/**
		 * @description Counts the success and registers the record the commit must save.
		 */
		public override void onSuccess()
		{
			successCount++;
			registerFoobar(Foobar__c.Name, SAVED_RECORD_NAME);
		}
	}

	/**
	 * @description The record-saving handler under its own service name, for the call row the test setup saves, so that
	 * row is never read by the tests that dispatch a new call.
	 */
	public class SavedRowOutbound extends RecordSavingOutbound
	{
	}

	/**
	 * @description A handler that registers a record the platform refuses, so saving the handler's records fails with a
	 * DmlException the platform raised.
	 */
	public class RefusedRecordOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Registers a record whose email value the platform refuses.
		 */
		public override void onSuccess()
		{
			registerFoobar(Foobar__c.Email__c, INVALID_EMAIL);
		}
	}

	/**
	 * @description A handler that builds a DmlException and throws it after the external system responded with a success.
	 */
	public class HandlerBuiltDmlExceptionOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Throws a DmlException built in code, which carries no row errors.
		 */
		public override void onSuccess()
		{
			throw new DmlException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description Test-only outbound handler with no `ApiSetting__mdt` record. Deliberately
	 * minimal: `configure()` only sets the request/response DTOs the validation pipeline expects
	 * before it reaches the setting-lookup branch.
	 */
	public class TestableOutbound extends API_Outbound
	{
		/**
		 * @description Initialises the handler: identical to `API_Outbound.configure()` plus DTO
		 * setup, so the validation pipeline advances to the `setting == null` check instead of
		 * aborting earlier on a missing payload.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new DTO_Payload();
			responsePayload = new DTO_Payload();
		}
	}

	/**
	 * @description A subscriber-shaped service that declares one required input and no triggering record,
	 * so the accessors are proven through the override path rather than the base defaults.
	 */
	public with sharing class DeclaringOutbound extends API_Outbound
	{
		/**
		 * @description Initialises the handler the way a subscriber service does: payload DTOs plus an
		 * explicit opt-out of the triggering-record requirement the base `configure()` switches on.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new DTO_Base();
			responsePayload = new DTO_Base();
			requiresTriggeringRecord = false;
		}

		/**
		 * @description Declares the one required input the accessor is expected to read back.
		 *
		 * @return The base set plus this service's required input name.
		 */
		public override Set<String> getRequiredInputs()
		{
			Set<String> requiredInputs = super.getRequiredInputs();
			requiredInputs.add(REQUIRED_INPUT_NAME);
			return requiredInputs;
		}
	}

	/**
	 * @description A service whose override returns null, proving the accessor never hands null to a caller.
	 */
	public with sharing class NullDeclaringOutbound extends API_Outbound
	{
		/**
		 * @description Returns null deliberately, standing in for a subscriber override that forgets the
		 * empty-set contract.
		 *
		 * @return Always null.
		 */
		public override Set<String> getRequiredInputs()
		{
			return null;
		}
	}

	/**
	 * @description A GET handler with in-memory payloads and no triggering record, the base of this class's retry
	 * handlers: a GET, so a callout that got no response is safe to repeat.
	 */
	public virtual class RetryProbeOutbound extends API_Outbound
	{
		/**
		 * @description Sets the payloads and clears the triggering-record requirement.
		 */
		public override virtual void configure()
		{
			super.configure();
			requestPayload = new DTO_Base();
			responsePayload = new DTO_Base();
			requiresTriggeringRecord = false;
		}

		/**
		 * @description A GET, so a repeat is safe.
		 *
		 * @return GET.
		 */
		public override virtual HttpMethod getHttpMethod()
		{
			return HttpMethod.GET;
		}

		/**
		 * @description Registers one new test record for the handler's commit to save, with one field set, so a handler
		 * can give its commit a record the platform saves or one it refuses.
		 *
		 * @param field The field to set on the record.
		 * @param value The value the field gets.
		 */
		protected void registerFoobar(SObjectField field, Object value)
		{
			doInsert(TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withOverride(field, value).build());
		}
	}

	/**
	 * @description The external system responds with 408 in the status test.
	 */
	public class RequestTimeoutOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 425 in the status test.
	 */
	public class TooEarlyOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 429 in the status test.
	 */
	public class TooManyRequestsOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 500 in the status test.
	 */
	public class InternalServerErrorOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 502 in the status test.
	 */
	public class BadGatewayOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 503 in the status test.
	 */
	public class ServiceUnavailableOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 504 in the status test.
	 */
	public class GatewayTimeoutOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 400 in the status test.
	 */
	public class BadRequestOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 401 in the status test.
	 */
	public class UnauthorizedOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 404 in the status test.
	 */
	public class NotFoundOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 302 in the status test.
	 */
	public class FoundOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description The external system responds with 409 in the status test, with the default set of retryable statuses.
	 */
	public class ConflictOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description A POST handler: a POST that got no response and carried no Idempotency-Key is not safe to repeat.
	 */
	public virtual class PostTransportOutbound extends RetryProbeOutbound
	{
		/**
		 * @description A POST, so a repeat is not safe without a key.
		 *
		 * @return POST.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.POST;
		}
	}

	/**
	 * @description A PATCH handler: a PATCH that got no response and carried no Idempotency-Key is not safe to repeat.
	 */
	public virtual class PatchTransportOutbound extends RetryProbeOutbound
	{
		/**
		 * @description A PATCH, so a repeat is not safe without a key.
		 *
		 * @return PATCH.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.PATCH;
		}
	}

	/**
	 * @description A DELETE handler: a DELETE is safe to repeat.
	 */
	public virtual class DeleteTransportOutbound extends RetryProbeOutbound
	{
		/**
		 * @description A DELETE, whose enum value is DELETION.
		 *
		 * @return DELETION.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.DELETION;
		}
	}

	/**
	 * @description A PUT handler: a PUT is safe to repeat.
	 */
	public virtual class PutTransportOutbound extends RetryProbeOutbound
	{
		/**
		 * @description A PUT, so a repeat is safe.
		 *
		 * @return PUT.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.PUT;
		}
	}

	/**
	 * @description A PATCH without an Idempotency-Key to which the external system responds with 500 in the server-error test.
	 */
	public class InternalServerErrorPatchOutbound extends PatchTransportOutbound
	{
	}

	/**
	 * @description A PATCH without an Idempotency-Key to which the external system responds with 502 in the server-error test.
	 */
	public class BadGatewayPatchOutbound extends PatchTransportOutbound
	{
	}

	/**
	 * @description A PATCH without an Idempotency-Key to which the external system responds with 408 in the not-processed test.
	 */
	public class RequestTimeoutPatchOutbound extends PatchTransportOutbound
	{
	}

	/**
	 * @description A PATCH without an Idempotency-Key to which the external system responds with 425 in the not-processed test.
	 */
	public class TooEarlyPatchOutbound extends PatchTransportOutbound
	{
	}

	/**
	 * @description A PATCH without an Idempotency-Key to which the external system responds with 429 in the not-processed test.
	 */
	public class TooManyRequestsPatchOutbound extends PatchTransportOutbound
	{
	}

	/**
	 * @description A PATCH without an Idempotency-Key to which the external system responds with 503 in the not-processed test.
	 */
	public class ServiceUnavailablePatchOutbound extends PatchTransportOutbound
	{
	}

	/**
	 * @description A PUT to which the external system responds with 500 in the safe-method test.
	 */
	public class InternalServerErrorPutOutbound extends PutTransportOutbound
	{
	}

	/**
	 * @description A PUT to which the external system responds with 502 in the safe-method test.
	 */
	public class BadGatewayPutOutbound extends PutTransportOutbound
	{
	}

	/**
	 * @description A PUT to which the external system responds with 504 in the safe-method test.
	 */
	public class GatewayTimeoutPutOutbound extends PutTransportOutbound
	{
	}

	/**
	 * @description A DELETE to which the external system responds with 500 in the safe-method test.
	 */
	public class InternalServerErrorDeleteOutbound extends DeleteTransportOutbound
	{
	}

	/**
	 * @description A DELETE to which the external system responds with 502 in the safe-method test.
	 */
	public class BadGatewayDeleteOutbound extends DeleteTransportOutbound
	{
	}

	/**
	 * @description A DELETE to which the external system responds with 504 in the safe-method test.
	 */
	public class GatewayTimeoutDeleteOutbound extends DeleteTransportOutbound
	{
	}

	/**
	 * @description A POST handler that lists System.CalloutException, taking responsibility for repeating a POST without an Idempotency-Key.
	 */
	public class PostOptingInCalloutOutbound extends PostTransportOutbound
	{
		/**
		 * @description Opts the callout exception in.
		 *
		 * @return The callout exception type.
		 */
		public override Set<Type> getRetryableExceptionTypes()
		{
			return new Set<Type> {System.CalloutException.class};
		}
	}

	/**
	 * @description A POST handler whose createRequest() override sends a request of its own, copied from the framework's
	 * request without any of its headers, so the request sent carries no Idempotency-Key although the framework worked
	 * one out.
	 */
	public class KeyDroppingPostOutbound extends PostTransportOutbound
	{
		/**
		 * @description Builds the framework's request, then returns a new request with the same method, endpoint and body
		 * and none of its headers.
		 *
		 * @param requestBody The body content of the request.
		 *
		 * @return The request that is sent, without the Idempotency-Key header.
		 */
		@SuppressWarnings('PMD.KernNoRawHttp')
		public override HttpRequest createRequest(String requestBody)
		{
			HttpRequest frameworkRequest = super.createRequest(requestBody);
			HttpRequest requestWithoutTheKey = new HttpRequest();
			requestWithoutTheKey.setMethod(frameworkRequest.getMethod());
			if(String.isNotBlank(frameworkRequest.getEndpoint()))
			{
				requestWithoutTheKey.setEndpoint(frameworkRequest.getEndpoint());
			}
			if(String.isNotBlank(frameworkRequest.getBody()))
			{
				requestWithoutTheKey.setBody(frameworkRequest.getBody());
			}
			return requestWithoutTheKey;
		}
	}

	/**
	 * @description A POST handler whose createRequest() override sets the Idempotency-Key header itself when the request
	 * has none, on a call with no stamped key and Idempotency Enabled off, so the framework works out no key of its own.
	 * A key already on the request (one recorded by an earlier attempt) is kept, as an idempotency key must be.
	 */
	public virtual class KeySettingPostOutbound extends PostTransportOutbound
	{
		/**
		 * @description Builds the framework's request and, when it carries no key, sets one of the handler's own on it,
		 * keeping the key in keySetByTheHandler.
		 *
		 * @param requestBody The body content of the request.
		 *
		 * @return The request that is sent, with an Idempotency-Key header.
		 */
		public override HttpRequest createRequest(String requestBody)
		{
			HttpRequest keyedRequest = super.createRequest(requestBody);
			if(String.isBlank(keyedRequest.getHeader(API_Base.HEADER_IDEMPOTENCY_KEY)))
			{
				keySetByTheHandler = UTIL_Random.randomName();
				keyedRequest.setHeader(API_Base.HEADER_IDEMPOTENCY_KEY, keySetByTheHandler);
			}
			return keyedRequest;
		}
	}

	/**
	 * @description The key-setting handler under its own service name, for the saved call row that carries a recorded
	 * key, so that row is never read by the tests that dispatch a new call.
	 */
	public class SavedKeySettingPostOutbound extends KeySettingPostOutbound
	{
	}

	/**
	 * @description A POST handler whose createRequest() override lets the framework build the request (working out a key
	 * under Idempotency Enabled), then throws before the send.
	 */
	public class KeyComputedThenThrowingPostOutbound extends PostTransportOutbound
	{
		/**
		 * @description Builds the framework's request, then throws.
		 *
		 * @param requestBody The body content of the request.
		 *
		 * @return Never returns.
		 */
		public override HttpRequest createRequest(String requestBody)
		{
			super.createRequest(requestBody);
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler that says GET but whose createRequest() override sends the request as a POST, with no
	 * Idempotency-Key.
	 */
	public class MethodChangingOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Builds the framework's request as a GET, then changes its method to POST.
		 *
		 * @param requestBody The body content of the request.
		 *
		 * @return The request that is sent, as a POST.
		 */
		public override HttpRequest createRequest(String requestBody)
		{
			HttpRequest postRequest = super.createRequest(requestBody);
			postRequest.setMethod(API_Base.toHttpString(HttpMethod.POST));
			return postRequest;
		}
	}

	/**
	 * @description A handler whose createRequest() override sends its request with the method written in lower case.
	 */
	public class LowerCaseMethodOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Builds the framework's request, then sets its method to "post".
		 *
		 * @param requestBody The body content of the request.
		 *
		 * @return The request that is sent.
		 */
		public override HttpRequest createRequest(String requestBody)
		{
			HttpRequest builtRequest = super.createRequest(requestBody);
			builtRequest.setMethod(API_Base.toHttpString(HttpMethod.POST).toLowerCase());
			return builtRequest;
		}
	}

	/**
	 * @description A handler that declares GET and whose createRequest() override sends HEAD, a method the call record's
	 * picklist does not hold.
	 */
	public class HeadSendingOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Builds the framework's request, then sets its method to HEAD.
		 *
		 * @param requestBody The body content of the request.
		 *
		 * @return The request that is sent.
		 */
		public override HttpRequest createRequest(String requestBody)
		{
			HttpRequest builtRequest = super.createRequest(requestBody);
			builtRequest.setMethod(HEAD_METHOD);
			return builtRequest;
		}
	}

	/**
	 * @description A POST handler whose self-retry scheduling is suppressed, as the async chain's step sets up the handler it runs.
	 */
	public class SuppressedPostOutbound extends PostTransportOutbound
	{
		/**
		 * @description Suppresses this instance's self-retry scheduling, then processes the call. The suppression is set
		 * here and not in configure(), which runs while the handler is still being built, before its own fields are set.
		 *
		 * @param apiCall The API call being processed.
		 */
		public override void process(ApiCall__c apiCall)
		{
			suppressSelfRetryScheduling();
			super.process(apiCall);
		}
	}

	/**
	 * @description A GET handler whose strategy denylists the callout exception.
	 */
	public class DenylistingGetOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Wraps the default strategy in a denylist of the callout exception.
		 *
		 * @return The denylisting strategy.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.dontRetryOnException(super.createRetryStrategy(), new Set<Type> {System.CalloutException.class});
		}
	}

	/**
	 * @description A GET handler whose strategy allows only the callout exception, which a status failure never carries.
	 */
	public class AllowlistingStatusOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Wraps the default strategy in an allowlist of the callout exception.
		 *
		 * @return The allowlisting strategy.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.retryOnlyOnException(super.createRetryStrategy(), new Set<Type> {System.CalloutException.class});
		}
	}

	/**
	 * @description A handler that adds 409 to the statuses a retry may follow.
	 */
	public class ConflictRetryingOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Adds the conflict status to the default set.
		 *
		 * @return The default statuses plus 409.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			Set<Integer> codes = super.getRetryableStatusCodes();
			codes.add(API_Base.HTTP_CONFLICT);
			return codes;
		}
	}

	/**
	 * @description A handler whose status set is null, which reads as no retryable status.
	 */
	public class NullStatusSetOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Returns null on purpose.
		 *
		 * @return Always null.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			return null;
		}
	}

	/**
	 * @description A POST without an Idempotency-Key to which the external system responds with 500 in the server-error test.
	 */
	public class InternalServerErrorPostOutbound extends PostTransportOutbound
	{
	}

	/**
	 * @description A POST without an Idempotency-Key to which the external system responds with 502 in the server-error test.
	 */
	public class BadGatewayPostOutbound extends PostTransportOutbound
	{
	}

	/**
	 * @description A POST without an Idempotency-Key to which the external system responds with 504 in the server-error test.
	 */
	public class GatewayTimeoutPostOutbound extends PostTransportOutbound
	{
	}

	/**
	 * @description A POST without an Idempotency-Key to which the external system responds with 408 in the not-processed test.
	 */
	public class RequestTimeoutPostOutbound extends PostTransportOutbound
	{
	}

	/**
	 * @description A POST without an Idempotency-Key to which the external system responds with 425 in the not-processed test.
	 */
	public class TooEarlyPostOutbound extends PostTransportOutbound
	{
	}

	/**
	 * @description A POST without an Idempotency-Key to which the external system responds with 429 in the not-processed test.
	 */
	public class TooManyRequestsPostOutbound extends PostTransportOutbound
	{
	}

	/**
	 * @description A POST without an Idempotency-Key to which the external system responds with 503 in the not-processed test.
	 */
	public class ServiceUnavailablePostOutbound extends PostTransportOutbound
	{
	}

	/**
	 * @description A POST handler that adds 409 to the statuses a retry may follow, its own choice for its unsafe requests.
	 */
	public class ConflictRetryingPostOutbound extends PostTransportOutbound
	{
		/**
		 * @description Adds the conflict status to the default set.
		 *
		 * @return The default statuses plus 409.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			Set<Integer> codes = super.getRetryableStatusCodes();
			codes.add(API_Base.HTTP_CONFLICT);
			return codes;
		}
	}

	/**
	 * @description A POST handler that leaves 500 out of the statuses a retry may follow.
	 */
	public class ServerErrorExcludingPostOutbound extends PostTransportOutbound
	{
		/**
		 * @description Removes the internal server error status from the default set.
		 *
		 * @return The default statuses without 500.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			Set<Integer> codes = super.getRetryableStatusCodes();
			codes.remove(API_Base.HTTP_INTERNAL_SERVER_ERROR);
			return codes;
		}
	}

	/**
	 * @description A handler whose parseResponse() throws after a successful response and whose onSuccess() counts its runs.
	 */
	public virtual class ParseThrowingOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Throws while reading the response.
		 */
		public override void parseResponse()
		{
			throw new JSONException(MESSAGE_HANDLER_THREW);
		}

		/**
		 * @description Counts the run, so a test proves onSuccess() did not run.
		 */
		public override void onSuccess()
		{
			successCount++;
		}
	}

	/**
	 * @description The parse-throwing GET handler with the JSON exception opted in.
	 */
	public virtual class ParseThrowingOptedInGetOutbound extends ParseThrowingOutbound
	{
		/**
		 * @description Opts the JSON exception in.
		 *
		 * @return The JSON exception type.
		 */
		public override Set<Type> getRetryableExceptionTypes()
		{
			return new Set<Type> {System.JSONException.class};
		}
	}

	/**
	 * @description The opted-in parse-throwing handler as a POST without an Idempotency-Key.
	 */
	public class ParseThrowingOptedInPostOutbound extends ParseThrowingOptedInGetOutbound
	{
		/**
		 * @description A POST, so a repeat after a success is not safe.
		 *
		 * @return POST.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.POST;
		}
	}

	/**
	 * @description A handler whose prepareRequest() throws before the send.
	 */
	public virtual class PrepareThrowingOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Throws before the request is built.
		 */
		public override void prepareRequest()
		{
			throw new NullPointerException();
		}
	}

	/**
	 * @description The prepare-throwing handler with the null pointer exception opted in.
	 */
	public class PrepareThrowingOptedInOutbound extends PrepareThrowingOutbound
	{
		/**
		 * @description Opts the null pointer exception in.
		 *
		 * @return The null pointer exception type.
		 */
		public override Set<Type> getRetryableExceptionTypes()
		{
			return new Set<Type> {System.NullPointerException.class};
		}
	}

	/**
	 * @description A handler whose authorisation token fetch throws a callout exception from its own code.
	 */
	public class TokenThrowingOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Throws a callout exception while the headers are set.
		 *
		 * @return Never returns.
		 */
		public override String getAuthorisationToken()
		{
			throw new CalloutException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler that refuses the retry from parseResponse() and whose onSuccess() counts its runs.
	 */
	public virtual class RefusingParseOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Refuses the retry while reading the response.
		 */
		public override void parseResponse()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}

		/**
		 * @description Counts the run, so a test proves onSuccess() did not run.
		 */
		public override void onSuccess()
		{
			successCount++;
		}
	}

	/**
	 * @description A handler whose parseResponse() says the external system refused the request in a success body.
	 */
	public class RefusingRequestInParseOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Refuses the request while reading the response.
		 */
		public override void parseResponse()
		{
			throw new UTIL_Exceptions.RequestRefusedException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler that throws the refusal from onSuccess(), where the external system has already acted.
	 */
	public class RefusingRequestInOnSuccessOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Refuses after the response was read.
		 */
		public override void onSuccess()
		{
			throw new UTIL_Exceptions.RequestRefusedException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler that refuses the retry from prepareRequest().
	 */
	public class RefusingPrepareOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Refuses the retry before the request is built.
		 */
		public override void prepareRequest()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler that refuses the retry from onSuccess().
	 */
	public class RefusingOnSuccessOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Refuses the retry after a successful response.
		 */
		public override void onSuccess()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler that refuses the retry from createRetryStrategy().
	 */
	public class RefusingStrategyOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Refuses the retry instead of building a strategy.
		 *
		 * @return Never returns.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description The parse-refusing handler with the refusal's own type opted in.
	 */
	public class RefusingOptedInOutbound extends RefusingParseOutbound
	{
		/**
		 * @description Opts the refusal's own type in.
		 *
		 * @return The refusal type.
		 */
		public override Set<Type> getRetryableExceptionTypes()
		{
			return new Set<Type> {UTIL_Exceptions.PermanentFailureException.class};
		}
	}

	/**
	 * @description A handler that refuses the call from getValidationErrors().
	 */
	public class RefusingValidationOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Refuses the call during validation.
		 *
		 * @return Never returns.
		 */
		public override List<String> getValidationErrors()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler whose strategy reads the response body and refuses a retry the body marks as permanent.
	 */
	public class BodyReadingStrategyOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Refuses the retry when the body carries the permanent marker.
		 *
		 * @return A strategy that never retries, or the default.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return result.responseBody.contains(PERMANENT_BODY_MARKER) ? UTIL_Retry.linear().withMaxRetries(0) : super.createRetryStrategy();
		}
	}

	/**
	 * @description A handler whose createRetryStrategy() throws.
	 */
	public class ThrowingStrategyOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Throws instead of building a strategy.
		 *
		 * @return Never returns.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler whose handleError override throws.
	 */
	public class ThrowingHandleErrorOutbound extends RetryProbeOutbound
	{
		/**
		 * @description Throws while handling the failure.
		 *
		 * @param exceptionThrown The failure being handled.
		 */
		public override void handleError(Exception exceptionThrown)
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A handler that completes, the other call of a batch whose first handler fails.
	 */
	public class CompletingOutbound extends RetryProbeOutbound
	{
	}

	/**
	 * @description Minimal DTO: any payload satisfies the base-level DTO check. Its contents are
	 * irrelevant because the test aborts at the setting-lookup branch before any HTTP work fires.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class DTO_Payload extends DTO_JsonBase
	{
	}
}
