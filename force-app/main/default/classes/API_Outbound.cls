// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base class for all outbound web service calls. Extends API_Base to provide functionality
 * for making HTTP callouts, handling responses, managing retries, and token replacements.
 *
 * @see API_Outbound_TEST
 * @see API_PostExample_TEST
 * @see API_GetPwndPasswords_TEST
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
 * public with sharing class API_SendEmail extends API_Outbound
 * {
 *     public override void configure()
 *     {
 *         super.configure();
 *         requestPayload = new DTO_Request();
 *         responsePayload = new DTO_Response();
 *         defaultMockBody = '{"messageId": "msg-12345"}';
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier,PMD.ExcessiveClassLength,PMD.AvoidBooleanMethodParameters')
global virtual inherited sharing class API_Outbound extends API_Base
{
	/**
	 * @description Feature flag name for disabling all outbound API calls.
	 */
	@TestVisible
	private static final String FLAG_DISABLE_ALL_OUTBOUND_APIS = 'DisableAllOutboundAPIs';

	/**
	 * @description Test flag to simulate circuit breaker failure during retry for coverage testing.
	 */
	@TestVisible
	private static Boolean simulateCircuitBreakerFailure = false;

	/**
	 * @description Test flag to simulate an unexpected exception during performValidation for coverage testing.
	 */
	@TestVisible
	private static Boolean simulateValidationException = false;

	/**
	 * @description Trace context for this outbound call (child span of current context).
	 */
	private TraceContext outboundTraceContext;

	/**
	 * @description Auto-generated idempotency key for this outbound call.
	 */
	private String outboundIdempotencyKey;

	/**
	 * @description Overrides the Named Credential name for this handler instance.
	 * Set by UTIL_HttpClient delegation mode when the caller provides a credential override.
	 */
	@TestVisible
	protected String namedCredentialOverride;

	/**
	 * @description The DTO that should be serialized for the request body in outbound service calls.
	 * This object contains the data that will be sent to the external service as part of the HTTP request.
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
	global protected DTO_Base requestPayload {get; set;}

	/**
	 * @description The DTO that will deserialize the response body of the external web service call.
	 * This object will be populated with the response data after the HTTP call completes.
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
	@TestVisible
	global protected DTO_Base responsePayload {get; set;}

	/**
	 * @description Default mock response body for unit tests and mock mode.
	 * Set this in configure() to declare the handler's default mock response.
	 * When set, API_MockFactory.CalloutMock uses this as fallback when no factory mock is registered.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void configure()
	 * {
	 *     super.configure();
	 *     defaultMockBody = '{"messageId": "msg-12345"}';
	 * }
	 * ```
	 */
	global protected String defaultMockBody {get; set;}

	/**
	 * @description Whether this service requires a triggering object ID.
	 * Override in configure() to set to false for services that don't require a triggering record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void configure()
	 * {
	 *     super.configure();
	 *     requiresTriggeringRecord = false;
	 * }
	 * ```
	 */
	global protected Boolean requiresTriggeringRecord;

	/**
	 * @description The request object used by the API handler to make an outbound call.
	 * The `HttpRequest` object is initialized lazily when it's first accessed.
	 *
	 * @see HttpRequest
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * request.setHeader('X-Custom', 'value');
	 * ```
	 */
	@TestVisible
	global protected HttpRequest request
	{
		get
		{
			if(request == null)
			{
				request = new HttpRequest();
			}
			return request;
		}
		private set;
	}

	/**
	 * @description The response object containing the results of the HTTP callout.
	 * This object is populated after the HTTP call is executed.
	 *
	 * @see HttpResponse
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Integer statusCode = response.getStatusCode();
	 * ```
	 */
	@TestVisible
	global protected HttpResponse response
	{
		get;
		private set;
	}

	/**
	 * @description Returns the HTTP response from this handler.
	 * Provides public access to the response for delegation patterns.
	 *
	 * @return The HTTP response from the callout
	 */
	public virtual HttpResponse getHttpResponse()
	{
		return response;
	}

	/**
	 * @description The `Http` client used to make the HTTP request and return the response object.
	 * It initializes when first accessed and makes the actual HTTP call.
	 *
	 * @see Http
	 *
	 * @example
	 * ```apex
	 * HttpResponse response = httpObject.send(request);
	 * ```
	 */
	protected Http httpObject
	{
		get
		{
			if(httpObject == null)
			{
				httpObject = new Http();
			}
			return httpObject;
		}
		private set;
	}

	/**
	 * @description Returns the base URL of the web service. This resolves Named Credentials to handle secure credential management in Salesforce.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String endpoint = baseUrl + '/path';
	 * ```
	 */
	global String baseUrl
	{
		get
		{
			if(baseUrl == null)
			{
				NamedCredential foundCredential = new SEL_NamedCredential().findByName(getNamedCredentialName());
				baseUrl = foundCredential?.Endpoint ?? UTIL_String.EMPTY;
			}
			return baseUrl;
		}
		protected set;
	}

	/**
	 * @description Circuit breaker instance for this service, used to prevent cascading failures.
	 * Lazily initialized from ApiSetting__mdt configuration when enabled.
	 *
	 * @see UTIL_CircuitBreaker
	 * @see ApiSetting__mdt.CircuitBreakerEnabled__c
	 */
	private UTIL_CircuitBreaker.Breaker circuitBreaker
	{
		get
		{
			if(circuitBreaker == null && isCircuitBreakerEnabled())
			{
				circuitBreaker = UTIL_CircuitBreaker.fromSetting(getServiceName(), setting);
			}
			return circuitBreaker;
		}
		set;
	}

	/**
	 * @description Performs framework-level validation and subscriber validation.
	 * Checks: triggering object, required inputs, settings, circuit breaker, then base validation.
	 *
	 * @return True if the request should be aborted, otherwise false.
	 */
	protected virtual override Boolean performValidation()
	{
		Boolean mustAbort = false;

		try
		{
			if(simulateValidationException)
			{
				throw new UTIL_Exceptions.IllegalStateException('Simulated validation exception');
			}

			// Framework validation: triggering object
			if(requiresTriggeringRecord && UTIL_SObject.validateId(apiCall.TriggeringRecordId__c) == null)
			{
				result.errors.add('A valid Triggering Object Id is required.');
				mustAbort = true;
			}

			// Framework validation: required inputs
			Set<String> requiredInputs = getRequiredInputs();
			if(!inputs.allExists(requiredInputs, true))
			{
				result.errors.add(String.format('All required parameters {0} were not provided or were provided blank', new List<String> {JSON.serialize(requiredInputs)}));
				mustAbort = true;
			}

			// Framework validation: settings
			if(setting == null)
			{
				result.errors.add(String.format('API setting record not found for service "{0}"', new List<String> {getServiceName()}));
				mustAbort = true;
			}

			// Framework validation: circuit breaker
			if(isCircuitBreakerEnabled() && !circuitBreaker.allowRequest())
			{
				result.errors.add('Circuit breaker is OPEN for service: ' + getServiceName() + '. Service is temporarily unavailable.');
				mustAbort = true;
			}
		}
		catch(Exception exceptionThrown)
		{
			handleError(exceptionThrown);
			mustAbort = true;
		}

		return mustAbort || super.performValidation();
	}

	/**
	 * @description Constructs the `HttpRequest` object used to make the outbound API call. It sets the headers, request body, and endpoint URL.
	 *
	 * @param requestBody The body content of the request.
	 *
	 * @return The fully configured request object.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override HttpRequest createRequest(String requestBody)
	 * {
	 *     HttpRequest httpRequest = super.createRequest(requestBody);
	 *     // customize request
	 *     return httpRequest;
	 * }
	 * ```
	 */
	global protected virtual HttpRequest createRequest(String requestBody)
	{
		setHeaders();

		String endPoint = getWebServiceEndPoint();
		String queryParams = getQueryParameters();
		if(String.isNotBlank(queryParams))
		{
			endPoint = (endPoint ?? '') + '?' + queryParams;
		}

		if(String.isNotBlank(endPoint))
		{
			request.setEndpoint(endPoint);
		}
		result.url = endPoint;

		Boolean hasBody = String.isNotBlank(requestBody) && HttpMethod.GET != getHttpMethod();
		if(hasBody)
		{
			request.setBody(requestBody);
		}

		resolveIdempotencyKey(endPoint, requestBody);
		result.requestBody = request.getBody();

		return request;
	}

	/**
	 * @description Returns the authorization token required for outbound API requests.
	 *
	 * @return The authorization token to be used in the `Authorization` HTTP header.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override String getAuthorisationToken()
	 * {
	 *     return 'Bearer ' + accessToken;
	 * }
	 * ```
	 */
	global protected virtual String getAuthorisationToken()
	{
		return UTIL_String.EMPTY;
	}

	/**
	 * @description Retrieves the HTTP encoding.
	 *
	 * @return The HTTP encoding, defaults to JSON.
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
		return HTTP_ENCODING_JSON;
	}

	/**
	 * @description Creates an endpoint mock instance for the API callout.
	 * Returns an API_MockFactory.CalloutMock configured with the handler's service name,
	 * setting developer name, and defaultMockBody.
	 *
	 * @return A new HttpCalloutMock instance for the API callout
	 */
	protected virtual HttpCalloutMock createEndpointMock()
	{
		API_MockFactory.CalloutMock endpointMock = new API_MockFactory.CalloutMock();
		endpointMock.apiClassName = getServiceName();
		endpointMock.settingDeveloperName = setting?.DeveloperName;
		endpointMock.defaultMockBody = defaultMockBody;

		return endpointMock;
	}

	/**
	 * @description Retrieves the HTTP method used for making the outbound request.
	 *
	 * @return The HTTP method to be used. Defaults to POST if not provided by the superclass.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override HttpMethod getHttpMethod()
	 * {
	 *     return HttpMethod.GET;
	 * }
	 * ```
	 */
	global protected override virtual HttpMethod getHttpMethod()
	{
		HttpMethod verb = super.getHttpMethod();
		return verb != null ? verb : HttpMethod.POST;
	}

	/**
	 * @description Retrieves relevant query parameters.
	 *
	 * @return A list of query parameters.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override String getQueryParameters()
	 * {
	 *     return 'key=' + EncodingUtil.urlEncode(value, 'UTF-8');
	 * }
	 * ```
	 */
	global protected virtual String getQueryParameters()
	{
		return null;
	}

	/**
	 * @description Indicates required service inputs.
	 *
	 * @return A set of required service input names.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override Set<String> getRequiredInputs()
	 * {
	 *     Set<String> requiredInputs = super.getRequiredInputs();
	 *     requiredInputs.add(PARAM_RECIPIENT);
	 *     return requiredInputs;
	 * }
	 * ```
	 */
	global protected virtual Set<String> getRequiredInputs()
	{
		return new Set<String>();
	}

	/**
	 * @description Retrieves the current response body; override to manipulate response body first.
	 * Automatically wraps array responses and applies token replacements.
	 *
	 * @return The response that will be parsed.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override String getResponseBody()
	 * {
	 *     String body = super.getResponseBody();
	 *     // manipulate response body before parsing
	 *     return body;
	 * }
	 * ```
	 */
	global protected virtual String getResponseBody()
	{
		String responseBody = response.getBody();

		responseBody = hasArrayResponse() ? '{ "responses" : ' + responseBody + '}' : responseBody;

		List<String> searchTokens = new List<String>();
		List<String> replaceTokens = new List<String>();

		getResponseReplacementTokens(searchTokens, replaceTokens);

		return UTIL_String.replaceWholeWords(responseBody, searchTokens, replaceTokens);
	}

	/**
	 * @description Retrieves the HTTP Service Timeout.
	 *
	 * @return The timeout value in milliseconds, defaults to 120000.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override Integer getTimeout()
	 * {
	 *     return 60000;
	 * }
	 * ```
	 */
	global protected virtual Integer getTimeout()
	{
		final Integer maximumAllowedTimeout = 120000;
		return maximumAllowedTimeout;
	}

	/**
	 * @description Logs the failed API call.
	 *
	 * @example
	 * ```apex
	 * global override void logApiIssues()
	 * {
	 *     super.logApiIssues();
	 *     // additional failure logging
	 * }
	 * ```
	 */
	protected virtual void logApiIssues()
	{
		ApiIssue__c apiIssue = createFailureRecord();
		if(apiIssue != null)
		{
			DML_Builder.newTransaction().withSystemMode().doInsert(apiIssue).allowPartial().execute();
		}
	}

	/**
	 * @description Generates the request body using the type of the requestPayload.
	 * Applies token replacements to the request body before sending.
	 *
	 * @return The serialized request body.
	 *
	 * @see DTO_Base
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override String getBody()
	 * {
	 *     return JSON.serialize(customPayload);
	 * }
	 * ```
	 */
	global protected virtual override String getBody()
	{
		super.getBody();
		prepareRequest();

		List<String> searchTokens = new List<String>();
		List<String> replaceTokens = new List<String>();

		getRequestReplacementTokens(searchTokens, replaceTokens);

		return UTIL_String.replaceEachRepeatedly(requestPayload.serialize(), searchTokens, replaceTokens, true);
	}

	/**
	 * @description Prepares the outbound request by querying Salesforce data and populating the request DTO.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void prepareRequest()
	 * {
	 *     super.prepareRequest();
	 *     // additional request preparation
	 * }
	 * ```
	 */
	global protected virtual void prepareRequest()
	{
		requestPayload.populate(apiCall.TriggeringRecordId__c, inputs);
	}

	/**
	 * @description Called if request is successful; override to consume response.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void parseResponse()
	 * {
	 *     super.parseResponse();
	 *     DTO_Response dto = (DTO_Response)responsePayload;
	 *     // process the response
	 * }
	 * ```
	 */
	global protected virtual void parseResponse()
	{
		String responseBody = getResponseBody();
		if(String.isNotBlank(responseBody))
		{
			responsePayload = responsePayload.deserialize(responseBody);
		}
	}

	/**
	 * @description Checks if the JSON response is in the form of an array without a key.
	 * Salesforce DTO classes cannot parse arrays directly, so this method helps handle responses that are arrays.
	 *
	 * @return Boolean indicating if the response is an array.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override Boolean hasArrayResponse()
	 * {
	 *     return true;
	 * }
	 * ```
	 */
	global protected virtual Boolean hasArrayResponse()
	{
		return false;
	}

	/**
	 * @description Specifies token replacements for the response body before deserialization.
	 * Override to replace reserved words or tokens in the response before processing.
	 *
	 * @param searchTokens The list of search tokens to look for in the response body.
	 * @param replaceTokens The list of replacement tokens to use if matching search tokens are found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void getResponseReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
	 * {
	 *     searchTokens.add('currency');
	 *     replaceTokens.add('currencyIsoCode');
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock,ApexUnusedDeclaration')
	global protected virtual void getResponseReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
	{
	}

	/**
	 * @description Specifies token replacements for the request body before serialization.
	 * Override to replace reserved words or tokens in the request body before sending.
	 *
	 * @param searchTokens The list of search tokens to look for in the request body.
	 * @param replaceTokens The list of replacement tokens to use if matching search tokens are found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void getRequestReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
	 * {
	 *     searchTokens.add('{TODAY}');
	 *     replaceTokens.add(String.valueOf(Date.today()));
	 * }
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration,PMD.EmptyStatementBlock')
	global protected virtual void getRequestReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
	{
	}

	/**
	 * @description Resolves the failed API call.
	 *
	 * @example
	 * ```apex
	 * global override void resolveApiIssues()
	 * {
	 *     super.resolveApiIssues();
	 *     // additional failure resolution
	 * }
	 * ```
	 */
	protected virtual void resolveApiIssues()
	{
		String hashParameter = generateApiIssueHash();
		List<ApiIssue__c> updateApiIssues = new List<ApiIssue__c>();

		List<ApiIssue__c> apiIssues =
				new SEL_ApiIssue().findByFailedApiCall(apiCall.TriggeringRecordId__c, apiCall.ServiceName__c, hashParameter);

		for(ApiIssue__c apiIssue : apiIssues)
		{
			apiIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
			updateApiIssues.add(apiIssue);
		}

		DML_Builder.newTransaction().withSystemMode().doUpdate(updateApiIssues).allowPartial().execute();
	}

	/**
	 * @description Sends the HTTP request to the specified endpoint and processes the response. If running in a test context, it uses the mock response object.
	 * Integrates with circuit breaker when enabled to prevent cascading failures.
	 *
	 * @param requestObj The HTTP request object containing the headers and body for the outbound call.
	 *
	 * @see HttpRequest
	 * @see UTIL_CircuitBreaker
	 *
	 * @example
	 * ```apex
	 * global override void sendRequest(HttpRequest requestObj)
	 * {
	 *     super.sendRequest(requestObj);
	 *     // post-send processing
	 * }
	 * ```
	 */
	protected virtual void sendRequest(HttpRequest requestObj)
	{
		result.isMocked = isMocking();

		if(result.isMocked)
		{
			response = createEndpointMock().respond(requestObj);
		}
		else
		{
			if(Test.isRunningTest())
			{
				Test.setMock(HttpCalloutMock.class, createEndpointMock());
			}
			response = httpObject.send(requestObj);
		}

		Integer httpStatusCode = response.getStatusCode();
		result.statusCode = String.valueOf(httpStatusCode);
		result.responseBody = response.getBody();

		Boolean isSuccessful = HTTP_SUCCESS_CODES.contains(httpStatusCode);
		result.isSuccess = isSuccessful;
		if(!isSuccessful)
		{
			result.hasFailed = true;
		}

		recordCircuitBreakerOutcome(isSuccessful, httpStatusCode);
	}

	/**
	 * @description Updates the circuit breaker with the outcome of the HTTP call.
	 * Records success for any 2xx response; records failure only for server errors (5xx).
	 *
	 * @param isSuccessful Whether the HTTP response had a success status code.
	 * @param httpStatusCode The HTTP status code from the response.
	 */
	private void recordCircuitBreakerOutcome(Boolean isSuccessful, Integer httpStatusCode)
	{
		if(!isCircuitBreakerEnabled())
		{
			return;
		}
		if(isSuccessful)
		{
			circuitBreaker.recordSuccess();
		}
		else if(httpStatusCode >= HTTP_INTERNAL_SERVER_ERROR)
		{
			circuitBreaker.recordFailure();
		}
	}

	/**
	 * @description Sets the HTTP headers for the request. Includes Accept header for JSON responses.
	 * Override in child classes to add additional service-specific headers.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void setHeaders()
	 * {
	 *     super.setHeaders();
	 *     request.setHeader('Custom-Header', 'CustomValue');
	 * }
	 * ```
	 */
	global protected virtual void setHeaders()
	{
		HttpMethod verb = getHttpMethod();
		request.setMethod(toHttpString(verb));
		request.setTimeout(getTimeout());

		request.setHeader(HTTP_HEADER_ACCEPT, HTTP_ACCEPT_JSON_WITH_CHARSET);
		if(HttpMethod.GET != verb)
		{
			request.setHeader(HTTP_CONTENT_TYPE, getEncoding());
		}

		String authorisationToken = getAuthorisationToken();
		if(String.isNotEmpty(authorisationToken))
		{
			request.setHeader(HTTP_HEADER_AUTHORIZATION, authorisationToken);
		}

		outboundTraceContext = currentOrNewTraceContext().createChildSpan();
		request.setHeader(HEADER_TRACE_PARENT, outboundTraceContext.toHeader());
	}

	/**
	 * @description Adds additional behaviour when item is set; specifically parsing the parameters.
	 *
	 * @param apiCall The API call used by the service calls to initiate an outbound call.
	 *
	 * @example
	 * ```apex
	 * global override void setApiCall(ApiCall__c apiCall)
	 * {
	 *     super.setApiCall(apiCall);
	 *     // parse additional parameters
	 * }
	 * ```
	 */
	protected override virtual void setApiCall(ApiCall__c apiCall)
	{
		super.setApiCall(apiCall);

		if(String.isNotBlank(apiCall.RequestParameters__c))
		{
			inputs = (DTO_NameValues)inputs.deserialize(apiCall.RequestParameters__c);
		}
	}

	/**
	 * @description Constructs and returns the full URL endpoint for the web service, resolving Named Credentials and appending the API path.
	 *
	 * @return The full URL endpoint for the web service.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override String getWebServiceEndPoint()
	 * {
	 *     return super.getWebServiceEndPoint() + '/custom-path';
	 * }
	 * ```
	 */
	global protected virtual String getWebServiceEndPoint()
	{
		String credentialName = getNamedCredentialName();
		if(String.isBlank(credentialName))
		{
			return null;
		}
		String path = setting?.EndpointPath__c;
		return 'callout:' + credentialName + (String.isNotBlank(path) ? path : UTIL_String.EMPTY);
	}

	/**
	 * @description Initializes global variables; override in descendant classes if needed.
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
	 *     defaultMockBody = '{"messageId": "msg-12345"}';
	 * }
	 * ```
	 */
	global protected override virtual void configure()
	{
		super.configure();
		requestPayload = new DTO_Base();
		responsePayload = new DTO_Base();
		requiresTriggeringRecord = true;
	}

	/**
	 * @description Checks whether the API has been disabled for the current user by verifying custom settings or feature switches.
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
		return super.isDisabled() || UTIL_FeatureFlag.isEnabled(FLAG_DISABLE_ALL_OUTBOUND_APIS);
	}

	/**
	 * @description Resolves the idempotency key for this outbound call.
	 * Priority: 1) Pre-set key on apiCall (subscriber-provided — always sent regardless of
	 * IdempotencyEnabled setting), 2) Deterministic SHA-256 content hash from endpoint URL,
	 * request parameters, and request body (only when IdempotencyEnabled is true).
	 * Sets the resolved key on the HTTP request header.
	 *
	 * @param endPoint The fully resolved endpoint URL including query parameters
	 * @param requestBody The serialized request body for content-based hashing
	 */
	private void resolveIdempotencyKey(String endPoint, String requestBody)
	{
		if(String.isNotBlank(apiCall.IdempotencyKey__c))
		{
			outboundIdempotencyKey = apiCall.IdempotencyKey__c;
		}
		else if(setting?.IdempotencyEnabled__c == true)
		{
			outboundIdempotencyKey = UTIL_Crypto.generateSHA256Hash(endPoint + '|' + apiCall.RequestParameters__c + '|' + requestBody);
		}

		if(String.isNotBlank(outboundIdempotencyKey))
		{
			request.setHeader(HEADER_IDEMPOTENCY_KEY, outboundIdempotencyKey);
		}
	}

	/**
	 * @description Determines if circuit breaker is enabled for this service based on ApiSetting configuration.
	 * Circuit breaker is only enabled if explicitly configured in metadata (backward compatible default: false).
	 *
	 * @return True if circuit breaker is enabled, false otherwise (default)
	 */
	private Boolean isCircuitBreakerEnabled()
	{
		return setting?.CircuitBreakerEnabled__c == true;
	}

	/**
	 * @description Transforms the response from the web service into an alternative structure defined by the provided class name.
	 *
	 * @param className The name of the class to which the response should be transformed.
	 *
	 * @return The transformed response object.
	 *
	 * @throws IllegalArgumentException If the class name does not map to a valid type.
	 */
	public DTO_Base transformResponse(String className)
	{
		return transformResponse(UTIL_System.getTypeForClassName(className));
	}

	/**
	 * @description Transforms the response from the web service into an alternative structure defined by the provided object type.
	 *
	 * @param objectType The class type to which the response should be transformed.
	 *
	 * @return The transformed response object.
	 *
	 * @throws TypeException If the provided type is not a child of `DTO_Base`.
	 */
	public DTO_Base transformResponse(Type objectType)
	{
		UTIL_System.assertTypeAssignable(DTO_Base.class, objectType);
		DTO_Base dtoBase = (DTO_Base)objectType.newInstance();
		transformResponse(dtoBase);
		return dtoBase;
	}

	/**
	 * @description Transforms the base response DTO into an alternative structure, populating the provided DTO object with the transformed data.
	 *
	 * @param dtoBase The DTO object that will be populated with the transformed response data.
	 */
	public virtual void transformResponse(DTO_Base dtoBase)
	{
		dtoBase.transform(responsePayload);
	}

	/**
	 * @description Creates a ApiIssue__c record for logging failures.
	 *
	 * @return A new uncommitted ApiIssue__c record, or null if failure logging is disabled.
	 *
	 * @example
	 * ```apex
	 * global override ApiIssue__c createFailureRecord()
	 * {
	 *     ApiIssue__c failure = super.createFailureRecord();
	 *     // customize failure record
	 *     return failure;
	 * }
	 * ```
	 */
	public override virtual ApiIssue__c createFailureRecord()
	{
		ApiIssue__c apiIssue = super.createFailureRecord();
		if(setting?.LogIssues__c == true)
		{
			apiIssue = TST_Factory.newApiIssue(apiCall, generateApiIssueHash());

			if(String.isNotBlank(outboundIdempotencyKey))
			{
				apiIssue.IdempotencyKey__c = outboundIdempotencyKey;
			}
		}
		return apiIssue;
	}

	/**
	 * @description Controls the processing of outbound request and ensures result of call is logged.
	 *
	 * @param apiCall The apiCall which will ultimately be saved to record activity of the API call.
	 *
	 * @example
	 * ```apex
	 * global override void process(ApiCall__c apiCall)
	 * {
	 *     super.process(apiCall);
	 *     // post-processing
	 * }
	 * ```
	 */
	public override virtual void process(ApiCall__c apiCall)
	{
		super.process(apiCall);
		LOG_Builder.setCorrelationId(currentOrNewTraceContext().traceId);

		if(performValidation())
		{
			result.isAborted = true;
		}
		else
		{
			calloutProcessingTime.start();
			sendRequest(createRequest(getBody()));
			calloutProcessingTime.stop();

			// Update logging context with response details (URL, status, duration)
			LOG_Builder.setGlobalContext('endpoint', result.url);
			LOG_Engine.updateWebserviceContext(null, result.statusCode, calloutProcessingTime.getTime());

			if(result.isSuccess)
			{
				try
				{
					parseResponse();
				}
				catch(Exception parseFailure)
				{
					result.parseError = true;
					handleError(parseFailure);
				}
				if(!result.parseError)
				{
					onSuccess();
				}
			}
		}

		setApiCallDetails();
	}

	/**
	 * @description Persists call results back to API Call.
	 */
	public override virtual void setApiCallDetails()
	{
		super.setApiCallDetails();
		apiCall.MaxRetries__c = setting?.MaxRetryCount__c ?? 0;

		if(outboundTraceContext != null)
		{
			apiCall.TraceId__c = outboundTraceContext.traceId;
			apiCall.ParentSpanId__c = outboundTraceContext.parentSpanId;
		}

		if(String.isNotBlank(outboundIdempotencyKey))
		{
			apiCall.IdempotencyKey__c = outboundIdempotencyKey;
		}

		if(request != null)
		{
			for(String key : new List<String>
			{
					HTTP_CONTENT_TYPE, HTTP_HEADER_AUTHORIZATION, HTTP_HEADER_ACCEPT,
					HEADER_TRACE_PARENT, HEADER_IDEMPOTENCY_KEY
			})
			{
				String value = request.getHeader(key);
				if(value != null)
				{
					result.requestHeaders.add(key, value);
				}
			}
		}

		if(response != null && response.getHeaderKeys() != null)
		{
			for(String key : response.getHeaderKeys())
			{
				result.responseHeaders.add(key, response.getHeader(key));
			}
		}

		if(result.hasFailed)
		{
			retry();
		}
	}

	/**
	 * @description Performs operations after UOW has performed DML operations.
	 *
	 * @param wasSuccessful Indicates if the commit was successful or not.
	 */
	public override virtual void onCommitWorkFinished(Boolean wasSuccessful)
	{
		if(wasSuccessful && result.isSuccess && setting?.ResolveIssues__c == true)
		{
			resolveApiIssues();
		}
		if(wasSuccessful && !result.isSuccess && setting?.LogIssues__c == true)
		{
			logApiIssues();
		}
		super.onCommitWorkFinished(wasSuccessful);
	}

	/**
	 * @description Generates hash for API issue deduplication.
	 *
	 * @return The hashed value.
	 *
	 * @example
	 * ```apex
	 * String hash = generateApiIssueHash();
	 * ```
	 */
	protected String generateApiIssueHash()
	{
		return UTIL_String.abbreviate(UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c), SEL_ApiIssue.REQUEST_PARAMETERS_HASH_LENGTH);
	}

	/**
	 * @description Retrieves the name of the Named Credential associated with the current service handler.
	 *
	 * @return The Named Credential name.
	 */
	protected virtual String getNamedCredentialName()
	{
		return namedCredentialOverride ?? setting?.ApiCredential__r?.NamedCredential__c;
	}

	/**
	 * @description Creates the retry strategy for failed service calls.
	 * Override this method in subclasses to provide custom retry strategies.
	 *
	 * @return Configured instance
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global class API_PaymentGateway extends API_Outbound
	 * {
	 *     global override UTIL_Retry.Strategy createRetryStrategy()
	 *     {
	 *         return UTIL_Retry.exponential()
	 *             .withBaseBackoff(5)
	 *             .withMaxRetries(3);
	 *     }
	 * }
	 * ```
	 */
	global virtual UTIL_Retry.Strategy createRetryStrategy()
	{
		Decimal baseBackoff = setting?.RetryBackoffSeconds__c ?? 0;
		Decimal maxRetries = setting?.MaxRetryCount__c ?? 0;

		return UTIL_Retry.linear()
				.withBaseBackoff(baseBackoff.intValue())
				.withMaxRetries(maxRetries.intValue());
	}

	/**
	 * @description Initiates a retry if the service call fails, based on retry settings.
	 * Uses the strategy returned by createRetryStrategy() to determine backoff timing.
	 *
	 * If circuit breaker is enabled and OPEN, extends the retry delay to allow time for circuit recovery.
	 * This prevents retry storms when external service is down.
	 */
	private void retry()
	{
		UTIL_Retry.Strategy retryStrategy = createRetryStrategy();
		UTIL_Retry.Context retryContext = UTIL_Retry.newContext((apiCall.Retries__c ?? 0).intValue());

		if(!retryStrategy.shouldRetry(retryContext))
		{
			return;
		}

		Integer backoffSeconds = retryStrategy.calculateBackoff(retryContext);
		backoffSeconds = applyCircuitBreakerBackoff(backoffSeconds);

		if(backoffSeconds > 0)
		{
			SEL_ApiCall.updateNextRetryInfo(apiCall, Datetime.now().addSeconds(backoffSeconds));
		}
	}

	/**
	 * @description Extends the retry backoff when the circuit breaker is open, ensuring retries
	 * do not fire while the external service is still considered unavailable.
	 *
	 * @param baseBackoffSeconds The backoff calculated by the retry strategy.
	 *
	 * @return The adjusted backoff, which may be extended to the circuit timeout.
	 */
	private Integer applyCircuitBreakerBackoff(Integer baseBackoffSeconds)
	{
		try
		{
			if(simulateCircuitBreakerFailure)
			{
				throw new UTIL_Exceptions.IllegalStateException('Simulated circuit breaker failure');
			}
			if(isCircuitBreakerEnabled() && circuitBreaker != null && !circuitBreaker.allowRequest())
			{
				Integer circuitTimeout = setting?.CircuitBreakerTimeout__c != null ? setting.CircuitBreakerTimeout__c.intValue() : 60;
				return Math.max(baseBackoffSeconds, circuitTimeout);
			}
		}
		catch(Exception error)
		{
			LOG_Builder.build().warn('Circuit breaker check failed during retry: ' + error.getMessage()).at(getServiceName() + '/retry').emit();
		}
		return baseBackoffSeconds;
	}
}