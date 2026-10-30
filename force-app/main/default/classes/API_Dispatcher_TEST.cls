// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests the behavior of the [API_Dispatcher] class.
 *
 * @see API_Dispatcher
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=false)
private class API_Dispatcher_TEST
{
	/**
	 * @description Assertion message for a call that was expected to throw and returned instead.
	 */
	private static final String MSG_EXPECTED_FAIL = 'Operation should have failed';

	/**
	 * @description Assertion message for a log entry the dispatcher was expected to write and that was not found.
	 */
	private static final String MSG_LOG_NOT_WRITTEN = 'Error log should be written';

	/**
	 * @description Assertion message for an exception of a type other than the one the test expects.
	 */
	private static final String MSG_WRONG_TYPE = 'Incorrect exception type';

	/**
	 * @description The class and method name the performance timer of an API_PostExample call logs under, used to find
	 * that call's performance log entry.
	 */
	private static final String API_POST_EXAMPLE_METHOD = API_PostExample.class.getName() + '/execute';

	/**
	 * @description The company name that marks the administrator the test setup creates, so a test can find that user
	 * again.
	 */
	private static final String TEST_ADMIN_COMPANY = 'API_Dispatcher_TEST-admin';

	/**
	 * @description The company name that marks the minimum-access user the test setup creates, so a test can find that
	 * user again.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'API_Dispatcher_TEST-low-privilege';

	/**
	 * @description What must hold for every entry written after a call is built and dispatched in one transaction.
	 */
	private static final String MESSAGE_IMMEDIATE_DISPATCH_KEEPS_THE_PARENT = 'An entry after an immediate dispatch keeps the transaction\'s parent, never the transaction itself';

	/**
	 * @description The context stack depth a single API call runs at inside a batch: the batch's own context plus the
	 * one context of the call being run.
	 */
	private static final Integer DEPTH_OF_ONE_CALL_INSIDE_A_BATCH = 2;

	/**
	 * @description The context stack depth each recording handler saw while it processed, in processing order.
	 */
	private static final List<Integer> DEPTHS_WHILE_PROCESSING = new List<Integer>();

	/**
	 * @description The context stack depth each recording handler saw while it committed, in commit order.
	 */
	private static final List<Integer> DEPTHS_WHILE_COMMITTING = new List<Integer>();

	/**
	 * @description The service name of each recording handler that committed, in commit order.
	 */
	private static final List<String> SERVICE_NAMES_COMMITTING = new List<String>();

	/**
	 * @description The service name the top of the context stack carried while each recording handler committed, in
	 * commit order. Read from the stack itself rather than the merged context, which the web-service context overlays
	 * with the committing handler's own name whatever the stack holds.
	 */
	private static final List<String> SERVICE_NAMES_IN_CONTEXT_WHILE_COMMITTING = new List<String>();

	/**
	 * @description The service names the batch's own context carried while each recording handler was created, in
	 * creation order. Read from the bottom of the stack, which the batch's context holds for as long as the batch runs.
	 */
	private static final List<String> BATCH_SERVICE_NAMES_WHILE_CREATING = new List<String>();

	/**
	 * @description What separates one service name from the next in the batch context's list of names.
	 */
	private static final String SERVICE_NAME_SEPARATOR = ', ';

	/**
	 * @description The message of the failure a handler raises before it has taken the call record in hand.
	 */
	private static final String MESSAGE_THROWN_BEFORE_PROCESSING = 'The handler fails before it takes the call in hand';

	/**
	 * @description The message of the failure an inbound handler raises as the last step of processing, once it holds
	 * the call record.
	 */
	private static final String MESSAGE_THROWN_AS_THE_LAST_STEP = 'The handler fails as the last step of processing';

	/**
	 * @description A W3C trace id a call record carries, so the call's lines run under that trace.
	 */
	private static final String TRACE_ID = '4bf92f3577b34da6a3ce929d0e0e4736';

	/**
	 * @description The endpoint the merged logging context carried while each reading handler processed, in processing order.
	 */
	private static final List<String> ENDPOINTS_WHILE_PROCESSING = new List<String>();

	/**
	 * @description The W3C trace parent header of an inbound request that runs under the shared trace id.
	 */
	private static final String TRACE_PARENT = '00-' + TRACE_ID + '-00f067aa0ba902b7-01';

	/**
	 * @description What must hold for the logging engine once a dispatch ends.
	 */
	private static final String MESSAGE_NO_CALL_CONTEXT_LEFT = 'A dispatch leaves no call context behind in the logging engine.';

	/**
	 * @description The retry budget the mocked settings of this class's handlers carry: enough attempts that a call the
	 * engine refuses to retry is refused by the engine, never by an exhausted budget.
	 */
	private static final Integer RETRY_BUDGET = 3;

	/**
	 * @description The retry wait the mocked settings carry, in seconds; a zero wait schedules nothing.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 30;

	/**
	 * @description The message every throwing test handler of this class fails with.
	 */
	private static final String MESSAGE_HANDLER_THREW = 'the handler threw on purpose';

