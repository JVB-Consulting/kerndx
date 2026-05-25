// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base class for all inbound REST API web service calls.
 * Provides foundational functionality for handling incoming HTTP requests,
 * processing them, parsing request/response DTOs, and sending appropriate responses.
 *
 * @see API_Echo_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * @RestResource(urlMapping='/api/echo/*')
 * global with sharing class API_Echo
 * {
 *     @HttpPost
 *     global static void doPost()
 *     {
 *         new EchoHandler().execute();
 *     }
 *     private class EchoHandler extends API_Inbound
 *     {
 *         global override void processRequest()
 *         {
 *             // handle the request
 *         }
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity')
global virtual inherited sharing class API_Inbound extends API_Base
{
	/**
	 * @description Feature flag name for disabling all inbound API calls.
	 */
	@TestVisible
	private static final String FLAG_DISABLE_ALL_INBOUND_APIS = 'DisableAllInboundAPIs';

	/**
	 * @description Error message used to test exception handling in inbound APIs.
	 */
	@TestVisible
	private static final String ERROR_TEST_EXCEPTION_HANDLING = 'This is an error to test exception handling';

	/**
	 * @description Set this static variable to true to generate an exception during unit test to test exception handling behaviour for inbound APIs.
	 */
	@TestVisible
	private static Boolean returnErrorResponse = false;

	/**
	 * @description The idempotency key extracted from the inbound request header.
	 */
	private String idempotencyKey;

	/**
	 * @description Whether this request was an idempotency duplicate that returned a cached response.
	 */
	private Boolean isIdempotencyHit = false;

	/**
	 * @description The DTO that will be populated from the inbound request body.
	 * Handles the request data in JSON format and ensures proper initialization and deserialization.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void configure()
	 * {
	 *     super.configure();
	 *     requestPayload = new DTO_Request();
	 * }
	 * ```
	 */
	global protected DTO_JsonBase requestPayload
	{
		get
		{
			if(requestPayload == null)
			{
				requestPayload = new DTO_JsonBase();
			}

			return requestPayload;
		}
		set;
	}

	/**
	 * @description The DTO that will be serialized to populate the response body.
	 * Handles the response data in JSON format and ensures proper initialization and serialization.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void configure()
	 * {
	 *     super.configure();
	 *     responsePayload = new DTO_Response();
	 * }
	 * ```
	 */
	global protected DTO_JsonBase responsePayload
	{
		get
		{
			if(responsePayload == null)
			{
				responsePayload = new DTO_JsonBase();
			}

			return responsePayload;
		}
		set;
	}

	/**
	 * @description Reference to the current inbound REST request. Provides access to the details of the incoming request,
	 * such as headers, parameters, and the request body.
	 *
	 * @see RestRequest
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String headerValue = request.headers.get('X-Custom-Header');
	 * ```
	 */
	global protected RestRequest request
	{
		get
		{
			return RestContext.request;
		}
	}

	/**
	 * @description Reference to the current REST response object. Allows manipulation of the response that will be sent
	 * back to the client, including setting the response body and status code.
	 *
	 * @see RestResponse
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * response.statusCode = 200;
	 * ```
	 */
	global protected RestResponse response
	{
		get
		{
			return RestContext.response;
		}
	}

	/**
	 * @description Returns the request body from the current inbound HTTP request.
	 * If the request body is null or empty, it returns an empty string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String body = requestBody;
	 * ```
	 */
	global protected String requestBody
	{
		get
		{
			return request.requestBody == null || request.requestBody.size() == 0 ? UTIL_String.EMPTY : request.requestBody.toString();
		}
	}

	/**
	 * @description Manages the response body that will be sent to the client.
	 * Ensures that the value is stored as a Blob in the response object.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * responseBody = JSON.serialize(result);
	 * ```
	 */
	global protected String responseBody
	{
		get
		{
			return response.responseBody == null || response.responseBody.size() == 0 ? UTIL_String.EMPTY : response.responseBody.toString();
		}
		set
		{
			response.responseBody = Blob.valueOf(value);
		}
	}

	/**
	 * @description Constructor. Initializes the object and parses the inbound request body.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Called automatically when the REST endpoint is invoked
	 * private class MyHandler extends API_Inbound { }
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration,RedundantSuppression')
	global API_Inbound()
	{
		super();
		parseRequest();
	}

	/**
	 * @description Checks custom settings to determine if the API has been disabled for the current user.
	 *
	 * @return True if the API is disabled, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override Boolean isDisabled()
	 * {
	 *     return super.isDisabled() || customDisableCheck();
	 * }
	 * ```
	 */
	global protected override Boolean isDisabled()
	{
		return super.isDisabled() || UTIL_FeatureFlag.isEnabled(FLAG_DISABLE_ALL_INBOUND_APIS);
	}

	/**
	 * @description Retrieves the HTTP method of the current inbound request.
	 *
	 * @return The HTTP method of the current request.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * HttpMethod method = getHttpMethod(); // Returns the inbound request's HTTP method
	 * ```
	 */
	global protected override HttpMethod getHttpMethod()
	{
		return fromHttpString(request?.httpMethod);
	}

	/**
	 * @description Retrieves the HTTP character encoding for the request.
	 *
	 * @return The content type header from the incoming request.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override String getEncoding()
	 * {
	 *     return 'application/xml';
	 * }
	 * ```
	 */
	global protected override virtual String getEncoding()
	{
		return request.headers.get(HTTP_CONTENT_TYPE);
	}

	/**
	 * @description Initializes class variables and sets up request details including headers and URL parameters.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void configure()
	 * {
	 *     super.configure();
	 *     requestPayload = new DTO_Request();
	 *     responsePayload = new DTO_Response();
	 * }
	 * ```
	 */
	global protected override virtual void configure()
	{
		super.configure();

		result.requestBody = requestBody;
		result.url = buildRequestUrl();

		response.addHeader(HTTP_CONTENT_TYPE, HTTP_ENCODING_JSON);
		response.addHeader(HTTP_HEADER_RFC_7230_CHECK, 'enabled');
	}

	/**
	 * @description Builds the full request URL from the REST context, including any query parameters.
	 * Query parameters are also registered in the inputs DTO for downstream access.
	 *
	 * @return The request URI with query string appended, or just the URI when no parameters are present.
	 */
	private String buildRequestUrl()
	{
		Map<String, String> parameterMap = request.params;
		if(parameterMap.isEmpty())
		{
			return request.requestURI;
		}

		List<String> parameterPairs = new List<String>();
		for(String key : parameterMap.keySet())
		{
			String value = parameterMap.get(key);
			inputs.add(key, value);
			parameterPairs.add(key + UTIL_String.EQUALS + value);
		}
		return request.requestURI + UTIL_String.QUESTION_MARK + String.join(parameterPairs, UTIL_String.AMPERSAND);
	}

	/**
	 * @description Parses the inbound request body and populates the requestPayload with deserialized JSON data.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void parseRequest()
	 * {
	 *     super.parseRequest();
	 *     // additional request parsing
	 * }
	 * ```
	 */
	global protected virtual void parseRequest()
	{
		String requestBody = requestBody;
		Boolean mustParseRequest = requestPayload != null && String.isNotBlank(requestBody) && getEncoding()?.containsIgnoreCase(HTTP_ENCODING_JSON) == true;
		requestPayload = mustParseRequest ? (DTO_JsonBase)requestPayload.deserialize(requestBody) : requestPayload;
	}

	/**
	 * @description Registers database changes after a successful call.
	 * Simulates an error for testing if `returnErrorResponse` is set.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onSuccess()
	 * {
	 *     super.onSuccess();
	 *     doInsert(newRecord);
	 * }
	 * ```
	 */
	global protected override virtual void onSuccess()
	{
		super.onSuccess();

		if(returnErrorResponse)
		{
			NullPointerException error = new NullPointerException();
			error.setMessage(ERROR_TEST_EXCEPTION_HANDLING);
			throw error;
		}
	}

	/**
	 * @description Handles the processing of the received request.
	 * Implement in descendant classes to define specific logic for handling API endpoints.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void processRequest()
	 * {
	 *     DTO_Request dto = (DTO_Request)requestPayload;
	 *     // process the inbound request
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global protected virtual void processRequest()
	{
	}

	/**
	 * @description Updates the results of the call, such as status and response body.
	 * Override in descendant classes to implement specific update logic.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void updateCallResult()
	 * {
	 *     super.updateCallResult();
	 *     // customize the response body
	 * }
	 * ```
	 */
	global protected virtual void updateCallResult()
	{
		result.responseBody = responsePayload?.serialize() ?? result.responseBody;
	}

	/**
	 * @description Updates the response DTO with relevant information before the response is sent.
	 * Override in inheriting classes to customize the response body data.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void updateResponseDTO()
	 * {
	 *     DTO_Response dto = (DTO_Response)responsePayload;
	 *     dto.recordId = newRecord.Id;
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global protected virtual void updateResponseDTO()
	{
	}

	/**
	 * @description Writes the response to the client based on the call result.
	 * Override to modify the response written to the client.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void writeResponse()
	 * {
	 *     super.writeResponse();
	 *     // customize response writing
	 * }
	 * ```
	 */
	global protected virtual void writeResponse()
	{
		if(result.isSuccess)
		{
			if(String.isBlank(result.statusCode))
			{
				result.statusCode = String.valueOf(API_Base.HTTP_OK);
			}
			if(String.isNotBlank(result.responseBody))
			{
				responseBody = result.responseBody;
			}
		}
		else if(!result.errors.isEmpty())
		{
			String serialisedErrors = JSON.serializePretty(result.errors, true);
			responseBody = serialisedErrors;
			result.responseBody = serialisedErrors;
		}

		response.statusCode = Integer.valueOf(result.statusCode);
	}

	/**
	 * @description Handles exceptions during request processing, setting appropriate status codes and writing the response.
	 *
	 * @param error The exception that needs to be managed.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void handleError(Exception error)
	 * {
	 *     super.handleError(error);
	 *     // custom error handling
	 * }
	 * ```
	 */
	global protected override virtual void handleError(Exception error)
	{
		super.handleError(error);

		Boolean isDMLException = error instanceof DmlException;
		Integer statusCode = isDMLException ? API_Base.HTTP_INTERNAL_SERVER_ERROR : API_Base.HTTP_BAD_REQUEST;

		result.statusCode = String.valueOf(statusCode);
		writeResponse();
	}

	/**
	 * @description Manages the inbound request and logs the result of the call.
	 * Processes the request and determines whether to complete or abort it.
	 *
	 * @param apiCall The apiCall that will record the activity of the web service object.
	 *
	 * @example
	 * ```apex
	 * global override void process(ApiCall__c apiCall)
	 * {
	 *     super.process(apiCall);
	 *     // custom processing
	 * }
	 * ```
	 */
	public override virtual void process(ApiCall__c apiCall)
	{
		super.process(apiCall);
		extractTraceContext();
		LOG_Builder.setCorrelationId(currentOrNewTraceContext().traceId);

		if(checkIdempotency())
		{
			setApiCallDetails();
			return;
		}

		if(shouldMock())
		{
			applyMockResult(API_MockFactory.getInboundMock(getServiceName(), setting?.DeveloperName, result.requestBody));
			return;
		}

		if(performValidation())
		{
			result.isAborted = true;
			result.statusCode = String.valueOf(API_Base.HTTP_BAD_REQUEST);
			updateCallResult();
			writeResponse();
			setApiCallDetails();
			return;
		}

		result.isSuccess = true;
		processRequest();
		onSuccess();
	}

	/**
	 * @description Applies a mock response to the REST context and result, falling back to a
	 * default mock when no factory mock is registered for this service.
	 *
	 * @param mock The mock response from the factory, or null to use a default.
	 */
	private void applyMockResult(API_MockFactory.MockResponse mock)
	{
		if(mock == null)
		{
			mock = new API_MockFactory.MockResponse();
			mock.body = '{"mocked":true,"message":"No mock response configured - using default"}';
		}

		response.statusCode = mock.statusCode;
		response.responseBody = Blob.valueOf(mock.body ?? '');
		result.isMocked = true;
		result.isSuccess = true;
		result.statusCode = String.valueOf(mock.statusCode);
		result.responseBody = mock.body;
		setApiCallDetails();
	}

	/**
	 * @description Performs actions before committing changes to the database.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onCommitWorkStarting()
	 * {
	 *     super.onCommitWorkStarting();
	 *     // pre-commit logic
	 * }
	 * ```
	 */
	global override virtual void onCommitWorkStarting()
	{
		super.onCommitWorkStarting();

		if(result.isSuccess)
		{
			// Ensure that the API call is correctly populated from the call result
			setApiCallDetails();
		}
	}

	/**
	 * @description Performs actions after a commit is completed, such as setting the response and updating the API call.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onCommitWorkFinishing()
	 * {
	 *     super.onCommitWorkFinishing();
	 *     // post-commit logic
	 * }
	 * ```
	 */
	global override virtual void onCommitWorkFinishing()
	{
		super.onCommitWorkFinishing();

		if(result.isMocked == true || isIdempotencyHit)
		{
			return;
		}

		// Ensure that if our response object needs committed data info, it can be updated here
		updateResponseDTO();

		if(result.isSuccess)
		{
			// Set the response object with outcome of the call
			updateCallResult();

			// Ensure we update the Http response appropriately based on call result
			writeResponse();

			// Update the API call record with result of the call so this can be logged.
			// This is done again as the response might have been altered with information that was committed
			setApiCallDetails();
		}

		clearTraceContext();
	}

	/**
	 * @description Extracts the W3C trace context from the incoming Trace Parent header.
	 * If no valid header is present, generates a new trace context for this request.
	 */
	private void extractTraceContext()
	{
		String traceParentHeader = request.headers.get(API_Base.HEADER_TRACE_PARENT);

		if(String.isNotBlank(traceParentHeader))
		{
			parseTraceParentHeader(traceParentHeader);
		}
		else
		{
			generateTraceContext();
		}
	}

	/**
	 * @description Checks for an idempotency key in the request headers.
	 * Idempotency ensures that processing the same request multiple times produces the same
	 * result as processing it once — preventing issues like duplicate charges or duplicate
	 * record creation. When enabled, the framework queries the ApiCall__c External ID index
	 * for a previous completed call with the same key. If found, the new request body's
	 * SHA-256 hash is compared against the original call's `IdempotencyKeyBodyHash__c`:
	 *
	 * - If the hashes match (or the original record predates the body-hash field), the
	 *   cached response is returned with HTTP 200 — the standard idempotent-replay path.
	 * - If the hashes differ, the framework returns HTTP 409 with a JSON body containing
	 *   the original `ApiCall__c.Id`. This surfaces the contract violation that would
	 *   otherwise silently mask divergent input under the same idempotency key.
	 *
	 * @return True if the request is a duplicate and a response was written (200 cached or 409 conflict)
	 */
	private Boolean checkIdempotency()
	{
		idempotencyKey = request.headers.get(API_Base.HEADER_IDEMPOTENCY_KEY);

		if(String.isBlank(idempotencyKey) || setting?.IdempotencyEnabled__c != true)
		{
			return false;
		}

		ApiCall__c existing = new SEL_ApiCall().findCompletedByIdempotencyKey(idempotencyKey);

		if(existing == null)
		{
			return false;
		}

		String requestBodyHash = computeBodyHash(result.requestBody);
		String existingBodyHash = existing.IdempotencyKeyBodyHash__c;

		if(String.isNotBlank(existingBodyHash) && existingBodyHash != requestBodyHash)
		{
			String conflictBody = JSON.serialize(new Map<String, Object>
			{
					'error' => 'Idempotency-Key reused with different request body',
					'originalApiCallId' => existing.Id
			});
			response.statusCode = HTTP_CONFLICT;
			response.responseBody = Blob.valueOf(conflictBody);
			result.isAborted = true;
			result.statusCode = String.valueOf(HTTP_CONFLICT);
			result.responseBody = conflictBody;
			isIdempotencyHit = true;
			return true;
		}

		response.statusCode = HTTP_OK;
		response.responseBody = Blob.valueOf(existing.Response__c ?? '');
		result.isSuccess = true;
		result.statusCode = String.valueOf(HTTP_OK);
		result.responseBody = existing.Response__c;
		isIdempotencyHit = true;
		return true;
	}

	/**
	 * @description Computes the SHA-256 hex digest of the inbound request body, used to detect
	 * Idempotency-Key reuse with divergent bodies. A null input is normalised to the empty string
	 * so callers always receive a deterministic 64-character hex digest — same-blank-body replays
	 * compare equal, and the `IdempotencyKeyBodyHash__c` field is non-null for every A5-era record
	 * (null on that field unambiguously means "legacy pre-A5 record").
	 *
	 * @param body The raw request body (typically `result.requestBody`).
	 *
	 * @return The 64-character hex SHA-256 digest of the body, or of the empty string when body is null.
	 */
	private static String computeBodyHash(String body)
	{
		return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(body == null ? '' : body)));
	}

	/**
	 * @description Updates the API call record with the idempotency key and body-hash fingerprint.
	 */
	public override void setApiCallDetails()
	{
		super.setApiCallDetails();

		if(String.isNotBlank(idempotencyKey))
		{
			apiCall.IdempotencyKey__c = idempotencyKey;
			apiCall.IdempotencyKeyBodyHash__c = computeBodyHash(result.requestBody);
		}

		apiCall.IsIdempotencyHit__c = isIdempotencyHit;
	}

	/**
	 * @description Determines whether mock injection should be applied for this inbound request.
	 * Checks two sources in priority order: per-service setting checkbox, global feature switch.
	 *
	 * @return True if mocking should be applied
	 */
	private Boolean shouldMock()
	{
		return API_MockFactory.isMockingEnabled(getServiceName()) ||
				setting?.MockingEnabled__c == true ||
				UTIL_FeatureFlag.isEnabled('MockAllInboundAPIs');
	}

}