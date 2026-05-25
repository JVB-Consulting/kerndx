// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Class has base methods that can be used to assist with testing inbound service calls
 *
 * @see API_InboundTestHelper_TEST
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * API_UpdateInvoice.DTO_Request request = new API_UpdateInvoice.DTO_Request();
 * request.invoiceId = invoice.Id;
 * request.status = 'Paid';
 * API_InboundTestHelper.setupRestContext(request);
 * API_Base handler = API_InboundTestHelper.assertCallSuccessful(API_UpdateInvoice.class.getName());
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class API_InboundTestHelper
{
	/**
	 * @description Sets up the RestContext objects of "request" and "response" for testing purposes.
	 * This method serializes the provided DTO into the request body to simulate a real inbound request.
	 *
	 * @param dtoRequest The DTO that should be serialized and represents the JSON sent in a request.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_InboundTestHelper.setupRestContext(new DTO_Base());
	 * ```
	 */
	global static void setupRestContext(DTO_Base dtoRequest)
	{
		setupRestContext();
		RestContext.request.requestBody = Blob.valueOf(dtoRequest.serialize());
	}

	/**
	 * @description Sets up the RestContext with a serialized DTO body and custom headers.
	 * Merges custom headers (e.g., idempotency keys, trace parents) into the RestContext request.
	 *
	 * @param dtoRequest The DTO that should be serialized and represents the JSON sent in a request.
	 * @param headers Map of header name-value pairs to add to the request.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_InboundTestHelper.setupRestContext(new DTO_Base(), new Map<String, String>{'Idempotency-Key' => 'abc-123'});
	 * ```
	 */
	global static void setupRestContext(DTO_Base dtoRequest, Map<String, String> headers)
	{
		setupRestContext(dtoRequest);

		if(headers != null)
		{
			for(String headerName : headers.keySet())
			{
				RestContext.request.headers.put(headerName, headers.get(headerName));
			}
		}
	}

	/**
	 * @description Checks to see if the method is being executed in the context of an unit test
	 */
	private static void assertRunningInUnitTest()
	{
		Assert.isTrue(Test.isRunningTest(), 'Method can only be run in a unit test');
	}

	/**
	 * @description Sets up the RestContext objects of "request" and "response" to prepare for testing inbound service calls.
	 * This method initializes the request and response objects with default values.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_InboundTestHelper.setupRestContext();
	 * ```
	 */
	global static void setupRestContext()
	{
		assertRunningInUnitTest();

		RestContext.request = new RestRequest();
		RestContext.request.headers.put(API_Base.HTTP_CONTENT_TYPE, API_Base.HTTP_ENCODING_JSON);
		RestContext.request.httpMethod = API_Base.toHttpString(API_Base.HttpMethod.POST);
		RestContext.request.requestURI = 'https://example.com/test';

		RestContext.response = new RestResponse();
	}

	/**
	 * @description Executes an inbound service call and asserts that it completed successfully.
	 * Sets up RestContext internally before executing. Mirrors the outbound test helper pattern.
	 *
	 * @param serviceName The name of the inbound webservice handler
	 *
	 * @return An instance of the handler for further assertions
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_InboundTestHelper.assertCallSuccessful('API_Echo');
	 * ```
	 */
	global static API_Base assertCallSuccessful(String serviceName)
	{
		assertRunningInUnitTest();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(serviceName);

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(serviceName);

		return handler;
	}

	/**
	 * @description Executes an inbound service call with a DTO body and asserts that it completed successfully.
	 *
	 * @param serviceName The name of the inbound webservice handler
	 * @param dtoRequest The DTO that should be serialized as the request body
	 *
	 * @return An instance of the handler for further assertions
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_InboundTestHelper.assertCallSuccessful('API_Echo', new DTO_Base());
	 * ```
	 */
	global static API_Base assertCallSuccessful(String serviceName, DTO_Base dtoRequest)
	{
		setupRestContext(dtoRequest);
		return assertCallSuccessful(serviceName);
	}

	/**
	 * @description Executes an inbound service call with a DTO body and custom headers, asserts successful completion.
	 *
	 * @param serviceName The name of the inbound webservice handler
	 * @param dtoRequest The DTO that should be serialized as the request body
	 * @param headers Map of header name-value pairs to add to the request
	 *
	 * @return An instance of the handler for further assertions
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_InboundTestHelper.assertCallSuccessful('API_Echo', new DTO_Base(), new Map<String, String>{'Idempotency-Key' => 'abc'});
	 * ```
	 */
	global static API_Base assertCallSuccessful(String serviceName, DTO_Base dtoRequest, Map<String, String> headers)
	{
		setupRestContext(dtoRequest, headers);
		return assertCallSuccessful(serviceName);
	}

	/**
	 * @description Executes an inbound service call and asserts that it failed.
	 *
	 * @param serviceName The name of the inbound webservice handler
	 *
	 * @return An instance of the handler for further assertions
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_InboundTestHelper.assertCallFailed('API_Echo');
	 * ```
	 */
	global static API_Base assertCallFailed(String serviceName)
	{
		assertRunningInUnitTest();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(serviceName);

		Test.stopTest();

		SEL_ApiCall.assertServiceFailed(serviceName);

		return handler;
	}

	/**
	 * @description Executes an inbound service call with a DTO body and asserts that it failed.
	 *
	 * @param serviceName The name of the inbound webservice handler
	 * @param dtoRequest The DTO that should be serialized as the request body
	 *
	 * @return An instance of the handler for further assertions
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_InboundTestHelper.assertCallFailed('API_Echo', new DTO_Base());
	 * ```
	 */
	global static API_Base assertCallFailed(String serviceName, DTO_Base dtoRequest)
	{
		setupRestContext(dtoRequest);
		return assertCallFailed(serviceName);
	}

	/**
	 * @description Executes a callout and ensures that the call was aborted due to the API being disabled.
	 * This method takes a service name and the request DTO, sets up the RestContext, and verifies that the expected exception message is present in the response.
	 *
	 * @param serviceName The name of the inbound  webservice handler
	 * @param dtoRequest The request being sent the handler
	 * @param exceptionMessage The message expected in the response/errors payload
	 *
	 * @return An instance of the handler, in case further checks are necessary
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base result = API_InboundTestHelper.assertCallAborted('API_InboundTestHelper', new DTO_Base(), 'An error occurred');
	 * ```
	 */
	global static API_Base assertCallAborted(String serviceName, DTO_Base dtoRequest, String exceptionMessage)
	{
		setupRestContext(dtoRequest);
		return assertCallAborted(serviceName, exceptionMessage);
	}

	/**
	 * @description Executes a callout and ensures that the call was aborted due to the API being disabled.
	 * This method takes a service name and checks if the expected exception message is present in the response/errors payload.
	 *
	 * @param serviceName The name of the inbound  webservice handler
	 * @param exceptionMessage The message expected in the response/errors payload
	 *
	 * @return An instance of the handler, in case further checks are necessary
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base result = API_InboundTestHelper.assertCallAborted('API_InboundTestHelper', 'An error occurred');
	 * ```
	 */
	global static API_Base assertCallAborted(String serviceName, String exceptionMessage)
	{
		API_Base handler = assertCallAborted(serviceName);

		Assert.isTrue(handler.result.errors.contains(exceptionMessage), 'Incorrect error message');

		return handler;
	}

	/**
	 * @description Executes a callout and ensures that the call was aborted due to the API being disabled.
	 * This method takes a service name and returns an instance of the handler for further checks.
	 *
	 * @param serviceName The name of the inbound  webservice handler
	 *
	 * @return An instance of the handler, in case further checks are necessary
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base result = API_InboundTestHelper.assertCallAborted('API_InboundTestHelper');
	 * ```
	 */
	global static API_Base assertCallAborted(String serviceName)
	{
		assertRunningInUnitTest();

		Test.startTest();

		API_Base handler = API_Dispatcher.processInboundService(serviceName);

		Test.stopTest();

		Assert.isTrue(handler.result.isAborted, 'Request not aborted as expected.');
		Assert.isFalse(handler.result.errors.isEmpty(), 'No errors thrown');

		return handler;
	}
}