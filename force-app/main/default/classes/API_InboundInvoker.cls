// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Invokes inbound API requests programmatically with Safe Mode support.
 * Routes requests through the inbound API pipeline without external HTTP traffic.
 * When Safe Mode is enabled, all DML is rolled back.
 *
 * @see API_InboundInvoker_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
public inherited sharing class API_InboundInvoker
{
	/**
	 * @description When a test sets this to true, the invoker throws an exception during the call. This is the only
	 * way a test can reach the invoker's error handling. API_Dispatcher.routeRequest() catches the errors of a
	 * handler itself, so no normal failure reaches this invoker's catch block. The catch block is a safety net for
	 * unexpected platform failures, such as a governor limit or a runtime error while the request is routed.
	 */
	@TestVisible
	private static Boolean forceException = false;

	/**
	 * @description Invokes an inbound request with optional Safe Mode and custom headers.
	 *
	 * @param path The request URI path
	 * @param method The HTTP method (GET, POST, etc.)
	 * @param body The request body (optional)
	 * @param headers Map of request headers to apply (optional)
	 * @param enableSafeMode When true, all DML is rolled back after execution
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
	public static DTO_InvocationResult invoke(String path, String method, String body, Map<String, String> headers, Boolean enableSafeMode)
	{
		DTO_InvocationResult dtoInvocationResult = new DTO_InvocationResult();
		dtoInvocationResult.safeModeEnabled = enableSafeMode;

		API_Base.SafeModeContext safeMode = null;

		try
		{
			if(enableSafeMode)
			{
				safeMode = API_Base.enterSafeMode();
			}

			RestContext.request = new RestRequest();
			RestContext.request.requestURI = path;
			RestContext.request.httpMethod = method;
			if(String.isNotBlank(body))
			{
				RestContext.request.requestBody = Blob.valueOf(body);
			}

			if(headers != null)
			{
				for(String headerName : headers.keySet())
				{
					RestContext.request.addHeader(headerName, headers.get(headerName));
				}
			}

			RestContext.response = new RestResponse();

			if(forceException)
			{
				throw new UTIL_Exceptions.IllegalStateException('Forced test exception');
			}

			API_Base handler = API_Dispatcher.routeRequest();

			dtoInvocationResult.statusCode = RestContext.response.statusCode;
			dtoInvocationResult.responseBody = RestContext.response.responseBody?.toString();
			dtoInvocationResult.requestBody = body;
			if(RestContext.request?.headers.isEmpty() == false)
			{
				dtoInvocationResult.requestHeaders = new DTO_NameValues(RestContext.request.headers);
			}
			if(RestContext.response?.headers.isEmpty() == false)
			{
				dtoInvocationResult.responseHeaders = new DTO_NameValues(RestContext.response.headers);
			}

			if(handler != null)
			{
				dtoInvocationResult.errorText = handler.errorText;
				dtoInvocationResult.executionTimeMs = handler.fullProcessingTime.getTime();
				dtoInvocationResult.isMockedResponse = handler.result.isMocked;

				dtoInvocationResult.handlerDurationMs = handler.serviceProcessingTime.getTime() - handler.calloutProcessingTime.getTime();
				dtoInvocationResult.calloutDurationMs = handler.calloutProcessingTime.getTime();
				dtoInvocationResult.commitDurationMs = handler.commitProcessingTime.getTime();

				if(handler.apiCall != null)
				{
					ApiCall__c log = handler.apiCall;
					dtoInvocationResult.serviceName = log.ServiceName__c;
					dtoInvocationResult.status = log.Status__c;
					dtoInvocationResult.httpMethod = log.HttpMethod__c;
					dtoInvocationResult.url = log.URL__c;
				}
			}
		}
		catch(Exception invocationError)
		{
			dtoInvocationResult.statusCode = API_Base.HTTP_INTERNAL_SERVER_ERROR;
			dtoInvocationResult.errors.add(invocationError.getMessage());
			dtoInvocationResult.errors.add(invocationError.getStackTraceString());
			dtoInvocationResult.errorText = String.join(dtoInvocationResult.errors, UTIL_String.LF);
			LOG_Builder.build().error(invocationError).emitAt(API_InboundInvoker.class.getName() + '.invoke');
		}
		finally
		{
			safeMode?.close();
		}

		return dtoInvocationResult;
	}

	/**
	 * @description Invokes an inbound request with optional Safe Mode (no custom headers).
	 *
	 * @param path The request URI path
	 * @param method The HTTP method (GET, POST, etc.)
	 * @param body The request body (optional)
	 * @param enableSafeMode When true, all DML is rolled back after execution
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	public static DTO_InvocationResult invoke(String path, String method, String body, Boolean enableSafeMode)
	{
		return invoke(path, method, body, null, enableSafeMode);
	}

	/**
	 * @description Invokes an inbound request with Safe Mode enabled by default.
	 *
	 * @param path The request URI path
	 * @param method The HTTP method
	 * @param body The request body
	 *
	 * @return DTO_InvocationResult
	 */
	public static DTO_InvocationResult invoke(String path, String method, String body)
	{
		return invoke(path, method, body, null, true);
	}

	/**
	 * @description Invokes an inbound API by service class name with optional mocking.
	 * Resolves the endpoint path and HTTP method from ApiSetting__mdt, enabling
	 * service discovery without requiring callers to know URL paths.
	 *
	 * @param serviceName The API handler class name (e.g., 'API_Echo')
	 * @param body The request body (optional)
	 * @param enableSafeMode When true, all DML is rolled back
	 * @param enableMocking When true, enables transaction-scoped mocking
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	public static DTO_InvocationResult invokeByServiceName(String serviceName, String body, Boolean enableSafeMode, Boolean enableMocking)
	{
		ApiSetting__mdt setting = new SEL_ApiSetting().findByClassName(serviceName);

		if(setting == null)
		{
			DTO_InvocationResult errorResult = new DTO_InvocationResult();
			errorResult.statusCode = API_Base.HTTP_NOT_FOUND;
			errorResult.errors.add('No ApiSetting__mdt found for service: ' + serviceName);
			errorResult.errorText = errorResult.errors.iterator().next();
			return errorResult;
		}

		if(enableMocking)
		{
			API_MockFactory.enableMocking(serviceName);
		}

		String path = toConcreteEndpointPath(setting.EndpointPath__c);

		DTO_InvocationResult invocationResult = invoke(path, null, body, null, enableSafeMode);
		invocationResult.mockingEnabled = enableMocking;
		return invocationResult;
	}

	/**
	 * @description Converts an endpoint pattern (e.g. '/echo/*') to a concrete
	 * routable path (e.g. '/echo/test') by replacing wildcard segments with 'test'.
	 *
	 * @param endpointPattern The pattern from ApiSetting__mdt EndpointPath__c
	 *
	 * @return A concrete path suitable for route matching
	 */
	@TestVisible
	private static String toConcreteEndpointPath(String endpointPattern)
	{
		if(String.isBlank(endpointPattern))
		{
			return '/test';
		}
		return endpointPattern.replace('/*', '/test').replace('*', 'test');
	}

	/**
	 * @description Replays a failed inbound request from ApiIssue__c. The issue keeps no headers, so the replay guesses
	 * the content type from the body's first character. A body that starts with { or [ is sent as JSON, the only encoding
	 * the inbound base class reads into the handler's request; a handler that reads the raw body therefore gets a JSON
	 * body parsed first, and a body that is not valid JSON ends the call Aborted, as a live call with that content type
	 * would. Any other body (blank, XML, plain text) is sent with no headers, as before, so a handler that reads the raw
	 * body gets it unchanged.
	 *
	 * @param failureId The ID of the ApiIssue__c record
	 * @param enableSafeMode When true, replay with rollback
	 *
	 * @return DTO_InvocationResult
	 */
	public static DTO_InvocationResult replay(Id failureId, Boolean enableSafeMode)
	{
		ApiIssue__c failure = (ApiIssue__c)new SEL_ApiIssue().findById(failureId);

		if(failure == null)
		{
			DTO_InvocationResult errorResult = new DTO_InvocationResult();
			errorResult.statusCode = API_Base.HTTP_NOT_FOUND;
			errorResult.errors.add('Failure record not found: ' + failureId);
			errorResult.errorText = errorResult.errors.iterator().next();
			return errorResult;
		}

		Map<String, String> headers = isJsonShaped(failure.RequestBody__c)
				? new Map<String, String> {API_Base.HTTP_CONTENT_TYPE => API_Base.HTTP_ENCODING_JSON}
				: null;
		return invoke(failure.RequestPath__c, failure.RequestMethod__c, failure.RequestBody__c, headers, enableSafeMode);
	}

	/**
	 * @description Checks whether a stored body looks like JSON: after whitespace is removed from both ends, it starts with
	 * { or [. The issue keeps no headers, so this first character is the only sign of the body's encoding.
	 *
	 * @param body The stored request body
	 *
	 * @return True when the body starts with { or [, false for a blank body or any other text
	 */
	private static Boolean isJsonShaped(String body)
	{
		String trimmedBody = body?.trim() ?? UTIL_String.EMPTY;
		return trimmedBody.startsWith('{') || trimmedBody.startsWith('[');
	}

	/**
	 * @description Replays a failed inbound request with Safe Mode enabled.
	 *
	 * @param failureId The ID of the ApiIssue__c record
	 *
	 * @return DTO_InvocationResult
	 */
	public static DTO_InvocationResult replay(Id failureId)
	{
		return replay(failureId, true);
	}
}