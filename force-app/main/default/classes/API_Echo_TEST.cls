// SPDX-License-Identifier: BUSL-1.1
/**
 * @description test class to test the Inbound API call that will echo exactly what was sent
 *
 * @see API_Echo
 * @see REST_Echo
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class API_Echo_TEST
{
	/**
	 * @description The API class name used for API call creation and service assertions.
	 */
	private static final String SERVICE_NAME = API_Echo.class.getName();

	/**
	 * @description The endpoint path pattern matching the REST_Echo URL mapping.
	 */
	private static final String TEST_ENDPOINT_PATH = '/echo/*';

	/**
	 * @description The content type header name in mixed case, as a client might send it.
	 */
	private static final String MIXED_CASE_CONTENT_TYPE = 'Content-TYPE';

	/**
	 * @description A content type value different from the canonical one, sent under the lower-case header name.
	 */
	private static final String LOWER_CASE_CONTENT_TYPE_VALUE = 'text/plain';

	/**
	 * @description The partner header the Web Services guide's example reads.
	 */
	private static final String PARTNER_HEADER = 'X-Partner-Id';

	/**
	 * @description The validation error the guide's example reports when the partner header is missing.
	 */
	private static final String PARTNER_HEADER_REQUIRED = 'The X-Partner-Id header is required';

	/**
	 * @description The routing priority of the echo setting a test registers; any value works, because it is the only
	 * setting for the path.
	 */
	private static final Integer ROUTE_PRIORITY = 100;

	/**
	 * @description How many queries a successful echo request makes once the settings a transaction keeps are read: one,
	 * the read of the switch that can turn off every API. A request that also read issues would make more.
	 */
	private static final Integer QUERIES_OF_A_SUCCESSFUL_REQUEST = 1;

	/**
	 * @description Sets up the Rest request context to mimic an inbound API call
	 *
	 * @return DTO that will be serialised in to the request object
	 */
	private static DTO_InboundTest setupContext()
	{
		DTO_InboundTest inboundRequest = new DTO_InboundTest();
		inboundRequest.helloWorld = UTIL_Random.randomName();

		API_InboundTestHelper.setupRestContext(inboundRequest);
		RestContext.request.addParameter(UTIL_Random.randomName(), UTIL_Random.randomName());

		return inboundRequest;

	}

	/**
	 * @description This method is use to test a successful call to Echo service
	 */
	@IsTest
	private static void successful()
	{
		API_Base.simulateStoreToFile = true;

		DTO_InboundTest inboundRequest = setupContext();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		List<ApiCall__c> apiCalls = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);

		Assert.isNotNull(handler.result.responseBody, 'Response body should be set');
		Assert.areEqual(inboundRequest.serialize(), handler.result.responseBody, 'Response does not match what was expected');

		List<ContentVersion> foundVersions = new SEL_ContentVersion().findByFirstPublishLocationId(apiCalls.iterator().next().Id);
		Assert.isFalse(foundVersions.isEmpty(), 'No files stored as expected');
	}

	/**
	 * @description This method is use to test a failed call to Echo service
	 */
	@IsTest
	private static void failed()
	{
		API_Base.simulateStoreToFile = true;

		setupContext();

		// this will result in an exception is throw
		API_Inbound.returnErrorResponse = true;

		Test.startTest();

		REST_Echo.echo();

		Test.stopTest();

		List<ApiCall__c> apiCalls = SEL_ApiCall.assertServiceFailed(SERVICE_NAME, UTIL_String.EMPTY);

		List<String> errors = UTIL_String.toList(apiCalls.iterator().next().ErrorMessages__c, UTIL_String.LF);

		//We expect at least lines, in dev org this will be 8, but in managed package 2 (due to stack being hidden)
		Assert.isTrue(errors.size() >= 2, 'Expected Error Message and Stack Trace Line');
		Assert.areEqual(API_Inbound.ERROR_TEST_EXCEPTION_HANDLING, errors.iterator().next(), 'Invalid Error Message');

		List<ContentVersion> foundVersions = new SEL_ContentVersion().findByFirstPublishLocationId(apiCalls.iterator().next().Id);
		Assert.isFalse(foundVersions.isEmpty(), 'No files stored as expected');
	}

	/**
	 * @description This method is use to test a failed call to Echo service due to unhandled exception in post commit processing
	 */
	@IsTest
	private static void failedDueToPostCommitProcessing()
	{
		API_Echo.simulatePostCommitProcessing = true;

		setupContext();

		Test.startTest();

		REST_Echo.echo();

		Test.stopTest();

		SEL_ApiCall.assertServiceFailed(SERVICE_NAME, API_Echo.ERROR_POST_COMMIT);
	}

	/**
	 * @description A successful inbound request closes no issue, even when its setting has Resolve Issues on. An open
	 * issue of the echo service matches the request the way an outbound success matches its issues: the same service,
	 * the same empty triggering record and the same hash of the request parameters. It stays Open, and the request reads
	 * no issue at all, because the request carries no Idempotency-Key: an inbound success closes only the issues of
	 * earlier calls of the same service that carried its key. A first request runs before the
	 * issue is saved, so the settings the framework reads once in a transaction and then keeps are already read; the
	 * request that is measured then makes only the one query every request makes.
	 */
	@IsTest
	private static void shouldResolveNothingWhenAnInboundRequestSucceedsWithResolveIssuesOn()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, TEST_ENDPOINT_PATH, ROUTE_PRIORITY, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.ResolveIssues__c => true,
				ApiSetting__mdt.LogIssues__c => true
		});
		setupContext();
		API_Dispatcher.processInboundService(SERVICE_NAME);
		String parameterName = UTIL_Random.randomName();
		String parameterValue = UTIL_Random.randomName();
		DTO_InboundTest inboundRequest = new DTO_InboundTest();
		inboundRequest.helloWorld = UTIL_Random.randomName();
		API_InboundTestHelper.setupRestContext(inboundRequest);
		RestContext.request.addParameter(parameterName, parameterValue);
		ApiIssue__c openIssue = insertOpenIssueForTheParameter(parameterName, parameterValue);

		Test.startTest();
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;
		Test.stopTest();

		ApiCall__c completed = (ApiCall__c)new SEL_ApiCall().findById(handler.apiCall.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, completed.Status__c, 'Expected the request to complete, got ' + completed.Status__c);
		Assert.isTrue(String.isBlank(completed.TriggeringRecordId__c), 'Expected no triggering record on the call, got ' + completed.TriggeringRecordId__c);
		String requestHash = UTIL_String.abbreviate(UTIL_Crypto.generateMD5Hash(completed.RequestParameters__c), SEL_ApiIssue.REQUEST_PARAMETERS_HASH_LENGTH);
		Assert.areEqual(openIssue.RequestParametersHash__c, requestHash, 'Expected the issue to match the request parameters, got ' + requestHash);
		List<ApiIssue__c> openIssues = new SEL_ApiIssue().findUnresolvedByService(SERVICE_NAME);
		Assert.areEqual(1, openIssues.size(), 'Expected the issue to stay open, got ' + openIssues.size() + ' open issues');
		Assert.areEqual(openIssue.Id, openIssues[0].Id, 'Expected the open issue to be the one inserted, got ' + openIssues[0].Id);
		Assert.areEqual(QUERIES_OF_A_SUCCESSFUL_REQUEST, queriesUsed, 'Expected only the query of the switch for every API, got ' + queriesUsed + ' queries');
	}

	/**
	 * @description Saves an open issue of the echo service for a request that carries one parameter, with no triggering
	 * record and the hash of the request parameters that the echo service records for such a request.
	 *
	 * @param parameterName The name of the request's parameter.
	 * @param parameterValue The value of the request's parameter.
	 *
	 * @return The saved issue.
	 */
	private static ApiIssue__c insertOpenIssueForTheParameter(String parameterName, String parameterValue)
	{
		ApiCall__c earlierCall = TST_Factory.newInboundApiCall(SERVICE_NAME);
		earlierCall.TriggeringRecordId__c = null;
		earlierCall.RequestParameters__c = new DTO_NameValues(new Map<String, String> {parameterName => parameterValue}).serialize();
		String requestHash = UTIL_String.abbreviate(UTIL_Crypto.generateMD5Hash(earlierCall.RequestParameters__c), SEL_ApiIssue.REQUEST_PARAMETERS_HASH_LENGTH);
		return TST_Factory.insertApiIssue(earlierCall, requestHash);
	}

	/**
	 * @description Emulates a call that is aborted because the API has been deactivated via ApiSetting__mdt and verifies file storage.
	 */
	@IsTest
	private static void abortApiDeactivatedWithFileStorage()
	{
		API_Base.simulateStoreToFile = true;

		enableApiSettingFeature(new Map<SObjectField, Object> {ApiSetting__mdt.IsActive__c => false});

		API_Echo handler = assertCallAborted();

		Assert.areEqual(String.valueOf(API_Base.HTTP_BAD_REQUEST), handler.result.statusCode, 'Status Code not set correctly');
		Assert.areEqual(API_Base.HTTP_BAD_REQUEST, RestContext.response.statusCode, 'Status Code not set correctly');

		List<ContentVersion> foundVersions = new SEL_ContentVersion().findByFirstPublishLocationId(handler.apiCall.Id);
		Assert.isFalse(foundVersions.isEmpty(), 'No files stored as expected');
	}

	/**
	 * @description Will execute a call out and ensure that the call aborted (due to API being disabled)
	 *
	 * @return The web service handler
	 */
	private static API_Echo assertCallAborted()
	{
		setupContext();
		return (API_Echo)API_InboundTestHelper.assertCallAborted(SERVICE_NAME);
	}

	/**
	 * @description Emulates a call that is aborted because all Inbound APIs have been disabled for the current user
	 */
	@IsTest
	private static void abortAllInboundApisDisabled()
	{
		TST_Factory.disableAllInboundApis();
		assertCallAborted();
	}

	/**
	 * @description Emulates a call that is aborted because all APIs have been disabled for the current user and checks that message is correct
	 */
	@IsTest
	private static void abortAllInboundApisDisabledAndCheckMessage()
	{
		TST_Factory.disableAllApis();

		DTO_InboundTest inboundRequest = new DTO_InboundTest();
		inboundRequest.helloWorld = UTIL_Random.randomName();

		API_InboundTestHelper.assertCallAborted(SERVICE_NAME, inboundRequest, API_Base.ERROR_API_DISABLED);
	}

	/**
	 * @description Emulates a call that is aborted because no payload was provided to the Echo service
	 */
	@IsTest
	private static void abortRequestBodyIsBlank()
	{
		API_InboundTestHelper.setupRestContext();
		API_InboundTestHelper.assertCallAborted(SERVICE_NAME, API_Echo.ERROR_NO_BODY_RECEIVED);
	}

	/**
	 * @description Checks that disabling outbound calls does not affect any inbound calls
	 */
	@IsTest
	private static void successfulOutboundDisabled()
	{
		TST_Factory.disableAllOutboundApis();
		setupContext();

		Test.startTest();

		REST_Echo.echo();

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
	}

	/**
	 * @description Emulates a call that is aborted because all inbound APIs have been disabled via feature flag.
	 *
	 * @see API_Inbound.isDisabled
	 * @see API_Inbound.FLAG_DISABLE_ALL_INBOUND_APIS
	 */
	@IsTest
	private static void abortAllInboundApisDisabledViaFeatureFlag()
	{
		TST_Factory.newFeatureFlag(API_Inbound.FLAG_DISABLE_ALL_INBOUND_APIS);
		assertCallAborted();
	}

	/**
	 * @description Tests that inbound mock injection returns a mocked response when mocking
	 * is enabled via the MockAllInboundAPIs feature flag and a mock is registered in the factory.
	 *
	 * @see API_Inbound.shouldMock
	 * @see API_Inbound.process
	 */
	@IsTest
	private static void shouldReturnMockedResponseWhenMockScenarioActive()
	{
		String mockedBody = '{"mocked":true,"echo":"intercepted"}';
		API_MockFactory.forService(SERVICE_NAME).body(mockedBody).statusCode(API_Base.HTTP_OK).register();

		TST_Factory.mockAllInboundApis();

		setupContext();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		Assert.areEqual(mockedBody, handler.result.responseBody, 'Should return factory mock body');
	}

	/**
	 * @description Tests that a default mock response is returned when shouldMock returns true
	 * but no mock is registered in the factory.
	 *
	 * @see API_Inbound.shouldMock
	 * @see API_Inbound.process
	 */
	@IsTest
	private static void shouldReturnDefaultMockWhenNoMockRegistered()
	{
		TST_Factory.mockAllInboundApis();

		setupContext();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		Assert.isTrue(handler.result.responseBody.contains('"mocked":true'), 'Should return default mock response when no mock registered');
	}

	/**
	 * @description Tests that inbound mocking is enabled via API_MockFactory.enableMocking()
	 * and a registered mock response is returned.
	 *
	 * @see API_Inbound.shouldMock
	 * @see API_MockFactory.enableMocking
	 */
	@IsTest
	private static void shouldMockInboundWhenEnabledViaFactory()
	{
		String mockedBody = '{"factory":"enabled"}';
		API_MockFactory.forService(SERVICE_NAME).body(mockedBody).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.enableMocking(SERVICE_NAME);

		setupContext();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		Assert.areEqual(mockedBody, handler.result.responseBody, 'Should return factory mock body when enabled via enableMocking');
	}

	/**
	 * @description Tests that enableMocking returns a default mock when no mock is registered
	 * for the service in API_MockFactory.
	 *
	 * @see API_Inbound.shouldMock
	 * @see API_MockFactory.enableMocking
	 */
	@IsTest
	private static void shouldReturnDefaultMockWhenEnabledViaFactoryWithNoRegisteredMock()
	{
		API_MockFactory.enableMocking(SERVICE_NAME);

		setupContext();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		Assert.areEqual(API_Base.HTTP_OK, RestContext.response.statusCode, 'Should return 200');
		Assert.isTrue(handler.result.responseBody.contains('"mocked":true'), 'Should return default mock body');
	}

	/**
	 * @description Tests that a W3C Trace Parent header is parsed and persisted on the API call record.
	 *
	 * @see API_Inbound.extractTraceContext
	 * @see API_Base.parseTraceParentHeader
	 */
	@IsTest
	private static void shouldParseTraceParentHeaderAndPersistTraceId()
	{
		String traceId = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
		String spanId = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 16);
		String traceParent = '00-' + traceId + '-' + spanId + '-01';

		setupContext();
		RestContext.request.headers.put(API_Base.HEADER_TRACE_PARENT, traceParent);

		Test.startTest();

		REST_Echo.echo();

		Test.stopTest();

		List<ApiCall__c> apiCalls = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		ApiCall__c apiCall = apiCalls.iterator().next();

		Assert.areEqual(traceId, apiCall.TraceId__c, 'Trace ID should be parsed from Trace Parent header');
		Assert.areEqual(spanId, apiCall.ParentSpanId__c, 'Parent span ID should be parsed from Trace Parent header');
	}

	/**
	 * @description Tests that a new trace context is generated when no Trace Parent header is present.
	 *
	 * @see API_Inbound.extractTraceContext
	 * @see API_Base.generateTraceContext
	 */
	@IsTest
	private static void shouldGenerateTraceContextWhenNoTraceParentHeader()
	{
		setupContext();

		Test.startTest();

		REST_Echo.echo();

		Test.stopTest();

		List<ApiCall__c> apiCalls = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		ApiCall__c apiCall = apiCalls.iterator().next();

		Assert.isNotNull(apiCall.TraceId__c, 'Trace ID should be generated when no Trace Parent header');
		Assert.areEqual(32, apiCall.TraceId__c.length(), 'Generated trace ID should be 32 hex characters');
	}

	/**
	 * @description Tests that the W3C trace ID from the inbound request is bridged to
	 * LOG_Builder.correlationId so log entries can be correlated with the distributed trace.
	 *
	 * @see API_Inbound.process
	 * @see LOG_Builder.setCorrelationId
	 */
	@IsTest
	private static void shouldSetLogCorrelationIdFromTraceContext()
	{
		String traceId = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
		String spanId = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 16);
		String traceParent = '00-' + traceId + '-' + spanId + '-01';

		setupContext();
		RestContext.request.headers.put(API_Base.HEADER_TRACE_PARENT, traceParent);

		Test.startTest();

		REST_Echo.echo();

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		Assert.areEqual(traceId, LOG_Builder.correlationId, 'LOG_Builder correlationId should equal the inbound trace ID');
	}

	/**
	 * @description Tests that the idempotency key from the request header is persisted on the API call record.
	 *
	 * @see API_Inbound.checkIdempotency
	 * @see API_Inbound.setApiCallDetails
	 */
	@IsTest
	private static void shouldPersistIdempotencyKeyFromHeader()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		DTO_InboundTest inboundRequest = setupContext();
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		List<ApiCall__c> apiCalls = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		ApiCall__c apiCall = apiCalls.iterator().next();

		Assert.areEqual(inboundRequest.serialize(), handler.result.responseBody, 'Should process normally when idempotency not enabled');
		Assert.areEqual(idempotencyKey, apiCall.IdempotencyKey__c, 'Idempotency key should be persisted from header');
	}

	/**
	 * @description Tests that inbound mock injection returns a mocked response when the
	 * MockingEnabled checkbox is enabled on the ApiSetting metadata record and the Mock Selected APIs feature flag is on.
	 *
	 * @see API_Inbound.shouldMock
	 */
	@IsTest
	private static void shouldReturnMockedResponseViaMockingEnabled()
	{
		String mockedBody = '{"scenario":"active"}';
		API_MockFactory.forService(SERVICE_NAME).body(mockedBody).statusCode(API_Base.HTTP_OK).register();

		TST_Factory.newInboundApiSetting(SERVICE_NAME, TEST_ENDPOINT_PATH, 100, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MockingEnabled__c => true
		});
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);

		setupContext();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		Assert.areEqual(mockedBody, handler.result.responseBody, 'Should return factory mock body via MockingEnabled');
	}

	/**
	 * @description Tests that assigning setting directly via applySettings()
	 * bypasses the lazy-loaded metadata query.
	 *
	 * @see API_Base.setting
	 * @see API_Base.applySettings
	 */
	@IsTest
	private static void shouldAcceptDirectSettingsAssignment()
	{
		API_InboundTestHelper.setupRestContext();

		API_Echo handler = new API_Echo();

		ApiSetting__mdt settingRecord = new ApiSetting__mdt();
		settingRecord.MockingEnabled__c = true;

		handler.applySettings(settingRecord);

		Assert.areEqual(true, handler.setting.MockingEnabled__c, 'Settings should be accessible after direct assignment');
	}

	/**
	 * @description Tests that a duplicate request with the same idempotency key returns
	 * the cached response from the original ApiCall instead of processing again.
	 *
	 * @see API_Inbound.checkIdempotency
	 */
	@IsTest
	private static void shouldReturnCachedResponseForDuplicateIdempotencyKey()
	{
		String idempotencyKey = UTIL_Random.randomUUID();
		String cachedResponseBody = '{"cached":"true","echo":"intercepted"}';

		insertCompletedApiCall(idempotencyKey, cachedResponseBody);

		enableIdempotency();

		setupContext();
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		Assert.areEqual(cachedResponseBody, handler.result.responseBody, 'Should return cached response for duplicate idempotency key');
		Assert.areEqual(API_Base.HTTP_OK, RestContext.response.statusCode, 'Status code should be 200');

		List<ApiCall__c> apiCalls = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		Boolean foundIdempotencyHit = false;
		for(ApiCall__c call : apiCalls)
		{
			if(call.IsIdempotencyHit__c == true)
			{
				foundIdempotencyHit = true;
				break;
			}
		}
		Assert.isTrue(foundIdempotencyHit, 'Should flag the duplicate request as an idempotency hit');
	}

	/**
	 * @description Proves a replay whose idempotency header name arrives all lower-case, as Node and every HTTP/2 client send it,
	 * still returns the cached response: header names carry no case, so the key must be found whatever case the client used.
	 *
	 * @see API_Inbound.checkIdempotency
	 */
	@IsTest
	private static void shouldReturnCachedResponseWhenIdempotencyHeaderNameIsLowerCase()
	{
		String idempotencyKey = UTIL_Random.randomUUID();
		String cachedResponseBody = '{"cached":"true","echo":"intercepted"}';

		insertCompletedApiCall(idempotencyKey, cachedResponseBody);

		enableIdempotency();

		setupContext();
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY.toLowerCase(), idempotencyKey);

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		Assert.areEqual(cachedResponseBody, handler.result.responseBody, 'A lower-case idempotency header name should still return the cached response');
	}

	/**
	 * @description Proves the call record keeps the idempotency key when the header name arrives all upper-case, so a replay can find it.
	 *
	 * @see API_Inbound.checkIdempotency
	 */
	@IsTest
	private static void shouldPersistIdempotencyKeyWhenHeaderNameIsUpperCase()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		enableIdempotency();

		setupContext();
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY.toUpperCase(), idempotencyKey);

		Test.startTest();

		API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		ApiCall__c apiCall = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME).iterator().next();

		Assert.areEqual(idempotencyKey, apiCall.IdempotencyKey__c, 'An upper-case idempotency header name should still persist the key');
	}

	/**
	 * @description Proves the content type is read when its header name arrives all lower-case, so a JSON body from such a client is recognised.
	 *
	 * @see API_Inbound.getEncoding
	 */
	@IsTest
	private static void shouldReadContentTypeWhenHeaderNameIsLowerCase()
	{
		setupContext();
		RestContext.request.headers.remove(API_Base.HTTP_CONTENT_TYPE);
		RestContext.request.headers.put(API_Base.HTTP_CONTENT_TYPE.toLowerCase(), API_Base.HTTP_ENCODING_JSON);

		Test.startTest();

		String encoding = new API_HeaderReader().readEncoding();

		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_ENCODING_JSON, encoding, 'A lower-case content type header name should still be read');
	}

	/**
	 * @description Proves the content type is read when its header name arrives in mixed case.
	 *
	 * @see API_Inbound.getEncoding
	 */
	@IsTest
	private static void shouldReadContentTypeWhenHeaderNameIsMixedCase()
	{
		setupContext();
		RestContext.request.headers.remove(API_Base.HTTP_CONTENT_TYPE);
		RestContext.request.headers.put(MIXED_CASE_CONTENT_TYPE, API_Base.HTTP_ENCODING_JSON);

		Test.startTest();

		String encoding = new API_HeaderReader().readEncoding();

		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_ENCODING_JSON, encoding, 'A mixed-case content type header name should still be read');
	}

	/**
	 * @description Proves the caller's trace is adopted when the trace header name arrives capitalised as `Traceparent`, so a caller that
	 * does not send the lower-case spelling still has its calls tied to its own trace.
	 *
	 * @see API_Inbound.extractTraceContext
	 */
	@IsTest
	private static void shouldAdoptTraceParentWhenHeaderNameIsCapitalised()
	{
		String traceId = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
		String spanId = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 16);
		String traceParent = '00-' + traceId + '-' + spanId + '-01';

		setupContext();
		RestContext.request.headers.put(API_Base.HEADER_TRACE_PARENT.capitalize(), traceParent);

		Test.startTest();

		API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		ApiCall__c apiCall = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME).iterator().next();

		Assert.areEqual(traceId, apiCall.TraceId__c, 'Trace ID should be parsed from a capitalised Trace Parent header');
		Assert.areEqual(spanId, apiCall.ParentSpanId__c, 'Parent span ID should be parsed from a capitalised Trace Parent header');
	}

	/**
	 * @description Proves that when a request carries the content type under both the canonical and the lower-case spelling, the canonical
	 * one is read, so a request that worked before keeps reading the same value.
	 *
	 * @see API_Inbound.getEncoding
	 */
	@IsTest
	private static void shouldPreferCanonicalContentTypeWhenBothSpellingsArePresent()
	{
		setupContext();
		RestContext.request.headers.put(API_Base.HTTP_CONTENT_TYPE.toLowerCase(), LOWER_CASE_CONTENT_TYPE_VALUE);

		Test.startTest();

		String encoding = new API_HeaderReader().readEncoding();

		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_ENCODING_JSON, encoding, 'The canonically spelled content type should win over the lower-case one');
	}

	/**
	 * @description Proves the header read the Web Services guide shows, written inside a handler's getValidationErrors override, compiles and
	 * finds a header sent in lower case, and reports the header as missing when the request does not carry it.
	 *
	 * @see UTIL_Map.CaseInsensitiveMap
	 */
	@IsTest
	private static void shouldReadHeaderInsideOverrideAsTheGuideShows()
	{
		setupContext();
		API_HeaderReader reader = new API_HeaderReader();

		Test.startTest();

		List<String> errorsWithoutHeader = reader.getValidationErrors();
		RestContext.request.headers.put(PARTNER_HEADER.toLowerCase(), UTIL_Random.randomName());
		List<String> errorsWithHeader = reader.getValidationErrors();

		Test.stopTest();

		Assert.areEqual(new List<String> {PARTNER_HEADER_REQUIRED}, errorsWithoutHeader, 'A request without the partner header should fail validation');
		Assert.isTrue(errorsWithHeader.isEmpty(), 'A lower-case partner header should satisfy the validation');
	}

	/**
	 * @description Tests that the idempotency key is persisted on the ApiCall after successful
	 * processing when idempotency is enabled for the service via the ApiSetting metadata,
	 * along with the SHA-256 body hash used for replay-divergence detection.
	 *
	 * @see API_Inbound.setApiCallDetails
	 */
	@IsTest
	private static void shouldCacheIdempotencyKeyAfterSuccessfulProcessing()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		enableIdempotency();

		DTO_InboundTest inboundRequest = setupContext();
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		List<ApiCall__c> apiCalls = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		ApiCall__c apiCall = apiCalls.iterator().next();

		String expectedBodyHash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(inboundRequest.serialize())));
		Assert.areEqual(inboundRequest.serialize(), handler.result.responseBody, 'Should echo request body on first call');
		Assert.areEqual(idempotencyKey, apiCall.IdempotencyKey__c, 'Idempotency key should be persisted');
		Assert.areEqual(expectedBodyHash, apiCall.IdempotencyKeyBodyHash__c, 'Body hash should be persisted as SHA-256 hex');
	}

	/**
	 * @description Tests that a replay with the same Idempotency-Key AND a matching body hash
	 * returns the cached response with HTTP 200 — the standard idempotent-replay path.
	 *
	 * @see API_Inbound.checkIdempotency
	 */
	@IsTest
	private static void shouldReturnCachedResponseWhenIdempotencyKeyAndBodyMatch()
	{
		String idempotencyKey = UTIL_Random.randomUUID();
		String matchingRequestBody = '{"helloWorld":"replay-payload"}';
		String cachedResponseBody = '{"cached":"true","echo":"replay-payload"}';
		String matchingBodyHash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(matchingRequestBody)));

		TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.withOverride(ApiCall__c.IdempotencyKeyBodyHash__c, matchingBodyHash)
				.withOverride(ApiCall__c.Response__c, cachedResponseBody)
				.withOverride(ApiCall__c.ServiceName__c, SERVICE_NAME)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_COMPLETED)
				.build();

		enableIdempotency();
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestBody = Blob.valueOf(matchingRequestBody);
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);
		Test.stopTest();

		Assert.areEqual(cachedResponseBody, handler.result.responseBody, 'Should return cached response when bodies match');
		Assert.areEqual(API_Base.HTTP_OK, RestContext.response.statusCode, 'Status code should be 200 for matching-body replay');
	}

	/**
	 * @description Tests that a replay with the same Idempotency-Key but a DIFFERENT request body
	 * returns HTTP 409 with a JSON body that references the original ApiCall__c.Id, surfacing the
	 * contract violation instead of silently returning a cached response that doesn't match the
	 * caller's new input.
	 *
	 * @see API_Inbound.checkIdempotency
	 * @see API_Base.HTTP_CONFLICT
	 */
	@IsTest
	private static void shouldReturnConflictWhenIdempotencyKeyReusedWithDifferentBody()
	{
		String idempotencyKey = UTIL_Random.randomUUID();
		String originalRequestBody = '{"helloWorld":"original"}';
		String divergentRequestBody = '{"helloWorld":"different"}';
		String originalBodyHash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(originalRequestBody)));

		ApiCall__c originalCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.withOverride(ApiCall__c.IdempotencyKeyBodyHash__c, originalBodyHash)
				.withOverride(ApiCall__c.Response__c, '{"echo":"original"}')
				.withOverride(ApiCall__c.ServiceName__c, SERVICE_NAME)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_COMPLETED)
				.build();

		enableIdempotency();
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestBody = Blob.valueOf(divergentRequestBody);
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);
		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_CONFLICT, RestContext.response.statusCode, 'Status code should be 409 for body-divergence replay');
		Map<String, Object> conflictBody = (Map<String, Object>)JSON.deserializeUntyped(handler.result.responseBody);
		Assert.areEqual('Idempotency-Key reused with different request body', conflictBody.get('error'), 'Conflict response should explain the divergence');
		Assert.areEqual(originalCall.Id, conflictBody.get('originalApiCallId'), 'Conflict response should reference the original ApiCall.Id');
	}

	/**
	 * @description Tests backward-compat for legacy ApiCall__c records that predate the body-hash
	 * field. When `IdempotencyKeyBodyHash__c` is blank on the existing record, the framework cannot
	 * detect divergence — it returns the cached response (existing behaviour) rather than 409. This
	 * test seeds a legacy-shape record with no body hash, replays with a different body, and asserts
	 * HTTP 200 with the cached response (no 409).
	 *
	 * @see API_Inbound.checkIdempotency
	 */
	@IsTest
	private static void shouldReturnCachedResponseWhenLegacyApiCallHasNoBodyHash()
	{
		String idempotencyKey = UTIL_Random.randomUUID();
		String divergentRequestBody = '{"helloWorld":"new-shape"}';
		String cachedResponseBody = '{"echo":"legacy-cached"}';

		insertCompletedApiCall(idempotencyKey, cachedResponseBody);

		enableIdempotency();
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestBody = Blob.valueOf(divergentRequestBody);
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);
		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_OK, RestContext.response.statusCode, 'Legacy record without body hash should return 200 (no 409 detection possible)');
		Assert.areEqual(cachedResponseBody, handler.result.responseBody, 'Should return the legacy cached response');
	}

	/**
	 * @description Tests that a retry with the same idempotency key is allowed when the
	 * original call failed. Only completed calls should block re-processing.
	 *
	 * @see API_Inbound.checkIdempotency
	 */
	@IsTest
	private static void shouldAllowRetryWhenPreviousCallFailed()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.withOverride(ApiCall__c.Response__c, '{"error":"something went wrong"}')
				.withOverride(ApiCall__c.ServiceName__c, SERVICE_NAME)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_FAILED)
				.build();

		enableIdempotency();

		DTO_InboundTest inboundRequest = setupContext();
		RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);

		Test.stopTest();

		Assert.areEqual(inboundRequest.serialize(), handler.result.responseBody, 'Should process normally after a failed call');
		Assert.areEqual(API_Base.HTTP_OK, RestContext.response.statusCode, 'Should return 200 on successful retry');
	}

	/**
	 * @description Verifies that inbound service aborts when IsActive__c is false on ApiSetting__mdt.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldAbortWhenServiceIsInactive()
	{
		enableApiSettingFeature(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => false
		});

		setupContext();

		API_InboundTestHelper.assertCallAborted(SERVICE_NAME, API_Base.ERROR_API_INACTIVE);
	}

	/**
	 * @description Verifies that inbound service aborts when RequiredFeatureFlag__c names a disabled feature flag.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldAbortWhenRequiredConditionNotMet()
	{
		String flagName = 'DisabledInboundFlag';
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = false;

		SEL_FeatureFlag.activeFlags.put(flagName, newFlag);
		SEL_FeatureFlag.allDeveloperNames = new Set<String>(SEL_FeatureFlag.allDeveloperNames);
		SEL_FeatureFlag.allDeveloperNames.add(flagName);

		enableApiSettingFeature(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => true,
				ApiSetting__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag(flagName, false)
		});

		setupContext();

		API_InboundTestHelper.assertCallAborted(SERVICE_NAME,
				String.format(API_Base.ERROR_REQUIRED_CONDITION_NOT_MET, new List<String> {flagName}));
	}

	/**
	 * @description Verifies that inbound service succeeds when RequiredFeatureFlag__c names an enabled feature flag.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldSucceedWhenRequiredConditionMet()
	{
		String flagName = 'EnabledInboundFlag';
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = true;

		SEL_FeatureFlag.activeFlags.put(flagName, newFlag);
		SEL_FeatureFlag.allDeveloperNames = new Set<String>(SEL_FeatureFlag.allDeveloperNames);
		SEL_FeatureFlag.allDeveloperNames.add(flagName);

		enableApiSettingFeature(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => true,
				ApiSetting__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag(flagName, false)
		});

		setupContext();

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
	}

	/**
	 * @description Verifies that inbound service aborts when BypassFeatureFlag__c names an enabled feature flag.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldAbortWhenBypassFeatureFlagActive()
	{
		String flagName = 'BypassInboundFlag';
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = true;

		SEL_FeatureFlag.activeFlags.put(flagName, newFlag);
		SEL_FeatureFlag.allDeveloperNames = new Set<String>(SEL_FeatureFlag.allDeveloperNames);
		SEL_FeatureFlag.allDeveloperNames.add(flagName);

		enableApiSettingFeature(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => true,
				ApiSetting__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag(flagName, false)
		});

		setupContext();

		API_InboundTestHelper.assertCallAborted(SERVICE_NAME,
				String.format(API_Base.ERROR_API_BYPASSED, new List<String> {flagName}));
	}

	/**
	 * @description Creates a mock ApiSetting__mdt for the Echo API with additional field overrides.
	 *
	 * @param overrides Map of ApiSetting__mdt fields to override beyond the defaults
	 */
	private static void enableApiSettingFeature(Map<SObjectField, Object> overrides)
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, TEST_ENDPOINT_PATH, 100, overrides);
	}

	/**
	 * @description Saves a completed Echo API call carrying an idempotency key and the response a replay should return.
	 *
	 * @param idempotencyKey The idempotency key the earlier call was made with
	 * @param responseBody The response the earlier call returned
	 */
	private static void insertCompletedApiCall(String idempotencyKey, String responseBody)
	{
		TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.withOverride(ApiCall__c.Response__c, responseBody)
				.withOverride(ApiCall__c.ServiceName__c, SERVICE_NAME)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_COMPLETED)
				.build();
	}

	/**
	 * @description Enables idempotency for the Echo API by mocking the ApiSetting metadata record.
	 */
	private static void enableIdempotency()
	{
		enableApiSettingFeature(new Map<SObjectField, Object> {ApiSetting__mdt.IdempotencyEnabled__c => true});
	}

	/**
	 * @description An inbound handler written the way the Web Services guide shows, used to read request headers through the protected API.
	 */
	private class API_HeaderReader extends API_Inbound
	{
		/**
		 * @description Rejects a request that does not name the partner sending it, reading the header exactly as the guide's example does.
		 *
		 * @return The validation errors, empty when the partner header is present in any case
		 */
		public override List<String> getValidationErrors()
		{
			List<String> errors = super.getValidationErrors();
			String partner = (String)new UTIL_Map.CaseInsensitiveMap(request.headers).get(PARTNER_HEADER);

			if(String.isBlank(partner))
			{
				errors.add(PARTNER_HEADER_REQUIRED);
			}

			return errors;
		}

		/**
		 * @description Reads the request's content type through the handler's own encoding lookup.
		 *
		 * @return The content type header value, or null when the request has none
		 */
		public String readEncoding()
		{
			return getEncoding();
		}
	}

	/**
	 * @description Class used to generate a test JSON payload to test the API
	 */
	private class DTO_InboundTest extends DTO_JsonBase
	{
		/**
		 * @description The only value in the test payload. The tests give it a random value so the request body serialises to
		 * JSON of the form {"helloWorld":"..."} and each test can check that the same body comes back from the echo service.
		 */
		private String helloWorld;

		/**
		 * @description The Type of the DTO used when deserializing the class
		 *
		 * @return Class of the DTO
		 */
		public override Type getObjectType()
		{
			return DTO_InboundTest.class;
		}
	}
}