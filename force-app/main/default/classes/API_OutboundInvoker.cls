// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Invokes outbound API requests programmatically with Safe Mode and mocking support.
 * Wraps the API pipeline to enable the test harness controller to execute outbound calls
 * with DML rollback and mock response control.
 *
 * @see API_OutboundInvoker_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
public inherited sharing class API_OutboundInvoker
{
	/**
	 * @description Test seam to force an exception during invocation for exercising defensive error handling.
	 * Architectural constraint: API_Dispatcher.execute() catches handler-level exceptions internally,
	 * so no realistic failure scenario can propagate an exception to this invoker's catch block.
	 * The catch block exists as a defensive guard for unexpected platform-level failures (governor limits,
	 * runtime errors in orchestration) and must be tested via this seam.
	 */
	@TestVisible
	private static Boolean forceException = false;

	/**
	 * @description Invokes an outbound API by service class name with full control over Safe Mode and mocking.
	 *
	 * @param serviceName The API handler class name (e.g., 'API_PostExample')
	 * @param recordId The triggering record ID
	 * @param parameters Map of request parameters
	 * @param enableSafeMode When true, all DML is rolled back
	 * @param enableMocking When true, enables transaction-scoped mocking
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static DTO_InvocationResult invoke(String serviceName, String recordId, Map<String, String> parameters, Boolean enableSafeMode, Boolean enableMocking)
	{
		DTO_InvocationResult dtoInvocationResult = new DTO_InvocationResult();

		dtoInvocationResult.mockingEnabled = enableMocking;
		dtoInvocationResult.safeModeEnabled = enableSafeMode;
		dtoInvocationResult.serviceName = serviceName;

		API_Base.SafeModeContext safeMode = null;

		try
		{
			if(enableMocking)
			{
				API_MockFactory.enableMocking(serviceName);
			}

			if(enableSafeMode)
			{
				safeMode = API_Base.enterSafeMode();
			}

			if(forceException)
			{
				throw new UTIL_Exceptions.IllegalStateException('Forced test exception');
			}

			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UTIL_SObject.validateId(recordId), parameters);

			List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});

			if(!handlers.isEmpty())
			{
				API_Base handler = handlers.iterator().next();

				dtoInvocationResult.errorText = handler.errorText;
				dtoInvocationResult.executionTimeMs = handler.fullProcessingTime.getTime();
				dtoInvocationResult.isMockedResponse = handler.result.isMocked;
				dtoInvocationResult.requestBody = handler.result.requestBody;
				dtoInvocationResult.requestHeaders = handler.result.requestHeaders;
				dtoInvocationResult.responseBody = handler.result.responseBody;
				dtoInvocationResult.responseHeaders = handler.result.responseHeaders;
				dtoInvocationResult.statusCode = String.isNotBlank(handler.result.statusCode) ? Integer.valueOf(handler.result.statusCode) : null;

				dtoInvocationResult.handlerDurationMs = handler.serviceProcessingTime.getTime() - handler.calloutProcessingTime.getTime();
				dtoInvocationResult.calloutDurationMs = handler.calloutProcessingTime.getTime();
				dtoInvocationResult.commitDurationMs = handler.commitProcessingTime.getTime();

				if(handler.apiCall != null)
				{
					dtoInvocationResult.apiCallId = handler.apiCall.Id;
					dtoInvocationResult.status = handler.apiCall.Status__c;
				}
			}
		}
		catch(Exception invocationError)
		{
			dtoInvocationResult.errors.add(invocationError.getMessage());
			dtoInvocationResult.errors.add(invocationError.getStackTraceString());
			dtoInvocationResult.errorText = String.join(dtoInvocationResult.errors, UTIL_String.LF);
			LOG_Builder.build().error(invocationError).emitAt(API_OutboundInvoker.class.getName() + '.invoke');
		}
		finally
		{
			safeMode?.close();
		}

		return dtoInvocationResult;
	}

	/**
	 * @description Invokes an outbound API with Safe Mode enabled and mocking disabled.
	 *
	 * @param serviceName The API handler class name
	 * @param recordId The triggering record ID
	 * @param parameters Map of request parameters
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	public static DTO_InvocationResult invoke(String serviceName, String recordId, Map<String, String> parameters)
	{
		return invoke(serviceName, recordId, parameters, true, false);
	}

	/**
	 * @description Invokes an outbound API with Safe Mode enabled, mocking disabled, and no parameters.
	 *
	 * @param serviceName The API handler class name
	 * @param recordId The triggering record ID
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	public static DTO_InvocationResult invoke(String serviceName, String recordId)
	{
		return invoke(serviceName, recordId, new Map<String, String>(), true, false);
	}
}