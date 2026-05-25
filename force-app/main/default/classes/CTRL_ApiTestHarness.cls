// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller for the API Test Harness LWC. Provides service discovery
 * and invocation methods for testing inbound and outbound APIs with Safe Mode
 * and mocking control.
 *
 * @see CTRL_ApiTestHarness_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 */
public inherited sharing class CTRL_ApiTestHarness
{
	/**
	 * @description Returns active API services filtered by direction for combobox population.
	 *
	 * @param direction The direction to filter by (Inbound or Outbound)
	 *
	 * @return List of service options with label and value
	 */
	@AuraEnabled(Cacheable=true)
	public static List<DTO_ServiceOption> getServices(String direction)
	{
		List<DTO_ServiceOption> options = new List<DTO_ServiceOption>();

		for(ApiSetting__mdt setting : new SEL_ApiSetting().findActiveByDirection(direction))
		{
			DTO_ServiceOption option = new DTO_ServiceOption();

			option.label = setting.MasterLabel;
			option.value = setting.ClassName__c;

			options.add(option);
		}

		return options;
	}

	/**
	 * @description Invokes an outbound API call through the test harness.
	 *
	 * @param requestJson JSON-serialized DTO_Request containing the service name, record Id, parameters, and execution flags.
	 *                    The string-over-typed-DTO shape avoids the LWC Proxy wrapping issue that corrupts complex DTO
	 *                    parameters in Aura deserialization (see CTRL_ScheduledJob.saveRecord for the canonical pattern).
	 *
	 * @return DTO_TestResult containing response and execution details
	 */
	@AuraEnabled
	public static DTO_TestResult invokeOutbound(String requestJson)
	{
		DTO_Request request = parseRequest(requestJson);

		Map<String, String> parameterMap = new Map<String, String>();

		if(request.parameters != null)
		{
			for(DTO_NameValue parameter : request.parameters)
			{
				if(String.isNotBlank(parameter.name))
				{
					parameterMap.put(parameter.name, parameter.value);
				}
			}
		}

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(request.serviceName, request.recordId, parameterMap, request.enableSafeMode, request.enableMocking);

		return mapResult(invocationResult);
	}

	/**
	 * @description Invokes an inbound API call through the test harness.
	 *
	 * @param requestJson JSON-serialized DTO_Request containing the service name, JSON body, and execution flags.
	 *
	 * @return DTO_TestResult containing response and execution details
	 */
	@AuraEnabled
	public static DTO_TestResult invokeInbound(String requestJson)
	{
		DTO_Request request = parseRequest(requestJson);

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invokeByServiceName(request.serviceName, request.jsonBody, request.enableSafeMode, request.enableMocking);

		return mapResult(invocationResult);
	}

	/**
	 * @description Deserialises the request JSON string into a DTO_Request, returning
	 * an empty request if the string is blank so callers can rely on non-null fields.
	 *
	 * @param requestJson The JSON payload from the LWC
	 *
	 * @return A populated DTO_Request
	 */
	private static DTO_Request parseRequest(String requestJson)
	{
		if(String.isBlank(requestJson))
		{
			return new DTO_Request();
		}
		return (DTO_Request)JSON.deserialize(requestJson, DTO_Request.class);
	}

	/**
	 * @description Maps an invocation result to the controller DTO, serializing headers for the LWC.
	 *
	 * @param invocationResult The invocation result from either invoker
	 *
	 * @return Mapped DTO_TestResult
	 */
	private static DTO_TestResult mapResult(DTO_InvocationResult invocationResult)
	{
		DTO_TestResult dtoTestResult = new DTO_TestResult();

		dtoTestResult.apiCallId = invocationResult.apiCallId;
		dtoTestResult.errorMessages = invocationResult.errorText;
		dtoTestResult.executionTimeMs = invocationResult.executionTimeMs;
		dtoTestResult.isMockedResponse = invocationResult.isMockedResponse;
		dtoTestResult.isSuccess = invocationResult.success;
		dtoTestResult.mockingEnabled = invocationResult.mockingEnabled;
		dtoTestResult.requestBody = invocationResult.requestBody;
		dtoTestResult.requestHeaders = invocationResult.requestHeaders.isEmpty() ? dtoTestResult.requestHeaders : invocationResult.requestHeaders.serialize();
		dtoTestResult.responseBody = invocationResult.responseBody;
		dtoTestResult.responseHeaders = invocationResult.responseHeaders.isEmpty() ? dtoTestResult.responseHeaders : invocationResult.responseHeaders.serialize();
		dtoTestResult.safeModeEnabled = invocationResult.safeModeEnabled;
		dtoTestResult.serviceName = invocationResult.serviceName;
		dtoTestResult.status = invocationResult.status;
		dtoTestResult.statusCode = invocationResult.statusCode;
		dtoTestResult.handlerDurationMs = invocationResult.handlerDurationMs;
		dtoTestResult.calloutDurationMs = invocationResult.calloutDurationMs;
		dtoTestResult.commitDurationMs = invocationResult.commitDurationMs;

		return dtoTestResult;
	}

	/**
	 * @description Unified request DTO for inbound and outbound invocations.
	 * The LWC serialises this shape to JSON and sends it as a single String parameter
	 * to avoid LWC Proxy wrapping issues with typed DTO parameters (see
	 * CTRL_ScheduledJob.saveRecord for the canonical pattern).
	 */
	public class DTO_Request
	{
		/**
		 * @description The API handler class name to invoke.
		 */
		@AuraEnabled
		public String serviceName;

		/**
		 * @description The triggering record Id for outbound invocations. Ignored for inbound.
		 */
		@AuraEnabled
		public String recordId;

		/**
		 * @description Outbound parameter name-value pairs. Ignored for inbound.
		 */
		@AuraEnabled
		public List<DTO_NameValue> parameters;

		/**
		 * @description JSON request body for inbound invocations. Ignored for outbound.
		 */
		@AuraEnabled
		public String jsonBody;

		/**
		 * @description When true, all DML is rolled back via a savepoint.
		 */
		@AuraEnabled
		public Boolean enableSafeMode;

		/**
		 * @description When true, enables transaction-scoped response mocking.
		 */
		@AuraEnabled
		public Boolean enableMocking;
	}

	/**
	 * @description Service option for combobox display.
	 */
	public class DTO_ServiceOption
	{
		/**
		 * @description Display label for the service.
		 */
		@AuraEnabled
		public String label;

		/**
		 * @description Class name value for the service.
		 */
		@AuraEnabled
		public String value;
	}

	/**
	 * @description Unified test result DTO for both inbound and outbound invocations.
	 */
	public class DTO_TestResult
	{
		/**
		 * @description HTTP status code of the response.
		 */
		@AuraEnabled
		public Integer statusCode;

		/**
		 * @description Response body content.
		 */
		@AuraEnabled
		public String responseBody;

		/**
		 * @description Original request body.
		 */
		@AuraEnabled
		public String requestBody;

		/**
		 * @description Whether the invocation was successful.
		 */
		@AuraEnabled
		public Boolean isSuccess;

		/**
		 * @description Whether Safe Mode was enabled.
		 */
		@AuraEnabled
		public Boolean safeModeEnabled;

		/**
		 * @description Whether mocking was enabled.
		 */
		@AuraEnabled
		public Boolean mockingEnabled;

		/**
		 * @description Whether the response was mocked.
		 */
		@AuraEnabled
		public Boolean isMockedResponse;

		/**
		 * @description Total execution time in milliseconds.
		 */
		@AuraEnabled
		public Long executionTimeMs;

		/**
		 * @description Error messages if invocation failed.
		 */
		@AuraEnabled
		public String errorMessages;

		/**
		 * @description The service class name.
		 */
		@AuraEnabled
		public String serviceName;

		/**
		 * @description The API call status.
		 */
		@AuraEnabled
		public String status;

		/**
		 * @description The API call record ID.
		 */
		@AuraEnabled
		public String apiCallId;

		/**
		 * @description JSON-serialized request headers.
		 */
		@AuraEnabled
		public String requestHeaders;

		/**
		 * @description JSON-serialized response headers.
		 */
		@AuraEnabled
		public String responseHeaders;

		/**
		 * @description Handler processing time in milliseconds.
		 */
		@AuraEnabled
		public Long handlerDurationMs;

		/**
		 * @description Callout processing time in milliseconds.
		 */
		@AuraEnabled
		public Long calloutDurationMs;

		/**
		 * @description Commit processing time in milliseconds.
		 */
		@AuraEnabled
		public Long commitDurationMs;
	}
}