// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Class has base methods that can be used to test an outbound service.
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
 * API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, parameters);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity')
global inherited sharing class API_OutboundTestHelper
{
	/**
	 * @description Tests the successful execution of a web service call.
	 *
	 * @param serviceName The name of the web service handler
	 * @param recordId Id of the triggering object (optional)
	 *
	 * @return The handler executing the API call
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id);
	 * ```
	 */
	global static API_Base assertCallSuccessful(String serviceName, Id recordId)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId);
		return assertCallSuccessful(new List<ApiCall__c> {apiCall}).iterator().next();
	}

	/**
	 * @description Tests the successful execution of a web service call and verifies response transformation.
	 *
	 * @param serviceName The name of the web service handler to be called
	 * @param recordId The ID of the object that triggered the service (optional)
	 * @param transformerClassName The class name to which the handler's response will be transformed
	 *
	 * @return The handler executing the API call
	 */
	public static API_Base assertCallSuccessfulWithTransformation(String serviceName, Id recordId, String transformerClassName)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId);
		API_Base handler = assertCallSuccessful(new List<ApiCall__c> {apiCall}).iterator().next();

		Assert.isInstanceOfType(handler, API_Outbound.class, 'Handler not of type API_Outbound');
		DTO_Base dtoBase = ((API_Outbound)handler).transformResponse(transformerClassName);
		Assert.isNotNull(dtoBase, 'No dto returned after transformation');

		return handler;
	}

	/**
	 * @description Tests a successful web service call but expects the transformation to fail.
	 *
	 * @param serviceName The name of the web service handler
	 * @param recordId Id of the triggering object (optional)
	 * @param transformerClassName Class name to which to transform handler response
	 */
	public static void assertCallSuccessfulWithInvalidTransformation(String serviceName, Id recordId, String transformerClassName)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId);
		API_Base handler = assertCallSuccessful(new List<ApiCall__c> {apiCall}).iterator().next();

		Assert.isInstanceOfType(handler, API_Outbound.class, 'Handler not of type" ' + API_Outbound.class.getName());

		Exception errorThrown;
		try
		{
			((API_Outbound)handler).transformResponse(transformerClassName);
		}
		catch(Exception error)
		{
			errorThrown = error;
		}

		Assert.isNotNull(errorThrown, 'No exception was throw');
		Assert.isTrue(errorThrown instanceof IllegalArgumentException || errorThrown instanceof TypeException, 'Incorrect exception type thrown: ' + errorThrown.getTypeName());
	}

	/**
	 * @description Tests that a web service call is executed successfully for each of the provided API calls.
	 *
	 * @param apiCalls The API calls containing the services and parameters to call
	 *
	 * @return A list of handlers that processed the request
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
	 * List<API_Base> handlers = API_OutboundTestHelper.assertCallSuccessful(apiCalls);
	 * ```
	 */
	global static List<API_Base> assertCallSuccessful(List<ApiCall__c> apiCalls)
	{
		assertRunningInUnitTest();

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(apiCalls);

		Test.stopTest();

		assertHandlersNotEmpty(handlers, apiCalls);

		for(API_Base handler : handlers)
		{
			assertStatusCorrect(handler.result.isSuccess, handler.result);
			Assert.isTrue(String.isNotBlank(handler.apiCall.Response__c), 'API call response not set');
			Assert.areNotEqual(UTIL_String.EMPTY_JSON_RESPONSE, handler.apiCall.Response__c, 'Response Empty JSON');
		}

		return handlers;
	}

	/**
	 * @description Will check that the status given is true.
	 *
	 * @param status The status to check
	 * @param callResult If status isn't valid then will throw an exception with the contents of call result
	 */
	private static void assertStatusCorrect(Boolean status, API_Base.ServiceCallResult callResult)
	{
		Assert.isTrue(status, String.format('Status invalid. Response Call Result JSON: {0}', new List<String> {JSON.serialize(callResult)}));
	}

	/**
	 * @description Will check that handlers list is not empty.
	 *
	 * @param handlers The handlers to check
	 * @param apiCalls The API calls being processed
	 */
	private static void assertHandlersNotEmpty(List<API_Base> handlers, List<ApiCall__c> apiCalls)
	{
		if(handlers.isEmpty())
		{
			throw new IllegalArgumentException(String.format('No handlers returned for apiCalls: "{0}"', new List<String> {JSON.serialize(apiCalls)}));
		}
	}

	/**
	 * @description Checks to see if the method is being executed in the context of a unit test.
	 */
	private static void assertRunningInUnitTest()
	{
		Assert.isTrue(Test.isRunningTest(), 'Method can only be run in a unit test');
	}

	/**
	 * @description Tests the successful execution of a web service call, passing a single parameter.
	 *
	 * @param serviceName The name of the web service handler
	 * @param recordId id of the triggering object (optional)
	 * @param parameterName Name of a parameter to pass to the service handler
	 *
	 * @return The handler executing the API call
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, API_MyService.PARAM_KEY);
	 * ```
	 */
	global static API_Base assertCallSuccessful(String serviceName, Id recordId, String parameterName)
	{
		return assertCallSuccessful(serviceName, recordId, new Set<String> {parameterName});
	}

	/**
	 * @description Tests the successful execution of a web service call, passing a set of parameters.
	 *
	 * @param serviceName The name of the web service handler
	 * @param recordId id of the triggering object (optional)
	 * @param parameterNames Names of parameters to pass to the service handler
	 *
	 * @return The handler executing the API call
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> parameterNames = new Set<String>{'param1', 'param2'};
	 * API_Base handler = API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, parameterNames);
	 * ```
	 */
	global static API_Base assertCallSuccessful(String serviceName, Id recordId, Set<String> parameterNames)
	{
		Map<String, String> parameterMap = new Map<String, String>();

		for(String parameterName : parameterNames)
		{
			parameterMap.put(parameterName, UTIL_Random.randomNumber());
		}

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId, parameterMap);
		return assertCallSuccessful(new List<ApiCall__c> {apiCall}).iterator().next();
	}

	/**
	 * @description Tests the successful execution of a web service call, passing a map of parameters.
	 *
	 * @param serviceName The name of the web service handler
	 * @param recordId id of the triggering object (optional)
	 * @param parameters Map of parameters to pass to the API call
	 *
	 * @return The handler executing the API call
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, String> parameters = new Map<String, String>{API_MyService.PARAM_KEY => 'value'};
	 * API_Base handler = API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, parameters);
	 * ```
	 */
	global static API_Base assertCallSuccessful(String serviceName, Id recordId, Map<String, String> parameters)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId, parameters);
		return assertCallSuccessful(new List<ApiCall__c> {apiCall}).iterator().next();
	}

	/**
	 * @description Tests that a web service call fails as expected.
	 *
	 * @param apiCalls The API calls containing the services and parameters to call
	 *
	 * @return A list of handlers that processed the request
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
	 * List<API_Base> handlers = API_OutboundTestHelper.assertCallFailed(apiCalls);
	 * ```
	 */
	global static List<API_Base> assertCallFailed(List<ApiCall__c> apiCalls)
	{
		assertRunningInUnitTest();

		for(ApiCall__c apiCall : apiCalls)
		{
			API_MockFactory.registerErrorMock(apiCall.ServiceName__c);
		}

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(apiCalls);

		assertHandlersNotEmpty(handlers, apiCalls);

		Test.stopTest();

		for(API_Base handler : handlers)
		{
			assertStatusCorrect(handler.result.hasFailed, handler.result);
			Assert.areEqual(API_Base.ERR_INTERNAL_SERVER, handler.result.responseBody, 'Incorrect response provided');
		}

		return handlers;
	}

	/**
	 * @description Tests that a web service call fails to parse the response.
	 *
	 * @param apiCalls The API calls containing the services and parameters to call
	 *
	 * @return A list of handlers that processed the request
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
	 * List<API_Base> handlers = API_OutboundTestHelper.assertParseFailed(apiCalls);
	 * ```
	 */
	global static List<API_Base> assertParseFailed(List<ApiCall__c> apiCalls)
	{
		assertRunningInUnitTest();

		for(ApiCall__c apiCall : apiCalls)
		{
			API_MockFactory.registerParseFailMock(apiCall.ServiceName__c);
		}

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(apiCalls);

		assertHandlersNotEmpty(handlers, apiCalls);

		Test.stopTest();

		for(API_Base handler : handlers)
		{
			assertStatusCorrect(handler.result.hasFailed, handler.result);
		}

		return handlers;
	}

	/**
	 * @description Tests that a web service call is aborted as expected.
	 *
	 * @param apiCalls The API calls containing the services and parameters to call
	 *
	 * @return A list of handlers that processed the requests.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
	 * List<API_Base> handlers = API_OutboundTestHelper.assertCallAborted(apiCalls);
	 * ```
	 */
	global static List<API_Base> assertCallAborted(List<ApiCall__c> apiCalls)
	{
		assertRunningInUnitTest();

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(apiCalls);

		assertHandlersNotEmpty(handlers, apiCalls);

		Test.stopTest();

		for(API_Base handler : handlers)
		{
			assertStatusCorrect(handler.result.isAborted, handler.result);
		}

		return handlers;
	}

	/**
	 * @description Tests that a web service call is aborted as expected.
	 *
	 * @param serviceName The class name of the API handler
	 * @param recordId The object that triggered the callout (optional)
	 *
	 * @return The handler executing the web service call.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, record.Id);
	 * ```
	 */
	global static API_Base assertCallAborted(String serviceName, Id recordId)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId);
		return assertCallAborted(new List<ApiCall__c> {apiCall}).iterator().next();
	}

	/**
	 * @description Tests an aborted API call with parameter names.
	 *
	 * @param serviceName The name of the web service handler
	 * @param recordId id of the triggering object (optional)
	 * @param parameterNames Names of parameters to pass to the service handler
	 *
	 * @return The handler executing the API call
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> parameterNames = new Set<String>{'param1', 'param2'};
	 * API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, record.Id, parameterNames);
	 * ```
	 */
	global static API_Base assertCallAborted(String serviceName, Id recordId, Set<String> parameterNames)
	{
		Map<String, String> parameterMap = new Map<String, String>();

		for(String parameterName : parameterNames)
		{
			parameterMap.put(parameterName, UTIL_Random.randomNumber());
		}

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId, parameterMap);

		return assertCallAborted(new List<ApiCall__c> {apiCall}).iterator().next();
	}

	/**
	 * @description Tests an aborted API call with a single parameter name.
	 *
	 * @param serviceName The name of the web service handler
	 * @param recordId id of the triggering object (optional)
	 * @param parameterName Name of a parameter to pass to the service handler
	 *
	 * @return The handler executing the API call
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, record.Id, API_MyService.PARAM_KEY);
	 * ```
	 */
	global static API_Base assertCallAborted(String serviceName, Id recordId, String parameterName)
	{
		return assertCallAborted(serviceName, recordId, new Set<String> {parameterName});
	}

	/**
	 * @description Tests that an API call aborts as expected with parameters.
	 *
	 * @param serviceName The name of the web service handler
	 * @param recordId id of the triggering object (optional)
	 * @param parameters Map of parameters to pass to the API call
	 *
	 * @return The handler executing the API call
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, String> parameters = new Map<String, String>{API_MyService.PARAM_KEY => 'value'};
	 * API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, record.Id, parameters);
	 * ```
	 */
	global static API_Base assertCallAborted(String serviceName, Id recordId, Map<String, String> parameters)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId, parameters);
		return assertCallAborted(new List<ApiCall__c> {apiCall}).iterator().next();
	}

	/**
	 * @description Tests that an API call aborts with a specific error message.
	 *
	 * @param apiCall The API call containing the service and parameters to call
	 * @param exceptionMessage The error message that must exist in the response
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
	 * API_OutboundTestHelper.assertCallAborted(apiCall, 'Expected error message');
	 * ```
	 */
	global static void assertCallAborted(ApiCall__c apiCall, String exceptionMessage)
	{
		assertCallAborted(new List<ApiCall__c> {apiCall}, exceptionMessage);
	}

	/**
	 * @description Tests that an API call aborts with a specific error message.
	 *
	 * @param apiCalls The API calls containing the services and parameters to call
	 * @param exceptionMessage The message string which is checked in the abort message
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
	 * API_OutboundTestHelper.assertCallAborted(apiCalls, 'Expected error message');
	 * ```
	 */
	global static void assertCallAborted(List<ApiCall__c> apiCalls, String exceptionMessage)
	{
		List<API_Base> handlers = assertCallAborted(apiCalls);

		for(API_Base handler : handlers)
		{
			Assert.isFalse(handler.result.errors.isEmpty(), 'No errors thrown');
			Assert.isTrue
					(
							handler.result.errors.contains(exceptionMessage),
							'Message "' + exceptionMessage + '" not found in "' + JSON.serialize(handler.result.errors, true) + '"'
					);
		}
	}
}