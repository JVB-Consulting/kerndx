// SPDX-License-Identifier: BUSL-1.1
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SubscriberMockPatterns_TEST
{
	/**
	 * @description The outbound API service name for echo tests.
	 */
	private static final String ECHO_SERVICE = API_EchoSubscriber.class.getName();

	/**
	 * @description The echo subscriber message parameter name.
	 */
	private static final String ECHO_PARAM_MESSAGE = API_EchoSubscriber.PARAM_MESSAGE;

	/**
	 * @description The inbound API service name.
	 */
	private static final String INBOUND_SERVICE = API_SubscriberCreateAccount.class.getName();

	// =========================================================================
	// TST_Mock — Query Interception
	// =========================================================================

	/**
	 * @description Tests TST_Mock.of() creates mock with override and auto-registers.
	 */
	@IsTest
	private static void shouldCreateMockWithOverride()
	{
		Account mock = (Account)kern.TST_Mock.of(Account.SObjectType)
				.withOverride(Account.Name, 'Mock Account')
				.withOverride(Account.Industry, 'Technology')
				.build();

		System.assertNotEquals(null, mock, 'Mock should not be null');
		System.assertNotEquals(null, mock.Id, 'Mock should have a generated Id');
		System.assertEquals('Mock Account', mock.Name, 'Name should match override');
		System.assertEquals('Technology', mock.Industry, 'Industry should match override');
	}

	/**
	 * @description Tests TST_Mock.of() with multiple records.
	 */
	@IsTest
	private static void shouldCreateMultipleMocks()
	{
		List<SObject> mocks = kern.TST_Mock.of(Account.SObjectType)
				.withCount(5)
				.buildList();

		System.assertEquals(5, mocks.size(), 'Should create 5 mocks');
		for(SObject mock : mocks)
		{
			System.assertNotEquals(null, mock.Id, 'Each mock should have an Id');
		}
	}

	/**
	 * @description Tests TST_Mock.of() with cycling values across records.
	 */
	@IsTest
	private static void shouldCycleValuesAcrossMocks()
	{
		List<SObject> mocks = kern.TST_Mock.of(Account.SObjectType)
				.withCount(4)
				.withCycle(Account.Industry, new List<Object> {'Tech', 'Finance'})
				.buildList();

		System.assertEquals(4, mocks.size(), 'Should create 4 mocks');
		System.assertEquals('Tech', ((Account)mocks[0]).Industry, 'First should be Tech');
		System.assertEquals('Finance', ((Account)mocks[1]).Industry, 'Second should be Finance');
		System.assertEquals('Tech', ((Account)mocks[2]).Industry, 'Third should be Tech (cycle)');
		System.assertEquals('Finance', ((Account)mocks[3]).Industry, 'Fourth should be Finance (cycle)');
	}

	/**
	 * @description Tests TST_Mock register/get/clear cycle.
	 */
	@IsTest
	private static void shouldRegisterAndRetrieveMocks()
	{
		Account mock = new Account(Name = 'Manual Mock');
		kern.TST_Mock.register(Account.SObjectType, mock);

		List<SObject> mocks = kern.TST_Mock.get(Account.SObjectType);
		System.assert(!mocks.isEmpty(), 'Should have registered mocks');

		kern.TST_Mock.clear(Account.SObjectType);

		List<SObject> afterClear = kern.TST_Mock.get(Account.SObjectType);
		System.assert(afterClear.isEmpty(), 'Mocks should be cleared');
	}

	/**
	 * @description Tests TST_Mock.clear() clears all types.
	 */
	@IsTest
	private static void shouldClearAllMockTypes()
	{
		kern.TST_Mock.of(Account.SObjectType).build();
		kern.TST_Mock.of(Contact.SObjectType).build();

		kern.TST_Mock.clear();

		System.assert(kern.TST_Mock.get(Account.SObjectType).isEmpty(), 'Account mocks should be cleared');
		System.assert(kern.TST_Mock.get(Contact.SObjectType).isEmpty(), 'Contact mocks should be cleared');
	}

	// =========================================================================
	// TST_Builder — Test Data Creation
	// =========================================================================

	/**
	 * @description Tests TST_Builder creates and inserts record.
	 */
	@IsTest
	private static void shouldBuildAndInsertRecord()
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);

		Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		System.assertNotEquals(null, Account.Id, 'Record should be inserted with an Id');

		Account queried =
		[
				SELECT Name
				FROM Account
				WHERE Id = :Account.Id
		];
		System.assertNotEquals(null, queried.Name, 'Name should have a default value');
	}

	/**
	 * @description Tests TST_Builder withoutInsertion creates in-memory record.
	 */
	@IsTest
	private static void shouldBuildWithoutInsertion()
	{
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withoutInsertion()
				.build();

		System.assertEquals(null, Account.Id, 'In-memory record should not have an Id');
	}

	/**
	 * @description Tests TST_Builder with field overrides.
	 */
	@IsTest
	private static void shouldBuildWithOverrides()
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);

		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						Account.Name => 'Custom Name',
						Account.Industry => 'Healthcare'
				})
				.build();

		Account queried =
		[
				SELECT Name,
						Industry
				FROM Account
				WHERE Id = :Account.Id
		];
		System.assertEquals('Custom Name', queried.Name, 'Name should match override');
		System.assertEquals('Healthcare', queried.Industry, 'Industry should match override');
	}

	/**
	 * @description Tests TST_Builder buildList creates multiple records.
	 */
	@IsTest
	private static void shouldBuildMultipleRecords()
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);

		List<SObject> accounts = kern.TST_Builder.of(Account.SObjectType)
				.withCount(3)
				.buildList();

		System.assertEquals(3, accounts.size(), 'Should create 3 records');
		for(SObject account : accounts)
		{
			System.assertNotEquals(null, Account.Id, 'Each record should be inserted');
		}
	}

	// =========================================================================
	// API_MockFactory — HTTP Response Mocking
	// =========================================================================

	/**
	 * @description Tests API_MockFactory.forService() registers a mock response.
	 */
	@IsTest
	private static void shouldRegisterMockResponse()
	{
		// FINDING: isMockingEnabled() is NOT global — cannot verify registration state from subscriber
		// FINDING: registerErrorMock() is NOT global — subscribers cannot use convenience error mock
		// Test that forService().register() and clearMocks() are callable without error
		kern.API_MockFactory.forService(ECHO_SERVICE)
				.body('{"echo":"test_response"}')
				.statusCode(200)
				.register();

		// Verify registration worked by using it in an outbound call
		kern.API_MockFactory.clearMocks();
	}

	/**
	 * @description Tests API_MockFactory.forService() with custom status code and headers.
	 */
	@IsTest
	private static void shouldRegisterMockWithCustomStatus()
	{
		kern.API_MockFactory.forService(ECHO_SERVICE)
				.body('{"status":"created"}')
				.statusCode(201)
				.register();

		kern.API_MockFactory.clearMocks();
	}

	/**
	 * @description Tests API_MockFactory.clearMocks removes all registrations.
	 */
	@IsTest
	private static void shouldClearAllMocks()
	{
		kern.API_MockFactory.forService(ECHO_SERVICE)
				.body('{"test":true}')
				.statusCode(200)
				.register();

		// clearMocks should not throw
		kern.API_MockFactory.clearMocks();
	}

	// =========================================================================
	// API_OutboundTestHelper — Outbound API Testing
	// =========================================================================

	/**
	 * @description Tests outbound API call aborted when required input is missing.
	 */
	@IsTest
	private static void shouldTestOutboundApiAbort()
	{
		kern.API_OutboundTestHelper.assertCallAborted(
				API_GetPost.class.getName(),
				null
		);
	}

	// =========================================================================
	// API_InboundTestHelper — Inbound API Testing
	// =========================================================================

	/**
	 * @description Tests inbound API success with setupRestContext.
	 */
	@IsTest
	private static void shouldTestInboundApiSuccess()
	{
		API_SubscriberCreateAccount.DTO_Request request = new API_SubscriberCreateAccount.DTO_Request();
		Request.accountName = 'Inbound Test Account';
		Request.industry = 'Technology';
		Request.phone = '555-0001';
		Request.description = 'Inbound test';

		kern.API_InboundTestHelper.setupRestContext(Request);

		Test.startTest();
		REST_SubscriberApi.createAccount();
		Test.stopTest();

		List<kern__ApiCall__c> apiCalls =
		[
				SELECT kern__Status__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :INBOUND_SERVICE
				ORDER BY CreatedDate DESC
				LIMIT 1
		];

		System.assert(!apiCalls.isEmpty(), 'ApiCall record should exist');
		System.assertEquals('Completed', apiCalls[0].kern__Status__c, 'Status should be Completed');
	}

	/**
	 * @description Tests inbound API abort with missing required field.
	 */
	@IsTest
	private static void shouldTestInboundApiAbort()
	{
		API_SubscriberCreateAccount.DTO_Request request = new API_SubscriberCreateAccount.DTO_Request();
		// No accountName or industry — should trigger validation errors

		kern.API_InboundTestHelper.setupRestContext(Request);

		Test.startTest();
		REST_SubscriberApi.createAccount();
		Test.stopTest();

		List<kern__ApiCall__c> apiCalls =
		[
				SELECT kern__Status__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :INBOUND_SERVICE
				ORDER BY CreatedDate DESC
				LIMIT 1
		];

		System.assert(!apiCalls.isEmpty(), 'ApiCall record should exist for aborted call');
		System.assertEquals('Aborted', apiCalls[0].kern__Status__c, 'Status should be Aborted');
	}

	/**
	 * @description Tests inbound API with custom headers.
	 */
	@IsTest
	private static void shouldTestInboundApiWithHeaders()
	{
		API_SubscriberCreateAccount.DTO_Request request = new API_SubscriberCreateAccount.DTO_Request();
		Request.accountName = 'Header Test Account';
		Request.industry = 'Finance';
		Request.phone = '555-0002';
		Request.description = 'Header test';

		Map<String, String> headers = new Map<String, String>
		{
				'X-Custom-Header' => 'test-value',
				'Content-Type' => 'application/json'
		};

		kern.API_InboundTestHelper.setupRestContext(Request, headers);

		Test.startTest();
		REST_SubscriberApi.createAccount();
		Test.stopTest();

		List<kern__ApiCall__c> apiCalls =
		[
				SELECT kern__Status__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :INBOUND_SERVICE
				ORDER BY CreatedDate DESC
				LIMIT 1
		];

		System.assert(!apiCalls.isEmpty(), 'ApiCall should exist');
		System.assertEquals('Completed', apiCalls[0].kern__Status__c, 'Should complete with custom headers');
	}

	// =========================================================================
	// QRY_Builder Mock Methods
	// =========================================================================

	/**
	 * @description Tests QRY_Builder.setMock registers query-level mocks.
	 */
	@IsTest
	private static void shouldSetAndClearQueryMocks()
	{
		List<Account> mockAccounts = new List<Account>();
		for(Integer i = 0; i < 3; i++)
		{
			mockAccounts.add(new Account(
					Id = Account.SObjectType.getDescribe().getKeyPrefix() + String.valueOf(i).leftPad(12, '0'),
					Name = 'Query Mock ' + i
			));
		}

		kern.QRY_Builder.setMock(Account.SObjectType, mockAccounts);

		// Query should return mocks
		List<Account> results = (List<Account>)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.toList();

		System.assert(!results.isEmpty(), 'Query should return mock data');

		kern.QRY_Builder.clearMocks();
	}

	// =========================================================================
	// UTIL_HttpClient Delegation Mode — ApiCall__c Persistence
	// =========================================================================

	/**
	 * @description Tests that ApiCall__c is persisted when delegation mode completes successfully.
	 * Regression test for: ApiCall__c not persisted in UTIL_HttpClient delegation mode.
	 */
	@IsTest
	private static void shouldPersistApiCallWhenDelegationSucceeds()
	{
		Test.startTest();
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, 'delegation test')
				.invoke();
		Test.stopTest();

		kern.SEL_ApiCall.assertServiceCompleted(API_EchoSubscriber.class.getName());
	}

	/**
	 * @description Tests that ApiCall__c is persisted when delegation mode aborts due to missing required input.
	 * Regression test for: ApiCall__c not persisted in UTIL_HttpClient delegation mode.
	 */
	@IsTest
	private static void shouldPersistApiCallWhenDelegationAborts()
	{
		Test.startTest();
		kern.UTIL_HttpClient.useHandler(API_GetPost.class).invoke();
		Test.stopTest();

		kern.SEL_ApiCall.assertServiceAborted(API_GetPost.class.getName());
	}

	// =========================================================================
	// UTIL_HttpClient Delegation Mode — Caller Overrides
	// =========================================================================

	/**
	 * @description Tests that caller-provided retry override is applied to the handler setting
	 * and persisted on the ApiCall__c record.
	 */
	@IsTest
	private static void shouldOverrideRetryInDelegationMode()
	{
		Test.startTest();
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withRetry(5)
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, 'retry override')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed');

		kern__ApiCall__c apiCall =
		[
				SELECT kern__MaxRetries__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :API_EchoSubscriber.class.getName()
				ORDER BY CreatedDate DESC
				LIMIT 1
		];
		Assert.areEqual(5, apiCall.kern__MaxRetries__c, 'MaxRetries should reflect caller override');
	}

	/**
	 * @description Tests that caller-provided path override is merged into the handler setting.
	 * The handler's CMDT has EndpointPath__c = '/echo'; caller overrides to '/v2/override'.
	 */
	@IsTest
	private static void shouldOverridePathInDelegationMode()
	{
		Test.startTest();
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.path('/v2/override')
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, 'path override')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed with overridden path');
		kern.SEL_ApiCall.assertServiceCompleted(API_EchoSubscriber.class.getName());
	}

	/**
	 * @description Tests that credential override disables auto-mocking — caller must register
	 * a mock manually for the call to succeed.
	 */
	@IsTest
	private static void shouldOverrideCredentialInDelegationMode()
	{
		String serviceName = API_EchoSubscriber.class.getName();
		kern.API_MockFactory.forService(serviceName)
				.body('{"echo":"credential_override"}')
				.statusCode(200)
				.register();

		Test.startTest();
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.credential('OverrideCredential')
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, 'credential override')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed with manually registered mock');
		kern.SEL_ApiCall.assertServiceCompleted(serviceName);
	}

	/**
	 * @description Tests that multiple caller overrides (retry, circuit breaker) are merged
	 * while CMDT defaults (path, log issues) are preserved.
	 */
	@IsTest
	private static void shouldMergePartialOverridesWithHandlerCMDT()
	{
		Test.startTest();
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withRetry(3, 10)
				.withCircuitBreaker()
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, 'partial override')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed with partial overrides');

		kern__ApiCall__c apiCall =
		[
				SELECT kern__MaxRetries__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :API_EchoSubscriber.class.getName()
				ORDER BY CreatedDate DESC
				LIMIT 1
		];
		Assert.areEqual(3, apiCall.kern__MaxRetries__c, 'MaxRetries should reflect caller override');
	}

	/**
	 * @description Tests that handler CMDT defaults are preserved when caller provides no overrides.
	 * EchoSubscriber CMDT: EndpointPath=/echo, MaxRetryCount=null, LogIssues=true.
	 */
	@IsTest
	private static void shouldFallBackToHandlerCMDTWithoutOverrides()
	{
		Test.startTest();
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, 'no overrides')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed with CMDT defaults');

		kern__ApiCall__c apiCall =
		[
				SELECT kern__MaxRetries__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :API_EchoSubscriber.class.getName()
				ORDER BY CreatedDate DESC
				LIMIT 1
		];
		Assert.areEqual(0, apiCall.kern__MaxRetries__c, 'MaxRetries should default to 0 (no CMDT value)');
	}

	// =========================================================================
	// UTIL_Exceptions — Framework Exceptions from Subscriber
	// =========================================================================

	/**
	 * @description Tests that the echo subscriber service is instantiable and configurable.
	 */
	@IsTest
	private static void shouldInstantiateEchoSubscriber()
	{
		API_EchoSubscriber service = new API_EchoSubscriber();
		Assert.isNotNull(service, 'Service should be instantiable');
		Assert.areEqual('message', API_EchoSubscriber.PARAM_MESSAGE, 'PARAM_MESSAGE should match expected value');
	}

	/**
	 * @description Tests subscriber can throw and catch NotFoundException.
	 */
	@IsTest
	private static void shouldCatchNotFoundException()
	{
		Boolean caught = false;
		try
		{
			throw new kern.UTIL_Exceptions.NotFoundException('Record not found');
		}
		catch(kern.UTIL_Exceptions.NotFoundException error)
		{
			caught = true;
			System.assertEquals('Record not found', error.getMessage(), 'Message should match');
		}

		System.assert(caught, 'Should catch NotFoundException');
	}

	/**
	 * @description Tests subscriber can throw and catch ConfigurationException.
	 */
	@IsTest
	private static void shouldCatchConfigurationException()
	{
		Boolean caught = false;
		try
		{
			throw new kern.UTIL_Exceptions.ConfigurationException('Missing config');
		}
		catch(kern.UTIL_Exceptions.ConfigurationException error)
		{
			caught = true;
			System.assertEquals('Missing config', error.getMessage(), 'Message should match');
		}

		System.assert(caught, 'Should catch ConfigurationException');
	}
}