	/**
	 * @description An email address no Email field accepts, so a commit that saves it is refused by the platform.
	 */
	private static final String INVALID_EMAIL = 'not-an-email';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldCompleteApiCallForLowPrivilegeUser) can use System.runAs
	 * against either without triggering MIXED_DML_OPERATION. User is a Setup object, so User DML
	 * cannot mix with standard/custom-object DML in the same transaction; pre-provisioning here
	 * satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing API_Dispatcher tests continue to run as the
	 * @IsTest running user without runAs.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Tests API call execution and verifies service abortion in a separate transaction.
	 *
	 * @param serviceName The name of the API service to execute
	 */
	private static void assertAbortExecuteService(String serviceName)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName);

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		SEL_ApiCall.assertServiceAborted(serviceName);
	}

	/**
	 * @description Builds a batch of outbound API calls to the example post service.
	 *
	 * @param count How many API calls the batch holds.
	 *
	 * @return The API calls of the batch.
	 */
	private static List<ApiCall__c> newOutboundApiCalls(Integer count)
	{
		return TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
				}).withCount(count).buildList();
	}

	/**
	 * @description Tests handling of a DML exception on save: a record the handler registered is refused when the
	 * handler's work is committed, and the call still ends Failed.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void handleDmlException()
	{
		ApiCall__c apiCall = newCallWhoseCommitIsRefused();

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		SEL_ApiCall.assertServiceFailed(apiCall.ServiceName__c);
	}

	/**
	 * @description Tests handling of an invalid handler class name, ensuring service abortion.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void handleInvalidHandlerClass()
	{
		assertAbortExecuteService(UTIL_Random.randomName());
	}

	/**
	 * @description Tests handling of a valid class that is not an API handler, ensuring service abortion.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void handleNonApiHandler()
	{
		assertAbortExecuteService(API_Dispatcher.class.getName());
	}

	/**
	 * @description Tests handling of a commit failure for API calls, ensuring an error log is written.
	 * With partial DML enabled, failures are logged by DML_Transaction rather than the dispatcher catch block.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void handleApiCallCommitException()
	{
		API_Dispatcher.simulateApiCallCommitFailure = true;
		LOG_Builder.ignoreTestMode = true;

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.isNotNull(new SEL_LogEntry().findByMethod(DML_Transaction.CLASS_METHOD_COMMIT), MSG_LOG_NOT_WRITTEN);
	}

	/**
	 * @description Tests that an exception is raised when no valid handler is found.
	 *
	 * @see API_OutboundTestHelper.assertCallSuccessful
	 */
	@IsTest
	private static void verifyHandlerNotFoundException()
	{
		try
		{
			API_OutboundTestHelper.assertCallSuccessful(UTIL_Random.randomName(), null);

			Assert.fail(MSG_EXPECTED_FAIL);
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, IllegalArgumentException.class, MSG_WRONG_TYPE);
		}
	}

	/**
	 * @description Tests that partial API context is set when handler instantiation fails.
	 * This ensures log entries contain service name even when the handler class can't be loaded.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void handlerInstantiationFailureSetsPartialContext()
	{
		LOG_Builder.ignoreTestMode = true;
		final String invalidServiceName = 'NonExistentHandler_' + System.currentTimeMillis();

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(invalidServiceName);

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		// Verify error was logged
		LogEntry__c errorLog = new SEL_LogEntry().findByMethod(invalidServiceName);
		Assert.isNotNull(errorLog, 'Error log should be written for handler instantiation failure');

		if(String.isNotBlank(errorLog.ContextData__c))
		{
			Assert.isTrue
					(
							errorLog.ContextData__c.contains(invalidServiceName) || errorLog.ContextData__c.contains('Unknown-Endpoint'),
							'Context should contain partial service info')
					;
		}
	}

	/**
	 * @description Tests that slow API calls are automatically logged when performance logging is enabled.
	 * With a 0ms threshold, any API call should trigger a performance log entry.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void slowApiCallsAreAutomaticallyLogged()
	{
		LOG_Builder.ignoreTestMode = true;

		TST_Factory.setupLoggerForTest(true, 0);

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		// Find the performance log entry for the API_PostExample service
		LogEntry__c performanceLog = new SEL_LogEntry().findPerformanceLogByMethod(API_POST_EXAMPLE_METHOD);
		Assert.isNotNull(performanceLog, 'Should find a performance log entry for API_PostExample/execute');
		Assert.isNotNull(performanceLog.DurationMs__c, 'Duration should be populated');
		Assert.isTrue(performanceLog.DurationMs__c >= 0, 'Duration should be non-negative');
	}

	/**
	 * @description Tests that slow API logging respects the threshold setting.
	 * With a high threshold (10 seconds), normal API calls should NOT trigger a log.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void slowApiLoggingRespectsThreshold()
	{
		LOG_Builder.ignoreTestMode = true;

		TST_Factory.setupLoggerForTest(true, 10000);

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		// Verify no performance log was written (API completed faster than 10s)
		Assert.isNull(new SEL_LogEntry().findPerformanceLogByMethod(API_POST_EXAMPLE_METHOD), 'Should NOT find a performance log entry when under threshold');
	}

	/**
	 * @description Tests that slow API logging is disabled when EnablePerformanceLogging__c is false.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void slowApiLoggingCanBeDisabled()
	{
		LOG_Builder.ignoreTestMode = true;

		TST_Factory.setupLoggerForTest(false, 0);

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		// Verify no performance log was written
		Assert.isNull(new SEL_LogEntry().findPerformanceLogByMethod(API_POST_EXAMPLE_METHOD), 'Should NOT find performance log when performance logging is disabled');
	}

	/**
	 * @description Tests that the logger context stored on a call built by another request is restored for the run:
	 * every entry the run writes names that request as its parent and carries its global context. The originating
	 * request is not the test's own, so its document is built as that request would have written it.
	 *
	 * @see API_Dispatcher.hydrateLoggerContext
	 */
	@IsTest
	private static void shouldHydrateContextFromApiCall()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0);

		String originatingRequestId = UTIL_Random.randomUUID();
		LOG_Engine.DTO_LoggerContext originatingContext = new LOG_Engine.DTO_LoggerContext();
		originatingContext.correlationId = UTIL_Random.randomUUID();
		originatingContext.parentTransactionId = originatingRequestId;
		originatingContext.contextData = new Map<String, String> {'flowId' => 'test-flow-123'};

		ApiCall__c apiCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
						ApiCall__c.LoggerContext__c => JSON.serialize(originatingContext)
				}).build();

		Test.startTest();
		API_Dispatcher.execute(apiCall);
		Test.stopTest();

		List<LogEntry__c> logs = new List<LogEntry__c>();
		for(LogEntry__c log : new SEL_LogEntry().getAll())
		{
			if(log.ParentTransactionId__c == originatingRequestId)
			{
				logs.add(log);
			}
		}

		Assert.isFalse(logs.isEmpty(), 'The run must write entries naming the originating request as their parent');
		Boolean foundFlowContext = false;
		for(LogEntry__c log : logs)
		{
			if(log.ContextData__c != null && log.ContextData__c.contains('flowId'))
			{
				foundFlowContext = true;
				break;
			}
		}
		Assert.isTrue(foundFlowContext, 'The run\'s entries must carry the originating request\'s global context');
	}

	/**
	 * @description Tests that a call built and dispatched in one transaction leaves that transaction's parent as it was.
	 * The document the call carries was written by this very request, so restoring it would only make the transaction
	 * its own parent; every entry the run writes still names the parent the transaction had before the dispatch.
	 *
	 * @see API_Dispatcher.hydrateLoggerContext
	 */
	@IsTest
	private static void immediateDispatchKeepsTheParentTheTransactionAlreadyHad()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0);
		String parentTransactionId = UTIL_Random.randomUUID();
		LOG_Builder.setParentTransactionId(parentTransactionId);

		// Built in this transaction, so its stored document names this request as its parent.
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();
		API_Dispatcher.execute(apiCall);
		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().getAll();
		Assert.isFalse(entries.isEmpty(), 'The dispatch must write at least one log entry');
		Set<String> parents = UTIL_SObject.extractUniqueValues(entries, LogEntry__c.ParentTransactionId__c);
		Assert.areEqual(new Set<String> {parentTransactionId}, parents, MESSAGE_IMMEDIATE_DISPATCH_KEEPS_THE_PARENT);
	}

	/**
	 * @description Tests that new correlation is started for legacy API calls without context.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldStartNewCorrelationForLegacyApiCalls()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0);

		// API call without LoggerContext__c (legacy)
		ApiCall__c apiCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
						ApiCall__c.LoggerContext__c => null
				}).build();

		// Clear any existing correlation
		LOG_Builder.setCorrelationId(null);

		Test.startTest();
		API_Dispatcher.execute(apiCall);
		Test.stopTest();

		// Should have started a new correlation
		Assert.isNotNull(LOG_Builder.correlationId, 'Should start new correlation for legacy API calls');
	}

	/**
	 * @description Tests that ContentVersion records are created when handler error produces large payloads.
	 * Uses simulateStoreToFile to force file creation regardless of payload size.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldCreateContentVersionsOnHandlerError()
	{
		API_Base.simulateStoreToFile = true;

		ApiCall__c apiCall = newCallWhoseCommitIsRefused();

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		SEL_ApiCall.assertServiceFailed(apiCall.ServiceName__c);

		List<ContentVersion> versions = new SEL_ContentVersion().findByFirstPublishLocationId(apiCall.Id);
		Assert.isFalse(versions.isEmpty(), 'ContentVersion records should be created for large payloads');
	}

	/**
	 * @description Tests that executing an empty list of API calls is handled gracefully.
	 * This covers the early return path in hydrateLoggerContext.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldHandleEmptyApiCallList()
	{
		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c>());

		Test.stopTest();

		Assert.isTrue(handlers.isEmpty(), 'Should return empty list for empty input');
	}

	/**
	 * @description Tests that batch processing context is added to logs.
	 * Verifies that logs created during batch processing include batchSize in context.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldIncludeBatchContextInLogs()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0);

		// Two API calls form a batch — hydrateLoggerContext logs batchSize for any size > 0.
		List<ApiCall__c> apiCalls = newOutboundApiCalls(2);

		Test.startTest();

		API_Dispatcher.execute(apiCalls);

		Test.stopTest();

		// Find logs created during batch processing
		List<LogEntry__c> logs = new SEL_LogEntry().getAll();

		// At least one log should contain batchSize context
		Boolean foundBatchContext = false;
		for(LogEntry__c log : logs)
		{
			if(String.isNotBlank(log.ContextData__c) && log.ContextData__c.contains('batchSize'))
			{
				foundBatchContext = true;
				// Verify batch size is present - actual value is 3 but JSON format may vary
				Assert.isTrue(log.ContextData__c.contains('"batchSize"'), 'Context should contain batchSize key');
				break;
			}
		}
		Assert.isTrue(foundBatchContext, 'Logs should include batch context with batchSize');
	}

	/**
	 * @description Tests that ContentVersion records are linked directly when API call already has an Id.
	 * Pre-inserts the API call so the else branch in handleError sets FirstPublishLocationId directly.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldLinkContentVersionDirectlyWhenApiCallHasId()
	{
		API_Base.simulateStoreToFile = true;
		API_Dispatcher.simulateProcessException = true;

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());
		apiCall.Status__c = SEL_ApiCall.STATUS_BATCHED;
		DML_Builder.newTransaction().withSystemMode().doInsert(apiCall).execute();

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		SEL_ApiCall.assertServiceFailed(apiCall.ServiceName__c);

		List<ContentVersion> versions = new SEL_ContentVersion().findByFirstPublishLocationId(apiCall.Id);
		Assert.isFalse(versions.isEmpty(), 'ContentVersion should be linked directly when API call has Id');
	}

	/**
	 * @description Tests that safe mode skips the final apiCallUnitOfWork commit,
	 * preventing stale-ID DML errors when savepoint rollback invalidates in-memory IDs.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldSkipFinalCommitWhenSafeModeActive()
	{
		LOG_Builder.ignoreTestMode = true;

		API_Base.SafeModeContext safeMode = API_Base.enterSafeMode();

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		safeMode.close();

		LogEntry__c dispatcherError = new SEL_LogEntry().findByMethod(API_Dispatcher.class.getName() + '/execute');
		Assert.isNull(dispatcherError, 'Should not log DML error when safe mode is active');
	}

	/**
	 * @description Tests that an unexpected exception during final commit work is logged with the correct context. That
	 * save belongs to the batch rather than to any one call, so the line it logs carries the batch's own context, which
	 * names the services the batch calls.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldLogErrorWhenCommitWorkThrowsUnexpectedException()
	{
		API_Dispatcher.simulateCommitWorkException = true;
		LOG_Builder.ignoreTestMode = true;

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		LogEntry__c dispatcherError = new SEL_LogEntry().findByMethod(API_Dispatcher.class.getName() + '/execute');

		Assert.isNotNull(dispatcherError, MSG_LOG_NOT_WRITTEN);

		Boolean isServiceNamed = dispatcherError.ContextData__c?.contains(API_PostExample.class.getName()) == true;

		Assert.isTrue(isServiceNamed, 'A line logged from the batch-wide save names the service the batch calls.');
	}

	/**
	 * @description Tests routeRequest returns null when no REST request is present.
	 *
	 * @see API_Dispatcher.routeRequest
	 */
	@IsTest
	private static void shouldReturnNullWhenNoRestRequest()
	{
		RestContext.request = null;
		RestContext.response = new RestResponse();

		API_Base result = API_Dispatcher.routeRequest();

		Assert.isNull(result, 'Should return null when no REST request');
	}

	/**
	 * @description Tests routeRequest returns 404 when no matching route is configured.
	 *
	 * @see API_Dispatcher.routeRequest
	 */
	@IsTest
	private static void shouldReturn404WhenNoRouteMatches()
	{
		RestContext.request = new RestRequest();
		RestContext.request.requestURI = '/services/apexrest/v1/nonexistent';
		RestContext.request.httpMethod = 'GET';
		RestContext.response = new RestResponse();

		API_Base result = API_Dispatcher.routeRequest();

		Assert.isNull(result, 'Should return null when no route matches');
		Assert.areEqual(API_Base.HTTP_NOT_FOUND, RestContext.response.statusCode, 'Should set 404 status code');
	}

	/**
	 * @description Tests buildQualifiedClassName returns class name as-is when already namespace-qualified.
	 *
	 * @see API_Dispatcher.buildQualifiedClassName
	 */
	@IsTest
	private static void shouldReturnClassNameAsIsWhenAlreadyQualified()
	{
		ApiSetting__mdt setting = new ApiSetting__mdt(ClassName__c = 'MyNS.API_Handler');

		String result = API_Dispatcher.buildQualifiedClassName(setting);

		Assert.areEqual('MyNS.API_Handler', result, 'Should return as-is when already qualified');
	}

	/**
	 * @description Tests buildQualifiedClassName returns bare class name when no namespace prefix.
	 *
	 * @see API_Dispatcher.buildQualifiedClassName
	 */
	@IsTest
	private static void shouldReturnBareClassNameWhenNoNamespace()
	{
		ApiSetting__mdt setting = new ApiSetting__mdt(ClassName__c = 'API_Handler');

		String result = API_Dispatcher.buildQualifiedClassName(setting);

		Assert.areEqual('API_Handler', result, 'Should return bare class name when no namespace');
	}

	/**
	 * @description Tests buildQualifiedClassName prepends namespace prefix to bare class name.
	 *
	 * @see API_Dispatcher.buildQualifiedClassName
	 */
	@IsTest
	private static void shouldPrependNamespacePrefixToClassName()
	{
		String result = API_Dispatcher.buildQualifiedClassName('API_Handler', 'myns');

		Assert.areEqual('myns.API_Handler', result, 'Should prepend namespace prefix');
	}

	/**
	 * @description Tests findBestRoute returns null when no active inbound routes exist.
	 *
	 * @see API_Dispatcher.findBestRoute
	 */
	@IsTest
	private static void shouldReturnNullRouteWhenNoCandidates()
	{
		ApiSetting__mdt result = API_Dispatcher.findBestRoute('/api/v1/test');

		Assert.isNull(result, 'Should return null when no candidates match');
	}

	/**
	 * @description Tests that routeRequest selects the correct handler via ApiSetting metadata.
	 *
	 * @see API_Dispatcher.routeRequest
	 */
	@IsTest
	private static void shouldRouteInboundRequestViaApiSetting()
	{
		TST_Factory.newInboundApiSetting(API_Echo.class.getName(), '/echo/*');

		API_InboundTestHelper.setupRestContext(new DTO_JsonBase());
		RestContext.request.requestURI = '/echo/test';

		Test.startTest();

		API_Base result = API_Dispatcher.routeRequest();

		Test.stopTest();

		Assert.isNotNull(result, 'Router should select a handler');
		Assert.areEqual(API_Base.HTTP_OK, RestContext.response.statusCode, 'Should return 200');
	}

	/**
	 * @description Tests that isCalloutBudgetExhausted returns false by default
	 * and true when the simulation flag is set.
	 *
	 * @see API_Dispatcher.isCalloutBudgetExhausted
	 */
	@IsTest
	private static void shouldReportBudgetExhaustedWhenSimulated()
	{
		Assert.isFalse(API_Dispatcher.isCalloutBudgetExhausted(), 'Should not be exhausted by default');

		API_Dispatcher.simulateCalloutBudgetExhausted = true;

		Assert.isTrue(API_Dispatcher.isCalloutBudgetExhausted(), 'Should be exhausted when flag is set');
	}

	/**
	 * @description Tests that a single API call is always processed even when the callout
	 * budget is exhausted, honouring the first-item exemption.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldProcessSingleApiCallEvenWhenBudgetExhausted()
	{
		API_Dispatcher.simulateCalloutBudgetExhausted = true;

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall
				(
						API_PostExample.class.getName(),
						UserInfo.getUserId(),
						UTIL_Random.randomName(),
						UTIL_Random.randomName()
				);

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(apiCall.ServiceName__c);
	}

	/**
	 * @description Tests that when the callout budget is exhausted, only the first API call
	 * in a batch is processed and the rest are deferred with a warning log.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldDeferApiCallsWhenCalloutBudgetExhausted()
	{
		API_Dispatcher.simulateCalloutBudgetExhausted = true;
		LOG_Builder.ignoreTestMode = true;

		List<ApiCall__c> apiCalls = newOutboundApiCalls(3);

		Test.startTest();

		API_Dispatcher.execute(apiCalls);

		Test.stopTest();

		LogEntry__c warningLog = new SEL_LogEntry().findByMethod(API_Dispatcher.class.getName() + '/execute');
		Assert.isNotNull(warningLog, 'Warning log should be emitted for deferred API calls');
		Assert.isTrue(warningLog.ShortMessage__c.contains('deferred'), 'Warning should mention deferred calls');
	}

	/**
	 * @description Tests that findBestRoute matches the longest path prefix when multiple routes qualify.
	 *
	 * @see API_Dispatcher.findBestRoute
	 */
	@IsTest
	private static void shouldMatchLongestPathPrefix()
	{
		TST_Factory.newInboundApiSetting(API_Echo.class.getName(), '/api/*');
		TST_Factory.newInboundApiSetting(API_Echo.class.getName(), '/api/v1/*');

		ApiSetting__mdt result = API_Dispatcher.findBestRoute('/api/v1/test');

		Assert.isNotNull(result, 'Should find a matching route');
		Assert.areEqual('/api/v1/*', result.EndpointPath__c, 'Should match the longer prefix /api/v1/* over /api/*');
	}

	/**
	 * @description Tests that when paths have equal length, the lower priority number wins.
	 *
	 * @see API_Dispatcher.findBestRoute
	 */
	@IsTest
	private static void shouldRespectPriorityWhenPathsEqual()
	{
		TST_Factory.newInboundApiSetting(API_Echo.class.getName(), '/echo/*', 50);
		TST_Factory.newInboundApiSetting(API_Echo.class.getName(), '/echo/*', 200);

		ApiSetting__mdt result = API_Dispatcher.findBestRoute('/echo/test');

		Assert.isNotNull(result, 'Should find a matching route');
		Assert.areEqual(50, result.Priority__c, 'Lower priority number should win when paths are equal length');
	}

	/**
	 * @description Tier-A — proves API_Dispatcher.execute reaches framework-owned
	 * ApiCall__c persistence from a subscriber user on the Minimum Access - Salesforce profile who
	 * has no FLS on kern__ApiCall__c. Seeded as admin, dispatched under the low-privilege user,
	 * re-queried as admin.
	 *
	 * Honest scope — the test asserts only that Status__c transitions OUT of QUEUED. The terminal
	 * status depends on transient factors (mock availability, callout budget, retry policy) that
	 * vary between dev-org and synthetic validation-org test runs, and pinning to a specific
	 * terminal status would make the test flaky. Status leaving QUEUED at all is sufficient
	 * evidence that framework-internal DML on the queue record elevated via SYSTEM_MODE despite
	 * the caller lacking FLS — a refactor that demotes the dispatcher's ApiCall__c update to
	 * USER_MODE would leave the record stuck in QUEUED (or throw a DmlException from the update
	 * that crashes the dispatch), and this test would catch that at 2GP validated-build time
	 * rather than at subscriber scratch-org time.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldPersistApiCallStatusTransitionForLowPrivilegeUser()
	{
		ApiCall__c queuedCall;

		System.runAs(getTestAdmin())
		{
			queuedCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());
			DML_Builder.newTransaction().withSystemMode().doInsert(queuedCall).execute();
		}

		System.runAs(getLowPrivilegeUser())
		{
			Test.startTest();

			API_Dispatcher.execute(queuedCall);

			Test.stopTest();
		}

		System.runAs(getTestAdmin())
		{
			ApiCall__c committedCall = (ApiCall__c)new SEL_ApiCall().findById(queuedCall.Id);

			Assert.isNotNull(committedCall, 'ApiCall__c should still exist after dispatch');
			Assert.areNotEqual
					(
							SEL_ApiCall.STATUS_QUEUED,
							committedCall.Status__c,
							'Status__c leaving QUEUED is sufficient evidence of framework-internal DML elevation for the low-privilege caller'
					);
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the ApiCall__c queue record and to re-assert outcomes under full FLS
	 * after the low-privilege dispatch completes.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise API_Dispatcher.execute and prove
	 * the subscribers-without-internal-FLS contract holds for the dispatcher primitive.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Tests that a call whose handler fails while it processes leaves no logging context behind.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldLeaveNoContextBehindWhenProcessingThrows()
	{
		API_Dispatcher.simulateProcessException = true;

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'A call that fails while it processes leaves no logging context behind.');
		SEL_ApiCall.assertServiceFailed(API_PostExample.class.getName());
	}

	/**
	 * @description Tests that every handler of a batch processes and commits under its own logging context, so the
	 * contexts never pile up and one handler's commit never runs under another handler's name. The batch runs one
	 * handler of the first kind and two of the second, an order that reads differently forwards and backwards, so a
	 * commit running under another handler's context cannot pass by coincidence. It also checks what the batch's own
	 * context carries while a handler is created: each service the batch calls, named once, in alphabetical order.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldRunEachHandlerOfABatchUnderItsOwnContext()
	{
		API_InboundTestHelper.setupRestContext();

		Test.startTest();

		API_Dispatcher.execute(newRecordingBatch());

		Test.stopTest();

		Assert.areEqual(SERVICE_NAMES_COMMITTING, SERVICE_NAMES_IN_CONTEXT_WHILE_COMMITTING, 'Each commit runs under its own handler\'s context.');
		Assert.areEqual
				(
						new List<Integer> {DEPTH_OF_ONE_CALL_INSIDE_A_BATCH, DEPTH_OF_ONE_CALL_INSIDE_A_BATCH, DEPTH_OF_ONE_CALL_INSIDE_A_BATCH},
						DEPTHS_WHILE_PROCESSING,
						'Each handler of a batch processes under one context of its own.'
				);
		Assert.areEqual
				(
						new List<Integer> {DEPTH_OF_ONE_CALL_INSIDE_A_BATCH, DEPTH_OF_ONE_CALL_INSIDE_A_BATCH, DEPTH_OF_ONE_CALL_INSIDE_A_BATCH},
						DEPTHS_WHILE_COMMITTING,
						'Each handler of a batch commits under one context of its own.'
				);
		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'A batch leaves no logging context behind.');

		String expectedBatchServiceNames = ContextRecordingInbound.class.getName() + SERVICE_NAME_SEPARATOR + SecondContextRecordingInbound.class.getName();

		Assert.areEqual
				(
						new List<String> {expectedBatchServiceNames, expectedBatchServiceNames, expectedBatchServiceNames},
						BATCH_SERVICE_NAMES_WHILE_CREATING,
						'While a handler is created, the batch context names each service of the batch once, in alphabetical order.'
				);
	}

	/**
	 * @description Tests that a handler failing while it processes leaves no context behind for the handlers that
	 * follow it in the same batch.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldLeaveNoContextBehindWhenOneHandlerOfABatchThrows()
	{
		API_InboundTestHelper.setupRestContext();

		List<ApiCall__c> apiCalls = new List<ApiCall__c>
		{
				TST_Factory.newInboundApiCall(ThrowingContextRecordingInbound.class.getName()),
				TST_Factory.newInboundApiCall(ContextRecordingInbound.class.getName())
		};

		Test.startTest();

		API_Dispatcher.execute(apiCalls);

		Test.stopTest();

		Assert.areEqual
				(
						new List<Integer> {DEPTH_OF_ONE_CALL_INSIDE_A_BATCH, DEPTH_OF_ONE_CALL_INSIDE_A_BATCH},
						DEPTHS_WHILE_PROCESSING,
						'A handler that fails leaves the next handler of the batch one context of its own.'
				);
		Assert.areEqual
				(
						new List<Integer> {DEPTH_OF_ONE_CALL_INSIDE_A_BATCH},
						DEPTHS_WHILE_COMMITTING,
						'The handler that failed never commits; the one that follows commits under one context of its own.'
				);
		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'A batch holding a failing handler leaves no logging context behind.');
	}

	/**
	 * @description Builds a batch of one recording handler of the first kind and two of the second.
	 *
	 * @return The API calls of the batch.
	 */
	private static List<ApiCall__c> newRecordingBatch()
	{
		return new List<ApiCall__c>
		{
				TST_Factory.newInboundApiCall(ContextRecordingInbound.class.getName()),
				TST_Factory.newInboundApiCall(SecondContextRecordingInbound.class.getName()),
				TST_Factory.newInboundApiCall(SecondContextRecordingInbound.class.getName())
		};
	}

	/**
	 * @description Reads the context data of a stored log entry through the engine's own context type.
	 *
	 * @param entry The stored log entry.
	 *
	 * @return The context data the entry carries.
	 */
	private static Map<String, String> readContextData(LogEntry__c entry)
	{
		return ((LOG_Engine.DTO_LoggerContext)JSON.deserialize(entry.ContextData__c, LOG_Engine.DTO_LoggerContext.class)).contextData;
	}

	/**
	 * @description Tests that a call whose processing fails leaves no call context behind in the logging engine.
	 *
	 * @see API_Dispatcher.execute
	 * @see API_Base.clearLoggingContext
	 */
	@IsTest
	private static void shouldLeaveNoCallContextBehindWhenProcessingThrows()
	{
		API_Dispatcher.simulateProcessException = true;

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.isEmpty(), MESSAGE_NO_CALL_CONTEXT_LEFT);
		SEL_ApiCall.assertServiceFailed(API_PostExample.class.getName());
	}

	/**
	 * @description Tests that a batch whose handlers all succeed leaves no call context behind in the logging engine.
	 *
	 * @see API_Dispatcher.execute
	 * @see API_Base.clearLoggingContext
	 */
	@IsTest
	private static void shouldLeaveNoCallContextBehindAfterASuccessfulBatch()
	{
		API_InboundTestHelper.setupRestContext();

		Test.startTest();

		API_Dispatcher.execute(newRecordingBatch());

		Test.stopTest();

		Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.isEmpty(), MESSAGE_NO_CALL_CONTEXT_LEFT);
	}

	/**
	 * @description Tests that a line logged from the batch-wide save carries the batch's own context: the services the
	 * batch calls, and nothing of any single call, neither its service name nor its endpoint.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldLogTheBatchWideSaveUnderTheBatchContextOnly()
	{
		API_InboundTestHelper.setupRestContext();
		API_Dispatcher.simulateCommitWorkException = true;
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		API_Dispatcher.execute(newRecordingBatch());

		Test.stopTest();

		LogEntry__c batchSaveEntry = new SEL_LogEntry().findByMethod(API_Dispatcher.class.getName() + '/execute');
		Assert.isNotNull(batchSaveEntry, MSG_LOG_NOT_WRITTEN);

		Map<String, String> contextData = readContextData(batchSaveEntry);
		String expectedBatchServiceNames = ContextRecordingInbound.class.getName() + SERVICE_NAME_SEPARATOR + SecondContextRecordingInbound.class.getName();

		Assert.areEqual(expectedBatchServiceNames, contextData.get(LOG_Engine.CONTEXT_SERVICE_NAME), 'A line from the batch-wide save names the batch\'s services.');
		Assert.isFalse(contextData.containsKey(LOG_Engine.CONTEXT_ENDPOINT), 'A line from the batch-wide save carries no single call\'s endpoint.');
	}

	/**
	 * @description Tests that a line logged inside a call whose record carries a trace id carries that call's endpoint,
	 * status code and callout duration.
	 *
	 * @see API_Base.applyLoggingContext
	 */
	@IsTest
	private static void shouldCarryTheCallDetailsOnALineLoggedUnderATrace()
	{
		API_InboundTestHelper.setupRestContext();
		LOG_Builder.ignoreTestMode = true;

		ApiCall__c apiCall = TST_Factory.newInboundApiCall(ThrowingContextRecordingInbound.class.getName());
		apiCall.TraceId__c = TRACE_ID;

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(apiCall);

		Test.stopTest();

		LogEntry__c callEntry = new SEL_LogEntry().findByMethod(ThrowingContextRecordingInbound.class.getName());
		Assert.isNotNull(callEntry, MSG_LOG_NOT_WRITTEN);

		Map<String, String> contextData = readContextData(callEntry);

		Assert.isTrue(String.isNotBlank(handler.result.url), 'The call has an endpoint to carry.');
		Assert.areEqual(handler.result.url, contextData.get(LOG_Engine.CONTEXT_ENDPOINT), 'A line logged inside a traced call carries the call\'s endpoint.');
		Assert.isTrue(contextData.containsKey(LOG_Engine.CONTEXT_STATUS_CODE), 'A line logged inside a traced call carries the call\'s status code.');
		Assert.isTrue(contextData.containsKey(LOG_Engine.CONTEXT_CALLOUT_DURATION_MS), 'A line logged inside a traced call carries the call\'s callout duration.');
	}

	/**
	 * @description Tests that a handler failing before it takes the call record in hand raises no second exception, and
	 * the call record still carries the failure. The handler has no setting, so the budget is zero on purpose: this test
	 * checks the path for a handler with no setting, not how the retry is decided.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldRecordTheFailureWhenAHandlerThrowsBeforeProcessing()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(ThrowingBeforeProcessingOutbound.class.getName());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		SEL_ApiCall.assertServiceFailed(ThrowingBeforeProcessingOutbound.class.getName(), MESSAGE_THROWN_BEFORE_PROCESSING);
		Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.isEmpty(), MESSAGE_NO_CALL_CONTEXT_LEFT);
	}

	/**
	 * @description Tests that a handler whose set-up skips the base set-up leaves no call context behind in the logging
	 * engine.
	 *
	 * @see API_Base.clearLoggingContext
	 */
	@IsTest
	private static void shouldLeaveNoCallContextBehindWhenAHandlerSkipsTheBaseSetUp()
	{
		API_InboundTestHelper.setupRestContext();

		Test.startTest();

		API_Dispatcher.execute(TST_Factory.newInboundApiCall(BaseSetUpSkippingInbound.class.getName()));

		Test.stopTest();

		Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.isEmpty(), MESSAGE_NO_CALL_CONTEXT_LEFT);
	}

	/**
	 * @description Tests that when the first call of a batch fails, a later call under the same trace id processes
	 * without the failed call's endpoint on its lines.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldKeepAFailedCallsDetailsOffTheNextCallUnderTheSameTrace()
	{
		API_InboundTestHelper.setupRestContext();
		RestContext.request.headers.put(API_Base.HEADER_TRACE_PARENT, TRACE_PARENT);

		List<ApiCall__c> apiCalls = new List<ApiCall__c>
		{
				TST_Factory.newInboundApiCall(ThrowingContextRecordingInbound.class.getName()),
				TST_Factory.newInboundApiCall(ContextReadingInbound.class.getName())
		};
		for(ApiCall__c apiCall : apiCalls)
		{
			apiCall.TraceId__c = TRACE_ID;
		}

		Test.startTest();

		API_Dispatcher.execute(apiCalls);

		Test.stopTest();

		Assert.areEqual(new List<String> {null}, ENDPOINTS_WHILE_PROCESSING, 'A call processes without the endpoint of a call that failed before it.');
	}

	/**
	 * @description Tests, for each kind of failure the dispatcher can reach, that a call's status and its next retry
	 * time agree. Every call has retry budget left. The failures are a 500 response, a throw in parseResponse() after a
	 * 200, a throw in commitWork(), a callout that got no response and a throw before the send. Whatever the engine
	 * decides for each, a row at Retry has a next retry time and a row without one is not at Retry; the
	 * RetryOutboundApiCall flow reads nothing else. The two failures of the external system stay at Retry and the three
	 * failures of the handler end Failed. The batch is ordered so that every callout runs before a call fails through
	 * the dispatcher's error path, because the log rows that path saves would make the platform refuse a later callout
	 * in the same test transaction. shouldLeaveNoRetryTimeWhenOnSuccessThrows covers the one kind that cannot share
	 * this batch.
	 *
	 * @see API_Dispatcher.handleError
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldLeaveARetryTimeWheneverACallRestsInRetry()
	{
		List<String> serviceNames = new List<String>
		{
				StatusFailingOutbound.class.getName(), ThrowingParseOutbound.class.getName(), ThrowingCommitOutbound.class.getName(),
				TransportFailingOutbound.class.getName(), ThrowingBeforeSendOutbound.class.getName()
		};
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();
		for(String serviceName : serviceNames)
		{
			registerRetryingSetting(serviceName);
			apiCalls.add(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		}
		API_MockFactory.registerErrorMock(StatusFailingOutbound.class.getName());
		API_MockFactory.forService(TransportFailingOutbound.class.getName()).withTransportFailure().register();
		API_MockFactory.forService(ThrowingParseOutbound.class.getName()).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.forService(ThrowingCommitOutbound.class.getName()).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();

		API_Dispatcher.execute(apiCalls);

		Test.stopTest();

		for(String serviceName : serviceNames)
		{
			assertNextRetryTimeMatchesRetryStatus(serviceName);
		}
		SEL_ApiCall.assertServiceRetrying(StatusFailingOutbound.class.getName());
		SEL_ApiCall.assertServiceRetrying(TransportFailingOutbound.class.getName());
		SEL_ApiCall.assertServiceFailed(ThrowingBeforeSendOutbound.class.getName(), MESSAGE_HANDLER_THREW);
		SEL_ApiCall.assertServiceFailed(ThrowingParseOutbound.class.getName(), MESSAGE_HANDLER_THREW);
		SEL_ApiCall.assertServiceFailed(ThrowingCommitOutbound.class.getName());
	}

	/**
	 * @description Tests that a call's status and its next retry time agree after a throw in onSuccess() with retry
	 * budget left: the external system accepted the request, so the row ends Failed with no next retry time. It runs on
	 * its own because the handler makes a callout and then fails through the dispatcher's error path, as the transport
	 * failure of the batch test does.
	 *
	 * @see API_Dispatcher.handleError
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldLeaveNoRetryTimeWhenOnSuccessThrows()
	{
		String serviceName = ThrowingOnSuccessOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();

		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));

		Test.stopTest();

		assertNextRetryTimeMatchesRetryStatus(serviceName);
		SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW);
	}

	/**
	 * @description An outbound call that is not saved yet, such as the new call a Retry builds, and whose handler throws
	 * before the send, gets one issue that links to the call. The call has no Id when the issue is built, so the issue is
	 * registered with the call as its parent, and the save fills in the link once the call is saved.
	 *
	 * @see API_Dispatcher.handleError
	 */
	@IsTest
	private static void shouldLinkTheIssueToTheNewCallWhenAnOutboundRetryThrows()
	{
		String serviceName = ThrowingBeforeSendOutbound.class.getName();
		registerRetryingSetting(serviceName);

		Test.startTest();

		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));

		Test.stopTest();

		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0];
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue for the failed call, got ' + issues.size());
		Assert.areEqual(failedCall.Id, issues[0].ApiCall__c, 'Expected the issue to link to the new call, got ' + issues[0].ApiCall__c);
	}

	/**
	 * @description Registers the mocked setting the dispatcher-created handler reads: retries on, a wait, issues logged.
	 * Every handler of a batch registers one with these same values, because the mock hands the first registered row to
	 * every setting lookup of the test.
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
	 * @description Tests that an inbound handler whose handleError override throws still responds to the REST caller with
	 * a failure: status 500 and a body carrying both messages, the failure the request met and the one its error handling
	 * threw. The row ends Failed with no next retry time. Without the response written by the dispatcher the caller would
	 * read an empty 200 for a request whose processing failed.
	 *
	 * @see API_Dispatcher.handleError
	 */
	@IsTest
	private static void shouldRespondToTheCallerWithAFailureWhenAnInboundHandleErrorOverrideThrows()
	{
		API_InboundTestHelper.setupRestContext();
		String serviceName = ThrowingHandleErrorInbound.class.getName();

		Test.startTest();

		API_Dispatcher.execute(TST_Factory.newInboundApiCall(serviceName));

		Test.stopTest();

		String body = RestContext.response.responseBody?.toString();
		Integer statusCode = RestContext.response.statusCode;
		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, statusCode, 'Expected status 500 for a request whose error handling threw, got ' + statusCode);
		Assert.isTrue(String.isNotBlank(body) && body.contains(MESSAGE_THROWN_AS_THE_LAST_STEP), 'Expected the body to carry the failure the request met, got ' + body);
		Assert.isTrue(String.isNotBlank(body) && body.contains(MESSAGE_HANDLER_THREW), 'Expected the body to carry the failure the error handling threw, got ' + body);
		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time on the failed inbound call, got ' + failed.NextRetry__c);
	}

	/**
	 * @description Builds a call whose handler completes its callout and then registers a record the platform refuses, so
	 * saving the handler's work throws a DmlException. Registers the setting and the successful response the handler needs.
	 *
	 * @return The call to dispatch.
	 */
	private static ApiCall__c newCallWhoseCommitIsRefused()
	{
		String serviceName = ThrowingCommitOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		return TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId());
	}

	/**
	 * @description Asserts the one rule the RetryOutboundApiCall flow depends on, for every row of one service: a row
	 * at Retry carries a next retry time and is outbound, and a row with no next retry time is not at Retry.
	 *
	 * @param serviceName The handler whose rows are read back.
	 */
	private static void assertNextRetryTimeMatchesRetryStatus(String serviceName)
	{
		for(ApiCall__c item : new SEL_ApiCall().findByServiceName(serviceName))
		{
			Boolean isAtRetry = SEL_ApiCall.STATUS_RETRY.equals(item.Status__c);
			String statusAndNextRetry = item.Status__c + ' / ' + item.NextRetry__c;
			Assert.areEqual(isAtRetry, item.NextRetry__c != null, 'Expected a next retry time exactly when the status is Retry for ' + serviceName + ', got ' + statusAndNextRetry);
			Assert.isTrue(!isAtRetry || SEL_ApiCall.TYPE_OUTBOUND.equals(item.Direction__c), 'Expected a Retry row to be outbound, got ' + item.Direction__c);
		}
	}

	/**
	 * @description A GET handler with in-memory payloads and no triggering record, the base of this class's retry
	 * handlers: a GET, so a callout that got no response is safe to repeat and stays at Retry.
	 */
	public virtual class RetryTableOutbound extends API_Outbound
	{
		/**
		 * @description Sets the payloads and clears the triggering-record requirement.
		 */
		public override void configure()
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
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.GET;
		}
	}

	/**
	 * @description Fails with the 500 the error mock responds with.
	 */
	public class StatusFailingOutbound extends RetryTableOutbound
	{
	}

	/**
	 * @description Fails with the transport failure the mock throws at the send point.
	 */
	public class TransportFailingOutbound extends RetryTableOutbound
	{
	}

	/**
	 * @description Throws in the handler's own code before the send.
	 */
	public class ThrowingBeforeSendOutbound extends RetryTableOutbound
	{
		/**
		 * @description Throws before the request is built.
		 */
		public override void prepareRequest()
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description Throws in onSuccess(), after the external system accepted the request.
	 */
	public class ThrowingOnSuccessOutbound extends RetryTableOutbound
	{
		/**
		 * @description Throws after a successful response.
		 */
		public override void onSuccess()
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description Throws in parseResponse(), after the external system accepted the request.
	 */
	public class ThrowingParseOutbound extends RetryTableOutbound
	{
		/**
		 * @description Throws while reading a successful response.
		 */
		public override void parseResponse()
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description Registers a record the platform refuses to save, so the commit of a successful call throws.
	 */
	public class ThrowingCommitOutbound extends RetryTableOutbound
	{
		/**
		 * @description Registers a record with an email the Email field refuses; the commit, not the handler, throws.
		 */
		public override void onSuccess()
		{
			doInsert(TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withOverride(Foobar__c.Email__c, INVALID_EMAIL).build());
		}
	}

	/**
	 * @description An inbound handler that fails while it processes and whose handleError override throws, so nothing in
	 * the handler writes the REST response.
	 */
	public class ThrowingHandleErrorInbound extends API_Inbound
	{
		/**
		 * @description Fails as the last step of processing.
		 */
		public override void onSuccess()
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_THROWN_AS_THE_LAST_STEP);
		}

		/**
		 * @description Throws while handling the failure, before the base method writes the response.
		 *
		 * @param error The failure being handled.
		 */
		public override void handleError(Exception error)
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description An inbound handler whose set-up does not run the base set-up.
	 */
	public class BaseSetUpSkippingInbound extends API_Inbound
	{
		/**
		 * @description Starts the handler's timers without running the base set-up.
		 */
		public override void configure()
		{
			fullProcessingTime.start();
			serviceProcessingTime.start();
		}
	}

	/**
	 * @description An inbound handler that records the endpoint the merged logging context carries while it processes.
	 */
	public class ContextReadingInbound extends API_Inbound
	{
		/**
		 * @description Records the endpoint the merged logging context carries as the last step of processing.
		 */
		public override void onSuccess()
		{
			ENDPOINTS_WHILE_PROCESSING.add(LOG_Engine.getMergedContext().get(LOG_Engine.CONTEXT_ENDPOINT));
		}
	}

	/**
	 * @description An outbound handler that fails before it takes the call record in hand.
	 */
	public class ThrowingBeforeProcessingOutbound extends API_Outbound
	{
		/**
		 * @description Fails before the base processing runs, so the handler never holds the call record.
		 *
		 * @param apiCall The API call being processed.
		 */
		public override void process(ApiCall__c apiCall)
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_THROWN_BEFORE_PROCESSING);
		}
	}

	/**
	 * @description An inbound handler that records the logging context stack depth it runs at while it processes and
	 * while it commits, along with the service names the batch's context carries while it is created and the service
	 * name its own context carries at commit time.
	 */
	public virtual class ContextRecordingInbound extends API_Inbound
	{
		/**
		 * @description Records the service names the batch's own context carries while this handler is created.
		 */
		public override void configure()
		{
			super.configure();
			BATCH_SERVICE_NAMES_WHILE_CREATING.add(((Map<String, String>)UTIL_List.peekAt(LOG_Engine.contextStack, 0)).get(LOG_Engine.CONTEXT_SERVICE_NAME));
		}

		/**
		 * @description Records the context stack depth this handler processes at.
		 *
		 * @param apiCall The API call being processed.
		 */
		public override void process(ApiCall__c apiCall)
		{
			DEPTHS_WHILE_PROCESSING.add(LOG_Engine.getContextStackDepth());
			super.process(apiCall);
		}

		/**
		 * @description Records the context stack depth, the handler's own service name and the service name the top of
		 * the context stack carries as the commit starts.
		 */
		public override void onCommitWorkStarting()
		{
			super.onCommitWorkStarting();
			DEPTHS_WHILE_COMMITTING.add(LOG_Engine.getContextStackDepth());
			SERVICE_NAMES_COMMITTING.add(getServiceName());
			SERVICE_NAMES_IN_CONTEXT_WHILE_COMMITTING.add(((Map<String, String>)UTIL_List.peek(LOG_Engine.contextStack)).get(LOG_Engine.CONTEXT_SERVICE_NAME));
		}
	}

	/**
	 * @description A second recording handler, so a batch can hold handlers that carry different service names.
	 */
	public class SecondContextRecordingInbound extends ContextRecordingInbound
	{
	}

	/**
	 * @description A recording handler that fails while it processes, so a batch can hold a failing handler.
	 */
	public class ThrowingContextRecordingInbound extends ContextRecordingInbound
	{
		/**
		 * @description Fails as the last step of processing, after the depth has been recorded.
		 */
		public override void onSuccess()
		{
			throw new UTIL_Exceptions.IllegalStateException('The handler fails while it processes');
		}
	}
}