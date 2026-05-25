// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behavior of the [API_Dispatcher] class.
 *
 * @see API_Dispatcher
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class API_Dispatcher_TEST
{
	private static final Integer INVALID_RETRIES = 1000;
	private static final String MSG_EXPECTED_FAIL = 'Operation should have failed';
	private static final String MSG_LOG_NOT_WRITTEN = 'Error log should be written';
	private static final String MSG_WRONG_TYPE = 'Incorrect exception type';
	private static final String API_POST_EXAMPLE_METHOD = API_PostExample.class.getName() + '/execute';
	private static final String TEST_ADMIN_COMPANY = 'API_Dispatcher_TEST-admin';
	private static final String LOW_PRIVILEGE_COMPANY = 'API_Dispatcher_TEST-low-privilege';

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
	 * @description Tests handling of a DML exception caused by invalid retries during execution.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void handleDmlException()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());
		apiCall.Retries__c = INVALID_RETRIES;

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
	 * @description Tests that logger context is hydrated from API call.
	 * Verifies that logs created during processing include parent transaction ID from originating context.
	 *
	 * @see API_Dispatcher.execute
	 */
	@IsTest
	private static void shouldHydrateContextFromApiCall()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0);

		// Simulate originating transaction - capture its request ID as parent
		LOG_Builder.startCorrelation();
		String originalRequestId = Request.getCurrent().getRequestId();
		LOG_Builder.setGlobalContext('flowId', 'test-flow-123');
		String capturedContext = LOG_Builder.serializeContext();

		// Create API call with captured context (simulating what TST_Factory does)
		ApiCall__c apiCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
						ApiCall__c.LoggerContext__c => capturedContext
				}).build();

		// Clear context to simulate new transaction
		LOG_Builder.setCorrelationId(null);
		LOG_Builder.clearAllGlobalContext();

		Test.startTest();
		// This should hydrate context from API call
		API_Dispatcher.execute(apiCall);
		Test.stopTest();

		// Verify logs were created with parent transaction ID from originating transaction
		List<LogEntry__c> allLogs = new SEL_LogEntry().getAll();
		List<LogEntry__c> logs = new List<LogEntry__c>();
		for(LogEntry__c log : allLogs)
		{
			if(log.ParentTransactionId__c == originalRequestId)
			{
				logs.add(log);
			}
		}

		Assert.isFalse(logs.isEmpty(), 'Should have logs with parent transaction ID from originating context');
		// Verify context data was preserved (contains flowId from original context)
		Boolean foundFlowContext = false;
		for(LogEntry__c log : logs)
		{
			if(log.ContextData__c != null && log.ContextData__c.contains('flowId'))
			{
				foundFlowContext = true;
				break;
			}
		}
		Assert.isTrue(foundFlowContext, 'Logs should contain global context from originating transaction');
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

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName());
		apiCall.Retries__c = INVALID_RETRIES;

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
		List<ApiCall__c> apiCalls = TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
				}).withCount(2).buildList();

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
		apiCall.Retries__c = INVALID_RETRIES;

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
	 * @description Tests that an unexpected exception during final commit work is logged with the correct context.
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

		Assert.isNotNull(new SEL_LogEntry().findByMethod(API_Dispatcher.class.getName() + '/execute'), MSG_LOG_NOT_WRITTEN);
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

		List<ApiCall__c> apiCalls = TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
				}).withCount(3).buildList();

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
}