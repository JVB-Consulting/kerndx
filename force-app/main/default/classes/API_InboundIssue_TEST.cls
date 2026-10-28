// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the issue records that failed inbound requests write. A request that fails while it is handled, or
 * that its checks refuse, writes one open inbound issue when its setting has Log Issues on. The issue links to the call
 * and holds no copy of the request: the body, the address, the parameters and the key stay on the call. A request that
 * fails before a handler exists, reuses a key with another body, is answered by a mock, runs in Safe Mode, or belongs
 * to a service with Log Issues off writes no issue.
 *
 * @see API_Inbound
 * @see API_Dispatcher
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class API_InboundIssue_TEST
{
	/**
	 * @description The service the echo endpoint sends its requests to.
	 */
	private static final String SERVICE_NAME = API_Echo.class.getName();

	/**
	 * @description The path each test request is sent to. It matches the echo service's route.
	 */
	private static final String REQUEST_PATH = '/echo/test';

	/**
	 * @description The route pattern of the settings the tests register, so a request to the request path finds them.
	 */
	private static final String ROUTE_PATH = '/echo/*';

	/**
	 * @description The routing priority of the settings the tests register. Any value works, because each test registers
	 * one setting.
	 */
	private static final Integer ROUTE_PRIORITY = 100;

	/**
	 * @description The one field of the JSON body each test sends.
	 */
	private static final String BODY_FIELD = 'helloWorld';

	/**
	 * @description A body that starts as JSON and stops in the middle, so it cannot be read.
	 */
	private static final String UNREADABLE_BODY = '{"helloWorld":';

	/**
	 * @description The character that fills a body value until the body is longer than the Request field of the call.
	 */
	private static final String PADDING_CHARACTER = 'x';

	/**
	 * @description The message of the failure a test handler throws while it handles the request or checks it.
	 */
	private static final String MESSAGE_HANDLER_THREW = 'The handler threw on purpose';

	/**
	 * @description The message of the failure a test handler throws while it handles its own error.
	 */
	private static final String MESSAGE_ERROR_HANDLING_THREW = 'The error handling threw on purpose';

	/**
	 * @description The HTTP method each test request uses.
	 */
	private static final String HTTP_METHOD_POST = API_Base.toHttpString(API_Base.HttpMethod.POST);

	/**
	 * @description A request whose handler throws ends Failed, keeps the request on its call, and leaves one open inbound issue that links to
	 * the call and holds no copy of the request.
	 */
	@IsTest
	private static void shouldWriteOneOpenInboundIssueWhenTheHandlerThrows()
	{
		registerSettingWithLogIssues(SERVICE_NAME);
		String body = buildBody();
		String parameterName = UTIL_Random.randomName();
		String idempotencyKey = UTIL_Random.randomUUID();
		setupRequest(body, idempotencyKey);
		RestContext.request.addParameter(parameterName, UTIL_Random.randomName());
		API_Inbound.returnErrorResponse = true;

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(SERVICE_NAME, API_Inbound.ERROR_TEST_EXCEPTION_HANDLING).iterator().next();
		Assert.areEqual(body, failedCall.Request__c, 'Expected the call to keep the body as it was received');
		Assert.isTrue(failedCall.URL__c.startsWith(REQUEST_PATH), 'Expected the call to keep the path the request was sent to');
		Assert.isTrue(failedCall.RequestParameters__c.contains(parameterName), 'Expected the call to keep the query parameter');
		Assert.areEqual(idempotencyKey, failedCall.IdempotencyKey__c, 'Expected the call to keep the key the request carried');
		Assert.isNotNull(failedCall.IdempotencyKeyBodyHash__c, 'Expected the call to record the hash of the body it received');
		Assert.isFalse(failedCall.IsPermanentFailure__c, 'Expected a thrown exception not to mark the call permanent');
		Assert.areEqual(SERVICE_NAME, failedCall.ServiceName__c, 'Expected the call to name the service the request was sent to');
		assertOneLeanInboundIssue(failedCall);
	}

	/**
	 * @description A failed request whose body is longer than the Request field of the call still leaves one open inbound
	 * issue. The call keeps only the start of the body in the field. The issue links to the call and holds no copy of the
	 * request, as for a body that fits.
	 */
	@IsTest
	private static void shouldWriteOneOpenInboundIssueWhenTheBodyIsLongerThanTheRequestField()
	{
		registerSettingWithLogIssues(SERVICE_NAME);
		String body = JSON.serialize(new Map<String, Object> {BODY_FIELD => UTIL_Random.randomName().rightPad(SEL_ApiCall.REQUEST_LENGTH, PADDING_CHARACTER)});
		setupRequest(body, null);
		API_Inbound.returnErrorResponse = true;

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(SERVICE_NAME, API_Inbound.ERROR_TEST_EXCEPTION_HANDLING).iterator().next();
		Assert.isTrue(body.length() > SEL_ApiCall.REQUEST_LENGTH, 'Expected the body to be longer than the Request field, got ' + body.length());
		Assert.isTrue(failedCall.Request__c.length() <= SEL_ApiCall.REQUEST_LENGTH, 'Expected the call to keep no more of the body than its field holds');
		assertOneLeanInboundIssue(failedCall);
	}

	/**
	 * @description A request whose handler fails while its work is saved has that save rolled back, so the call is not
	 * saved yet when the failure is handled. The call is still saved as Failed, and its one issue links to it: the issue
	 * is registered with the call as its parent, so the save fills in the link once the call has an Id.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldWriteOneIssueWhenTheHandlersCommitFails()
	{
		registerSettingWithLogIssues(SERVICE_NAME);
		setupRequest(buildBody(), null);
		API_Echo.simulatePostCommitProcessing = true;

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(SERVICE_NAME, API_Echo.ERROR_POST_COMMIT).iterator().next();
		assertOneLeanInboundIssue(failedCall);
	}

	/**
	 * @description A request refused because every inbound API is switched off ends Aborted with status 400, and writes
	 * one issue. The switch is the case most worth recovering: the request can run once the APIs are switched on again.
	 */
	@IsTest
	private static void shouldWriteOneIssueWhenInboundApisAreSwitchedOff()
	{
		registerSettingWithLogIssues(SERVICE_NAME);
		TST_Factory.disableAllInboundApis();
		setupRequest(buildBody(), null);

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		ApiCall__c abortedCall = SEL_ApiCall.assertServiceAborted(SERVICE_NAME, API_Base.ERROR_API_DISABLED).iterator().next();
		Assert.areEqual(API_Base.HTTP_BAD_REQUEST, RestContext.response.statusCode, 'Expected status 400 for a refused request');
		assertOneLeanInboundIssue(abortedCall);
	}

	/**
	 * @description A request the handler's own checks refuse ends Aborted and writes one issue, and the call is not marked
	 * as a permanent failure. The request may become valid once the data it refers to is fixed, so it may be run again.
	 */
	@IsTest
	private static void shouldWriteATransientIssueWhenTheHandlerRefusesTheRequest()
	{
		registerSettingWithLogIssues(SERVICE_NAME);
		setupRequest(UTIL_String.EMPTY, null);

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		ApiCall__c abortedCall = SEL_ApiCall.assertServiceAborted(SERVICE_NAME, API_Echo.ERROR_NO_BODY_RECEIVED).iterator().next();
		Assert.isFalse(abortedCall.IsPermanentFailure__c, 'Expected errors the handler returns not to mark the call permanent');
		assertOneLeanInboundIssue(abortedCall);
	}

	/**
	 * @description A handler that throws a UTIL_Exceptions.PermanentFailureException while it handles the request ends
	 * the call Failed with status 400, marks the call as a permanent failure, and writes one issue.
	 */
	@IsTest
	private static void shouldMarkTheCallPermanentWhenTheHandlerRaisesAPermanentFailure()
	{
		String serviceName = PermanentFailureInbound.class.getName();
		registerSettingWithLogIssues(serviceName);
		setupRequest(buildBody(), null);

		Test.startTest();
		API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW).iterator().next();
		Assert.areEqual(API_Base.HTTP_BAD_REQUEST, RestContext.response.statusCode, 'Expected status 400 for a permanent failure');
		Assert.isTrue(failedCall.IsPermanentFailure__c, 'Expected a permanent failure to mark the call permanent');
		assertOneLeanInboundIssue(failedCall);
	}

	/**
	 * @description A handler that throws a UTIL_Exceptions.RequestRefusedException while it handles the request ends the
	 * call Failed with status 400 and writes one issue, but does not mark the call as a permanent failure: a person may run
	 * a refused request again once the cause is fixed.
	 */
	@IsTest
	private static void shouldNotMarkTheCallPermanentWhenTheHandlerRefusesTheRequest()
	{
		String serviceName = RequestRefusingInbound.class.getName();
		registerSettingWithLogIssues(serviceName);
		setupRequest(buildBody(), null);

		Test.startTest();
		API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW).iterator().next();
		Assert.areEqual(API_Base.HTTP_BAD_REQUEST, RestContext.response.statusCode, 'Expected status 400 for a refused request');
		Assert.isFalse(failedCall.IsPermanentFailure__c, 'Expected a refused request not to mark the call permanent');
		assertOneLeanInboundIssue(failedCall);
	}

	/**
	 * @description A handler whose getValidationErrors() throws a UTIL_Exceptions.PermanentFailureException ends the call
	 * Aborted, marks the call as a permanent failure, and writes one issue. The exception is caught by the checks, not by
	 * the dispatcher, so the call is marked from the exception the checks kept.
	 */
	@IsTest
	private static void shouldMarkTheCallPermanentWhenValidationRaisesAPermanentFailure()
	{
		String serviceName = PermanentlyRefusingValidationInbound.class.getName();
		registerSettingWithLogIssues(serviceName);
		setupRequest(buildBody(), null);

		Test.startTest();
		API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		ApiCall__c abortedCall = SEL_ApiCall.assertServiceAborted(serviceName, MESSAGE_HANDLER_THREW).iterator().next();
		Assert.isTrue(abortedCall.IsPermanentFailure__c, 'Expected a permanent failure from the checks to mark the call permanent');
		assertOneLeanInboundIssue(abortedCall);
	}

	/**
	 * @description A handler whose getValidationErrors() throws any other exception ends the call Aborted with status 400
	 * and writes one issue, and the call is not marked as a permanent failure.
	 */
	@IsTest
	private static void shouldWriteOneIssueWhenTheValidationCodeThrows()
	{
		String serviceName = ThrowingValidationInbound.class.getName();
		registerSettingWithLogIssues(serviceName);
		setupRequest(buildBody(), null);

		Test.startTest();
		API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		ApiCall__c abortedCall = SEL_ApiCall.assertServiceAborted(serviceName, MESSAGE_HANDLER_THREW).iterator().next();
		Assert.areEqual(API_Base.HTTP_BAD_REQUEST, RestContext.response.statusCode, 'Expected status 400 when the checks throw');
		Assert.isFalse(abortedCall.IsPermanentFailure__c, 'Expected an ordinary exception not to mark the call permanent');
		assertOneLeanInboundIssue(abortedCall);
	}

	/**
	 * @description A handler whose own error handling throws ends the call Failed with both messages and answers
	 * status 500. The call still keeps the key and the hash of the body, and gets its one issue: the dispatcher records
	 * them and builds the issue without running the handler's code again.
	 */
	@IsTest
	private static void shouldWriteOneIssueWhenTheErrorHandlingThrows()
	{
		String serviceName = ThrowingErrorHandlingInbound.class.getName();
		registerSettingWithLogIssues(serviceName);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		setupRequest(body, idempotencyKey);

		Test.startTest();
		API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW).iterator().next();
		Assert.isTrue(failedCall.ErrorMessages__c.contains(MESSAGE_ERROR_HANDLING_THREW), 'Expected the call to keep both messages, got ' + failedCall.ErrorMessages__c);
		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, RestContext.response.statusCode, 'Expected status 500 when the error handling throws');
		Assert.areEqual(idempotencyKey, failedCall.IdempotencyKey__c, 'Expected the call to keep the key the request carried');
		Assert.areEqual(hashBody(body), failedCall.IdempotencyKeyBodyHash__c, 'Expected the call to record the hash of the body it received');
		Assert.isFalse(failedCall.IsPermanentFailure__c, 'Expected an ordinary exception not to mark the call permanent');
		assertOneLeanInboundIssue(failedCall);
	}

	/**
	 * @description A handler that throws a UTIL_Exceptions.PermanentFailureException, and whose own error handling then
	 * throws, still marks the call as a permanent failure. So running the request again is refused, as for any other
	 * permanent failure.
	 */
	@IsTest
	private static void shouldMarkTheCallPermanentWhenTheErrorHandlingThrowsAfterAPermanentFailure()
	{
		String serviceName = PermanentFailureWithThrowingErrorHandlingInbound.class.getName();
		registerSettingWithLogIssues(serviceName);
		setupRequest(buildBody(), null);

		Test.startTest();
		API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW).iterator().next();
		Assert.isTrue(failedCall.IsPermanentFailure__c, 'Expected a permanent failure to mark the call permanent');
		assertOneLeanInboundIssue(failedCall);
	}

	/**
	 * @description A request that reuses the Idempotency-Key of a completed call with another body writes no issue, even
	 * when its save fails and its own error handling then throws. The dispatcher keeps the same rule as the handler: there
	 * is nothing to run again.
	 */
	@IsTest
	private static void shouldWriteNoIssueForAKeyReusedWithAnotherBodyWhenTheErrorHandlingThrows()
	{
		String serviceName = ThrowingCommitAndErrorHandlingInbound.class.getName();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiCall__c completedCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.withOverride(ApiCall__c.IdempotencyKeyBodyHash__c, hashBody(buildBody()))
				.withOverride(ApiCall__c.ServiceName__c, serviceName)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_COMPLETED)
				.build();
		registerSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.IdempotencyEnabled__c => true
		});
		setupRequest(buildBody(), idempotencyKey);

		Test.startTest();
		API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		Map<Id, ApiCall__c> callsById = new Map<Id, ApiCall__c>(new SEL_ApiCall().findByServiceName(serviceName));
		callsById.remove(completedCall.Id);
		Assert.areEqual(1, callsById.size(), 'Expected one new call for the refused request, got ' + callsById.size());
		ApiCall__c failedCall = callsById.values().iterator().next();
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, failedCall.Status__c, 'Expected the failed save to end the call Failed');
		Assert.isTrue(failedCall.ErrorMessages__c.contains(MESSAGE_ERROR_HANDLING_THREW), 'Expected the call to keep both messages, got ' + failedCall.ErrorMessages__c);
		Assert.isTrue(new SEL_ApiIssue().getAll().isEmpty(), 'Expected no issue for a key reused with another body');
	}

	/**
	 * @description A request whose body cannot be read fails before a handler exists. The call ends Aborted with status
	 * 500, and no issue is written, even with Log Issues on.
	 */
	@IsTest
	private static void shouldWriteNoIssueWhenTheBodyCannotBeRead()
	{
		registerSettingWithLogIssues(SERVICE_NAME);
		setupRequest(UNREADABLE_BODY, null);

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		SEL_ApiCall.assertServiceAborted(SERVICE_NAME);
		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, RestContext.response.statusCode, 'Expected status 500 when no handler can be built');
		Assert.isTrue(new SEL_ApiIssue().getAll().isEmpty(), 'Expected no issue for a request that has no handler');
	}

	/**
	 * @description A request that reuses the Idempotency-Key of a completed call with another body is refused with status
	 * 409, and no issue is written, even with Log Issues on: there is nothing to run again.
	 */
	@IsTest
	private static void shouldWriteNoIssueForAKeyReusedWithAnotherBody()
	{
		String idempotencyKey = UTIL_Random.randomUUID();
		TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.withOverride(ApiCall__c.IdempotencyKeyBodyHash__c, hashBody(buildBody()))
				.withOverride(ApiCall__c.ServiceName__c, SERVICE_NAME)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_COMPLETED)
				.build();
		registerSetting(SERVICE_NAME, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.IdempotencyEnabled__c => true
		});
		setupRequest(buildBody(), idempotencyKey);

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_CONFLICT, RestContext.response.statusCode, 'Expected status 409 for a key reused with another body');
		Assert.isTrue(new SEL_ApiIssue().getAll().isEmpty(), 'Expected no issue for a key reused with another body');
	}

	/**
	 * @description A request answered by a mock writes no issue. The handler would throw if it ran, which proves the mock
	 * answered instead.
	 */
	@IsTest
	private static void shouldWriteNoIssueForAMockedRequest()
	{
		registerSetting(SERVICE_NAME, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.MockingEnabled__c => true
		});
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);
		setupRequest(buildBody(), null);
		API_Inbound.returnErrorResponse = true;

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);
		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(SERVICE_NAME);
		Assert.isTrue(handler.result.isMocked, 'Expected the mock to answer the request');
		Assert.isTrue(new SEL_ApiIssue().getAll().isEmpty(), 'Expected no issue for a mocked request');
	}

	/**
	 * @description A request that fails in Safe Mode saves nothing: no call and no issue, even with Log Issues on. The
	 * result still shows that the request failed.
	 */
	@IsTest
	private static void shouldSaveNoIssueInSafeMode()
	{
		registerSettingWithLogIssues(SERVICE_NAME);
		API_Inbound.returnErrorResponse = true;

		Test.startTest();
		DTO_InvocationResult invocationResult = API_InboundInvoker.invoke(REQUEST_PATH, HTTP_METHOD_POST, buildBody(), null, true);
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, invocationResult.status, 'Expected the request to fail, got ' + invocationResult.status);
		Assert.isTrue(new SEL_ApiCall().findByServiceName(SERVICE_NAME).isEmpty(), 'Expected Safe Mode to save no call');
		Assert.isTrue(new SEL_ApiIssue().getAll().isEmpty(), 'Expected Safe Mode to save no issue');
	}

	/**
	 * @description A request that fails for a service with Log Issues off writes no issue. The call is still saved as
	 * Failed.
	 */
	@IsTest
	private static void shouldWriteNoIssueWhenLogIssuesIsOff()
	{
		registerSetting(SERVICE_NAME, new Map<SObjectField, Object> {ApiSetting__mdt.LogIssues__c => false});
		setupRequest(buildBody(), null);
		API_Inbound.returnErrorResponse = true;

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		SEL_ApiCall.assertServiceFailed(SERVICE_NAME, API_Inbound.ERROR_TEST_EXCEPTION_HANDLING);
		Assert.isTrue(new SEL_ApiIssue().getAll().isEmpty(), 'Expected no issue with Log Issues off');
	}

	/**
	 * @description A request with no Idempotency-Key still records the SHA-256 hash of the body it received on its call,
	 * so a later run can prove the stored body is an exact copy.
	 */
	@IsTest
	private static void shouldRecordTheBodyHashWithoutAKey()
	{
		registerSettingWithLogIssues(SERVICE_NAME);
		String body = buildBody();
		setupRequest(body, null);

		Test.startTest();
		REST_Echo.echo();
		Test.stopTest();

		ApiCall__c completedCall = SEL_ApiCall.assertServiceCompleted(SERVICE_NAME).iterator().next();
		Assert.isNull(completedCall.IdempotencyKey__c, 'Expected no key on a request that carried none');
		Assert.areEqual(hashBody(body), completedCall.IdempotencyKeyBodyHash__c, 'Expected the hash of the body the request carried');
	}

	/**
	 * @description Reads the one issue the test wrote and checks that it is a lean inbound issue for the call: open,
	 * inbound, linked to the call, with the call's service and error messages, no copy of the request, and the flag that
	 * says the external system may have acted left clear.
	 *
	 * @param apiCall The saved call the issue belongs to.
	 */
	private static void assertOneLeanInboundIssue(ApiCall__c apiCall)
	{
		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(1, issues.size(), 'Expected one issue for the failed request, got ' + issues.size());
		ApiIssue__c issue = issues.iterator().next();
		Assert.areEqual(apiCall.Id, issue.ApiCall__c, 'Expected the issue to link to the call');
		Assert.areEqual(SEL_ApiIssue.DIRECTION_INBOUND, issue.Direction__c, 'Expected an inbound issue');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, issue.Status__c, 'Expected the issue to be open');
		Assert.areEqual(apiCall.ServiceName__c, issue.ServiceName__c, 'Expected the service the request was sent to');
		Assert.areEqual(apiCall.ErrorMessages__c, issue.ErrorMessages__c, 'Expected the error messages of the call');
		Assert.isNull(issue.RequestBody__c, 'Expected the issue to hold no copy of the body');
		Assert.isNull(issue.RequestPath__c, 'Expected the issue to hold no copy of the path');
		Assert.isNull(issue.RequestMethod__c, 'Expected the issue to hold no copy of the method');
		Assert.isNull(issue.RequestParameters__c, 'Expected the issue to hold no copy of the parameters');
		Assert.isNull(issue.IdempotencyKey__c, 'Expected the issue to hold no copy of the key');
		Assert.isFalse(issue.ExternalSystemMayHaveActed__c, 'Expected the external system flag to stay clear');
	}

	/**
	 * @description Registers the setting of a service through the test mock, with Log Issues on.
	 *
	 * @param serviceName The handler class the setting names.
	 */
	private static void registerSettingWithLogIssues(String serviceName)
	{
		registerSetting(serviceName, new Map<SObjectField, Object> {ApiSetting__mdt.LogIssues__c => true});
	}

	/**
	 * @description Registers the inbound setting of a service through the test mock, routed to the echo path.
	 *
	 * @param serviceName The handler class the setting names.
	 * @param overrides The field values the setting gets on top of the defaults.
	 */
	private static void registerSetting(String serviceName, Map<SObjectField, Object> overrides)
	{
		TST_Factory.newInboundApiSetting(serviceName, ROUTE_PATH, ROUTE_PRIORITY, overrides);
	}

	/**
	 * @description Sets up a POST request to the echo service's path, with a JSON body and, when given, an Idempotency-Key header.
	 *
	 * @param body The JSON body to send
	 * @param idempotencyKey The key to send, or null to send none
	 */
	private static void setupRequest(String body, String idempotencyKey)
	{
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestURI = REQUEST_PATH;
		RestContext.request.requestBody = Blob.valueOf(body);
		if(String.isNotBlank(idempotencyKey))
		{
			RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);
		}
	}

	/**
	 * @description Builds a JSON body the echo service accepts, with a random value so each test's body is its own.
	 *
	 * @return The body
	 */
	private static String buildBody()
	{
		return JSON.serialize(new Map<String, Object> {BODY_FIELD => UTIL_Random.randomName()});
	}

	/**
	 * @description Works out the SHA-256 hash of a body, as the call records it, written as hexadecimal text.
	 *
	 * @param body The body to hash
	 *
	 * @return The hash of the body
	 */
	private static String hashBody(String body)
	{
		return API_Inbound.computeBodyHash(body);
	}

	/**
	 * @description An inbound handler that throws a UTIL_Exceptions.PermanentFailureException while it handles the
	 * request.
	 */
	public class PermanentFailureInbound extends API_Inbound
	{
		/**
		 * @description Says the request can never succeed.
		 */
		public override void processRequest()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description An inbound handler that throws a UTIL_Exceptions.RequestRefusedException while it handles the request.
	 */
	public class RequestRefusingInbound extends API_Inbound
	{
		/**
		 * @description Says the request was refused.
		 */
		public override void processRequest()
		{
			throw new UTIL_Exceptions.RequestRefusedException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description An inbound handler whose checks throw a UTIL_Exceptions.PermanentFailureException.
	 */
	public class PermanentlyRefusingValidationInbound extends API_Inbound
	{
		/**
		 * @description Says, while the request is checked, that the request can never succeed.
		 *
		 * @return Never returns.
		 */
		public override List<String> getValidationErrors()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description An inbound handler whose checks throw an ordinary exception.
	 */
	public class ThrowingValidationInbound extends API_Inbound
	{
		/**
		 * @description Throws while the request is checked.
		 *
		 * @return Never returns.
		 */
		public override List<String> getValidationErrors()
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description An inbound handler that fails while it handles the request, and whose own error handling then throws.
	 */
	public class ThrowingErrorHandlingInbound extends API_Inbound
	{
		/**
		 * @description Fails as the last step of handling the request.
		 */
		public override void onSuccess()
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}

		/**
		 * @description Throws while it handles the failure, before the base method writes the answer.
		 *
		 * @param error The failure being handled.
		 */
		public override void handleError(Exception error)
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_ERROR_HANDLING_THREW);
		}
	}

	/**
	 * @description An inbound handler that throws a UTIL_Exceptions.PermanentFailureException while it handles the
	 * request, and whose own error handling then throws.
	 */
	public class PermanentFailureWithThrowingErrorHandlingInbound extends API_Inbound
	{
		/**
		 * @description Says the request can never succeed.
		 */
		public override void processRequest()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}

		/**
		 * @description Throws while it handles the failure, before the base method writes the answer.
		 *
		 * @param error The failure being handled.
		 */
		public override void handleError(Exception error)
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_ERROR_HANDLING_THREW);
		}
	}

	/**
	 * @description An inbound handler that fails when its work starts to be saved, and whose own error handling then
	 * throws.
	 */
	public class ThrowingCommitAndErrorHandlingInbound extends API_Inbound
	{
		/**
		 * @description Fails when the save of the handler's work starts.
		 */
		public override void onCommitWorkStarting()
		{
			super.onCommitWorkStarting();
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_HANDLER_THREW);
		}

		/**
		 * @description Throws while it handles the failure, before the base method writes the answer.
		 *
		 * @param error The failure being handled.
		 */
		public override void handleError(Exception error)
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_ERROR_HANDLING_THREW);
		}
	}
}
