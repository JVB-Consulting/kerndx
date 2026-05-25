// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests mock selection integration through the outbound delegation pipeline.
 * Verifies catch-all CMDT mock resolution and in-memory mock precedence via
 * UTIL_HttpClient.useHandler().invoke() — the real subscriber invocation path.
 *
 * Pattern matching and priority ordering are tested in the framework's API_MockFactory_TEST
 * which calls getOutboundMock() directly with controlled request bodies. The delegation
 * pipeline (EchoSubscriber) has no request DTO, so the HTTP request body is empty and
 * only catch-all mocks (blank pattern) are exercised here.
 *
 * @see API_EchoSubscriber
 * @see API_MockFactory_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SubscriberMockSelection_TEST
{
	/**
	 * @description The outbound echo service class name.
	 */
	private static final String ECHO_SERVICE = API_EchoSubscriber.class.getName();

	/**
	 * @description Verifies CMDT catch-all mock is selected through the full delegation pipeline.
	 * Registers a single catch-all mock (no pattern) and invokes via UTIL_HttpClient.
	 * Proves the end-to-end path: delegation → CalloutMock → resolveMock → CMDT lookup → ApiCall__c.
	 */
	@IsTest
	private static void shouldSelectCatchAllMockViaDelegation()
	{
		kern.TST_Mock.clear(kern__ApiMock__mdt.SObjectType);

		kern.TST_Mock.of(kern__ApiMock__mdt.SObjectType)
				.withOverride(kern__ApiMock__mdt.kern__IsActive__c, true)
				.withOverride(kern__ApiMock__mdt.kern__Priority__c, 100)
				.withOverride(kern__ApiMock__mdt.kern__IsRegex__c, false)
				.withOverride(kern__ApiMock__mdt.kern__StatusCode__c, 202)
				.withOverride(kern__ApiMock__mdt.kern__ResponseBody__c, '{"mock":"catch-all"}')
				.build();

		Test.startTest();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, 'any-body')
				.invoke();
		Test.stopTest();

		kern__ApiCall__c apiCall =
		[
				SELECT kern__Response__c,
						kern__StatusCode__c,
						kern__IsMockedResponse__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :ECHO_SERVICE
				ORDER BY CreatedDate DESC
				LIMIT 1
		];

		Assert.isTrue(apiCall.kern__IsMockedResponse__c, 'Should be a mocked response');
		Assert.areEqual('202', apiCall.kern__StatusCode__c, 'Catch-all mock should return status 202');
		Assert.isTrue(
				apiCall.kern__Response__c != null && apiCall.kern__Response__c.contains('"catch-all"'),
				'Response should contain catch-all mock body'
		);
	}

	/**
	 * @description Verifies in-memory mock (API_MockFactory) takes precedence over CMDT mocks
	 * when both are registered for the same service.
	 */
	@IsTest
	private static void shouldPreferInMemoryMockOverMetadata()
	{
		kern.TST_Mock.clear(kern__ApiMock__mdt.SObjectType);

		kern.TST_Mock.of(kern__ApiMock__mdt.SObjectType)
				.withOverride(kern__ApiMock__mdt.kern__IsActive__c, true)
				.withOverride(kern__ApiMock__mdt.kern__Priority__c, 100)
				.withOverride(kern__ApiMock__mdt.kern__IsRegex__c, false)
				.withOverride(kern__ApiMock__mdt.kern__StatusCode__c, 202)
				.withOverride(kern__ApiMock__mdt.kern__ResponseBody__c, '{"mock":"cmdt"}')
				.build();

		kern.API_MockFactory.forService(ECHO_SERVICE)
				.body('{"mock":"in-memory"}')
				.statusCode(299)
				.register();

		Test.startTest();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, 'test')
				.invoke();
		Test.stopTest();

		kern__ApiCall__c apiCall =
		[
				SELECT kern__Response__c,
						kern__StatusCode__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :ECHO_SERVICE
				ORDER BY CreatedDate DESC
				LIMIT 1
		];

		Assert.areEqual('299', apiCall.kern__StatusCode__c, 'In-memory mock should take precedence over CMDT');
		Assert.isTrue(
				apiCall.kern__Response__c != null && apiCall.kern__Response__c.contains('"in-memory"'),
				'Response should contain in-memory mock body'
		);
	}
}
