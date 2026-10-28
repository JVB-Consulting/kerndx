// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base class for all outbound web service calls. Extends API_Base to provide functionality
 * for making HTTP callouts, handling responses, managing retries, and token replacements.
 *
 * @see API_Outbound_TEST
 * @see API_PostExample_TEST
 * @see API_GetPwndPasswords_TEST
 * @see UTIL_HttpClientRetryTiming_TEST
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
	public static final String FLAG_DISABLE_ALL_OUTBOUND_APIS = 'DisableAllOutboundAPIs';

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
	 * @description The idempotency key the framework worked out for this outbound call (the key stamped on the call, or one
	 * built under Idempotency Enabled). It is recorded on the call and its issue only when no request was sent (see
	 * getRecordedIdempotencyKey()), and whether a repeat is safe is never judged from it (see isSafeToRepeat()).
	 */
	private String outboundIdempotencyKey;

	/**
	 * @description The request handed to the send point by the last send of this call: the one createRequest() returned,
	 * which a handler's override may have built or changed after the framework set its headers. Null until a send is
	 * attempted.
	 */
	private HttpRequest sentRequest;

	/**
	 * @description When true, retry() returns immediately: this handler instance performs no
	 * NextRetry__c self-scheduling. Instance-scoped on purpose: a fresh handler instance always
	 * starts unsuppressed, and the flag never expires mid-lifecycle (a silently expiring
	 * suppression would be a worse failure mode than instance reuse, which the framework does not
	 * do).
	 */
	private Boolean selfRetrySchedulingSuppressed = false;

	/**
	 * @description The HTTP status codes the framework retries by default when the external system responds with one of
	 * them: 408, 425, 429, 500, 502, 503 and 504. Any other status ends the call Failed at once. 408, 425, 429 and 503 say
	 * the external system did not process the request, so they are retried for every request; 500, 502 and 504 can follow
	 * a request it processed, so they are retried only for a request that is safe to repeat. UTIL_HttpClient's synchronous
	 * loop reads the same set through getRetryableStatusCodes(), so the attempts made in one transaction and the attempts
	 * scheduled for later agree on which responses are worth a retry.
	 */
	public static final Set<Integer> DEFAULT_RETRYABLE_STATUS_CODES = new Set<Integer>
	{
			API_Base.HTTP_REQUEST_TIMEOUT, API_Base.HTTP_TOO_EARLY, API_Base.HTTP_TOO_MANY_REQUESTS, API_Base.HTTP_INTERNAL_SERVER_ERROR,
			API_Base.HTTP_BAD_GATEWAY, API_Base.HTTP_SERVICE_UNAVAILABLE, API_Base.HTTP_GATEWAY_TIMEOUT
	};

	/**
	 * @description The default retryable statuses by which the external system says it did not process the request: 408
	 * (it stopped waiting for the request), 425 (too early), 429 (too many requests) and 503 (unavailable). They are
	 * retried for every request, whatever its method. The other default statuses can follow a request the external
	 * system processed: a 504 means a gateway gave up waiting while the system behind it may have finished, a 502 means
	 * a gateway could not read a response the system may have produced, and a 500 can follow partial processing. Those
	 * three are retried only for a request that is safe to repeat.
	 */
	private static final Set<Integer> NOT_PROCESSED_STATUS_CODES = new Set<Integer>
	{
			API_Base.HTTP_REQUEST_TIMEOUT, API_Base.HTTP_TOO_EARLY, API_Base.HTTP_TOO_MANY_REQUESTS, API_Base.HTTP_SERVICE_UNAVAILABLE
	};

	/**
	 * @description The HTTP methods an external system can receive twice without acting twice (RFC 9110 section 9.2.2), so a
	 * call that got no response may be sent again, in the form a request carries them. POST and PATCH are not among them;
	 * such a call is safe to repeat only with an Idempotency-Key.
	 */
	private static final Set<String> IDEMPOTENT_METHODS = new Set<String> {toHttpString(HttpMethod.GET), toHttpString(HttpMethod.PUT), toHttpString(HttpMethod.DELETION)};

	/**
	 * @description The message the simulated circuit breaker failure throws with, shared by the two guarded breaker calls.
	 */
	private static final String MESSAGE_SIMULATED_CIRCUIT_BREAKER_FAILURE = 'Simulated circuit breaker failure';

	/**
	 * @description The name of the call input that asks for exponential backoff. UTIL_HttpClient writes it with the value
	 * true for a request built with withExponentialBackoff. createRetryStrategy reads it.
	 */
	public static final String INPUT_EXPONENTIAL_BACKOFF = '__exponentialBackoff';

	/**
	 * @description The name of the call input that holds the maximum number of retries the caller asked for.
	 * UTIL_HttpClient writes it for a request built with withRetry or withExponentialBackoff. When it is on the call, it
	 * wins over Max Retry Count in the service setting, on the first run and on every scheduled retry.
	 */
	public static final String INPUT_MAXIMUM_RETRIES = '__maxRetries';

	/**
	 * @description The name of the call input that holds the base wait, in seconds, the caller asked for. UTIL_HttpClient
	 * writes it for a request built with withRetry or withExponentialBackoff. When it is on the call, it wins over Retry
	 * Backoff Seconds in the service setting, on the first run and on every scheduled retry.
	 */
	public static final String INPUT_BASE_BACKOFF_SECONDS = '__backoffSeconds';

	/**
	 * @description Where a failed outbound call stopped. The framework decides whether the call may be tried again from
	 * where it stopped, never from the exception's type or message on its own.
	 */
	private enum FailurePhase
	{
		/**
		 * @description The call was never attempted: the circuit breaker for the service was open, so the framework refused
		 * the call before a request was built. Nothing reached the external system.
		 */
		CIRCUIT_OPEN,
		/**
		 * @description The request was built but never left the org: the platform refused the callout, for example because
		 * the transaction had unsaved work pending. Nothing reached the external system.
		 */
		NOT_SENT,
		/**
		 * @description The handler's own code failed while the request was being prepared, before a callout was attempted.
		 * Nothing reached the external system.
		 */
		BEFORE_SEND,
		/**
		 * @description The request was handed over to be sent and no response came back, for example a timeout or a dropped
		 * connection. The external system may or may not have received the request and acted on it.
		 */
		AT_SEND,
		/**
		 * @description The external system received the request and refused it: it responded with a status that is not a
		 * success.
		 */
		EXTERNAL_SYSTEM_REFUSAL,
		/**
		 * @description The external system accepted the request and responded with a success status, and the call then
		 * failed in this org while the response was read or the handler's records were saved. The external system has
		 * already acted.
		 */
		AFTER_SUCCESS
	}

	/**
	 * @description True once a throw happened inside the send point: the one assignment of response in sendRequest, for
	 * the mocked branch and the real branch alike. A throw anywhere else with no response is the handler's own code.
	 */
	private Boolean failedAtSendPoint = false;

	/**
	 * @description True when the platform refused the callout before the request left the org, for example because the
	 * transaction had unsaved work pending. The framework reads a throw at the platform's send that leaves the count of
	 * callouts unchanged as a callout that never left the org. That reading rests on what tests have shown, not on a rule
	 * the platform documents: the count moves only when the platform tries to send. Nothing reached the external system,
	 * so the call is not one that got no response.
	 */
	private Boolean refusedBeforeLeavingTheOrg = false;

	/**
	 * @description True when validation refused the call because the circuit breaker was open.
	 */
	private Boolean refusedByOpenCircuit = false;

	/**
	 * @description True when the external system may already have acted on the request this call sent: the call got no
	 * response on a request that is not safe to repeat, or the external system accepted it before the call failed in this
	 * org. Copied onto the issue record so the operator sees it before pressing Retry.
	 */
	private Boolean externalSystemMayHaveActed = false;

	/**
	 * @description True when this handler refuses to send the request again: its code threw a
	 * UTIL_Exceptions.PermanentFailureException, or the external system may already have acted on a request that is not
	 * safe to repeat. Worked out only while self-retry scheduling is suppressed, for the caller that owns the retries;
	 * see isRepeatRefusedByTheHandler().
	 */
	private Boolean repeatRefusedByTheHandler = false;

	/**
	 * @description True when the refusal in repeatRefusedByTheHandler came from a UTIL_Exceptions.PermanentFailureException,
	 * the handler's own word that the call must never be retried; see isRepeatRefusedByAPermanentFailure().
	 */
	private Boolean repeatRefusedByAPermanentFailure = false;

	/**
	 * @description True when the retry decision caught a UTIL_Exceptions.PermanentFailureException that marks the call as
	 * a permanent failure (see API_Base.isPermanentFailure), for example one that createRetryStrategy() threw. A
	 * UTIL_Exceptions.RequestRefusedException does not set it. It is set whether or not self-retry scheduling is
	 * suppressed, so the call is marked as a permanent failure on every path (see setApiCallDetails).
	 */
	private Boolean permanentFailureCaughtByTheRetryDecision = false;

	/**
	 * @description Overrides the Named Credential name for this handler instance.
	 * Set by UTIL_HttpClient delegation mode when the caller provides a credential override.
	 */
	@TestVisible
	protected String namedCredentialOverride;

	/**
	 * @description The circuit breaker name a caller chose for this call through UTIL_HttpClient's withCircuitBreaker(String).
	 * Calls that carry the same name share one breaker whatever their service; when it is blank, the breaker is the service's own.
	 */
	protected String circuitBreakerNameOverride;

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
	 * When set, the callout mock registered for the service through API_MockFactory.forService uses
	 * this as fallback when no factory mock is registered.
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
	 * Lazily initialized from ApiSetting__mdt configuration when enabled, under the name getCircuitBreakerName gives.
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
				circuitBreaker = UTIL_CircuitBreaker.fromSetting(getCircuitBreakerName(), setting);
			}
			return circuitBreaker;
		}
		set;
	}

	/**
	 * @description Performs framework-level validation and subscriber validation.
	 * Checks: triggering object, required inputs, settings, circuit breaker, then base validation. A throw inside the
	 * framework checks aborts the call. Its catch leaves lastFailure null on purpose: the retry decision reads a null
	 * failure as an exception type no handler opted in, which is what keeps an Aborted call from being scheduled for a
	 * retry. Setting lastFailure there would let a handler that opts the thrown type in move an Aborted call to Retry.
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
				result.errors.add(System.Label.OutboundCall_TriggeringRecordIdRequired);
				mustAbort = true;
			}

			// Framework validation: required inputs
			Set<String> requiredInputs = getRequiredInputs();
			if(!inputs.allExists(requiredInputs, true))
			{
				result.errors.add(String.format(System.Label.OutboundCall_RequiredParametersMissing, new List<String> {JSON.serialize(requiredInputs)}));
				mustAbort = true;
			}

			// Framework validation: settings
			if(setting == null)
			{
				result.errors.add(String.format(System.Label.OutboundCall_ApiSettingNotFound, new List<String> {getServiceName()}));
				mustAbort = true;
			}

			// Framework validation: circuit breaker
			if(isCircuitBreakerEnabled() && !circuitBreaker.allowRequest())
			{
				refusedByOpenCircuit = true;
				result.errors.add(String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {getCircuitBreakerName()}));
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
	 * The request this method returns is the one sent, and whether a failed call is safe to send again is judged from its
	 * method and headers: a GET, PUT or DELETE, or a request that carries an Idempotency-Key header, is safe to repeat,
	 * and a POST or PATCH that drops the header (for example a new request your override builds without copying it) is
	 * treated as not safe to repeat, even when Idempotency Enabled is on or the call has a key. A key your override sets on
	 * the request itself counts as sent, and the key recorded on the call and its issue is the one the request carried.
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
	 * @description Reads the required inputs this service declares, through the subscriber's `getRequiredInputs()`
	 * override, for package callers that are not subclasses (the API Test Harness describes a service with it before
	 * the administrator executes). Never null.
	 *
	 * @return The declared required input names, or an empty set
	 */
	public Set<String> describeRequiredInputs()
	{
		return getRequiredInputs() ?? new Set<String>();
	}

	/**
	 * @description Reads whether this service declares that a triggering record Id must accompany the call, as set in
	 * `configure()`, for package callers that are not subclasses.
	 *
	 * @return True when a triggering record Id is required
	 */
	public Boolean isTriggeringRecordRequired()
	{
		return requiresTriggeringRecord == true;
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
	 * @description Resolves the failed API call. When a call succeeds, every open issue logged for the same request (the
	 * same triggering record, service and request parameters) is marked Resolved, with the time it was resolved, whoever
	 * made the call that failed. The read and the save both waive record sharing on purpose: the framework is closing its
	 * own record of a failed request, and API issues are Private.
	 *
	 * @example
	 * ```apex
	 * protected override void resolveApiIssues()
	 * {
	 *     super.resolveApiIssues();
	 *     // additional failure resolution
	 * }
	 * ```
	 */
	protected override virtual void resolveApiIssues()
	{
		String hashParameter = generateApiIssueHash();
		List<ApiIssue__c> updateApiIssues = new List<ApiIssue__c>();

		List<ApiIssue__c> apiIssues =
				new SEL_ApiIssue().findByFailedApiCall(apiCall.TriggeringRecordId__c, apiCall.ServiceName__c, hashParameter);

		Datetime resolvedDate = Datetime.now();

		for(ApiIssue__c apiIssue : apiIssues)
		{
			apiIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
			apiIssue.ResolvedDate__c = resolvedDate;
			updateApiIssues.add(apiIssue);
		}

		DML_Builder.newTransaction().withSystemMode().bypassSharingInternal().doUpdate(updateApiIssues).allowPartial().execute();
	}

	/**
	 * @description Performs actions before the framework saves the call's changes to the database. It runs once for each
	 * attempt of the save: an attempt the platform refused for a row lock is tried again once, and this method runs again
	 * for the new attempt. So write what you add here so that it is safe to run more than once. Always call
	 * super.onCommitWorkStarting() first: it prepares the save and the logging for the call.
	 *
	 * @since 1.10
	 *
	 * @example
	 * ```apex
	 * global override void onCommitWorkStarting()
	 * {
	 *     super.onCommitWorkStarting();
	 *     // work to do before the save
	 * }
	 * ```
	 */
	global override virtual void onCommitWorkStarting()
	{
		super.onCommitWorkStarting();
	}

	/**
	 * @description Sends the HTTP request to the specified endpoint and processes the response. In a unit test it
	 * answers from the handler's mock instead of sending; inside an Apex integration test the call reaches the
	 * endpoint unless a mock is registered. Integrates with circuit breaker when enabled to prevent cascading failures.
	 * A throw inside the send itself, from the real send and from the mocked response alike, marks the call as one that got
	 * no response and counts one failure on the circuit breaker before it leaves this method; a throw from anywhere else is
	 * the handler's own code. One throw at the real send is set apart: when the platform's count of callouts did not move,
	 * the framework takes it that the platform refused the callout before the request left the org (as when unsaved work
	 * is pending in the transaction), so the call is marked as never sent, no circuit breaker failure is counted and a warning is logged. Both markers start
	 * clear on every call of this method, so one send's outcome never decides the next. It keeps the request it is handed,
	 * so whether a repeat is safe is judged from the Idempotency-Key header of the request that was sent.
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
		sentRequest = requestObj;
		failedAtSendPoint = false;
		refusedBeforeLeavingTheOrg = false;
		Integer calloutsUsedBeforeTheSend;

		try
		{
			if(result.isMocked)
			{
				response = createEndpointMock().respond(requestObj);
			}
			else
			{
				if(Test.isRunningTest() && (!UTIL_System.isRunningIntegrationTest() || API_MockFactory.hasMock(getServiceName())))
				{
					Test.setMock(HttpCalloutMock.class, createEndpointMock());
				}
				calloutsUsedBeforeTheSend = UTIL_Limits.callouts().used();
				response = httpObject.send(requestObj);
			}
		}
		catch(Exception sendFailure)
		{
			if(calloutsUsedBeforeTheSend != null && UTIL_Limits.callouts().used() == calloutsUsedBeforeTheSend)
			{
				refusedBeforeLeavingTheOrg = true;
				LOG_Builder.build().warn('The callout was refused before it left the org: ' + sendFailure.getMessage()).at(getServiceName() + '/sendRequest').emit();
			}
			else
			{
				failedAtSendPoint = true;
				recordCircuitBreakerFailureSafely();
			}
			throw sendFailure;
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
	 * @description Counts one circuit breaker failure for a callout that got no response, inside a guard: the breaker
	 * writes Platform Cache, and a cache failure must never replace the transport exception the caller is about to see.
	 */
	private void recordCircuitBreakerFailureSafely()
	{
		try
		{
			if(simulateCircuitBreakerFailure)
			{
				throw new UTIL_Exceptions.IllegalStateException(MESSAGE_SIMULATED_CIRCUIT_BREAKER_FAILURE);
			}
			if(isCircuitBreakerEnabled())
			{
				circuitBreaker.recordFailure();
			}
		}
		catch(Exception breakerFailure)
		{
			LOG_Builder.build().warn('Circuit breaker could not record the transport failure: ' + breakerFailure.getMessage()).at(getServiceName() + '/sendRequest').emit();
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
	 * Priority: 1) Pre-set key on apiCall (subscriber-provided, always sent regardless of
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
	 * @description The name this call's circuit breaker is kept under: the name the caller chose, else the service name.
	 * The open-circuit error line names the same breaker.
	 *
	 * @return The circuit breaker name.
	 */
	private String getCircuitBreakerName()
	{
		return String.isBlank(circuitBreakerNameOverride) ? getServiceName() : circuitBreakerNameOverride;
	}

	/**
	 * @description Whether validation refused the call for the open circuit breaker and nothing else, on a call whose
	 * setting allows retries. Such a call is marked failed instead of aborted, so the retry decision runs: with budget left
	 * it schedules the call at the breaker's cool-off and spends one attempt; with the budget spent the strategy refuses
	 * and the call ends Failed with one issue, as any failure whose retries are used up does, never a loop. A call whose
	 * setting allows no retries, or a call refused for any other reason beside the open circuit, ends Aborted as every
	 * validation refusal does. Only the framework's own checks made before the circuit breaker can count as another
	 * reason: once the breaker refuses, the handler's own validation (getValidationErrors() and a performValidation
	 * override) is not run. It runs on the retry, so a call it would refuse waits the cool-off, spends one attempt and is
	 * Aborted then.
	 *
	 * @return True when the open circuit was the only refusal and the setting allows retries.
	 */
	private Boolean isOpenCircuitRefusalOfARetryableCall()
	{
		return refusedByOpenCircuit && result.errors.size() == 1 && getMaximumRetries() > 0;
	}

	/**
	 * @description The maximum number of retries of this call. The value the caller asked for (see INPUT_MAXIMUM_RETRIES)
	 * wins when the call carries it. Otherwise it is Max Retry Count in the service setting, or 0 without a setting.
	 *
	 * @return The maximum number of retries.
	 */
	private Integer getMaximumRetries()
	{
		String callersMaximum = inputs.get(INPUT_MAXIMUM_RETRIES);
		return callersMaximum != null ? Integer.valueOf(callersMaximum) : (setting?.MaxRetryCount__c ?? 0).intValue();
	}

	/**
	 * @description The base wait, in seconds, before a scheduled retry of this call. The value the caller asked for (see
	 * INPUT_BASE_BACKOFF_SECONDS) wins when the call carries it. Otherwise it is Retry Backoff Seconds in the service
	 * setting, or 0 without a setting.
	 *
	 * @return The base wait, in seconds.
	 */
	private Integer getBaseBackoffSeconds()
	{
		String callersBaseBackoff = inputs.get(INPUT_BASE_BACKOFF_SECONDS);
		return callersBaseBackoff != null ? Integer.valueOf(callersBaseBackoff) : (setting?.RetryBackoffSeconds__c ?? 0).intValue();
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
	 * @description Builds the issue record for an outbound call that failed: the record every direction shares (see
	 * API_Base.buildFailureRecord) plus the outbound fields, which are the Outbound direction, the call's request
	 * parameters and the hash of those parameters. A later success of the same request finds the issue by that hash. The
	 * record is not saved.
	 *
	 * @param apiCall The outbound call that failed.
	 * @param requestHash The hash of the call's request parameters.
	 *
	 * @return A new outbound issue record for the call, not yet saved.
	 */
	public static ApiIssue__c buildOutboundFailureRecord(ApiCall__c apiCall, String requestHash)
	{
		ApiIssue__c apiIssue = API_Base.buildFailureRecord(apiCall);
		apiIssue.Direction__c = SEL_ApiIssue.DIRECTION_OUTBOUND;
		apiIssue.RequestParameters__c = apiCall.RequestParameters__c;
		apiIssue.RequestParametersHash__c = requestHash;
		return apiIssue;
	}

	/**
	 * @description Creates the issue record for this failed call when its setting has Log Issues on: the outbound issue
	 * (see buildOutboundFailureRecord) with the Idempotency-Key the call recorded and whether the external system may
	 * have acted on the request. The setting is checked here as well as in the step after the commit, because the
	 * dispatcher's error handling asks for this record, and the HTTP client saves it, outside that step.
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
			apiIssue = buildOutboundFailureRecord(apiCall, generateApiIssueHash());

			String recordedIdempotencyKey = getRecordedIdempotencyKey();
			if(String.isNotBlank(recordedIdempotencyKey))
			{
				apiIssue.IdempotencyKey__c = recordedIdempotencyKey;
			}
			apiIssue.ExternalSystemMayHaveActed__c = externalSystemMayHaveActed;
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
			if(isOpenCircuitRefusalOfARetryableCall())
			{
				result.hasFailed = true;
			}
			else
			{
				result.isAborted = true;
			}
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
					lastFailure = parseFailure;
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
	 * @description The method of the request that was sent, in the form the call record's HttpMethod__c picklist holds
	 * (GET, POST, PUT, PATCH or DELETE), whatever its letter case. A method the picklist does not hold (a createRequest()
	 * override that sends HEAD, OPTIONS or TRACE) records the method the handler declares instead, because the picklist
	 * is restricted and an unknown value would make the save of every call in the batch fail.
	 *
	 * @return The method to record.
	 */
	private String resolveSentHttpMethod()
	{
		try
		{
			return toHttpString(fromHttpString(sentRequest.getMethod()) ?? getHttpMethod());
		}
		catch(NoSuchElementException methodNotInThePicklist)
		{
			return toHttpString(getHttpMethod());
		}
	}

	/**
	 * @description Persists call results back to API Call. The Idempotency-Key recorded on the call and the request headers
	 * logged for it are those of the request that was sent, so the record never shows a key that did not leave the org: a
	 * key stamped on the call is cleared when the request sent dropped it. Before a send was attempted the call keeps its
	 * own key or takes the one the framework worked out, and the headers are those of the request the framework built.
	 * The HTTP method follows the same rule: the method of the request that was sent, normalised to a picklist value, or
	 * the declared getHttpMethod() before a send and when the sent method is not a picklist value (see
	 * resolveSentHttpMethod). On every run, after the retry decision, the call is marked as a permanent failure or not
	 * (see hasFailedPermanently).
	 */
	public override virtual void setApiCallDetails()
	{
		super.setApiCallDetails();
		apiCall.MaxRetries__c = getMaximumRetries();

		if(outboundTraceContext != null)
		{
			apiCall.TraceId__c = outboundTraceContext.traceId;
			apiCall.ParentSpanId__c = outboundTraceContext.parentSpanId;
		}

		String recordedIdempotencyKey = getRecordedIdempotencyKey();
		if(sentRequest != null || String.isNotBlank(recordedIdempotencyKey))
		{
			apiCall.IdempotencyKey__c = recordedIdempotencyKey;
		}

		if(sentRequest != null)
		{
			apiCall.HttpMethod__c = resolveSentHttpMethod();
		}

		HttpRequest loggedRequest = sentRequest ?? request;
		for(String key : new List<String>
		{
				HTTP_CONTENT_TYPE, HTTP_HEADER_AUTHORIZATION, HTTP_HEADER_ACCEPT,
				HEADER_TRACE_PARENT, HEADER_IDEMPOTENCY_KEY
		})
		{
			String value = loggedRequest.getHeader(key);
			if(value != null)
			{
				result.requestHeaders.add(key, value);
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
			apiCall.ErrorMessages__c = errorText;
		}

		apiCall.IsPermanentFailure__c = hasFailedPermanently();
	}

	/**
	 * @description Whether this call failed in a way that sending the same request again cannot fix. That is true when the
	 * call did not succeed (it ended Failed, or Aborted by its checks) and a UTIL_Exceptions.PermanentFailureException
	 * was thrown: by the handler's own code (lastFailure), by getValidationErrors() (validationFailure), or inside the
	 * retry decision, for example by createRetryStrategy(). A UTIL_Exceptions.RequestRefusedException does not count
	 * (see API_Base.isPermanentFailure): a person can run a refused call again once the cause is fixed. The answer does
	 * not depend on whether self-retry scheduling is suppressed, so the dispatcher, Retry and the async chain all mark the
	 * call the same way.
	 *
	 * @return True when the call failed permanently.
	 */
	private Boolean hasFailedPermanently()
	{
		Boolean hasNotSucceeded = result.hasFailed || result.isAborted;
		Boolean wasPermanentFailureThrown = isPermanentFailure(lastFailure) || isPermanentFailure(validationFailure) || permanentFailureCaughtByTheRetryDecision;
		return hasNotSucceeded && wasPermanentFailureThrown;
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
	 * @description Creates the retry strategy for a failed call. Override it to give a handler its own backoff, or to
	 * refuse a retry the framework would otherwise allow.
	 * It runs once for each failed call, after the response has arrived (or after the failure, when there was no
	 * response). It runs on the same handler instance that ran prepareRequest(), parseResponse() and onSuccess(), so
	 * you may read response, result.statusCode and result.responseBody, and result.errors holds the failure text.
	 * The context the strategy receives carries the retry count. When the failure was an exception (a parse failure, a
	 * throw from your own code, or a callout that got no response), the context carries that exception too. A failure
	 * by status carries no exception, so an allowlist does not stop it and a denylist cannot match it: use
	 * getRetryableStatusCodes() for statuses.
	 * To refuse the retry, return a strategy whose shouldRetry returns false (UTIL_Retry.linear().withMaxRetries(0)),
	 * or throw UTIL_Exceptions.PermanentFailureException. Any other throw ends the call Failed with a warning in the
	 * log.
	 * The framework decides first, from where the failure happened. The strategy is asked only about a failure the
	 * framework may retry.
	 *
	 * The default strategy reads the service setting: Retry Backoff Seconds is the base wait, and Max Retry Count is the
	 * number of retries. A call made through UTIL_HttpClient with withRetry or withExponentialBackoff uses the number of
	 * retries passed there, and the base wait when one was passed, instead of the setting's values, on every run. It waits the base before the first scheduled retry,
	 * and then the base times the number of retries already made. A call made with withExponentialBackoff gets a
	 * different wait: the base before the first retry, then twice as long each time, up to 300 seconds. For a base of 30
	 * seconds that is 30, 60, 120, 240 and then 300 seconds. The retries already made count, including the ones sent
	 * again at once in the same transaction. This also holds for your handler when it is called through
	 * UTIL_HttpClient.useHandler, unless your handler overrides this method: then your strategy decides.
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
		UTIL_Retry.Strategy strategy = 'true'.equalsIgnoreCase(inputs.get(INPUT_EXPONENTIAL_BACKOFF)) ? UTIL_Retry.exponential() : UTIL_Retry.linear();

		return strategy
				.withBaseBackoff(getBaseBackoffSeconds())
				.withMaxRetries(getMaximumRetries());
	}

	/**
	 * @description The HTTP status codes the framework may retry when the external system responds with one of them.
	 * The default is 408, 425, 429, 500, 502, 503 and 504. Any other status ends the call Failed at once.
	 * A 408, 425, 429 or 503 means the external system did not process the request, so it is retried for every request.
	 * A 500, 502 or 504 can come after the external system processed the request, so it is retried only when the
	 * request is safe to repeat: a GET, PUT or DELETE, or a request that sent an Idempotency-Key. A POST or PATCH
	 * without a key that gets one of those three ends Failed at once, and its issue says the external system may have
	 * acted.
	 * Override this method to add a code your external system uses to mean "try later", or to remove one. An empty set,
	 * or null, retries no status. A code you add that is not in the default list is your own choice, so it is retried
	 * for every request, whatever its method. Adding it does not change how 500, 502 and 504 are treated.
	 * This method does for a handler what UTIL_HttpClient's retryOn(...) does for a call built with UTIL_HttpClient,
	 * with one difference: a 500, 502 or 504 you name in retryOn is retried whatever the method, while one returned
	 * here is not.
	 * A callout the platform refused before it left your org (for example because unsaved work was pending) has no
	 * status, so this method does not decide it. Nothing was sent, so it is tried again while retries remain, whatever
	 * the HTTP method.
	 *
	 * @return The status codes a retry may follow.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * global override Set<Integer> getRetryableStatusCodes()
	 * {
	 *     Set<Integer> codes = super.getRetryableStatusCodes();
	 *     codes.add(409);
	 *     return codes;
	 * }
	 * ```
	 */
	global protected virtual Set<Integer> getRetryableStatusCodes()
	{
		return new Set<Integer>(DEFAULT_RETRYABLE_STATUS_CODES);
	}

	/**
	 * @description The exception types from your own code that the framework may retry. By default none: code that ran in
	 * your org and threw fails the same way on every attempt, so the call ends Failed at once with one issue. List a
	 * type here when a failure of that type can pass on its own, for example a row lock in a selector. A type is matched
	 * by its exact name; list each concrete type you throw, because a parent type such as Exception matches nothing.
	 * After a successful response the framework retries a listed type only when the request is safe to repeat: GET, PUT,
	 * DELETE, or an Idempotency-Key was sent. A callout that got no response retries on a safe-to-repeat request without
	 * being listed here; listing System.CalloutException retries it on a POST without an Idempotency-Key too, at your own risk.
	 *
	 * @return The exception types a retry may follow; empty by default.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * global override Set<Type> getRetryableExceptionTypes()
	 * {
	 *     return new Set<Type> {System.QueryException.class};
	 * }
	 * ```
	 */
	global protected virtual Set<Type> getRetryableExceptionTypes()
	{
		return new Set<Type>();
	}

	/**
	 * @description Framework-internal: turns off this handler instance's own retry scheduling, so that a caller that
	 * manages the retries itself (the async chain's per-step retry) is the only code that schedules them. It applies to
	 * this instance only: other instances of the same service in the same transaction keep scheduling their own
	 * retries.
	 *
	 * @since 1.6
	 */
	public void suppressSelfRetryScheduling()
	{
		selfRetrySchedulingSuppressed = true;
	}

	/**
	 * @description Whether this handler refuses to send the request of the call just made again, for one of two reasons.
	 * Its own code threw a UTIL_Exceptions.PermanentFailureException, which says the call must not be retried, whatever
	 * the method or key. Or the external system may already have acted on a request that is not safe to repeat (a POST or
	 * PATCH sent with no Idempotency-Key): the call got no response, the external system responded with a 500, 502 or
	 * 504, or the external system accepted the request and the call then failed in this org; the call's errors then start
	 * with the line that says why, whether or not the handler's retryable set holds the status. A request that is safe to
	 * repeat, a callout that never left the org and every other failure return false. Framework-internal: it serves the
	 * caller that owns the retries (the async chain's API step), so it is worked out only while self-retry scheduling
	 * is suppressed, and it ignores this handler's own retry budget.
	 *
	 * @return True when the handler refuses the repeat.
	 */
	public Boolean isRepeatRefusedByTheHandler()
	{
		return repeatRefusedByTheHandler;
	}

	/**
	 * @description Whether this handler's refusal (see isRepeatRefusedByTheHandler()) came from a
	 * UTIL_Exceptions.PermanentFailureException, thrown by the handler's own code or by one of the hooks the refusal read
	 * calls. Such a refusal is the handler's explicit word that the call must never be retried, so it outranks a status
	 * the caller that owns the retries chose to repeat. Framework-internal, worked out like isRepeatRefusedByTheHandler().
	 *
	 * @return True when a permanent failure refuses the repeat.
	 */
	public Boolean isRepeatRefusedByAPermanentFailure()
	{
		return repeatRefusedByAPermanentFailure;
	}

	/**
	 * @description Whether this handler's request is safe to send again, judged before any send from what the handler
	 * declares: its getHttpMethod() is a GET, PUT or DELETE, or its service setting has Idempotency Enabled, so the engine
	 * sends an Idempotency-Key with every attempt. It reads the setting the handler loads anyway and makes no callout. The
	 * handler is judged as created, with no parameters, triggering record or credential applied, so a getHttpMethod() that
	 * depends on those inputs is judged on the answer it gives without them. A handler whose createRequest() override drops
	 * the Idempotency-Key header is still judged keyed here, because only the request that was sent shows the drop.
	 * Framework-internal: the async chain's API step answers isIdempotent() with it when the chain is built.
	 *
	 * @return True when the declared request is safe to repeat.
	 */
	public Boolean isDeclaredRequestSafeToRepeat()
	{
		return IDEMPOTENT_METHODS.contains(toHttpString(getHttpMethod())) || setting?.IdempotencyEnabled__c == true;
	}

	/**
	 * @description Decides whether the failed call is scheduled for another attempt, and schedules it when it is. It first
	 * derives where the call failed and marks whether the external system may already have acted, on every path, so the
	 * issue record always carries that fact. When this instance's self-retry scheduling is suppressed it schedules
	 * nothing and only works out, for the caller that owns the retries, whether this handler refuses the repeat (see
	 * isRepeatRefusedByTheHandler()). Everything runs inside one guard: a throw from the strategy, from a hook or from
	 * the breaker is logged at warn and ends the call Failed with the labelled text, so one handler's bug never costs the
	 * dispatcher its batch; a UTIL_Exceptions.PermanentFailureException thrown there is the refusal it means: it is not
	 * logged as a failure of the decision, and while self-retry scheduling is suppressed it refuses the repeat for the
	 * caller that owns the retries, as one the handler's own code threw does.
	 */
	private void retry()
	{
		try
		{
			FailurePhase phase = resolveFailurePhase();
			externalSystemMayHaveActed = canTheExternalSystemHaveActed(phase);
			if(selfRetrySchedulingSuppressed)
			{
				refuseTheRepeatForTheCallerThatOwnsTheRetries(phase);
			}
			else
			{
				scheduleRetryWhenAllowed(phase);
			}
		}
		catch(UTIL_Exceptions.PermanentFailureException refusal)
		{
			permanentFailureCaughtByTheRetryDecision = isPermanentFailure(refusal);
			repeatRefusedByTheHandler = selfRetrySchedulingSuppressed;
			repeatRefusedByAPermanentFailure = selfRetrySchedulingSuppressed;
			result.errors.add(refusal.getMessage());
		}
		catch(Exception decisionFailure)
		{
			LOG_Builder.build().warn('The retry decision failed: ' + decisionFailure.getMessage()).at(getServiceName() + '/retry').emit();
			result.errors.add(String.format(System.Label.OutboundCall_RetryDecisionFailed, new List<Object> {getServiceName(), decisionFailure.getMessage()}));
		}
	}

	/**
	 * @description The retry decision, in order: a UTIL_Exceptions.PermanentFailureException refuses; the phase rule
	 * refuses what a repeat cannot fix; the strategy (with the kept exception in its context, so the shipped filters see
	 * it) applies the budget and the filters; the backoff is stretched to the breaker's cool-off when the circuit is open
	 * or the circuit breaker refused the call, a half-open circuit with no trial request left included;
	 * a positive wait is scheduled through SEL_ApiCall.updateNextRetryInfo, which sets Retry, the time and the count
	 * together. A zero wait schedules nothing.
	 *
	 * @param phase Where the call failed.
	 */
	private void scheduleRetryWhenAllowed(FailurePhase phase)
	{
		if(lastFailure instanceof UTIL_Exceptions.PermanentFailureException)
		{
			return;
		}

		if(!isRetryableByPhase(phase))
		{
			noteWhyTheCallIsNotRetried(phase);
			return;
		}

		UTIL_Retry.Strategy retryStrategy = createRetryStrategy();
		UTIL_Retry.Context retryContext = UTIL_Retry.newContext((apiCall.Retries__c ?? 0).intValue()).withCustomData(lastFailure);
		if(!retryStrategy.shouldRetry(retryContext))
		{
			return;
		}

		Integer backoffSeconds = applyCircuitBreakerBackoff(retryStrategy.calculateBackoff(retryContext));
		if(backoffSeconds > 0)
		{
			SEL_ApiCall.updateNextRetryInfo(apiCall, Datetime.now().addSeconds(backoffSeconds));
		}
	}

	/**
	 * @description For a call whose retries another caller owns: works out whether this handler refuses the repeat. A
	 * UTIL_Exceptions.PermanentFailureException kept for the call refuses it, whatever the method or key; its message is
	 * already among the call's errors. Otherwise the repeat is refused when the external system may have acted, the
	 * request is not safe to repeat and the phase rule refuses it, whether or not the handler's retryable set holds a
	 * 500, 502 or 504: leaving such a status out of the set says less about retrying, never that an unsafe request may be
	 * sent again. The line that says why is then put first among the call's errors, so a caller that keeps only the start
	 * of the error text still shows it. The hooks are read only once the external system may have acted and the request
	 * is not safe to repeat.
	 *
	 * @param phase Where the call failed.
	 */
	private void refuseTheRepeatForTheCallerThatOwnsTheRetries(FailurePhase phase)
	{
		if(lastFailure instanceof UTIL_Exceptions.PermanentFailureException)
		{
			repeatRefusedByTheHandler = true;
			repeatRefusedByAPermanentFailure = true;
			return;
		}
		repeatRefusedByTheHandler = externalSystemMayHaveActed && !isSafeToRepeat() && !isRetryableByPhase(phase);
		if(repeatRefusedByTheHandler)
		{
			List<String> errorsSoFar = result.errors.clone();
			result.errors.clear();
			result.errors.add(describeWhyTheRequestIsNotSentAgain(phase));
			result.errors.addAll(errorsSoFar);
		}
	}

	/**
	 * @description Derives where the call failed from what this instance holds: the open-circuit flag, the marker of a
	 * callout the platform refused before it left the org, the send-point marker, then the response (none means the
	 * handler's own code threw before the send; a success status means the handler's handling of the response threw; any
	 * other status is the external system's refusal).
	 *
	 * @return The failure phase.
	 */
	private FailurePhase resolveFailurePhase()
	{
		if(refusedByOpenCircuit)
		{
			return FailurePhase.CIRCUIT_OPEN;
		}
		if(refusedBeforeLeavingTheOrg)
		{
			return FailurePhase.NOT_SENT;
		}
		if(failedAtSendPoint)
		{
			return FailurePhase.AT_SEND;
		}
		if(response == null)
		{
			return FailurePhase.BEFORE_SEND;
		}
		return HTTP_SUCCESS_CODES.contains(response.getStatusCode()) ? FailurePhase.AFTER_SUCCESS : FailurePhase.EXTERNAL_SYSTEM_REFUSAL;
	}

	/**
	 * @description The phase rule: an open circuit may retry (the cool-off is the wait); a callout the platform refused
	 * before it left the org may retry whatever its method, because nothing was sent and a repeat in a later transaction
	 * is what fixes it; a refusal by the external system when the status is in the retryable set (a null set reads as
	 * empty) and either a repeat after that status is safe (see isUnsafeToRepeatAfterStatus) or the handler chose the
	 * status itself (see isStatusTheHandlersOwnChoice); a throw before the send only when its exact type is opted in; a
	 * callout that got no response when the request is safe to repeat or the type is opted in; a throw after a success
	 * only when the type is opted in and the request is safe to repeat. The type compared is that of lastFailure, the
	 * exception kept for this call, which is null for a status failure. Each hook is read only by the phases that need
	 * it, so a throwing override of one never decides a phase that does not use it.
	 *
	 * @param phase Where the call failed.
	 *
	 * @return True when the framework may consult the strategy about a retry.
	 */
	private Boolean isRetryableByPhase(FailurePhase phase)
	{
		if(phase == FailurePhase.CIRCUIT_OPEN || phase == FailurePhase.NOT_SENT)
		{
			return true;
		}
		if(phase == FailurePhase.EXTERNAL_SYSTEM_REFUSAL)
		{
			Integer statusCode = response.getStatusCode();
			return isRetryableStatus(statusCode) && (!isUnsafeToRepeatAfterStatus(statusCode) || isStatusTheHandlersOwnChoice(statusCode));
		}
		Boolean isTypeOptedIn = UTIL_Retry.matchesExceptionType(lastFailure, getRetryableExceptionTypes());
		if(phase == FailurePhase.BEFORE_SEND)
		{
			return isTypeOptedIn;
		}
		if(phase == FailurePhase.AT_SEND)
		{
			return isSafeToRepeat() || isTypeOptedIn;
		}
		return isSafeToRepeat() && isTypeOptedIn;
	}

	/**
	 * @description Whether sending this request again cannot make the external system act twice: the request handed to the
	 * send point went as a GET, PUT or DELETE, or carried a non-blank Idempotency-Key header. Both are read from the
	 * request that was sent, whoever set them: a key the framework worked out (stamped on the call, or built under
	 * Idempotency Enabled) counts only when the request sent still carries it, a key a handler's createRequest() override
	 * set itself counts too, and a method an override changed on the request is the method judged. Before a send was
	 * attempted the handler's getHttpMethod() alone decides; no failure that happens before the send asks.
	 *
	 * @return True when a repeat is safe.
	 */
	private Boolean isSafeToRepeat()
	{
		String sentMethod = sentRequest != null ? sentRequest.getMethod() : toHttpString(getHttpMethod());
		return IDEMPOTENT_METHODS.contains(sentMethod?.toUpperCase()) || String.isNotBlank(sentRequest?.getHeader(HEADER_IDEMPOTENCY_KEY));
	}

	/**
	 * @description The Idempotency-Key to record on the call and its issue: the header of the request that was sent when a
	 * send was attempted, which is blank when that request dropped the key; otherwise the key the framework worked out,
	 * so a call that failed before the send keeps the key a retry should start from.
	 *
	 * @return The key to record, or null when there is none.
	 */
	private String getRecordedIdempotencyKey()
	{
		return sentRequest != null ? sentRequest.getHeader(HEADER_IDEMPOTENCY_KEY) : outboundIdempotencyKey;
	}

	/**
	 * @description Whether sending this request again after this status could make the external system act twice: the
	 * status is one of the default retryable statuses that can follow a request the external system processed (500, 502
	 * and 504, the default set less NOT_PROCESSED_STATUS_CODES) and the request is not safe to repeat. A status a
	 * handler adds to its retryable set is not in the default set, so it never counts here. This is the fact the issue's
	 * flag records, whatever a handler then chooses. The scheduled retry sends such a request again only when
	 * isStatusTheHandlersOwnChoice says the handler chose the status; UTIL_HttpClient's synchronous loop re-sends it only
	 * when the caller named the status in retryOn(...).
	 *
	 * @param statusCode The status the external system responded with.
	 *
	 * @return True when a repeat after this status is not safe.
	 */
	protected Boolean isUnsafeToRepeatAfterStatus(Integer statusCode)
	{
		return DEFAULT_RETRYABLE_STATUS_CODES.contains(statusCode) && !NOT_PROCESSED_STATUS_CODES.contains(statusCode) && !isSafeToRepeat();
	}

	/**
	 * @description Whether the handler chose this status itself, so the scheduled retry may send the request again after
	 * it even when the request is not safe to repeat. By default a status counts as the handler's own choice when the
	 * handler's getRetryableStatusCodes() override added it, which means it is not in the default set; a 500, 502 or 504
	 * is never chosen this way, because those are in the default set. UTIL_HttpClient's ad-hoc handler overrides this to
	 * count every code the caller named in retryOn(...). The retry decision asks only about a 500, 502 or 504 sent in a
	 * request that is not safe to repeat, so this base answer is always false where it is read; the body states the rule
	 * an override widens rather than returning false outright.
	 *
	 * @param statusCode The status the external system responded with.
	 *
	 * @return True when the handler chose the status.
	 */
	protected virtual Boolean isStatusTheHandlersOwnChoice(Integer statusCode)
	{
		return !DEFAULT_RETRYABLE_STATUS_CODES.contains(statusCode);
	}

	/**
	 * @description Whether the status is in the handler's retryable set, read through getRetryableStatusCodes(); a null
	 * set reads as empty.
	 *
	 * @param statusCode The status the external system responded with.
	 *
	 * @return True when the handler's set holds the status.
	 */
	private Boolean isRetryableStatus(Integer statusCode)
	{
		return (getRetryableStatusCodes() ?? new Set<Integer>()).contains(statusCode);
	}

	/**
	 * @description Whether the external system may already have acted on this call, the fact the issue's
	 * ExternalSystemMayHaveActed__c field records: after a success status it did act, unless parseResponse() threw a
	 * UTIL_Exceptions.RequestRefusedException, which says the body refused the request; a request that got no response may
	 * have reached it unless a repeat is safe; a 500, 502 or 504 to a request that is not safe to repeat may follow a
	 * request it processed. The fact depends only on where the call failed and on the request, never on whether a
	 * handler then allows a retry.
	 *
	 * @param phase Where the call failed.
	 *
	 * @return True when the external system may have acted.
	 */
	private Boolean canTheExternalSystemHaveActed(FailurePhase phase)
	{
		if(phase == FailurePhase.EXTERNAL_SYSTEM_REFUSAL)
		{
			return isUnsafeToRepeatAfterStatus(response.getStatusCode());
		}
		if(phase == FailurePhase.AFTER_SUCCESS)
		{
			return !isRequestRefusedWhileReadingTheResponse();
		}
		return phase == FailurePhase.AT_SEND && !isSafeToRepeat();
	}

	/**
	 * @description Whether the handler's parseResponse() threw a UTIL_Exceptions.RequestRefusedException: the external system
	 * answered with a success status whose body says it refused the request, so it did not act. The same exception thrown
	 * anywhere else does not count; once onSuccess() has started, the external system has acted.
	 *
	 * @return True when parseResponse() refused the request.
	 */
	private Boolean isRequestRefusedWhileReadingTheResponse()
	{
		return result.parseError && lastFailure instanceof UTIL_Exceptions.RequestRefusedException;
	}

	/**
	 * @description Adds the labelled reason when the phase rule refused a retry the operator needs to understand: a call
	 * that got no response and was not repeated (the external system may have acted), a call the external system
	 * accepted before the handler's own code failed (the external system did act), or a status in the retryable set that
	 * was not sent again because the request is not safe to repeat (the external system may have processed it). A status
	 * outside the retryable set gets no line: the handler chose not to retry it, so the advice to add a key would not help.
	 * It reads getRetryableStatusCodes() a second time, after isRetryableByPhase read it, on purpose: the line follows the
	 * handler's own set, and a handler whose override answers differently on the two reads has a bug of its own.
	 *
	 * @param phase Where the call failed.
	 */
	private void noteWhyTheCallIsNotRetried(FailurePhase phase)
	{
		Boolean isExplained = phase == FailurePhase.AT_SEND || phase == FailurePhase.AFTER_SUCCESS
				|| (phase == FailurePhase.EXTERNAL_SYSTEM_REFUSAL && isRetryableStatus(response.getStatusCode()));
		if(isExplained)
		{
			result.errors.add(describeWhyTheRequestIsNotSentAgain(phase));
		}
	}

	/**
	 * @description The labelled line that says why the request is not sent again: for a call that got no response, for a
	 * refusal by the external system (its status), and otherwise for a call the external system accepted before the call
	 * failed in this org, the only other phase this is asked about.
	 *
	 * @param phase Where the call failed: no response, a refusal by the external system, or a failure after a success.
	 *
	 * @return The line, formatted with the service name and, where it applies, the status.
	 */
	private String describeWhyTheRequestIsNotSentAgain(FailurePhase phase)
	{
		if(phase == FailurePhase.AT_SEND)
		{
			return String.format(System.Label.OutboundCall_NoResponseNotRepeated, new List<Object> {getServiceName()});
		}
		if(phase == FailurePhase.EXTERNAL_SYSTEM_REFUSAL)
		{
			return String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {getServiceName(), response.getStatusCode()});
		}
		return String.format(System.Label.OutboundCall_ExternalSystemAcceptedBeforeFailure, new List<Object> {getServiceName(), result.statusCode});
	}

	/**
	 * @description Extends the retry backoff to the circuit breaker's cool-off when the circuit refused this call (open, or
	 * half-open with every trial request used) or is open now, ensuring retries do not fire while the external service is
	 * still considered unavailable. It reads only the refusal this call recorded and the breaker's state: working out a
	 * wait sends nothing, so it uses none of the trial requests a half-open circuit lets through.
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
				throw new UTIL_Exceptions.IllegalStateException(MESSAGE_SIMULATED_CIRCUIT_BREAKER_FAILURE);
			}
			if(isCircuitBreakerEnabled() && (refusedByOpenCircuit || circuitBreaker?.getState() == UTIL_CircuitBreaker.State.OPEN))
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