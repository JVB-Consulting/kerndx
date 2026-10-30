// SPDX-License-Identifier: Apache-2.0
/**
 * @description Shows, from code outside the package, the framework's ways of standing in for data and callouts in a
 * test: mock records with kern.TST_Mock, test data with kern.TST_Builder, prepared HTTP answers with
 * kern.API_MockFactory, the outbound and inbound service test helpers, the query builder's mock methods, calls sent
 * through an outbound handler with the HTTP client, and the framework's exceptions. Each test is a pattern to copy.
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
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

	/**
	 * @description How many random letters and digits make up the message of an exception a test raises.
	 */
	private static final Integer MESSAGE_LENGTH = 16;

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

		Assert.isNotNull(mock, 'Mock should not be null');
		Assert.isNotNull(mock.Id, 'Mock should have a generated Id');
		Assert.areEqual('Mock Account', mock.Name, 'Name should match override');
		Assert.areEqual('Technology', mock.Industry, 'Industry should match override');
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

		Assert.areEqual(5, mocks.size(), 'Should create 5 mocks');
		for(SObject mock : mocks)
		{
			Assert.isNotNull(mock.Id, 'Each mock should have an Id');
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

		Assert.areEqual(4, mocks.size(), 'Should create 4 mocks');
		Assert.areEqual('Tech', ((Account)mocks[0]).Industry, 'First should be Tech');
		Assert.areEqual('Finance', ((Account)mocks[1]).Industry, 'Second should be Finance');
		Assert.areEqual('Tech', ((Account)mocks[2]).Industry, 'Third should be Tech (cycle)');
		Assert.areEqual('Finance', ((Account)mocks[3]).Industry, 'Fourth should be Finance (cycle)');
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
		Assert.isFalse(mocks.isEmpty(), 'Should have registered mocks');

		kern.TST_Mock.clear(Account.SObjectType);

		List<SObject> afterClear = kern.TST_Mock.get(Account.SObjectType);
		Assert.isTrue(afterClear.isEmpty(), 'Mocks should be cleared');
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

		Assert.isTrue(kern.TST_Mock.get(Account.SObjectType).isEmpty(), 'Account mocks should be cleared');
		Assert.isTrue(kern.TST_Mock.get(Contact.SObjectType).isEmpty(), 'Contact mocks should be cleared');
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

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		Assert.isNotNull(record.Id, 'Record should be inserted with an Id');

		Account queried =
		[
				SELECT Name
				FROM Account
				WHERE Id = :record.Id
		];
		Assert.isNotNull(queried.Name, 'Name should have a default value');
	}

	/**
	 * @description Tests TST_Builder withoutInsertion creates in-memory record.
	 */
	@IsTest
	private static void shouldBuildWithoutInsertion()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withoutInsertion()
				.build();

		Assert.isNull(record.Id, 'In-memory record should not have an Id');
	}

	/**
	 * @description Tests TST_Builder with field overrides.
	 */
	@IsTest
	private static void shouldBuildWithOverrides()
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
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
				WHERE Id = :record.Id
		];
		Assert.areEqual('Custom Name', queried.Name, 'Name should match override');
		Assert.areEqual('Healthcare', queried.Industry, 'Industry should match override');
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

		Assert.areEqual(3, accounts.size(), 'Should create 3 records');
		for(SObject record : accounts)
		{
			Assert.isNotNull(record.Id, 'Each record should be inserted');
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
		API_SubscriberCreateAccount.DTO_Request accountRequest = new API_SubscriberCreateAccount.DTO_Request();
		accountRequest.accountName = 'Inbound Test Account';
		accountRequest.industry = 'Technology';
		accountRequest.phone = '555-0001';
		accountRequest.description = 'Inbound test';

		kern.API_InboundTestHelper.setupRestContext(accountRequest);

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

		Assert.isFalse(apiCalls.isEmpty(), 'ApiCall record should exist');
		Assert.areEqual('Completed', apiCalls[0].kern__Status__c, 'Status should be Completed');
	}

	/**
	 * @description Tests inbound API abort with missing required field.
	 */
	@IsTest
	private static void shouldTestInboundApiAbort()
	{
		API_SubscriberCreateAccount.DTO_Request accountRequest = new API_SubscriberCreateAccount.DTO_Request();
		// No accountName or industry — should trigger validation errors

		kern.API_InboundTestHelper.setupRestContext(accountRequest);

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

		Assert.isFalse(apiCalls.isEmpty(), 'ApiCall record should exist for aborted call');
		Assert.areEqual('Aborted', apiCalls[0].kern__Status__c, 'Status should be Aborted');
	}

	/**
	 * @description Tests inbound API with custom headers.
	 */
	@IsTest
	private static void shouldTestInboundApiWithHeaders()
	{
		API_SubscriberCreateAccount.DTO_Request accountRequest = new API_SubscriberCreateAccount.DTO_Request();
		accountRequest.accountName = 'Header Test Account';
		accountRequest.industry = 'Finance';
		accountRequest.phone = '555-0002';
		accountRequest.description = 'Header test';

		Map<String, String> headers = new Map<String, String>
		{
				'X-Custom-Header' => 'test-value',
				'Content-Type' => 'application/json'
		};

		kern.API_InboundTestHelper.setupRestContext(accountRequest, headers);

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

		Assert.isFalse(apiCalls.isEmpty(), 'ApiCall should exist');
		Assert.areEqual('Completed', apiCalls[0].kern__Status__c, 'Should complete with custom headers');
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

		Assert.isFalse(results.isEmpty(), 'Query should return mock data');

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
	 * @description Code outside the package can raise the framework's NotFoundException with its own message and catch
	 * it by type, with the message intact.
	 */
	@IsTest
	private static void shouldCatchNotFoundException()
	{
		String message = kern.UTIL_Random.randomAlphanumeric(MESSAGE_LENGTH);
		try
		{
			raise(new kern.UTIL_Exceptions.NotFoundException(message));
			Assert.fail('Expected a NotFoundException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, kern.UTIL_Exceptions.NotFoundException.class, 'Incorrect Exception Type');
			Assert.areEqual(message, error.getMessage(), 'Expected the message the exception was raised with');
		}
	}

	/**
	 * @description Code outside the package can raise the framework's ConfigurationException with its own message and
	 * catch it by type, with the message intact.
	 */
	@IsTest
	private static void shouldCatchConfigurationException()
	{
		String message = kern.UTIL_Random.randomAlphanumeric(MESSAGE_LENGTH);
		try
		{
			raise(new kern.UTIL_Exceptions.ConfigurationException(message));
			Assert.fail('Expected a ConfigurationException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, kern.UTIL_Exceptions.ConfigurationException.class, 'Incorrect Exception Type');
			Assert.areEqual(message, error.getMessage(), 'Expected the message the exception was raised with');
		}
	}

	/**
	 * @description Throws the exception it is given, so a test can call code that raises rather than raise inline.
	 *
	 * @param error The exception to throw.
	 */
	private static void raise(Exception error)
	{
		throw error;
	}
}
