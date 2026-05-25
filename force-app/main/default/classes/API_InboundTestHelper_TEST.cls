// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for API_InboundTestHelper. Verifies REST context setup,
 * header injection, and the assertCallSuccessful/assertCallFailed/assertCallAborted helpers.
 *
 * @see API_InboundTestHelper
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class API_InboundTestHelper_TEST
{
	/**
	 * @description The service class name used for testing.
	 */
	private static final String SERVICE_NAME = API_Echo.class.getName();

	/**
	 * @description Tests that setupRestContext initializes request and response objects.
	 */
	@IsTest
	private static void shouldSetupRestContext()
	{
		API_InboundTestHelper.setupRestContext();

		Assert.isNotNull(RestContext.request, 'Request should be initialized');
		Assert.isNotNull(RestContext.response, 'Response should be initialized');
		Assert.areEqual(API_Base.HTTP_ENCODING_JSON, RestContext.request.headers.get(API_Base.HTTP_CONTENT_TYPE), 'Content-Type should be JSON');
	}

	/**
	 * @description Tests that setupRestContext with DTO sets the request body.
	 */
	@IsTest
	private static void shouldSetupRestContextWithDto()
	{
		DTO_JsonBase dtoRequest = new DTO_JsonBase();

		API_InboundTestHelper.setupRestContext(dtoRequest);

		Assert.isNotNull(RestContext.request.requestBody, 'Request body should be set');
	}

	/**
	 * @description Tests that setupRestContext with headers merges custom headers into the request.
	 */
	@IsTest
	private static void shouldSetupRestContextWithHeaders()
	{
		DTO_JsonBase dtoRequest = new DTO_JsonBase();
		Map<String, String> headers = new Map<String, String>
		{
				'Idempotency-Key' => 'test-key-123',
				'X-Custom-Header' => 'custom-value'
		};

		API_InboundTestHelper.setupRestContext(dtoRequest, headers);

		Assert.areEqual('test-key-123', RestContext.request.headers.get('Idempotency-Key'), 'Idempotency-Key header should be set');
		Assert.areEqual('custom-value', RestContext.request.headers.get('X-Custom-Header'), 'Custom header should be set');
	}

	/**
	 * @description Tests that setupRestContext with null headers does not throw.
	 */
	@IsTest
	private static void shouldHandleNullHeaders()
	{
		DTO_JsonBase dtoRequest = new DTO_JsonBase();

		API_InboundTestHelper.setupRestContext(dtoRequest, null);

		Assert.isNotNull(RestContext.request, 'Request should be initialized even with null headers');
	}

	/**
	 * @description Tests that assertCallSuccessful completes for a valid inbound service.
	 */
	@IsTest
	private static void shouldAssertCallSuccessful()
	{
		API_InboundTestHelper.setupRestContext(new DTO_JsonBase());

		API_Base handler = API_InboundTestHelper.assertCallSuccessful(SERVICE_NAME);

		Assert.isNotNull(handler, 'Handler should be returned');
	}

	/**
	 * @description Tests that assertCallSuccessful with DTO sets up context and completes.
	 */
	@IsTest
	private static void shouldAssertCallSuccessfulWithDto()
	{
		DTO_JsonBase dtoRequest = new DTO_JsonBase();

		API_Base handler = API_InboundTestHelper.assertCallSuccessful(SERVICE_NAME, dtoRequest);

		Assert.isNotNull(handler, 'Handler should be returned');
	}

	/**
	 * @description Tests that assertCallSuccessful with DTO and headers completes.
	 */
	@IsTest
	private static void shouldAssertCallSuccessfulWithDtoAndHeaders()
	{
		DTO_JsonBase dtoRequest = new DTO_JsonBase();
		Map<String, String> headers = new Map<String, String> {'X-Test' => 'value'};

		API_Base handler = API_InboundTestHelper.assertCallSuccessful(SERVICE_NAME, dtoRequest, headers);

		Assert.isNotNull(handler, 'Handler should be returned');
	}

	/**
	 * @description Tests that assertCallAborted aborts when the API is disabled.
	 */
	@IsTest
	private static void shouldAssertCallAborted()
	{
		TST_Factory.newFeatureFlag(API_Inbound.FLAG_DISABLE_ALL_INBOUND_APIS);
		API_InboundTestHelper.setupRestContext();

		API_Base handler = API_InboundTestHelper.assertCallAborted(SERVICE_NAME);

		Assert.isTrue(handler.result.isAborted, 'Call should be aborted');
	}

	/**
	 * @description Tests that assertCallFailed returns a handler for a failed service.
	 */
	@IsTest
	private static void shouldAssertCallFailed()
	{
		API_Inbound.returnErrorResponse = true;
		API_InboundTestHelper.setupRestContext(new DTO_JsonBase());

		API_Base handler = API_InboundTestHelper.assertCallFailed(SERVICE_NAME);

		Assert.isNotNull(handler, 'Handler should be returned');
	}

	/**
	 * @description Tests that assertCallFailed with DTO sets up context and fails.
	 */
	@IsTest
	private static void shouldAssertCallFailedWithDto()
	{
		API_Inbound.returnErrorResponse = true;
		DTO_JsonBase dtoRequest = new DTO_JsonBase();

		API_Base handler = API_InboundTestHelper.assertCallFailed(SERVICE_NAME, dtoRequest);

		Assert.isNotNull(handler, 'Handler should be returned');
	}
}