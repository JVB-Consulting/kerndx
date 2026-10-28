// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base class for all inbound REST API web service calls.
 * Provides foundational functionality for handling incoming HTTP requests,
 * processing them, parsing request/response DTOs, and sending appropriate responses.
 *
 * @see API_Echo_TEST
 * @see API_InboundIssue_TEST
 * @see API_InboundRetryLink_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
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
@SuppressWarnings('PMD.CognitiveComplexity,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength')
global virtual inherited sharing class API_Inbound extends API_Base
{
	/**
	 * @description Feature flag name for disabling all inbound API calls. The checks made before an issue's request is run
	 * again read it too, so a request is not run again while every inbound API is switched off.
	 */
	public static final String FLAG_DISABLE_ALL_INBOUND_APIS = 'DisableAllInboundAPIs';

	/**
	 * @description Feature flag name that mocks every incoming service for the users it is on for. A request signed in as
	 * such a user gets a mock answer, whatever the service's API Setting says. The Health Check reads it too.
	 */
	public static final String FLAG_MOCK_ALL_INBOUND_APIS = 'MockAllInboundAPIs';

	/**
	 * @description Error message used to test exception handling in inbound APIs.
	 */
	@TestVisible
	private static final String ERROR_TEST_EXCEPTION_HANDLING = 'This is an error to test exception handling';

	/**
	 * @description The lowest status code that is not a success: 300, the first redirect status. A success answers with
	 * a status from 200 to 299.
	 */
	private static final Integer HTTP_FIRST_REDIRECT_STATUS = 300;

	/**
	 * @description Where the warnings and errors of the read for an open issue of an earlier call are logged.
	 */
	private static final String LOCATION_FIND_OPEN_ISSUE = API_Inbound.class.getName() + '.hasEarlierAttemptWithAnOpenIssue';

	/**
	 * @description Where the warnings and errors of resolving the issues of earlier calls are logged.
	 */
	private static final String LOCATION_RESOLVE_ISSUES = API_Inbound.class.getName() + '.resolveApiIssues';

	/**
	 * @description The warning logged when no query is left to look for an open issue of an earlier call. The failed
	 * request then writes its own issue.
	 */
	private static final String WARNING_NO_QUERY_TO_FIND_OPEN_ISSUE = 'No query is left to look for an open issue of an earlier call, so the failed request writes its own issue';

	/**
	 * @description The warning logged when no query or no save is left to resolve the issues of earlier calls. Those
	 * issues stay Open.
	 */
	private static final String WARNING_NO_ROOM_TO_RESOLVE_ISSUES = 'No query or save is left to resolve the issues of earlier calls, so they stay open';

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
	 * @description Whether this request reused an Idempotency-Key with a body other than the one the completed call of that
	 * key received. Such a request is refused with status 409, and it writes no issue: the caller sent a different
	 * request under a key that is already used, so there is nothing to run again.
	 */
	private Boolean isKeyReusedWithAnotherBody = false;

	/**
	 * @description Whether this request has an earlier call that did not complete. Two calls are of the same request when
	 * the same user sent them to the same service with the same Idempotency-Key, whatever body each received. The call of
	 * an issue's request run again counts as sent by the user who sent the call it was read from. Only when this is true
	 * does a success look for open issues to mark Resolved (see resolveApiIssues), and a failure look for an open issue
	 * that makes its own issue needless (see createFailureRecord). It stays false for a request with no key, and for a
	 * service that does not have Idempotency Enabled.
	 */
	private Boolean hasEarlierAttempts = false;

	/**
	 * @description The user who sent this request: the running user, or, while an issue's request is run again, the user
	 * who sent the call the request was read from (see API_InboundInvoker.getReplayedCallSenderId). The key of a request
	 * belongs to this user, so the earlier calls and their open issues are read as this user's. Null for a request with
	 * no key, or for a service that does not have Idempotency Enabled.
	 */
	private Id senderId;

	/**
	 * @description The newest earlier call of this request that the same user created, that did not complete and that
	 * received the same body. This request is a retry of that call, so its own call links to it through
	 * PreviousAttempt__c. Null when there is no such call.
	 */
	private Id previousAttemptId;

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
	 * such as headers, parameters, and the request body. Header names carry no case, and many clients send them in lower case,
	 * so read a header through `UTIL_Map.CaseInsensitiveMap`, which finds it whatever case its name arrived in.
	 *
	 * @see RestRequest
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String partner = (String)new UTIL_Map.CaseInsensitiveMap(request.headers).get('X-Partner-Id');
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
		return readHeader(HTTP_CONTENT_TYPE);
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
	 * Records you register here are saved in system mode, so the running user's object and field permissions are not checked.
	 * To save with the user's permissions, use `DML_Builder.newTransaction().withUserMode()` in its own transaction.
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
	 * @description Performs actions before committing changes to the database. It runs once for each attempt of the
	 * commit: an attempt the platform refused for a row lock is tried again once, and this method runs again for the new
	 * attempt. So write what you add here so that it is safe to run more than once.
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
		String traceParentHeader = readHeader(API_Base.HEADER_TRACE_PARENT);

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
	 * @description Reads a request header whatever case its name arrived in. Header names carry no case, and many clients send them
	 * in lower case. A header spelled exactly as asked is returned first, so a request that carries both spellings yields the one
	 * spelled as asked; otherwise the name is matched without regard to case.
	 *
	 * @param name The header name to read
	 *
	 * @return The header value, or null when the request carries no header of that name in any case
	 */
	private String readHeader(String name)
	{
		Map<String, String> headers = request.headers;

		return headers.containsKey(name) ? headers.get(name) : (String)new UTIL_Map.CaseInsensitiveMap(headers).get(name);
	}

	/**
	 * @description Checks for an idempotency key in the request headers. Idempotency means that sending the same request
	 * more than once has the same effect as sending it once, so a caller can send a request again without creating a
	 * second charge or a second record. When the request carries a key and the service has Idempotency Enabled, this
	 * method reads once the calls the sender sent to the same service with the same key (see
	 * SEL_ApiCall.findByServiceAndIdempotencyKey), newest first. The sender is the running user. While an issue's request
	 * is run again, the sender is the user who sent the call the request was read from (see
	 * API_InboundInvoker.getReplayedCallSenderId), because the request still belongs to that user. A key belongs to the
	 * user who sent it, so a call another user sent with the same key is never read: this request is never answered from
	 * it, never linked to it and never resolves its issues. The read decides:
	 *
	 * 1. When one of them completed, the request does not run. If the body's SHA-256 hash matches the completed call's
	 *    IdempotencyKeyBodyHash__c, or that call has no hash, the stored response is returned with status 200. If the
	 *    hashes differ, status 409 is returned with a JSON body that holds the completed call's Id, because the caller
	 *    sent another request under a key that is already used.
	 * 2. Otherwise the request runs. The calls that did not complete are the earlier attempts of the request (see
	 *    hasEarlierAttempts). The newest of them that the sender created and that received the same body is the call
	 *    this request retries (see previousAttemptId). A call that another person created when they ran the request
	 *    again is never chosen, so a link never points at a call of another user.
	 *
	 * The read returns only the newest calls of the key. That is enough for the two decisions above. The open issues of
	 * the request are read in another way, from every call of the request (see hasEarlierAttemptWithAnOpenIssue and
	 * resolveApiIssues).
	 *
	 * @return True if the request is a duplicate and a response was written (200 cached or 409 conflict)
	 */
	private Boolean checkIdempotency()
	{
		idempotencyKey = readHeader(API_Base.HEADER_IDEMPOTENCY_KEY);

		if(String.isBlank(idempotencyKey) || setting?.IdempotencyEnabled__c != true)
		{
			return false;
		}

		String requestBodyHash = computeBodyHash(result.requestBody);
		ApiCall__c existing = null;
		senderId = API_InboundInvoker.getReplayedCallSenderId() ?? UserInfo.getUserId();

		for(ApiCall__c earlierCall : new SEL_ApiCall().findByServiceAndIdempotencyKey(getServiceName(), idempotencyKey, senderId))
		{
			if(earlierCall.Status__c == SEL_ApiCall.STATUS_COMPLETED)
			{
				existing = existing ?? earlierCall;
			}
			else
			{
				hasEarlierAttempts = true;
				if(previousAttemptId == null && earlierCall.CreatedById == senderId && earlierCall.IdempotencyKeyBodyHash__c == requestBodyHash)
				{
					previousAttemptId = earlierCall.Id;
				}
			}
		}

		if(existing == null)
		{
			return false;
		}

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
			isKeyReusedWithAnotherBody = true;
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
	 * @description Computes the SHA-256 hex digest of the inbound request body. It is used to detect an Idempotency-Key
	 * that is reused with another body, and to prove later that a stored body is an exact copy of the body received. A null
	 * body is treated as the empty string, so the result is always a 64-character hex digest, and two blank bodies give the
	 * same digest. This is the one place the hash of a body is made: running an issue's request again compares the
	 * stored body with the recorded hash through this method too. It calls Crypto itself on purpose, because
	 * UTIL_Crypto.generateSHA256Hash gives no hash for a blank body, while a body of spaces must get its own hash here.
	 *
	 * @param body The raw request body (typically `result.requestBody`).
	 *
	 * @return The 64-character hex SHA-256 digest of the body, or of the empty string when body is null.
	 */
	@SuppressWarnings('PMD.KernNoRawCrypto')
	public static String computeBodyHash(String body)
	{
		return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(body == null ? '' : body)));
	}

	/**
	 * @description Updates the API call record with the details only an inbound call has:
	 *
	 * 1. The Idempotency-Key, when the request carried one.
	 * 2. The SHA-256 hash of the body as it was received, for every request, with or without a key. A later run of the
	 *    request can compare it with the stored body to prove the body was not changed or cut.
	 * 3. Whether the answer came from an earlier call with the same key.
	 * 4. Whether the call failed permanently: its code threw a UTIL_Exceptions.PermanentFailureException, from
	 *    processRequest(), onSuccess() or getValidationErrors(). Running such a request again cannot help. A
	 *    UTIL_Exceptions.RequestRefusedException does not mark the call (see API_Base.isPermanentFailure). Errors that
	 *    getValidationErrors() returns do not mark the call, because the request may become valid once the data it
	 *    refers to is fixed.
	 * 5. The earlier call this call tries again (PreviousAttempt__c): the call an issue's request was read from while
	 *    that request is run again, or else the newest earlier call with the same key and body that did not complete
	 *    (see checkIdempotency).
	 */
	public override void setApiCallDetails()
	{
		super.setApiCallDetails();
		recordRequestDetails();
		apiCall.IsIdempotencyHit__c = isIdempotencyHit;
	}

	/**
	 * @description Records on the call the key, the hash of the body and the permanent failure marker (see
	 * setApiCallDetails), when the service's own error handling threw and setApiCallDetails may not have run. This
	 * method only reads fields and runs no code that a service can override, so the dispatcher can still use it after
	 * the service's own code threw.
	 */
	public void recordRequestDetailsWithoutTheHandler()
	{
		recordRequestDetails();
	}

	/**
	 * @description Records on the call the details every inbound call keeps: the Idempotency-Key when the request carried
	 * one, the SHA-256 hash of the body as it was received, and whether the call failed permanently. The call failed
	 * permanently when its code, or the checks of the request, threw a UTIL_Exceptions.PermanentFailureException that
	 * is not a UTIL_Exceptions.RequestRefusedException (see API_Base.isPermanentFailure). When
	 * the request is an issue's request run again from its call (see API_InboundInvoker.getReplayedCallId), the call
	 * links to that earlier call through PreviousAttempt__c. Otherwise, when the request is a retry of an earlier call
	 * with the same key and body (see previousAttemptId), the call links to that call. The call the request was read
	 * from comes first, because that is the call the person who ran it again chose. This method only reads fields.
	 */
	private void recordRequestDetails()
	{
		if(String.isNotBlank(idempotencyKey))
		{
			apiCall.IdempotencyKey__c = idempotencyKey;
		}

		Id earlierCallId = API_InboundInvoker.getReplayedCallId() ?? previousAttemptId;
		if(earlierCallId != null)
		{
			apiCall.PreviousAttempt__c = earlierCallId;
		}

		apiCall.IdempotencyKeyBodyHash__c = computeBodyHash(result.requestBody);
		apiCall.IsPermanentFailure__c = isPermanentFailure(lastFailure) || isPermanentFailure(validationFailure);
	}

	/**
	 * @description Creates the issue record for this failed request (see buildInboundFailureRecord). A request with a key
	 * gets no issue when an earlier call of the same request already holds an open one (see
	 * hasEarlierAttemptWithAnOpenIssue), so a caller that sends a failing request again and again leaves one open issue,
	 * not one for each try.
	 *
	 * @return A new inbound issue record, not yet saved, or null when no issue is written.
	 */
	public override ApiIssue__c createFailureRecord()
	{
		return buildInboundFailureRecord();
	}

	/**
	 * @description Checks whether an earlier call of this request holds an open issue. It makes one read, and only when
	 * the request has earlier calls. The read looks at every call of the request, however many times the caller sent it
	 * (see SEL_ApiIssue.findOpenByIdempotencyKey): only the first failed call of a request holds the open issue, and it
	 * may be older than the newest calls the key read returns. When no query is left, it logs a warning. When the read
	 * fails, it logs the error. In both cases it answers false, and the failed request writes its own issue, because a
	 * second open issue for a request is better than a failure with no issue at all.
	 *
	 * @return True when an earlier call of this request holds an open issue
	 */
	private Boolean hasEarlierAttemptWithAnOpenIssue()
	{
		if(!hasEarlierAttempts)
		{
			return false;
		}

		if(UTIL_Limits.soqlQueries().isExhausted())
		{
			LOG_Builder.build().warn(WARNING_NO_QUERY_TO_FIND_OPEN_ISSUE).emitAt(LOCATION_FIND_OPEN_ISSUE);
			return false;
		}

		try
		{
			return !new SEL_ApiIssue().findOpenByIdempotencyKey(getServiceName(), idempotencyKey, senderId).isEmpty();
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).emitAt(LOCATION_FIND_OPEN_ISSUE);
			return false;
		}
	}

	/**
	 * @description Marks Resolved the open issues of the earlier calls of this request (see hasEarlierAttempts), after
	 * this request succeeded. The framework runs it after the call is saved, when the call succeeded and its setting has
	 * Resolve Issues on, so the caller's answer is already decided. It resolves nothing when:
	 *
	 * 1. The answer came from a mock or from a completed call with the same key, because nothing ran.
	 * 2. The status of the answer is not from 200 to 299. The handler answered with an error on purpose, so the
	 *    operation did not succeed.
	 * 3. The request has no earlier calls. That is always so for a request with no key, or for a service that does not
	 *    have Idempotency Enabled.
	 *
	 * Otherwise it reads the open issues of every earlier call of the request, however many times the caller sent it (see
	 * SEL_ApiIssue.findOpenByIdempotencyKey), and saves them as Resolved, all with the same time. The read and the save
	 * waive field access and record sharing, for this method only: the user who sends requests often has no access to API
	 * issues, and an issue is Private and can belong to another owner. The earlier calls are all calls this same user
	 * sent (see senderId), so no other user's issue is resolved. The save keeps the issues it can save. When no query or
	 * no save is left, it logs a warning and resolves nothing. An error in the read or the save is logged, and it never
	 * reaches the caller.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	protected override void resolveApiIssues()
	{
		if(result.isMocked == true || isIdempotencyHit || !hasSuccessStatus() || !hasEarlierAttempts)
		{
			return;
		}

		if(UTIL_Limits.soqlQueries().isExhausted() || UTIL_Limits.dmlStatements().isExhausted())
		{
			LOG_Builder.build().warn(WARNING_NO_ROOM_TO_RESOLVE_ISSUES).emitAt(LOCATION_RESOLVE_ISSUES);
			return;
		}

		try
		{
			List<ApiIssue__c> openIssues = new SEL_ApiIssue().findOpenByIdempotencyKey(getServiceName(), idempotencyKey, senderId);
			Datetime resolvedDate = Datetime.now();
			for(ApiIssue__c openIssue : openIssues)
			{
				openIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
				openIssue.ResolvedDate__c = resolvedDate;
			}
			DML_Builder.newTransaction().withSystemMode().bypassSharingInternal().doUpdate(openIssues).allowPartial().execute();
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).emitAt(LOCATION_RESOLVE_ISSUES);
		}
	}

	/**
	 * @description Checks whether the answer to the caller has a success status: a status from 200 to 299. A blank
	 * status counts as no success.
	 *
	 * @return True when the status of the answer is from 200 to 299
	 */
	private Boolean hasSuccessStatus()
	{
		Integer statusCode = String.isBlank(result.statusCode) ? null : Integer.valueOf(result.statusCode);
		return statusCode != null && statusCode >= API_Base.HTTP_OK && statusCode < HTTP_FIRST_REDIRECT_STATUS;
	}

	/**
	 * @description Builds the issue record for this failed request when its setting has Log Issues on: the record every
	 * direction shares (see API_Base.buildFailureRecord) with the Inbound direction. The issue holds nothing of the
	 * request. The body, the address, the parameters and the key stay on the call, and the issue links to the call. A
	 * request that reused an Idempotency-Key with another body gets no issue: it was refused with status 409, and there is
	 * nothing to run again. A request that is an issue's request run again (see API_InboundInvoker.isReplayRunning) gets
	 * no issue either: the issue it was run for stays open, so a failed run does not add a second open issue for the same
	 * request. A request with a key gets no issue when an earlier call of the same request already holds an open one
	 * (see hasEarlierAttemptWithAnOpenIssue). This method reads fields, makes at most that one read and runs no code that
	 * a service can override. The read checks the query limit first and catches its own errors, so this method cannot
	 * throw the way the service's code can. So the dispatcher can still use it when the service's own error handling threw.
	 *
	 * @return A new inbound issue record, not yet saved, or null when Log Issues is off, the key was reused with another
	 * body, the request is an issue's request run again, or an earlier call of the same request holds an open issue.
	 */
	public ApiIssue__c buildInboundFailureRecord()
	{
		if(setting?.LogIssues__c != true || isKeyReusedWithAnotherBody || API_InboundInvoker.isReplayRunning() || hasEarlierAttemptWithAnOpenIssue())
		{
			return null;
		}

		ApiIssue__c apiIssue = API_Base.buildFailureRecord(apiCall);
		apiIssue.Direction__c = SEL_ApiIssue.DIRECTION_INBOUND;
		return apiIssue;
	}

	/**
	 * @description Checks if this incoming request gets a mock answer instead of running the service's own code. There
	 * are three ways a service mocks:
	 * 1. The API Test Harness or a test turned mocking on for the service in this transaction.
	 * 2. The Mock All Inbound APIs feature flag is on for the running user.
	 * 3. The service's API Setting has Mocking Enabled ticked, and the Mock Selected APIs feature flag is on for the
	 * running user. The box alone, or the flag alone, mocks nothing.
	 * Each flag is checked for the user the request runs as.
	 *
	 * @return True if the request gets a mock answer, otherwise false.
	 */
	private Boolean shouldMock()
	{
		return API_MockFactory.isMockingEnabled(getServiceName()) ||
				(setting?.MockingEnabled__c == true && UTIL_FeatureFlag.isEnabled(API_Base.FLAG_MOCK_SELECTED_APIS)) ||
				UTIL_FeatureFlag.isEnabled(FLAG_MOCK_ALL_INBOUND_APIS);
	}

}