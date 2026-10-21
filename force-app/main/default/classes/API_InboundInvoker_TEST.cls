// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for API_InboundInvoker. Verifies invocation of inbound API
 * requests with and without Safe Mode, replay from failure records, and error handling.
 *
 * @see API_InboundInvoker
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class API_InboundInvoker_TEST
{
	/**
	 * @description The service class name used for routing.
	 */
	private static final String SERVICE_NAME = API_Echo.class.getName();
	/**
	 * @description Test request body payload.
	 */
	private static final String TEST_BODY = '{"hello":"world"}';
	/**
	 * @description Test request path matching the echo route pattern.
	 */
	private static final String TEST_PATH = '/echo/test';
	/**
	 * @description HTTP POST method constant.
	 */
	private static final String HTTP_POST = 'POST';
	/**
	 * @description A stored request body in XML, which the inbound base class does not read into a request object.
	 */
	private static final String TEST_XML_BODY = '<hello>world</hello>';
	/**
	 * @description Stored parameters that are not the JSON text a call keeps them as, so they cannot be read back.
	 */
	private static final String UNREADABLE_PARAMETERS = 'reference=order-42';
	/**
	 * @description The character a stored body is filled with when a test needs a body that fills the call's Request__c
	 * field to its full length, as a body that was cut does.
	 */
	private static final String FILL_CHARACTER = 'x';

	/**
	 * @description Tests that invocation populates status code, response body, request body, and execution time.
	 */
	@IsTest
	private static void shouldPopulateResultFieldsOnSuccessfulInvocation()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.areEqual(API_Base.HTTP_OK, invocationResult.statusCode, 'Should return 200');
		Assert.isFalse(invocationResult.safeModeEnabled, 'Safe mode should be off');
		Assert.isNotNull(invocationResult.responseBody, 'Response body should be set');
		Assert.areEqual(TEST_BODY, invocationResult.requestBody, 'Request body should be preserved');
		Assert.isNotNull(invocationResult.executionTimeMs, 'Execution time should be tracked');
	}

	/**
	 * @description Tests that Safe Mode invocation captures service name, status, and HTTP method from the handler.
	 */
	@IsTest
	private static void shouldCaptureHandlerMetadataWithSafeModeEnabled()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, true);

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Safe mode should be enabled');
		Assert.isNotNull(invocationResult.serviceName, 'Service name should be captured');
		Assert.isNotNull(invocationResult.status, 'Status should be captured');
		Assert.isNotNull(invocationResult.httpMethod, 'HTTP method should be captured');
	}

	/**
	 * @description Tests that the three-parameter overload enables Safe Mode by default.
	 */
	@IsTest
	private static void shouldDefaultToSafeModeForThreeParameterOverload()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY);

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Should default to safe mode enabled');
	}

	/**
	 * @description Tests that an unmatched request path produces a 404 Not Found response.
	 */
	@IsTest
	private static void shouldReturnNotFoundForUnmatchedPath()
	{
		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke('/nonexistent/path', 'GET', null, false);

		Assert.areEqual(API_Base.HTTP_NOT_FOUND, invocationResult.statusCode, 'Should return 404');
		Assert.isFalse(invocationResult.success, 'Should not be successful');
	}

	/**
	 * @description Creates an inbound issue made by hand for replay testing: it links to no call, holds the request in
	 * its own fields and names the echo service.
	 *
	 * @return The inserted ApiIssue__c record
	 */
	private static ApiIssue__c createInboundFailure()
	{
		return (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.RequestPath__c, TEST_PATH)
				.withOverride(ApiIssue__c.RequestMethod__c, HTTP_POST)
				.withOverride(ApiIssue__c.RequestBody__c, TEST_BODY)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, SERVICE_NAME)
				.build();
	}

	/**
	 * @description An issue that links to no call and holds no request in its own fields has nothing to run again. The
	 * replay is refused with the labelled message that says so, and it is not successful.
	 */
	@IsTest
	private static void shouldRefuseToReplayAnIssueWithNoRequest()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, SERVICE_NAME)
				.build();

		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, false);

		Assert.isFalse(invocationResult.success, 'Expected the replay to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_OriginalCallMissing, invocationResult.errorText, 'Expected the refusal to come from the label');
		Assert.isTrue(new SEL_ApiCall().findByServiceName(SERVICE_NAME).isEmpty(), 'Expected nothing to run');
	}

	/**
	 * @description Saves a failed inbound call of the echo service that kept the test request (path, method and body, with
	 * the hash of the body), and an inbound issue that links to it.
	 *
	 * @param requestParameters The parameters the call kept, or null for none
	 *
	 * @return The saved issue
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static ApiIssue__c insertIssueOfFailedCall(String requestParameters)
	{
		ApiCall__c originalCall = TST_Factory.newInboundApiCall(SERVICE_NAME);
		originalCall.Status__c = SEL_ApiCall.STATUS_FAILED;
		originalCall.URL__c = TEST_PATH;
		originalCall.HttpMethod__c = HTTP_POST;
		originalCall.Request__c = TEST_BODY;
		originalCall.IdempotencyKeyBodyHash__c = API_Inbound.computeBodyHash(TEST_BODY);
		originalCall.RequestParameters__c = requestParameters;
		DML_Builder.newTransaction().withSystemMode().doInsert(originalCall).execute();
		return (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, SERVICE_NAME)
				.withOverride(ApiIssue__c.ApiCall__c, originalCall.Id)
				.build();
	}

	/**
	 * @description A call that kept no parameters is replayed from the call: the body it kept reaches the echo service
	 * unchanged, and the replay's call links to the call the request was read from.
	 */
	@IsTest
	private static void shouldReplayTheRequestOfACallWithNoParameters()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = insertIssueOfFailedCall(null);

		Test.startTest();
		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, false);
		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Expected the replay to succeed, got: ' + invocationResult.errorText);
		Assert.areEqual(TEST_BODY, invocationResult.responseBody, 'Expected the echo service to receive the body the call kept');
		Boolean isLinked = false;
		for(ApiCall__c apiCall : new SEL_ApiCall().findByServiceName(SERVICE_NAME))
		{
			isLinked = isLinked || apiCall.PreviousAttempt__c == failure.ApiCall__c;
		}
		Assert.isTrue(isLinked, 'Expected the replay\'s call to link to the call the request was read from');
	}

	/**
	 * @description Parameters the call kept that cannot be read back may not be what the request carried, so the request
	 * is not replayed: the replay is refused with the labelled message that says the stored request is not the one
	 * received, even though the body's hash matches.
	 */
	@IsTest
	private static void shouldRefuseToReplayParametersThatCannotBeReadBack()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = insertIssueOfFailedCall(UNREADABLE_PARAMETERS);

		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, false);

		Assert.isFalse(invocationResult.success, 'Expected the replay to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_StoredRequestDiffers, invocationResult.errorText, 'Expected the refusal to come from the label');
		Assert.areEqual(1, new SEL_ApiCall().findByServiceName(SERVICE_NAME).size(), 'Expected nothing to run');
	}

	/**
	 * @description Builds, without saving it, a failed inbound call of the echo service that kept the test path and method
	 * and the given body, the way version 1.8 saved a request with no Idempotency-Key: no key and no hash of the body.
	 *
	 * @param storedBody The body the call kept
	 *
	 * @return The call, not yet saved
	 */
	private static ApiCall__c newFailedCallWithoutAHash(String storedBody)
	{
		ApiCall__c originalCall = TST_Factory.newInboundApiCall(SERVICE_NAME);
		originalCall.Status__c = SEL_ApiCall.STATUS_FAILED;
		originalCall.URL__c = TEST_PATH;
		originalCall.HttpMethod__c = HTTP_POST;
		originalCall.Request__c = storedBody;
		return originalCall;
	}

	/**
	 * @description Saves a call and an inbound issue of the echo service that links to it. When a body is given, the issue
	 * also holds the test path, method and that body in its own fields, as a person may have typed them in version 1.8.
	 *
	 * @param originalCall The call to save
	 * @param issueBody The body the issue holds, or null for an issue that holds no request of its own
	 *
	 * @return The saved issue
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static ApiIssue__c insertIssueOfCall(ApiCall__c originalCall, String issueBody)
	{
		DML_Builder.newTransaction().withSystemMode().doInsert(originalCall).execute();
		TST_Builder.Builder issueBuilder = TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, SERVICE_NAME)
				.withOverride(ApiIssue__c.ApiCall__c, originalCall.Id);
		if(issueBody != null)
		{
			issueBuilder
					.withOverride(ApiIssue__c.RequestPath__c, TEST_PATH)
					.withOverride(ApiIssue__c.RequestMethod__c, HTTP_POST)
					.withOverride(ApiIssue__c.RequestBody__c, issueBody);
		}
		return (ApiIssue__c)issueBuilder.build();
	}

	/**
	 * @description Checks that a replay ran and that the echo service received the given body, and that the replay's call
	 * links to the issue's call.
	 *
	 * @param invocationResult What the replay returned
	 * @param failure The issue whose request was run again
	 * @param expectedBody The body the echo service should have received
	 */
	private static void assertReplayedBody(DTO_InvocationResult invocationResult, ApiIssue__c failure, String expectedBody)
	{
		Assert.isTrue(invocationResult.success, 'Expected the replay to succeed, got: ' + invocationResult.errorText);
		Assert.areEqual(expectedBody, invocationResult.responseBody, 'Expected the echo service to receive the body, got ' + invocationResult.responseBody);
		Boolean isLinked = false;
		for(ApiCall__c apiCall : new SEL_ApiCall().findByServiceName(SERVICE_NAME))
		{
			isLinked = isLinked || apiCall.PreviousAttempt__c == failure.ApiCall__c;
		}
		Assert.isTrue(isLinked, 'Expected the replay\'s call to link to the issue\'s call');
	}

	/**
	 * @description Version 1.8 recorded the hash of the body only for a request with an Idempotency-Key. So an issue on a
	 * call with no key and no hash, saved by version 1.8, is replayed from the call when the call kept the body whole: the
	 * missing hash means the body cannot be checked, not that it was changed.
	 */
	@IsTest
	private static void shouldReplayTheBodyOfACallWithNoKeyAndNoHash()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = insertIssueOfCall(newFailedCallWithoutAHash(TEST_BODY), null);

		Test.startTest();
		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, false);
		Test.stopTest();

		assertReplayedBody(invocationResult, failure, TEST_BODY);
	}

	/**
	 * @description A call with no key and no hash whose body fills Request__c to its full length may have been cut. When
	 * its issue holds a request in its own fields, as version 1.8 ran it, the request the issue holds is replayed instead,
	 * and the replay's call still links to the issue's call.
	 */
	@IsTest
	private static void shouldReplayTheIssuesOwnRequestWhenACallWithNoHashKeptItsBodyCut()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = insertIssueOfCall(newFailedCallWithoutAHash(FILL_CHARACTER.repeat(SEL_ApiCall.REQUEST_LENGTH)), TEST_BODY);

		Test.startTest();
		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, false);
		Test.stopTest();

		assertReplayedBody(invocationResult, failure, TEST_BODY);
	}

	/**
	 * @description A call with no key and no hash whose body fills Request__c to its full length may have been cut, and its
	 * issue holds no request of its own. Nothing whole is left to run, so the replay is refused with the labelled message
	 * that says the stored request is not the one received.
	 */
	@IsTest
	private static void shouldRefuseACallWithNoHashThatKeptItsBodyCutWhenTheIssueHoldsNoRequest()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = insertIssueOfCall(newFailedCallWithoutAHash(FILL_CHARACTER.repeat(SEL_ApiCall.REQUEST_LENGTH)), null);

		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, false);

		Assert.isFalse(invocationResult.success, 'Expected the replay to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_StoredRequestDiffers, invocationResult.errorText, 'Expected the refusal to come from the label');
		Assert.areEqual(1, new SEL_ApiCall().findByServiceName(SERVICE_NAME).size(), 'Expected nothing to run');
	}

	/**
	 * @description A call whose recorded hash differs from the hash of the body it kept no longer holds the body it
	 * received, so the replay is refused with the labelled message, even when the issue holds a request of its own. A call
	 * with a key but no hash is refused the same way: a call with a key always recorded the hash.
	 */
	@IsTest
	private static void shouldRefuseACallWhoseBodyCannotBeProvedToBeTheOneReceived()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiCall__c changedBodyCall = newFailedCallWithoutAHash(TEST_BODY);
		changedBodyCall.IdempotencyKeyBodyHash__c = API_Inbound.computeBodyHash(TEST_XML_BODY);
		ApiCall__c keyedCall = newFailedCallWithoutAHash(TEST_BODY);
		keyedCall.IdempotencyKey__c = UTIL_Random.randomUUID();
		ApiIssue__c changedBodyIssue = insertIssueOfCall(changedBodyCall, TEST_BODY);
		ApiIssue__c keyedIssue = insertIssueOfCall(keyedCall, null);

		DTO_InvocationResult changedBodyResult = API_InboundInvoker.replay(changedBodyIssue.Id, false);
		DTO_InvocationResult keyedResult = API_InboundInvoker.replay(keyedIssue.Id, false);

		Assert.areEqual(System.Label.RetryApiIssue_StoredRequestDiffers, changedBodyResult.errorText, 'Expected the changed body to be refused by the label');
		Assert.areEqual(System.Label.RetryApiIssue_StoredRequestDiffers, keyedResult.errorText, 'Expected the keyed call with no hash to be refused by the label');
		Assert.areEqual(2, new SEL_ApiCall().findByServiceName(SERVICE_NAME).size(), 'Expected nothing to run');
	}

	/**
	 * @description Tests that replay re-executes the request from the stored failure record.
	 */
	@IsTest
	private static void shouldReplayRequestFromFailureRecord()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = createInboundFailure();

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.replay(failure.Id, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Replay should succeed');
		Assert.areEqual(TEST_BODY, invocationResult.requestBody, 'Should use body from failure record');
	}

	/**
	 * @description Tests that replay returns Not Found when the failure record does not exist.
	 */
	@IsTest
	private static void shouldReturnNotFoundWhenFailureRecordMissing()
	{
		Id fakeId = UTIL_Random.randomId(ApiIssue__c.SObjectType);

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.replay(fakeId, false);

		Assert.areEqual(API_Base.HTTP_NOT_FOUND, invocationResult.statusCode, 'Should return 404');
		Assert.isFalse(invocationResult.errors.isEmpty(), 'Should contain error message');
	}

	/**
	 * @description Tests that the single-parameter replay overload enables Safe Mode by default.
	 */
	@IsTest
	private static void shouldDefaultToSafeModeForSingleParameterReplay()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = createInboundFailure();

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.replay(failure.Id);

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Should default to safe mode enabled');
	}

	/**
	 * @description Tests that platform-level exceptions produce a 500 status with error details.
	 */
	@IsTest
	private static void shouldReturnInternalServerErrorOnException()
	{
		API_InboundInvoker.forceException = true;

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, false);

		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, invocationResult.statusCode, 'Should return 500');
		Assert.isFalse(invocationResult.errors.isEmpty(), 'Should contain error details');
		Assert.isFalse(invocationResult.success, 'Should not be successful');
	}

	/**
	 * @description Tests that Safe Mode context is released even when an exception occurs.
	 */
	@IsTest
	private static void shouldCloseSafeModeContextOnException()
	{
		API_InboundInvoker.forceException = true;

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, true);

		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, invocationResult.statusCode, 'Should return 500');
		Assert.isTrue(invocationResult.safeModeEnabled, 'Safe mode should have been enabled');
		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe mode should be closed after exception');
	}

	/**
	 * @description Tests that invokeByServiceName resolves the endpoint path from ApiSetting metadata.
	 */
	@IsTest
	private static void shouldResolveEndpointPathFromApiSettingMetadata()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invokeByServiceName(SERVICE_NAME, TEST_BODY, false, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Should succeed when resolving by service name');
		Assert.areEqual(API_Base.HTTP_OK, invocationResult.statusCode, 'Should return 200');
		Assert.isFalse(invocationResult.mockingEnabled, 'Mocking should be disabled');
	}

	/**
	 * @description Tests that invokeByServiceName produces a mocked response when mocking is enabled.
	 */
	@IsTest
	private static void shouldReturnMockedResponseWhenMockingEnabledByServiceName()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invokeByServiceName(SERVICE_NAME, TEST_BODY, false, true);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Should succeed');
		Assert.isTrue(invocationResult.mockingEnabled, 'Mocking should be enabled');
		Assert.isTrue(invocationResult.isMockedResponse, 'Response should be mocked');
	}

	/**
	 * @description Tests that invokeByServiceName returns Not Found when no ApiSetting metadata exists.
	 */
	@IsTest
	private static void shouldReturnNotFoundWhenApiSettingMissing()
	{
		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invokeByServiceName('API_NonExistent', TEST_BODY, false, false);

		Assert.areEqual(API_Base.HTTP_NOT_FOUND, invocationResult.statusCode, 'Should return 404');
		Assert.isFalse(invocationResult.errors.isEmpty(), 'Should contain error message');
	}

	/**
	 * @description Tests that custom request headers are surfaced in the invocation result.
	 */
	@IsTest
	private static void shouldSurfaceCustomRequestHeaders()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Map<String, String> headers = new Map<String, String>
		{
				'X-Test-Header' => 'test-value'
		};

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, headers, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.isFalse(invocationResult.requestHeaders.isEmpty(), 'Request headers should be captured');
		Assert.isTrue(invocationResult.requestHeaders.exists('X-Test-Header'), 'Should contain custom header');
	}

	/**
	 * @description Tests that the Idempotency-Key header propagates to the ApiCall record.
	 */
	@IsTest
	private static void shouldPropagateIdempotencyKeyHeaderToApiCallRecord()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Map<String, String> headers = new Map<String, String>
		{
				'Idempotency-Key' => 'test-key-12345',
				'X-Custom-Header' => 'custom-value'
		};

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, headers, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.areEqual(TEST_BODY, invocationResult.requestBody, 'Request body should match');

		ApiCall__c apiCallRecord = new SEL_ApiCall().findByIdempotencyKey('test-key-12345');
		Assert.isNotNull(apiCallRecord, 'Idempotency-Key header should be captured on API call record');
		Assert.areEqual('test-key-12345', apiCallRecord.IdempotencyKey__c, 'Idempotency-Key header value should be applied to request');
	}

	/**
	 * @description Tests that toConcreteEndpointPath returns a default path when the endpoint pattern is blank.
	 */
	@IsTest
	private static void shouldReturnDefaultPathWhenEndpointPatternIsBlank()
	{
		Assert.areEqual('/test', API_InboundInvoker.toConcreteEndpointPath(null), 'Null pattern should produce default path');
		Assert.areEqual('/test', API_InboundInvoker.toConcreteEndpointPath(''), 'Empty pattern should produce default path');
	}

	/**
	 * @description A replay from a stored issue hands the stored body to the handler as its parsed request, as the original request
	 * did: the handler saves a record named by a field of the body, and the record is found by that name. The issue keeps no headers,
	 * so the replay must say the body is JSON itself; without that the handler runs on an empty request and still reports success.
	 */
	@IsTest
	private static void shouldHandTheStoredBodyToTheHandlerAsItsParsedRequestOnReplay()
	{
		String serviceName = RecordSavingInbound.class.getName();
		TST_Factory.newInboundApiSetting(serviceName, TEST_PATH);
		RecordSavingRequest storedRequest = new RecordSavingRequest();
		storedRequest.recordName = UTIL_Random.randomName();
		ApiIssue__c failure = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.RequestPath__c, TEST_PATH)
				.withOverride(ApiIssue__c.RequestMethod__c, HTTP_POST)
				.withOverride(ApiIssue__c.RequestBody__c, JSON.serialize(storedRequest))
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, serviceName)
				.build();

		Test.startTest();
		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, false);
		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Expected the replay to succeed, got: ' + invocationResult.errorText);
		Integer savedCount = QRY_Builder.selectFrom(Foobar__c.SObjectType).condition(Foobar__c.Name).equals(storedRequest.recordName).count();
		Assert.areEqual(1, savedCount, 'Expected the handler to save one record named by the stored body on replay, got ' + savedCount);
	}

	/**
	 * @description A replay of a stored issue with no body sends no content type header: there is nothing to read, so the replay
	 * does not say the request is JSON.
	 */
	@IsTest
	private static void shouldReplayAnIssueWithNoBodyWithoutAContentType()
	{
		TST_Factory.newInboundApiSetting(RecordSavingInbound.class.getName(), TEST_PATH);
		ApiIssue__c failure = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.RequestPath__c, TEST_PATH)
				.withOverride(ApiIssue__c.RequestMethod__c, HTTP_POST)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, RecordSavingInbound.class.getName())
				.build();

		Test.startTest();
		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, true);
		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Expected the replay with no body to reach the handler, got: ' + invocationResult.errorText);
		Boolean hasContentType = invocationResult.requestHeaders?.exists(API_Base.HTTP_CONTENT_TYPE) == true;
		Assert.isFalse(hasContentType, 'Expected no content type header on a replay with no body');
	}

	/**
	 * @description A replay of a stored XML body sends no content type header, as before, and the handler that reads the raw body
	 * gets it unchanged: the echo handler sends back exactly the stored XML.
	 */
	@IsTest
	private static void shouldReplayAnXmlBodyWithoutAContentTypeAndUnchanged()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.RequestPath__c, TEST_PATH)
				.withOverride(ApiIssue__c.RequestMethod__c, HTTP_POST)
				.withOverride(ApiIssue__c.RequestBody__c, TEST_XML_BODY)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, SERVICE_NAME)
				.build();

		Test.startTest();
		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(failure.Id, false);
		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Expected the replay of an XML body to succeed, got: ' + invocationResult.errorText);
		Assert.areEqual(TEST_XML_BODY, invocationResult.responseBody, 'Expected the handler to receive the stored XML body unchanged');
		Boolean hasContentType = invocationResult.requestHeaders?.exists(API_Base.HTTP_CONTENT_TYPE) == true;
		Assert.isFalse(hasContentType, 'Expected no content type header on a replay of an XML body');
	}

	/**
	 * @description The request a replayed body is parsed into: the name of the record the handler saves.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class RecordSavingRequest extends DTO_JsonBase
	{
		/**
		 * @description The name the saved record gets.
		 */
		public String recordName;
	}

	/**
	 * @description An inbound handler that saves one record, named by its parsed request, when the request succeeds.
	 */
	public inherited sharing class RecordSavingInbound extends API_Inbound
	{
		/**
		 * @description Sets the typed request so the body is parsed into it.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new RecordSavingRequest();
			responsePayload = new DTO_JsonBase();
		}

		/**
		 * @description Saves the record named by the request.
		 */
		public override void onSuccess()
		{
			super.onSuccess();
			doInsert(TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, ((RecordSavingRequest)requestPayload).recordName).withoutInsertion().build());
		}
	}
}