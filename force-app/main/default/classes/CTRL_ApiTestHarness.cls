// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller for the API Test Harness LWC. Provides service discovery
 * and invocation methods for testing inbound and outbound APIs with Safe Mode
 * and mocking control.
 *
 * @see API_Outbound
 * @see CTRL_ApiTestHarness_TEST
 * @see LOG_Builder
 * @see LOG_Engine
 * @see UTIL_System
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, October 2026
 */
public inherited sharing class CTRL_ApiTestHarness
{
	/**
	 * @description Class name for log source attribution on the service description endpoint.
	 */
	private static final String CLASS_NAME = CTRL_ApiTestHarness.class.getName();

	/**
	 * @description Returns active API services filtered by direction for combobox population.
	 *
	 * @param direction The direction to filter by (Inbound or Outbound)
	 *
	 * @return List of service options with label and value
	 */
	@AuraEnabled(cacheable=true)
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
	 * @description Describes what an outbound service declares before the administrator executes it: the required
	 * input names (from the service's `getRequiredInputs()` override) and whether a triggering record Id is required
	 * (from `requiresTriggeringRecord` after `configure()`). The harness seeds its form from this. A blank, unknown,
	 * non-outbound or failing class name yields an empty description rather than an error, so a misconfigured
	 * ApiSetting__mdt never blocks the form; the cause is logged at DEBUG. Instantiating the service runs its
	 * `configure()`, which registers a webservice logging context; that context is cleared before returning.
	 *
	 * @param className The outbound service class name from ApiSetting__mdt.ClassName__c
	 *
	 * @return The declared inputs and record requirement, never null
	 */
	@AuraEnabled(cacheable=true)
	public static DTO_ServiceDescription describeService(String className)
	{
		DTO_ServiceDescription description = new DTO_ServiceDescription();
		if(String.isBlank(className))
		{
			return description;
		}

		API_Outbound service;
		try
		{
			service = (API_Outbound)UTIL_System.getTypeForClassName(className, API_Outbound.class).newInstance();
			List<String> requiredNames = new List<String>(service.describeRequiredInputs());
			requiredNames.sort();
			for(String requiredName : requiredNames)
			{
				DTO_InputDescription input = new DTO_InputDescription();
				input.name = requiredName;
				input.isRequired = true;
				description.inputs.add(input);
			}
			description.requiresTriggeringRecord = service.isTriggeringRecordRequired();
		}
		catch(Exception describeFailure)
		{
			LOG_Builder.build().debug('Service could not be described: ' + className + ' (' + describeFailure.getMessage() + ')').at(CLASS_NAME + '.describeService').emit();
			description = new DTO_ServiceDescription();
		}
		finally
		{
			if(service != null)
			{
				LOG_Engine.clearWebserviceContext(service.correlationId);
			}
		}

		return description;
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
	 * @description Maps an invocation result to the controller DTO, serialising the headers for the LWC with every
	 * credential value redacted (API_Base.redactCredentialHeaders), so neither the page, its copy actions, nor the
	 * Aura payload carries a token or cookie.
	 *
	 * @param invocationResult The invocation result from either invoker
	 *
	 * @return Mapped DTO_TestResult
	 */
	private static DTO_TestResult mapResult(DTO_InvocationResult invocationResult)
	{
		DTO_TestResult dtoTestResult = new DTO_TestResult();
		DTO_NameValues requestHeaders = API_Base.redactCredentialHeaders(invocationResult.requestHeaders);
		DTO_NameValues responseHeaders = API_Base.redactCredentialHeaders(invocationResult.responseHeaders);

		dtoTestResult.apiCallId = invocationResult.apiCallId;
		dtoTestResult.errorMessages = invocationResult.errorText;
		dtoTestResult.executionTimeMs = invocationResult.executionTimeMs;
		dtoTestResult.isMockedResponse = invocationResult.isMockedResponse;
		dtoTestResult.isSuccess = invocationResult.success;
		dtoTestResult.mockingEnabled = invocationResult.mockingEnabled;
		dtoTestResult.requestBody = invocationResult.requestBody;
		dtoTestResult.requestHeaders = requestHeaders.isEmpty() ? dtoTestResult.requestHeaders : requestHeaders.serialize();
		dtoTestResult.responseBody = invocationResult.responseBody;
		dtoTestResult.responseHeaders = responseHeaders.isEmpty() ? dtoTestResult.responseHeaders : responseHeaders.serialize();
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
	 * @description What an outbound service declares about its inputs, shaped for the harness form. Inputs are
	 * descriptors rather than names so later attributes (type, description, sensitivity) are additive.
	 */
	public class DTO_ServiceDescription
	{
		/**
		 * @description The declared inputs, sorted by name, never null. Today every entry is required.
		 */
		@AuraEnabled
		public List<DTO_InputDescription> inputs = new List<DTO_InputDescription>();

		/**
		 * @description Whether a triggering record Id must accompany the call.
		 */
		@AuraEnabled
		public Boolean requiresTriggeringRecord = false;
	}

	/**
	 * @description One declared input of an outbound service.
	 */
	public class DTO_InputDescription
	{
		/**
		 * @description The input name the service reads from its parameters.
		 */
		@AuraEnabled
		public String name;

		/**
		 * @description Whether the service refuses to run without a non-blank value.
		 */
		@AuraEnabled
		public Boolean isRequired = false;
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
		 * @description The name of the service the harness ran, as the inbound or outbound invoker reports it back.
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
		 * @description JSON-serialized request headers; credential header values are redacted.
		 */
		@AuraEnabled
		public String requestHeaders;

		/**
		 * @description JSON-serialized response headers; credential header values are redacted.
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