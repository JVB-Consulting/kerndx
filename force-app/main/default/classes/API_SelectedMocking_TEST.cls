// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the rule that decides when one picked service answers mock data, for outgoing calls and for
 * incoming requests. An administrator picks a service by ticking Mocking Enabled on its API Setting. The Mock Selected
 * APIs feature flag then turns mocking on for the users it is on for. A picked service answers mock data only when both
 * are true: the box alone, or the flag alone, changes nothing. Mock All APIs and Mock All Inbound APIs still mock every
 * service on their own.
 *
 * In a unit test an outgoing call that is not mocked also gets its answer from the mock factory, through the test
 * callout mock. So these tests tell a mocked send from a real one by the result's mocked marker, by the Is Mocked
 * Response field on the saved call, and by the callout count: a mocked send makes no callout.
 *
 * @see API_Base
 * @see API_Inbound
 * @see API_MockFactory
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class API_SelectedMocking_TEST
{
	/**
	 * @description The outgoing service most tests send through. Its setting is registered by each test.
	 */
	private static final String SELECTED_SERVICE_NAME = SelectedOutbound.class.getName();

	/**
	 * @description The outgoing service whose handler sets a default mock body.
	 */
	private static final String DEFAULT_BODY_SERVICE_NAME = DefaultBodyOutbound.class.getName();

	/**
	 * @description The outgoing POST service that has no mock data of any kind.
	 */
	private static final String NO_MOCK_DATA_SERVICE_NAME = NoMockDataPostOutbound.class.getName();

	/**
	 * @description The outgoing service the query test sends first, so the settings a transaction keeps are already read.
	 */
	private static final String WARM_UP_SERVICE_NAME = WarmUpOutbound.class.getName();

	/**
	 * @description The outgoing service the query test sends with the box not ticked.
	 */
	private static final String UNTICKED_SERVICE_NAME = UntickedOutbound.class.getName();

	/**
	 * @description The incoming service the inbound tests call. It answers with the body it was sent.
	 */
	private static final String INBOUND_SERVICE_NAME = API_Echo.class.getName();

	/**
	 * @description The developer name given to the outgoing setting, so that an API Mock record can be found for it.
	 */
	private static final String SETTING_DEVELOPER_NAME = 'SelectedMockingSetting';

	/**
	 * @description The endpoint path the incoming setting routes.
	 */
	private static final String INBOUND_ENDPOINT_PATH = '/echo/*';

	/**
	 * @description The routing priority of the incoming setting.
	 */
	private static final Integer INBOUND_PRIORITY = 100;

	/**
	 * @description The body of the answer a test registers in memory with the mock factory.
	 */
	private static final String MEMORY_ANSWER_BODY = '{"answer":"memory"}';

	/**
	 * @description The body of the API Mock record a test registers for the outgoing setting.
	 */
	private static final String RECORD_ANSWER_BODY = '{"answer":"record"}';

	/**
	 * @description The status of the API Mock record a test registers. It differs from the memory answer's status, so
	 * the test can tell which one answered.
	 */
	private static final Integer RECORD_ANSWER_STATUS = API_Base.HTTP_CREATED;

	/**
	 * @description The default mock body of the handler DefaultBodyOutbound.
	 */
	private static final String DEFAULT_MOCK_BODY = '{"answer":"default"}';

	/**
	 * @description The body an incoming service answers with when it is mocked and nothing is registered for it.
	 */
	private static final String INBOUND_DEFAULT_MOCK_BODY = '{"mocked":true,"message":"No mock response configured - using default"}';

	/**
	 * @description The name of the one field in the incoming request body.
	 */
	private static final String INBOUND_BODY_FIELD = 'helloWorld';

	/**
	 * @description How many retries the setting of the POST service without mock data allows.
	 */
	private static final Integer RETRY_BUDGET = 3;

	/**
	 * @description How many seconds the setting of the POST service without mock data waits before a retry.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 30;

	/**
	 * @description The number of queries each query-counting handler used inside its send, by service name.
	 */
	private static final Map<String, Integer> QUERIES_USED_BY_SEND = new Map<String, Integer>();

	/**
	 * @description An outgoing service whose box is ticked, while Mock Selected APIs stays off as it ships, makes the
	 * real call. This is what an org sees straight after the upgrade. The API Mock record and the memory answer give
	 * the real call an answer, and the call is still not marked as mocked.
	 */
	@IsTest
	private static void shouldMakeTheRealCallWhenOnlyTheBoxIsTicked()
	{
		registerOutboundSetting(SELECTED_SERVICE_NAME, true);
		registerApiMockRecord();
		registerMemoryAnswer(SELECTED_SERVICE_NAME);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS, true, false);

		Test.startTest();
		Integer calloutsBefore = UTIL_Limits.callouts().used();
		API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(SELECTED_SERVICE_NAME, UserInfo.getUserId()));
		Integer calloutsUsed = UTIL_Limits.callouts().used() - calloutsBefore;
		Test.stopTest();

		Assert.isFalse(handler.result.isMocked, 'Expected the call not to be mocked when only the box is ticked');
		Assert.isFalse(readIsMockedResponse(SELECTED_SERVICE_NAME), 'Expected the saved call not to be marked as mocked');
		Assert.areEqual(1, calloutsUsed, 'Expected the real call to make one callout, got ' + calloutsUsed);
		Assert.areEqual(MEMORY_ANSWER_BODY, handler.result.responseBody, 'Expected the real call to get the memory answer');
	}

	/**
	 * @description An outgoing service whose box is not ticked makes the real call, even when Mock Selected APIs is on
	 * for the user. The flag only turns mocking on for the services an administrator picked.
	 */
	@IsTest
	private static void shouldMakeTheRealCallWhenOnlyTheFlagIsOn()
	{
		registerOutboundSetting(SELECTED_SERVICE_NAME, false);
		registerMemoryAnswer(SELECTED_SERVICE_NAME);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);

		Test.startTest();
		Integer calloutsBefore = UTIL_Limits.callouts().used();
		API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(SELECTED_SERVICE_NAME, UserInfo.getUserId()));
		Integer calloutsUsed = UTIL_Limits.callouts().used() - calloutsBefore;
		Test.stopTest();

		Assert.isFalse(handler.result.isMocked, 'Expected the call not to be mocked when only the flag is on');
		Assert.isFalse(readIsMockedResponse(SELECTED_SERVICE_NAME), 'Expected the saved call not to be marked as mocked');
		Assert.areEqual(1, calloutsUsed, 'Expected the real call to make one callout, got ' + calloutsUsed);
	}

	/**
	 * @description An outgoing service whose box is ticked, with Mock Selected APIs on for the user, answers from its
	 * API Mock record. It makes no callout, and the call is saved as mocked.
	 */
	@IsTest
	private static void shouldAnswerFromTheApiMockRecordWhenTheBoxIsTickedAndTheFlagIsOn()
	{
		registerOutboundSetting(SELECTED_SERVICE_NAME, true);
		registerApiMockRecord();
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);

		Test.startTest();
		Integer calloutsBefore = UTIL_Limits.callouts().used();
		API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(SELECTED_SERVICE_NAME, UserInfo.getUserId()));
		Integer calloutsUsed = UTIL_Limits.callouts().used() - calloutsBefore;
		Test.stopTest();

		Assert.isTrue(handler.result.isMocked, 'Expected the call to be mocked when the box is ticked and the flag is on');
		Assert.isTrue(readIsMockedResponse(SELECTED_SERVICE_NAME), 'Expected the saved call to be marked as mocked');
		Assert.areEqual(0, calloutsUsed, 'Expected a mocked call to make no callout, got ' + calloutsUsed);
		Assert.areEqual(RECORD_ANSWER_BODY, handler.result.responseBody, 'Expected the body of the API Mock record');
		Assert.areEqual(String.valueOf(RECORD_ANSWER_STATUS), handler.result.statusCode, 'Expected the status of the API Mock record');
	}

	/**
	 * @description A mocked outgoing service with no API Mock record and no memory answer answers with the default mock
	 * body its handler sets. No callout is made, which shows the mock answered and not the test callout mock of the
	 * real call.
	 */
	@IsTest
	private static void shouldAnswerTheDefaultMockBodyWhenNoApiMockRecordMatches()
	{
		registerOutboundSetting(DEFAULT_BODY_SERVICE_NAME, true);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);

		Test.startTest();
		Integer calloutsBefore = UTIL_Limits.callouts().used();
		API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(DEFAULT_BODY_SERVICE_NAME, UserInfo.getUserId()));
		Integer calloutsUsed = UTIL_Limits.callouts().used() - calloutsBefore;
		Test.stopTest();

		Assert.isTrue(handler.result.isMocked, 'Expected the call to be mocked');
		Assert.isTrue(readIsMockedResponse(DEFAULT_BODY_SERVICE_NAME), 'Expected the saved call to be marked as mocked');
		Assert.areEqual(0, calloutsUsed, 'Expected a mocked call to make no callout, got ' + calloutsUsed);
		Assert.areEqual(DEFAULT_MOCK_BODY, handler.result.responseBody, 'Expected the default mock body of the handler');
	}

	/**
	 * @description A mocked outgoing POST with no mock data of any kind fails with the message that tells the
	 * administrator what to do. The failure counts once on the circuit breaker, and the call is not retried, even with
	 * retries left: a POST is not safe to send again. In an org whose org cache has no space set aside, the breaker
	 * cannot save the failure, so a new breaker for the service reads no failures.
	 */
	@IsTest
	private static void shouldFailWithTheNoMockMessageAndNotRetryAPost()
	{
		Integer expectedFailures = UTIL_Cache.isOrgAllocated() ? 1 : 0;
		TST_Factory.newOutboundApiSetting(NO_MOCK_DATA_SERVICE_NAME, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MockingEnabled__c => true, ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET,
				ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS, ApiSetting__mdt.CircuitBreakerEnabled__c => true
		});
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);
		UTIL_CircuitBreaker.monitor(NO_MOCK_DATA_SERVICE_NAME).reset();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(NO_MOCK_DATA_SERVICE_NAME, UserInfo.getUserId()));
		Test.stopTest();

		String expectedMessage = String.format(System.Label.ApiMocking_NoMockResponseConfigured, new List<Object> {NO_MOCK_DATA_SERVICE_NAME});
		ApiCall__c apiCall = SEL_ApiCall.assertServiceFailed(NO_MOCK_DATA_SERVICE_NAME).iterator().next();
		Assert.isTrue(apiCall.ErrorMessages__c.startsWith(expectedMessage), 'Expected the errors to start with the message about mock data, got ' + apiCall.ErrorMessages__c);
		Assert.areNotEqual(SEL_ApiCall.STATUS_RETRY, apiCall.Status__c, 'Expected the POST not to be retried');
		Assert.isNull(apiCall.NextRetry__c, 'Expected no next retry time for the POST, got ' + apiCall.NextRetry__c);
		Integer failureCount = UTIL_CircuitBreaker.monitor(NO_MOCK_DATA_SERVICE_NAME).getMetrics().failureCount;
		Assert.areEqual(expectedFailures, failureCount, 'Expected a new breaker to read ' + expectedFailures + ' failures, got ' + failureCount);
	}

	/**
	 * @description Mock All APIs still mocks every outgoing service on its own: the box is not ticked and Mock Selected
	 * APIs is off, and the call is mocked.
	 */
	@IsTest
	private static void shouldStillMockEveryServiceUnderMockAllApis()
	{
		registerOutboundSetting(SELECTED_SERVICE_NAME, false);
		registerMemoryAnswer(SELECTED_SERVICE_NAME);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_ALL_APIS);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS, true, false);

		Test.startTest();
		Integer calloutsBefore = UTIL_Limits.callouts().used();
		API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(SELECTED_SERVICE_NAME, UserInfo.getUserId()));
		Integer calloutsUsed = UTIL_Limits.callouts().used() - calloutsBefore;
		Test.stopTest();

		Assert.isTrue(handler.result.isMocked, 'Expected Mock All APIs to mock the call');
		Assert.isTrue(readIsMockedResponse(SELECTED_SERVICE_NAME), 'Expected the saved call to be marked as mocked');
		Assert.areEqual(0, calloutsUsed, 'Expected a mocked call to make no callout, got ' + calloutsUsed);
	}

	/**
	 * @description Deciding whether to mock adds no query to a send. The three services go out in one dispatch. The first
	 * one reads the settings a transaction keeps. Then a send with the box ticked and the flag off uses as many queries
	 * as a send with the box not ticked. Each handler counts the queries used inside its own send.
	 */
	@IsTest
	private static void shouldAddNoQueryToDecideMocking()
	{
		registerOutboundSetting(WARM_UP_SERVICE_NAME, false);
		registerOutboundSetting(UNTICKED_SERVICE_NAME, false);
		registerOutboundSetting(SELECTED_SERVICE_NAME, true);
		registerMemoryAnswer(WARM_UP_SERVICE_NAME);
		registerMemoryAnswer(UNTICKED_SERVICE_NAME);
		registerMemoryAnswer(SELECTED_SERVICE_NAME);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS, true, false);

		Test.startTest();
		API_Dispatcher.execute(new List<ApiCall__c>
		{
				TST_Factory.newOutboundApiCall(WARM_UP_SERVICE_NAME, UserInfo.getUserId()),
				TST_Factory.newOutboundApiCall(UNTICKED_SERVICE_NAME, UserInfo.getUserId()),
				TST_Factory.newOutboundApiCall(SELECTED_SERVICE_NAME, UserInfo.getUserId())
		});
		Test.stopTest();

		Integer untickedQueries = QUERIES_USED_BY_SEND.get(UNTICKED_SERVICE_NAME);
		Integer tickedQueries = QUERIES_USED_BY_SEND.get(SELECTED_SERVICE_NAME);
		Assert.isNotNull(untickedQueries, 'Expected the send with the box not ticked to run');
		Assert.areEqual(untickedQueries, tickedQueries, 'Expected the ticked box to add no query to the send, got ' + tickedQueries + ' and ' + untickedQueries);
	}

	/**
	 * @description An incoming service whose box is ticked, while Mock Selected APIs stays off as it ships, runs its own
	 * code. This is what an org sees straight after the upgrade: the service answers with the body it was sent.
	 */
	@IsTest
	private static void shouldRunTheHandlerWhenOnlyTheBoxIsTickedOnAnIncomingService()
	{
		registerInboundSetting(true);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS, true, false);
		String requestBody = setupInboundRequest();

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(INBOUND_SERVICE_NAME);
		Test.stopTest();

		Assert.isFalse(handler.result.isMocked ?? false, 'Expected the request not to be mocked when only the box is ticked');
		Assert.isFalse(readIsMockedResponse(INBOUND_SERVICE_NAME), 'Expected the saved call not to be marked as mocked');
		Assert.areEqual(requestBody, handler.result.responseBody, 'Expected the handler to answer with the body it was sent');
	}

	/**
	 * @description An incoming service whose box is not ticked runs its own code, even when Mock Selected APIs is on for
	 * the user.
	 */
	@IsTest
	private static void shouldRunTheHandlerWhenOnlyTheFlagIsOnForAnIncomingService()
	{
		registerInboundSetting(false);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);
		String requestBody = setupInboundRequest();

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(INBOUND_SERVICE_NAME);
		Test.stopTest();

		Assert.isFalse(handler.result.isMocked ?? false, 'Expected the request not to be mocked when only the flag is on');
		Assert.isFalse(readIsMockedResponse(INBOUND_SERVICE_NAME), 'Expected the saved call not to be marked as mocked');
		Assert.areEqual(requestBody, handler.result.responseBody, 'Expected the handler to answer with the body it was sent');
	}

	/**
	 * @description An incoming service whose box is ticked, with Mock Selected APIs on for the user, answers with the
	 * mock answer registered for it, and the call is saved as mocked.
	 */
	@IsTest
	private static void shouldAnswerMockDataWhenTheBoxIsTickedAndTheFlagIsOnForAnIncomingService()
	{
		registerInboundSetting(true);
		registerMemoryAnswer(INBOUND_SERVICE_NAME);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);
		setupInboundRequest();

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(INBOUND_SERVICE_NAME);
		Test.stopTest();

		Assert.isTrue(handler.result.isMocked, 'Expected the request to be mocked when the box is ticked and the flag is on');
		Assert.isTrue(readIsMockedResponse(INBOUND_SERVICE_NAME), 'Expected the saved call to be marked as mocked');
		Assert.areEqual(MEMORY_ANSWER_BODY, handler.result.responseBody, 'Expected the registered mock answer');
	}

	/**
	 * @description A mocked incoming service with nothing registered for it answers with the default mock body.
	 */
	@IsTest
	private static void shouldAnswerTheDefaultBodyWhenAnIncomingServiceHasNoMockAnswer()
	{
		registerInboundSetting(true);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS);
		setupInboundRequest();

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(INBOUND_SERVICE_NAME);
		Test.stopTest();

		Assert.isTrue(handler.result.isMocked, 'Expected the request to be mocked');
		Assert.isTrue(readIsMockedResponse(INBOUND_SERVICE_NAME), 'Expected the saved call to be marked as mocked');
		Assert.areEqual(INBOUND_DEFAULT_MOCK_BODY, handler.result.responseBody, 'Expected the default mock body');
	}

	/**
	 * @description Mock All Inbound APIs still mocks every incoming service on its own: the box is not ticked and Mock
	 * Selected APIs is off, and the request is mocked.
	 */
	@IsTest
	private static void shouldStillMockEveryIncomingServiceUnderMockAllInboundApis()
	{
		registerInboundSetting(false);
		registerMemoryAnswer(INBOUND_SERVICE_NAME);
		TST_Factory.newFeatureFlag(API_Inbound.FLAG_MOCK_ALL_INBOUND_APIS);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS, true, false);
		setupInboundRequest();

		Test.startTest();
		API_Base handler = API_Dispatcher.processInboundService(INBOUND_SERVICE_NAME);
		Test.stopTest();

		Assert.isTrue(handler.result.isMocked, 'Expected Mock All Inbound APIs to mock the request');
		Assert.isTrue(readIsMockedResponse(INBOUND_SERVICE_NAME), 'Expected the saved call to be marked as mocked');
		Assert.areEqual(MEMORY_ANSWER_BODY, handler.result.responseBody, 'Expected the registered mock answer');
	}

	/**
	 * @description Registers the outgoing setting of a service through the test mock, with the developer name the API
	 * Mock record looks for.
	 *
	 * @param serviceName The handler class the setting names.
	 * @param isMockingEnabled Whether the setting has Mocking Enabled ticked.
	 */
	private static void registerOutboundSetting(String serviceName, Boolean isMockingEnabled)
	{
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.DeveloperName => SETTING_DEVELOPER_NAME, ApiSetting__mdt.MockingEnabled__c => isMockingEnabled
		});
	}

	/**
	 * @description Registers the incoming setting of the echo service through the test mock.
	 *
	 * @param isMockingEnabled Whether the setting has Mocking Enabled ticked.
	 */
	private static void registerInboundSetting(Boolean isMockingEnabled)
	{
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, INBOUND_ENDPOINT_PATH, INBOUND_PRIORITY, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MockingEnabled__c => isMockingEnabled
		});
	}

	/**
	 * @description Registers one active API Mock record through the test mock, with its own body and status.
	 */
	private static void registerApiMockRecord()
	{
		TST_Factory.newApiMock(new Map<SObjectField, Object>
		{
				ApiMock__mdt.StatusCode__c => RECORD_ANSWER_STATUS, ApiMock__mdt.ResponseBody__c => RECORD_ANSWER_BODY
		});
	}

	/**
	 * @description Registers an answer in memory with the mock factory for a service. Registering an answer does not
	 * turn mocking on for the service.
	 *
	 * @param serviceName The service the answer is for.
	 */
	private static void registerMemoryAnswer(String serviceName)
	{
		API_MockFactory.forService(serviceName).body(MEMORY_ANSWER_BODY).statusCode(API_Base.HTTP_OK).register();
	}

	/**
	 * @description Sets up an incoming request to the echo service with a JSON body that has a random value.
	 *
	 * @return The body that was sent.
	 */
	private static String setupInboundRequest()
	{
		String requestBody = JSON.serialize(new Map<String, Object> {INBOUND_BODY_FIELD => UTIL_Random.randomName()});
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestBody = Blob.valueOf(requestBody);
		return requestBody;
	}

	/**
	 * @description Reads the Is Mocked Response field of the saved call of a service. The call selector does not select
	 * that field, so the read goes through QRY_Builder, in system mode: the user a package build runs its tests as has
	 * no access to the package's own fields.
	 *
	 * @param serviceName The service whose saved call is read.
	 *
	 * @return The value of the field, or null when no call was saved.
	 */
	private static Boolean readIsMockedResponse(String serviceName)
	{
		ApiCall__c saved = (ApiCall__c)QRY_Builder.selectFrom(ApiCall__c.SObjectType)
				.fields(new List<SObjectField> {ApiCall__c.IsMockedResponse__c})
				.condition(ApiCall__c.ServiceName__c).equals(serviceName)
				.withSystemMode()
				.getFirst();
		return saved?.IsMockedResponse__c;
	}

	/**
	 * @description An outgoing GET handler that counts the queries used inside its send, and saves the count under its
	 * service name.
	 */
	public virtual class SelectedOutbound extends API_Outbound_TEST.RetryProbeOutbound
	{
		/**
		 * @description Sends the request and saves how many queries the send used.
		 *
		 * @param requestObj The request to send.
		 */
		protected override void sendRequest(HttpRequest requestObj)
		{
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			super.sendRequest(requestObj);
			QUERIES_USED_BY_SEND.put(getServiceName(), UTIL_Limits.soqlQueries().used() - queriesBefore);
		}
	}

	/**
	 * @description The first service the query test sends.
	 */
	public class WarmUpOutbound extends SelectedOutbound
	{
	}

	/**
	 * @description The service the query test sends with the box not ticked.
	 */
	public class UntickedOutbound extends SelectedOutbound
	{
	}

	/**
	 * @description An outgoing GET handler that sets a default mock body.
	 */
	public class DefaultBodyOutbound extends API_Outbound_TEST.RetryProbeOutbound
	{
		/**
		 * @description Sets the handler up with its default mock body.
		 */
		public override void configure()
		{
			super.configure();
			defaultMockBody = DEFAULT_MOCK_BODY;
		}
	}

	/**
	 * @description An outgoing POST handler with no default mock body. A POST is not safe to send again.
	 */
	public class NoMockDataPostOutbound extends API_Outbound_TEST.PostTransportOutbound
	{
	}
}
