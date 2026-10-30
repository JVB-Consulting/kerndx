// SPDX-License-Identifier: Apache-2.0
/**
 * @description Fluent HTTP client facade over the API_Dispatcher pipeline. Provides zero-boilerplate callouts
 * with automatic retry, circuit breaker, failure logging, performance timing, sensitive data masking,
 * and ApiCall__c lifecycle management, all routed through API_Dispatcher.execute().
 *
 * Supports two usage modes:
 * - Ad-hoc mode: Direct HTTP calls via get()/post()/put()/del()/patch() entry points
 * - Delegation mode: your own handler classes via useHandler() entry point
 *
 * @see UTIL_HttpClient_TEST
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
 * HttpResponse response = UTIL_HttpClient.post('PaymentGateway', '/charges')
 *    .body(chargeRequest)
 *    .withRetry(3)
 *    .send();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.ExcessiveClassLength,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
global inherited sharing class UTIL_HttpClient
{
	/**
	 * @description Parameter key prefix for HttpClient configuration values.
	 */
	private static final String KEY_PREFIX = '__';

	/**
	 * @description Parameter key for the Named Credential name.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	@TestVisible
	private static final String KEY_CREDENTIAL = KEY_PREFIX + 'credential';

	/**
	 * @description Parameter key for the URL path.
	 */
	@TestVisible
	private static final String KEY_PATH = KEY_PREFIX + 'path';

	/**
	 * @description Parameter key for the HTTP method string.
	 */
	@TestVisible
	private static final String KEY_HTTP_METHOD = KEY_PREFIX + 'httpMethod';

	/**
	 * @description Parameter key for the request body.
	 */
	@TestVisible
	private static final String KEY_BODY = KEY_PREFIX + 'body';

	/**
	 * @description Parameter key for custom headers (JSON-serialized Map).
	 */
	@TestVisible
	private static final String KEY_HTTP_HEADERS = KEY_PREFIX + 'httpHeaders';

	/**
	 * @description Parameter key for query parameters (JSON-serialized Map).
	 */
	@TestVisible
	private static final String KEY_QUERY_PARAMETERS = KEY_PREFIX + 'queryParameters';

	/**
	 * @description Parameter key for path parameters (JSON-serialized Map).
	 */
	@TestVisible
	private static final String KEY_PATH_PARAMETERS = KEY_PREFIX + 'pathParameters';

	/**
	 * @description Parameter key for timeout in milliseconds.
	 */
	@TestVisible
	private static final String KEY_TIMEOUT_MS = KEY_PREFIX + 'timeoutMs';

	/**
	 * @description Parameter key for maximum retry attempts. It is the input name API_Outbound reads for the call's
	 * maximum number of retries.
	 */
	@TestVisible
	private static final String KEY_MAX_RETRIES = API_Outbound.INPUT_MAXIMUM_RETRIES;

	/**
	 * @description Parameter key for backoff seconds between retries. It is the input name API_Outbound reads for the
	 * call's base wait.
	 */
	@TestVisible
	private static final String KEY_BACKOFF_SECONDS = API_Outbound.INPUT_BASE_BACKOFF_SECONDS;

	/**
	 * @description Parameter key for exponential backoff flag. It is the input name API_Outbound.createRetryStrategy reads.
	 */
	@TestVisible
	private static final String KEY_EXPONENTIAL_BACKOFF = API_Outbound.INPUT_EXPONENTIAL_BACKOFF;

	/**
	 * @description The internal inputs that carry the caller's retry values. A handler called through useHandler gets
	 * them and saves them with its call, so its retry decision uses them on every run.
	 */
	private static final Set<String> RETRY_VALUE_KEYS = new Set<String> {KEY_MAX_RETRIES, KEY_BACKOFF_SECONDS, KEY_EXPONENTIAL_BACKOFF};

	/**
	 * @description Parameter key for circuit breaker enabled flag.
	 */
	@TestVisible
	private static final String KEY_CIRCUIT_BREAKER_ENABLED = KEY_PREFIX + 'circuitBreakerEnabled';

	/**
	 * @description Parameter key for failure logging flag.
	 */
	@TestVisible
	private static final String KEY_LOG_FAILURES = KEY_PREFIX + 'logFailures';

	/**
	 * @description Parameter key for skip retry flag.
	 */
	@TestVisible
	private static final String KEY_SKIP_RETRY = KEY_PREFIX + 'skipRetry';

	/**
	 * @description Parameter key for retryable status codes (JSON-serialized Set).
	 */
	@TestVisible
	private static final String KEY_RETRYABLE_CODES = KEY_PREFIX + 'retryableCodes';

	/**
	 * @description Parameter key for circuit breaker name.
	 */
	@TestVisible
	private static final String KEY_CIRCUIT_NAME = KEY_PREFIX + 'circuitName';

	/**
	 * @description Parameter key for explicit idempotency key.
	 */
	@TestVisible
	private static final String KEY_IDEMPOTENCY_KEY = KEY_PREFIX + 'idempotencyKey';

	/**
	 * @description Parameter key for delegate handler class name.
	 */
	@TestVisible
	private static final String KEY_API_HANDLER_NAME = KEY_PREFIX + 'apiHandlerName';

	/**
	 * @description Parameter key for skip persistence flag.
	 */
	@TestVisible
	private static final String KEY_SKIP_PERSISTENCE = KEY_PREFIX + 'skipPersistence';

	/**
	 * @description Parameter key requesting suppression of the delegate handler's own retry
	 * scheduling. Set by RequestBuilder.suppressHandlerSelfRetryScheduling() and applied to the
	 * fresh handler instance at instantiation, before the callout runs.
	 */
	private static final String KEY_SUPPRESS_SELF_RETRY = KEY_PREFIX + 'suppressSelfRetryScheduling';

	/**
	 * @description Parameter key for request replacement tokens (JSON-serialized Map).
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	@TestVisible
	private static final String KEY_REQUEST_TOKENS = KEY_PREFIX + 'requestTokens';

	/**
	 * @description Parameter key for response replacement tokens (JSON-serialized Map).
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	@TestVisible
	private static final String KEY_RESPONSE_TOKENS = KEY_PREFIX + 'responseTokens';

	/**
	 * @description Status codes by which the external system asks the caller to wait: 425 (too early) and 429 (too many
	 * requests). When the caller gave no retryOn(...) codes, the synchronous loop in DefaultOutboundHandler.sendRequest
	 * does not re-send these at once and leaves them to the scheduled retry, which waits the backoff. A caller who names
	 * one of them in retryOn(...) chose the immediate re-send, so the loop re-sends it like any other named code.
	 */
	private static final Set<Integer> WAIT_BEFORE_RETRY_CODES = new Set<Integer> {API_Base.HTTP_TOO_EARLY, API_Base.HTTP_TOO_MANY_REQUESTS};

	/**
	 * @description Maximum number of synchronous retry attempts to prevent governor limit exhaustion.
	 */
	@TestVisible
	private static final Integer MAX_SYNCHRONOUS_RETRIES = 3;

	/**
	 * @description Status code carried by the response the builder supplies when a request produced
	 * none of its own. No HTTP exchange can report it, so a caller reading it knows no response came
	 * back, whether the request was refused before it left the org or went out and produced none.
	 */
	private static final Integer SYNTHETIC_STATUS_CODE = 0;

	/**
	 * @description Longest status line the supplied response carries. The recorded error is trimmed to
	 * it so a long message stays a single readable status line.
	 */
	private static final Integer SYNTHETIC_STATUS_MAXIMUM_LENGTH = 255;

	/**
	 * @description Defines the action to take when an HTTP call fails.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_HttpClient.post('MyService', '/send')
	 *    .onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
	 *    .send();
	 * ```
	 */
	global enum FailureAction
	{
		/**
		 * @description Log an ApiIssue__c record without retrying.
		 *
		 * **Caveat — delegation mode:** the underlying `KEY_SKIP_RETRY` flag that distinguishes
		 * `LOG_FAILURE` from `RETRY_THEN_LOG` is consumed only by `DefaultOutboundHandler.sendRequest`'s
		 * synchronous retry loop. When the request is delegated to your own handler
		 * via `useHandler(HandlerClass.class)`, your handler decides its own retry
		 * behaviour and the `LOG_FAILURE` / `RETRY_THEN_LOG` distinction is observationally
		 * identical from the framework's side. If you write your own handlers, they should
		 * read the `KEY_SKIP_RETRY` parameter from the inbound DTO_NameValues if they want to
		 * honour the caller's "don't retry" intent.
		 */
		LOG_FAILURE,
		/**
		 * @description Retry the request, then log a failure record if all retries are exhausted.
		 *
		 * In delegation mode (your own handler via `useHandler`), retry behaviour is
		 * your handler's responsibility. See `LOG_FAILURE` for the contract caveat.
		 */
		RETRY_THEN_LOG
	}

	/**
	 * @description Returns LOG_FAILURE enum value for inner class access.
	 *
	 * @return The LOG_FAILURE enum value
	 */
	private static FailureAction logFailureValue()
	{
		return FailureAction.LOG_FAILURE;
	}

	/**
	 * @description Returns RETRY_THEN_LOG enum value for inner class access.
	 *
	 * @return The RETRY_THEN_LOG enum value
	 */
	private static FailureAction retryThenLogValue()
	{
		return FailureAction.RETRY_THEN_LOG;
	}

	/**
	 * @description Starts a request that reads data. Nothing is sent until you call send() on the builder. The path is
	 * added to the credential's endpoint, and it can hold {name} placeholders that pathParam fills in.
	 *
	 * @param credential The Named Credential or ApiCredential__mdt DeveloperName
	 * @param path The URL path to append to the endpoint
	 *
	 * @return A RequestBuilder for further configuration
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * HttpResponse response = UTIL_HttpClient.get('CRM', '/accounts/{id}')
	 *    .pathParam('id', accountId)
	 *    .send();
	 * ```
	 */
	global static RequestBuilder get(String credential, String path)
	{
		return new RequestBuilder(credential).path(path).method(API_Base.HttpMethod.GET);
	}

	/**
	 * @description Starts a request that sends new data, usually with body(...). Nothing is sent until you call send() on
	 * the builder. With retries turned on and no retryOn list, a POST that carries no idempotency key (the key you give
	 * withIdempotencyKey so the other system can recognise a repeat) is not sent again after a 500, 502 or 504, because
	 * the other system may already have acted on it.
	 *
	 * @param credential The Named Credential or ApiCredential__mdt DeveloperName
	 * @param path The URL path to append to the endpoint
	 *
	 * @return A RequestBuilder for further configuration
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * HttpResponse response = UTIL_HttpClient.post('EmailService', '/send')
	 *    .body(emailPayload)
	 *    .send();
	 * ```
	 */
	global static RequestBuilder post(String credential, String path)
	{
		return new RequestBuilder(credential).path(path).method(API_Base.HttpMethod.POST);
	}

	/**
	 * @description Starts a request that replaces a resource, usually with body(...). Nothing is sent until you call send()
	 * on the builder. With retries turned on and no retryOn list, a PUT counts as safe to repeat, so it is sent again
	 * after a 500, 502 or 504.
	 *
	 * @param credential The Named Credential or ApiCredential__mdt DeveloperName
	 * @param path The URL path to append to the endpoint
	 *
	 * @return A RequestBuilder for further configuration
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * HttpResponse response = UTIL_HttpClient.put('CRM', '/contacts/{id}')
	 *    .pathParam('id', contactId)
	 *    .body(contactPayload)
	 *    .send();
	 * ```
	 */
	global static RequestBuilder put(String credential, String path)
	{
		return new RequestBuilder(credential).path(path).method(API_Base.HttpMethod.PUT);
	}

	/**
	 * @description Creates a DELETE request for the specified credential and path.
	 *
	 * @param credential The Named Credential or ApiCredential__mdt DeveloperName
	 * @param path The URL path to append to the endpoint
	 *
	 * @return A RequestBuilder for further configuration
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * HttpResponse response = UTIL_HttpClient.del('CRM', '/contacts/{id}')
	 *    .pathParam('id', contactId)
	 *    .send();
	 * ```
	 */
	global static RequestBuilder del(String credential, String path)
	{
		return new RequestBuilder(credential).path(path).method(API_Base.HttpMethod.DELETION);
	}

	/**
	 * @description Starts a request that changes part of a resource, usually with body(...). Nothing is sent until you call
	 * send() on the builder. With retries turned on and no retryOn list, a PATCH that carries no idempotency key (the key
	 * you give withIdempotencyKey so the other system can recognise a repeat) is not sent again after a 500, 502 or 504,
	 * because the other system may already have acted on it.
	 *
	 * @param credential The Named Credential or ApiCredential__mdt DeveloperName
	 * @param path The URL path to append to the endpoint
	 *
	 * @return A RequestBuilder for further configuration
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * HttpResponse response = UTIL_HttpClient.patch('CRM', '/contacts/{id}')
	 *    .pathParam('id', contactId)
	 *    .body(patchPayload)
	 *    .send();
	 * ```
	 */
	global static RequestBuilder patch(String credential, String path)
	{
		return new RequestBuilder(credential).path(path).method(API_Base.HttpMethod.PATCH);
	}

	/**
	 * @description Creates a delegation mode request for the specified handler class of your own. Your handler's inputs also
	 * carry three keys that hold the retry values of withRetry and withExponentialBackoff: `__exponentialBackoff`,
	 * `__maxRetries` and `__backoffSeconds`. Leave them in place, the framework reads them on every run.
	 *
	 * @param handlerType The API_Outbound subclass Type to delegate to
	 *
	 * @return A RequestBuilder configured for delegation mode
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Outbound handler = UTIL_HttpClient.useHandler(API_SendEmail.class)
	 *    .credential('EmailGateway')
	 *    .withParameter(API_SendEmail.PARAM_RECIPIENT, email)
	 *    .invoke();
	 * ```
	 */
	global static RequestBuilder useHandler(Type handlerType)
	{
		return new RequestBuilder(handlerType);
	}

	/**
	 * @description Internal handler for ad-hoc HTTP requests. Reads configuration from API call parameters
	 * (DTO_NameValues with __ prefixed keys) and applies in-memory ApiSetting__mdt via applySettings().
	 */
	public class DefaultOutboundHandler extends API_Outbound
	{
		/**
		 * @description Number of retry attempts performed.
		 */
		private Integer retriesPerformed = 0;

		/**
		 * @description The subscriber handler instance when using useHandler() mode.
		 */
		@TestVisible
		private API_Outbound subscriberHandler;

		/**
		 * @description Configure the handler for ad-hoc callouts.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = '{"success":true}';
		}

		/**
		 * @description Detects skipPersistence from API call parameters (delegation or explicit skip).
		 * In delegation mode, the dispatcher owns the API call DML lifecycle.
		 * In skipLogging mode, no API call DML occurs at all.
		 *
		 * @param apiCallRecord The API call to set
		 */
		public override void setApiCall(ApiCall__c apiCallRecord)
		{
			if(hasSubscriberHandler(apiCallRecord)
					|| (String.isNotBlank(apiCallRecord.RequestParameters__c)
					&& apiCallRecord.RequestParameters__c.contains(KEY_SKIP_PERSISTENCE)))
			{
				skipPersistence = true;
			}
			super.setApiCall(apiCallRecord);
		}

		/**
		 * @description Processes the API call. Delegates to subscriber handler or runs normal outbound flow.
		 * For delegation mode, calls setApiCall directly, puts the caller's idempotency key on the call, then delegates.
		 * For normal mode, super.process() handles the full lifecycle (setApiCall is called by API_Base.process).
		 *
		 * @param apiCallRecord The API call to process
		 */
		public override void process(ApiCall__c apiCallRecord)
		{
			if(hasSubscriberHandler(apiCallRecord))
			{
				setApiCall(apiCallRecord);
				applyCallersIdempotencyKey();
				processSubscriberHandler(apiCallRecord);
			}
			else
			{
				super.process(apiCallRecord);
			}
		}

		/**
		 * @description Framework validation hook. Builds and applies in-memory settings before the standard validation
		 * runs, ensuring settings are available for circuit breaker checks etc. Also aborts, before any callout leaves
		 * the org, a dispatch of a stored call whose credential header carries the redaction marker instead of a value:
		 * that call cannot authenticate however often it is re-dispatched, so a scheduled retry made before the park
		 * existed, or a retry started from the issue list, stops here with the labelled reason naming the header rather
		 * than spending a callout to be rejected. Credential merge-field text is stored verbatim and never carries the
		 * marker, so a merge-field header dispatches untouched.
		 *
		 * @return True if the request should be aborted
		 */
		protected override Boolean performValidation()
		{
			buildAndApplySettings();

			String headersJson = inputs.get(KEY_HTTP_HEADERS);
			if(String.isNotBlank(headersJson) && headersJson.contains(API_Base.REDACTED_HEADER_VALUE))
			{
				Map<String, String> storedHeaders = (Map<String, String>)JSON.deserialize(headersJson, Map<String, String>.class);
				List<String> redactedNames = new List<String>();
				for(String name : storedHeaders.keySet())
				{
					if(API_Base.REDACTED_HEADER_VALUE.equals(storedHeaders.get(name)))
					{
						redactedNames.add(name);
					}
				}
				if(!redactedNames.isEmpty())
				{
					result.errors.add(String.format(System.Label.RetryApiIssue_CredentialHeaderNotStored, new List<Object> {String.join(redactedNames, ', ')}));
					return true;
				}
			}

			return super.performValidation();
		}

		/**
		 * @description Returns the service name for logging.
		 *
		 * @return The service name
		 */
		public override String getServiceName()
		{
			String handlerName = inputs.get(KEY_API_HANDLER_NAME);
			if(handlerName != null)
			{
				return handlerName;
			}
			return inputs.get(KEY_CREDENTIAL) ?? super.getServiceName();
		}

		/**
		 * @description Returns the HTTP method from inputs.
		 *
		 * @return The HTTP method enum value
		 */
		public override HttpMethod getHttpMethod()
		{
			String method = inputs.get(KEY_HTTP_METHOD);
			return method != null ? API_Base.fromHttpString(method) : HttpMethod.POST;
		}

		/**
		 * @description The caller's retryOn(...) codes when given, else the shared default, so the attempts made in this
		 * transaction and the attempt the framework schedules later agree on which responses are worth a retry.
		 *
		 * @return The status codes a retry may follow.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			String retryableCodesJson = inputs.get(KEY_RETRYABLE_CODES);
			return retryableCodesJson != null ? (Set<Integer>)JSON.deserialize(retryableCodesJson, Set<Integer>.class) : super.getRetryableStatusCodes();
		}

		/**
		 * @description Every code the caller named in retryOn(...) is the caller's own choice, so the scheduled retry may
		 * send the request again after it whatever the method, as the synchronous loop does. The retryable set is then
		 * exactly the caller's codes (getRetryableStatusCodes), so a status outside them never reaches this question.
		 * Without retryOn(...) the framework's default rule applies.
		 *
		 * @param statusCode The status the external system responded with.
		 *
		 * @return True when the caller named codes through retryOn(...), or when the default rule counts the status as chosen.
		 */
		protected override Boolean isStatusTheHandlersOwnChoice(Integer statusCode)
		{
			return inputs.get(KEY_RETRYABLE_CODES) != null || super.isStatusTheHandlersOwnChoice(statusCode);
		}

		/**
		 * @description The issue record for this call, or none when the call is delegated to a subscriber handler. In
		 * delegation mode this handler reads the subscriber handler's setting, because its service name is the subscriber
		 * handler's name, but the subscriber handler records the call's issue itself (from its own commit, or from
		 * processSubscriberHandler when its handling threw) and only it knows where the call failed. Recording one here
		 * too would give the call a second issue that never says whether the external system may have acted.
		 *
		 * @return The issue record, or null in delegation mode or when failure logging is off.
		 */
		public override ApiIssue__c createFailureRecord()
		{
			return subscriberHandler == null ? super.createFailureRecord() : null;
		}

		/**
		 * @description Returns the request body from inputs with replacement tokens applied.
		 *
		 * @return The request body string
		 */
		public override String getBody()
		{
			String body = inputs.get(KEY_BODY) ?? UTIL_String.EMPTY;

			List<String> searchTokens = new List<String>();
			List<String> replaceTokens = new List<String>();

			deserializeTokens(inputs.get(KEY_REQUEST_TOKENS), searchTokens, replaceTokens);

			return UTIL_String.replaceEachRepeatedly(body, searchTokens, replaceTokens, true);
		}

		/**
		 * @description Returns the request timeout from inputs.
		 *
		 * @return The timeout in milliseconds
		 */
		public override Integer getTimeout()
		{
			String timeout = inputs.get(KEY_TIMEOUT_MS);
			return timeout != null ? Integer.valueOf(timeout) : super.getTimeout();
		}

		/**
		 * @description Returns the Named Credential name from inputs.
		 *
		 * @return The credential name
		 */
		protected override String getNamedCredentialName()
		{
			return inputs.get(KEY_CREDENTIAL) ?? super.getNamedCredentialName();
		}

		/**
		 * @description Builds the endpoint URL with path parameter substitution.
		 *
		 * @return The full callout URL
		 */
		public override String getWebServiceEndPoint()
		{
			String endpoint = super.getWebServiceEndPoint();

			String pathParamsJson = inputs.get(KEY_PATH_PARAMETERS);
			if(String.isNotBlank(pathParamsJson) && String.isNotBlank(endpoint))
			{
				Map<String, String> pathParameters = (Map<String, String>)JSON.deserialize(pathParamsJson, Map<String, String>.class);
				for(String paramName : pathParameters.keySet())
				{
					endpoint = endpoint.replace('{' + paramName + '}', pathParameters.get(paramName));
				}
			}

			return endpoint;
		}

		/**
		 * @description Builds query string from inputs.
		 *
		 * @return The URL-encoded query string
		 */
		public override String getQueryParameters()
		{
			String queryParamsJson = inputs.get(KEY_QUERY_PARAMETERS);
			if(String.isBlank(queryParamsJson))
			{
				return null;
			}

			Map<String, String> queryParameters = (Map<String, String>)JSON.deserialize(queryParamsJson, Map<String, String>.class);
			if(queryParameters.isEmpty())
			{
				return null;
			}

			List<String> params = new List<String>();

			for(String paramName : queryParameters.keySet())
			{
				params.add
						(
								EncodingUtil.urlEncode(paramName, API_Base.UTF8_ENCODING_SCHEME)
								+ '=' + EncodingUtil.urlEncode(queryParameters.get(paramName), API_Base.UTF8_ENCODING_SCHEME)
						);
			}

			return String.join(params, '&');
		}

		/**
		 * @description Applies custom headers from inputs.
		 */
		public override void setHeaders()
		{
			super.setHeaders();

			String headersJson = inputs.get(KEY_HTTP_HEADERS);
			if(String.isNotBlank(headersJson))
			{
				Map<String, String> customHeaders = (Map<String, String>)JSON.deserialize(headersJson, Map<String, String>.class);
				for(String headerName : customHeaders.keySet())
				{
					request.setHeader(headerName, customHeaders.get(headerName));
				}
			}
		}

		/**
		 * @description Redacts the credential headers the caller set through header() / headers() in the stored copy of
		 * the request parameters, before the base class writes them to the call record, and parks (holds back from any retry) a failed call whose
		 * credential was redacted: its scheduled retry could never authenticate (the stored value is the marker, and
		 * credential merge-field text is deliberately kept instead, for the platform to substitute), so instead of
		 * burning the retry schedule on a deterministic dead end, no self-retry is scheduled and the error text says
		 * why in the labelled words, leaving the issue for a human to resolve by moving the credential to a Named or
		 * External Credential and running the call again. Runs after every send attempt of this transaction has used
		 * the live HttpRequest (and again if the dispatcher handles an exception; the redaction and the park are both
		 * idempotent: the second pass finds nothing left to redact), so the callout itself is unaffected. The two JSON
		 * passes run once per call on the persistence path and are negligible against the callout they follow; do not
		 * cache or restructure them. Parking a call (see above) turns off this handler's own retry scheduling. The
		 * retry decision still runs. It still works out whether the handler refuses to send the request again (see
		 * API_Outbound.isRepeatRefusedByTheHandler). No caller reads that answer here. But for a POST or PATCH sent
		 * with no idempotency key that got no response or a 500, 502 or 504, the answer is yes. So the call's errors
		 * start with the line saying the request was not sent again, ahead of the credential line. Both lines are true;
		 * neither changes what happens to the call.
		 */
		public override void setApiCallDetails()
		{
			String headersJson = inputs.get(KEY_HTTP_HEADERS);
			if(String.isNotBlank(headersJson))
			{
				Map<String, String> callerHeaders = (Map<String, String>)JSON.deserialize(headersJson, Map<String, String>.class);
				Map<String, String> redactedHeaders = API_Base.redactCredentialHeaders(callerHeaders);
				List<String> redactedNames = new List<String>();
				for(String name : callerHeaders.keySet())
				{
					if(API_Base.REDACTED_HEADER_VALUE.equals(redactedHeaders.get(name)) && !API_Base.REDACTED_HEADER_VALUE.equals(callerHeaders.get(name)))
					{
						redactedNames.add(name);
					}
				}
				inputs.add(KEY_HTTP_HEADERS, JSON.serialize(redactedHeaders));
				if(!redactedNames.isEmpty() && result.hasFailed)
				{
					suppressSelfRetryScheduling();
					result.errors.add(String.format(System.Label.RetryApiIssue_CredentialHeaderNotStored, new List<Object> {String.join(redactedNames, ', ')}));
				}
			}
			super.setApiCallDetails();
		}

		/**
		 * @description Sends the request with synchronous retry logic. Codes the caller named in retryOn(...) are re-sent
		 * at once, whichever they are and whatever the method. Without retryOn(...) the shared default applies, and two
		 * kinds of its codes are not re-sent at once: the two that mean wait (425, 429), which are left to the scheduled
		 * retry, and a 500, 502 or 504 to a request that is not safe to repeat (see isUnsafeToRepeatAfterStatus), which
		 * stops the loop so the scheduled retry decision ends the call Failed. A throw from the send escapes the loop, so a
		 * callout that got no response is never re-sent in the transaction and is decided by the scheduled retry.
		 *
		 * The call's retry count (Retries__c) adds up across runs. A stored call that runs again has already used some of
		 * its retries, so this loop re-sends only what is left of the budget: the maximum number of retries minus the
		 * retries already counted on the call, and never more than three. When nothing is left, the request is sent once
		 * and not again. Each re-send adds one to the count.
		 *
		 * @param requestObj The HTTP request to send
		 */
		public override void sendRequest(HttpRequest requestObj)
		{
			String maxRetriesValue = inputs.get(KEY_MAX_RETRIES);
			String skipRetryValue = inputs.get(KEY_SKIP_RETRY);

			Integer retriesAlreadyCounted = (apiCall.Retries__c ?? 0).intValue();
			Integer retriesLeft = (maxRetriesValue != null ? Integer.valueOf(maxRetriesValue) : 0) - retriesAlreadyCounted;
			Integer maxAttempts = 1 + Math.max(0, Math.min(retriesLeft, MAX_SYNCHRONOUS_RETRIES));
			Set<Integer> codes = getRetryableStatusCodes();
			Boolean hasCallerNamedCodes = inputs.get(KEY_RETRYABLE_CODES) != null;
			Boolean isSkipRetry = 'true'.equalsIgnoreCase(skipRetryValue);

			for(Integer attempt = 0; attempt < maxAttempts; attempt++)
			{
				if(attempt > 0)
				{
					if(API_Dispatcher.isCalloutBudgetExhausted())
					{
						break;
					}
					retriesPerformed++;
					result.status = null;
				}

				super.sendRequest(requestObj);

				if(result.isSuccess || isSkipRetry)
				{
					break;
				}

				Integer statusCode = response.getStatusCode();
				Boolean isResentAtOnceByDefault = !WAIT_BEFORE_RETRY_CODES.contains(statusCode) && !isUnsafeToRepeatAfterStatus(statusCode);
				Boolean isRetryable = codes.contains(statusCode) && (hasCallerNamedCodes || isResentAtOnceByDefault);

				if(attempt < (maxAttempts - 1) && isRetryable)
				{
					continue;
				}

				break;
			}

			if(retriesPerformed > 0)
			{
				apiCall.Retries__c = retriesAlreadyCounted + retriesPerformed;
			}
		}

		/**
		 * @description In delegation mode (a call made through useHandler) it hands back the response the delegate handler
		 * received, because that handler makes the callout; otherwise it hands back this handler's own response.
		 *
		 * @return The response, or delegate's response in delegation mode
		 */
		public override HttpResponse getHttpResponse()
		{
			return subscriberHandler != null ? subscriberHandler.getHttpResponse() : response;
		}

		/**
		 * @description Returns the subscriber handler instance when using useHandler() mode.
		 *
		 * @return The subscriber handler, or null in ad-hoc mode
		 */
		public API_Outbound getSubscriberHandler()
		{
			return subscriberHandler;
		}

		/**
		 * @description Skips request DTO population for ad-hoc mode.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public override void prepareRequest()
		{
		}

		/**
		 * @description Applies response replacement tokens to the response body when configured.
		 */
		public override void parseResponse()
		{
			List<String> searchTokens = new List<String>();
			List<String> replaceTokens = new List<String>();

			deserializeTokens(inputs.get(KEY_RESPONSE_TOKENS), searchTokens, replaceTokens);

			if(!searchTokens.isEmpty())
			{
				response.setBody(UTIL_String.replaceWholeWords(response.getBody(), searchTokens, replaceTokens));
			}
		}

		/**
		 * @description Deserializes a JSON token map into parallel search/replace lists.
		 *
		 * @param tokensJson The JSON-serialized Map of search to replace tokens
		 * @param searchTokens List to populate with search strings
		 * @param replaceTokens List to populate with replacement strings
		 */
		private void deserializeTokens(String tokensJson, List<String> searchTokens, List<String> replaceTokens)
		{
			if(String.isBlank(tokensJson))
			{
				return;
			}

			Map<String, String> tokens = (Map<String, String>)JSON.deserialize(tokensJson, Map<String, String>.class);

			searchTokens.addAll(tokens.keySet());
			replaceTokens.addAll(tokens.values());
		}

		/**
		 * @description Checks whether the API call is in delegation mode by inspecting
		 * the raw RequestParameters__c before inputs are parsed.
		 *
		 * @param apiCallRecord The API call to check
		 *
		 * @return True if the API call contains a delegate handler name
		 */
		private Boolean hasSubscriberHandler(ApiCall__c apiCallRecord)
		{
			return String.isNotBlank(apiCallRecord.RequestParameters__c)
					&& apiCallRecord.RequestParameters__c.contains(KEY_API_HANDLER_NAME);
		}

		/**
		 * @description Builds and applies in-memory ApiSetting__mdt from inputs, with the caller's idempotency key and the
		 * circuit breaker name the caller chose, if any.
		 */
		private void buildAndApplySettings()
		{
			String backoffValue = inputs.get(KEY_BACKOFF_SECONDS);
			String circuitBreakerValue = inputs.get(KEY_CIRCUIT_BREAKER_ENABLED);
			String logFailuresValue = inputs.get(KEY_LOG_FAILURES);
			String maxRetriesValue = inputs.get(KEY_MAX_RETRIES);
			String pathValue = inputs.get(KEY_PATH);
			String settingName = inputs.get(KEY_API_HANDLER_NAME) ?? getServiceName();

			ApiSetting__mdt setting = (ApiSetting__mdt)TST_Builder.of(ApiSetting__mdt.SObjectType)
					.withOverride(ApiSetting__mdt.IsActive__c, true)
					.withOverride(ApiSetting__mdt.RetryBackoffSeconds__c, backoffValue != null ? Integer.valueOf(backoffValue) : 0)
					.withOverride(ApiSetting__mdt.CircuitBreakerEnabled__c, 'true'.equalsIgnoreCase(circuitBreakerValue))
					.withOverride(ApiSetting__mdt.ClassName__c, settingName)
					.withOverride(ApiSetting__mdt.DeveloperName, settingName)
					.withOverride(ApiSetting__mdt.LogIssues__c, 'true'.equalsIgnoreCase(logFailuresValue))
					.withOverride(ApiSetting__mdt.MaxRetryCount__c, maxRetriesValue != null ? Integer.valueOf(maxRetriesValue) : 0)
					.withOverride(ApiSetting__mdt.EndpointPath__c, pathValue)
					.withoutInsertion()
					.build();

			applySettings(setting);
			applyCallersIdempotencyKey();
			circuitBreakerNameOverride = inputs.get(KEY_CIRCUIT_NAME);
		}

		/**
		 * @description Puts the idempotency key the caller gave withIdempotencyKey on the call, in ad-hoc and delegation
		 * mode alike, so the request sends it as the Idempotency-Key header whatever the service setting says. When the
		 * caller gave no key, the call keeps any key it already carries.
		 */
		private void applyCallersIdempotencyKey()
		{
			String callersIdempotencyKey = inputs.get(KEY_IDEMPOTENCY_KEY);
			if(String.isNotBlank(callersIdempotencyKey))
			{
				apiCall.IdempotencyKey__c = callersIdempotencyKey;
			}
		}

		/**
		 * @description Delegates processing to a subscriber handler. When the subscriber handler's processing or commit
		 * throws, the exception is kept on the handler for its retry decision, as the dispatcher keeps it, its own error
		 * handling runs and it records the call's issue, as its commit records the issue of a call that failed without a
		 * throw; the dispatcher never sees that throw, so it records none. The call it hands the handler already carries
		 * the idempotency key the caller gave (see applyCallersIdempotencyKey), so the handler sends that key. The catch has
		 * no guard of its own around the handler's error handling: if that handling throws too, the throw leaves this method
		 * and reaches the dispatcher's error path for this handler, which keeps the exception for the retry decision and
		 * runs its own guard, so the call still ends with a status.
		 *
		 * The handler gets the caller's own parameters. Of the client's internal inputs (their names start with two
		 * underscores), it gets only the retry values of withRetry and withExponentialBackoff: the maximum number of
		 * retries, the base wait and the exponential backoff choice. Those inputs are saved with the call, so the handler's
		 * retry decision reads them on this run and on every scheduled retry, in place of its service setting.
		 *
		 * @param apiCallRecord The API call to process
		 */
		private void processSubscriberHandler(ApiCall__c apiCallRecord)
		{
			String handlerName = inputs.get(KEY_API_HANDLER_NAME);
			Type handlerType = UTIL_System.getTypeForClassName(handlerName, API_Outbound.class);
			subscriberHandler = (API_Outbound)handlerType.newInstance();
			subscriberHandler.skipPersistence = true;

			if('true'.equalsIgnoreCase(inputs.get(KEY_SUPPRESS_SELF_RETRY)))
			{
				subscriberHandler.suppressSelfRetryScheduling();
			}

			apiCallRecord.ServiceName__c = handlerName;

			Map<String, String> callerOverrides = new Map<String, String>();
			for(String key : new List<String>
			{
					KEY_CREDENTIAL, KEY_PATH, KEY_MAX_RETRIES, KEY_BACKOFF_SECONDS,
					KEY_CIRCUIT_BREAKER_ENABLED, KEY_LOG_FAILURES
			})
			{
				String value = inputs.get(key);
				if(value != null)
				{
					callerOverrides.put(key, value);
				}
			}

			DTO_NameValues subscriberInputs = new DTO_NameValues();
			for(String key : inputs.names)
			{
				if(!key.startsWith(KEY_PREFIX) || RETRY_VALUE_KEYS.contains(key))
				{
					subscriberInputs.add(key, inputs.get(key));
				}
			}

			apiCallRecord.RequestParameters__c = subscriberInputs.isEmpty()
					? null
					: subscriberInputs.serialize();

			applySubscriberSettings(handlerName, callerOverrides);

			LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_CALL, subscriberHandler.buildCallContext());
			try
			{
				subscriberHandler.process(apiCallRecord);
				subscriberHandler.commitWork();
			}
			catch(Exception error)
			{
				subscriberHandler.lastFailure = error;
				subscriberHandler.handleError(error);
				subscriberHandler.assignApiCallWhenMissing(apiCallRecord);
				subscriberHandler.setApiCallDetails();
				subscriberHandler.logApiIssues();
			}
			finally
			{
				LOG_Engine.popOperationContext();
				subscriberHandler.clearLoggingContext();
			}

			if(!inputs.exists(KEY_SKIP_PERSISTENCE))
			{
				skipPersistence = false;
			}

			result.isSuccess = subscriberHandler.result.isSuccess;
			result.hasFailed = subscriberHandler.result.hasFailed;
			result.isAborted = subscriberHandler.result.isAborted;
			result.errors.addAll(subscriberHandler.result.errors);
		}

		/**
		 * @description Applies in-memory settings and caller overrides to the subscriber handler.
		 * When the handler has its own ApiSetting__mdt, caller overrides are merged onto it.
		 * When no CMDT exists, a minimal in-memory setting is created and overrides applied.
		 * A circuit breaker name the caller chose replaces the handler's own breaker for this call.
		 * Inside a unit test, a handler that declares a defaultMockBody and gets no credential from the caller is put
		 * into mock mode, so it answers a registered mock or, failing one, that body. Outside a unit test, in production
		 * and inside an Apex integration test alike, the handler always makes its real call.
		 *
		 * @param handlerName The subscriber handler class name
		 * @param callerOverrides Caller-provided configuration values to merge onto the setting
		 */
		private void applySubscriberSettings(String handlerName, Map<String, String> callerOverrides)
		{
			ApiSetting__mdt baseSetting = subscriberHandler.setting;

			if(baseSetting == null)
			{
				baseSetting = (ApiSetting__mdt)TST_Builder.of(ApiSetting__mdt.SObjectType)
						.withOverride(ApiSetting__mdt.IsActive__c, true)
						.withOverride(ApiSetting__mdt.ClassName__c, handlerName)
						.withOverride(ApiSetting__mdt.DeveloperName, handlerName)
						.withoutInsertion()
						.build();
			}

			applyCallerOverrides(baseSetting, callerOverrides);
			subscriberHandler.applySettings(baseSetting);

			String credentialOverride = callerOverrides.get(KEY_CREDENTIAL);
			if(credentialOverride != null)
			{
				subscriberHandler.namedCredentialOverride = credentialOverride;
			}
			subscriberHandler.circuitBreakerNameOverride = inputs.get(KEY_CIRCUIT_NAME);

			Boolean hasCredential = String.isNotBlank(subscriberHandler.namedCredentialOverride);
			if(Test.isRunningTest() && !UTIL_System.isRunningIntegrationTest() && !hasCredential && subscriberHandler.defaultMockBody != null)
			{
				API_MockFactory.enableMocking(handlerName);
			}
		}

		/**
		 * @description Merges caller-provided configuration values onto the target setting record.
		 * Only fields the caller explicitly set are overridden; unset fields retain their original values.
		 *
		 * @param targetSetting The ApiSetting__mdt record to modify in place
		 * @param overrides Caller-provided values keyed by internal KEY constants
		 */
		private void applyCallerOverrides(ApiSetting__mdt targetSetting, Map<String, String> overrides)
		{
			if(overrides.isEmpty())
			{
				return;
			}

			String path = overrides.get(KEY_PATH);
			if(path != null)
			{
				targetSetting.EndpointPath__c = path;
			}

			String maxRetries = overrides.get(KEY_MAX_RETRIES);
			if(maxRetries != null)
			{
				targetSetting.MaxRetryCount__c = Integer.valueOf(maxRetries);
			}

			String backoff = overrides.get(KEY_BACKOFF_SECONDS);
			if(backoff != null)
			{
				targetSetting.RetryBackoffSeconds__c = Integer.valueOf(backoff);
			}

			String circuitBreaker = overrides.get(KEY_CIRCUIT_BREAKER_ENABLED);
			if(circuitBreaker != null)
			{
				targetSetting.CircuitBreakerEnabled__c = 'true'.equalsIgnoreCase(circuitBreaker);
			}

			String logFailures = overrides.get(KEY_LOG_FAILURES);
			if(logFailures != null)
			{
				targetSetting.LogIssues__c = 'true'.equalsIgnoreCase(logFailures);
			}
		}
	}

	/**
	 * @description Fluent builder for configuring and executing HTTP requests through API_Dispatcher.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, Object> result = UTIL_HttpClient.get('MyService', '/status')
	 *    .header('X-Custom', 'value')
	 *    .timeout(30000)
	 *    .asMap();
	 * ```
	 */
	@SuppressWarnings('PMD.CognitiveComplexity,PMD.ExcessivePublicCount,PMD.CyclomaticComplexity,PMD.TooManyFields')
	global inherited sharing class RequestBuilder
	{
		/**
		 * @description The credential name (Named Credential or ApiCredential__mdt).
		 */
		private String credentialName;

		/**
		 * @description The URL path appended to the endpoint.
		 */
		private String urlPath;

		/**
		 * @description Starts as POST for a request built from a credential, and as null for one built with useHandler.
		 * buildApiCall stores it with the call's inputs only when it is not null.
		 */
		private API_Base.HttpMethod httpMethod;

		/**
		 * @description Custom headers to include in the request.
		 */
		private final Map<String, String> requestHeaders;

		/**
		 * @description Query parameters appended to the URL.
		 */
		private final Map<String, String> queryParameters;

		/**
		 * @description Path parameters substituted into the URL template.
		 */
		private final Map<String, String> pathParameters;

		/**
		 * @description Request body replacement tokens (search -> replace).
		 */
		private final Map<String, String> requestReplacementTokens;

		/**
		 * @description Response body replacement tokens (search -> replace).
		 */
		private final Map<String, String> responseReplacementTokens;

		/**
		 * @description Request parameters for subscriber handler mode.
		 */
		private final Map<String, String> subscriberParameters;

		/**
		 * @description The serialized request body.
		 */
		private String requestBody;

		/**
		 * @description The request timeout in milliseconds.
		 */
		private Integer timeoutMs;

		/**
		 * @description Maximum number of retry attempts.
		 */
		private Integer maxRetries = 0;

		/**
		 * @description Backoff period in seconds between retries.
		 */
		private Integer backoffSeconds = 0;

		/**
		 * @description Set to true only by withExponentialBackoff, and never set back to false. When true, buildApiCall
		 * stores it with the call's inputs, and API_Outbound.createRetryStrategy reads it back: each scheduled retry then
		 * waits twice as long as the one before. A handler given to useHandler gets it too.
		 */
		private Boolean exponentialBackoff = false;

		/**
		 * @description Status codes eligible for retry.
		 */
		private Set<Integer> retryableCodes;

		/**
		 * @description Action to take on failure.
		 */
		private FailureAction failureAction;

		/**
		 * @description Set to true by either withCircuitBreaker method, and never set back to false. When true, buildApiCall
		 * stores it with the call's inputs, and the call's settings then turn the breaker on (see buildAndApplySettings).
		 */
		private Boolean useCircuitBreaker = false;

		/**
		 * @description Circuit breaker identifier.
		 */
		private String circuitName;

		/**
		 * @description Whether to skip ApiCall__c logging.
		 */
		private Boolean loggingSkipped = false;

		/**
		 * @description Correlation ID for log tracing.
		 */
		private String correlationId;

		/**
		 * @description Explicit idempotency key for duplicate detection.
		 */
		private String idempotencyKey;

		/**
		 * @description The business record that triggered this callout.
		 */
		private Id triggeringRecordId;

		/**
		 * @description The subscriber handler type for useHandler() mode.
		 */
		private final Type subscriberHandlerType;

		/**
		 * @description When true, the delegate handler's own NextRetry__c self-scheduling is
		 * suppressed for this invocation (delegation mode only).
		 */
		private Boolean handlerSelfRetrySchedulingSuppressed = false;

		/**
		 * @description Injectable mock response for this request.
		 */
		private API_MockFactory.MockResponse mockResponse;

		/**
		 * @description Cached HttpResponse from execution.
		 */
		private HttpResponse cachedResponse;

		/**
		 * @description Whether the request has been executed.
		 */
		private Boolean executed = false;

		/**
		 * @description Whether cachedResponse holds the response the builder supplied because execution
		 * produced none. That response carries no body, and the platform reads an unset body back as an
		 * empty string rather than as null, so asString() consults this flag to keep answering null.
		 */
		private Boolean responseSynthesized = false;

		/**
		 * @description The handler instance after execution.
		 */
		@TestVisible
		private DefaultOutboundHandler handlerInstance;

		/**
		 * @description The subscriber handler instance after useHandler() mode execution.
		 */
		@TestVisible
		private API_Outbound subscriberInstance;

		/**
		 * @description Constructs a RequestBuilder in ad-hoc mode.
		 *
		 * @param credential The credential name
		 */
		private RequestBuilder(String credential)
		{
			this();
			credentialName = credential;
			subscriberHandlerType = null;
			httpMethod = API_Base.HttpMethod.POST;
		}

		/**
		 * @description Constructs a RequestBuilder in subscriber handler mode.
		 *
		 * @param handlerType The API_Outbound subclass type
		 */
		private RequestBuilder(Type handlerType)
		{
			this();
			credentialName = null;
			subscriberHandlerType = handlerType;
		}

		/**
		 * @description Initialises shared collections for all constructor paths.
		 */
		private RequestBuilder()
		{
			requestHeaders = new Map<String, String>();
			queryParameters = new Map<String, String>();
			pathParameters = new Map<String, String>();
			requestReplacementTokens = new Map<String, String>();
			responseReplacementTokens = new Map<String, String>();
			subscriberParameters = new Map<String, String>();
		}

		/**
		 * @description Sets the Named Credential for the endpoint.
		 *
		 * @param credential The Named Credential name
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.useHandler(API_SendEmail.class)
		 *    .credential('EmailGateway')
		 *    .invoke();
		 * ```
		 */
		global RequestBuilder credential(String credential)
		{
			credentialName = credential;
			return this;
		}

		/**
		 * @description Replaces the path given before, including the one given to get, post, put, del or patch. The path is
		 * added to the credential's endpoint, and it can hold {name} placeholders that pathParam fills in.
		 *
		 * @param urlPath The URL path to append
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/api')
		 *    .path('/v2/send')
		 *    .send();
		 * ```
		 */
		global RequestBuilder path(String urlPath)
		{
			this.urlPath = urlPath;
			return this;
		}

		/**
		 * @description Replaces the HTTP method that get, post, put, del or patch chose. On a request built from a credential,
		 * passing null sends the request as POST.
		 *
		 * @param httpMethod The HTTP method enum value
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/data')
		 *    .method(API_Base.HttpMethod.PUT)
		 *    .send();
		 * ```
		 */
		global RequestBuilder method(API_Base.HttpMethod httpMethod)
		{
			this.httpMethod = httpMethod;
			return this;
		}

		/**
		 * @description Adds a single header to the request.
		 *
		 * @param name The header name
		 * @param value The header value
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .header('X-Custom', 'value')
		 *    .send();
		 * ```
		 */
		global RequestBuilder header(String name, String value)
		{
			requestHeaders.put(name, value);
			return this;
		}

		/**
		 * @description Adds multiple headers to the request.
		 *
		 * @param headerMap Map of header names to values
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .headers(new Map<String, String>{'X-Custom' => 'value', 'X-Trace' => 'abc'})
		 *    .send();
		 * ```
		 */
		global RequestBuilder headers(Map<String, String> headerMap)
		{
			requestHeaders.putAll(headerMap);
			return this;
		}

		/**
		 * @description Adds a query parameter to the request URL.
		 *
		 * @param name The parameter name
		 * @param value The parameter value
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.get('MyService', '/search')
		 *    .queryParam('q', 'test')
		 *    .queryParam('limit', '10')
		 *    .send();
		 * ```
		 */
		global RequestBuilder queryParam(String name, String value)
		{
			queryParameters.put(name, value);
			return this;
		}

		/**
		 * @description Replaces a {name} placeholder in the URL path with a value.
		 *
		 * @param name The placeholder name (without braces)
		 * @param value The replacement value
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.get('CRM', '/accounts/{id}')
		 *    .pathParam('id', accountId)
		 *    .send();
		 * ```
		 */
		global RequestBuilder pathParam(String name, String value)
		{
			pathParameters.put(name, value);
			return this;
		}

		/**
		 * @description Sets the request body by JSON-serializing the provided object.
		 *
		 * @param requestBody The object to serialize as JSON
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .body(new Map<String, String>{'key' => 'value'})
		 *    .send();
		 * ```
		 */
		global RequestBuilder body(Object requestBody)
		{
			this.requestBody = JSON.serialize(requestBody, true);
			return this;
		}

		/**
		 * @description Sets the request body as a raw string.
		 *
		 * @param requestBody The raw body string
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .body('{"key": "value"}')
		 *    .send();
		 * ```
		 */
		global RequestBuilder body(String requestBody)
		{
			this.requestBody = requestBody;
			return this;
		}

		/**
		 * @description Sets how long, in milliseconds, to wait for the external system to answer. Without this call, or with
		 * null, the framework's default of 120,000 milliseconds (two minutes) applies. On a request built with useHandler,
		 * the handler's own timeout applies instead.
		 *
		 * @param milliseconds The timeout value
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.get('MyService', '/data')
		 *    .timeout(30000)
		 *    .send();
		 * ```
		 */
		global RequestBuilder timeout(Integer milliseconds)
		{
			timeoutMs = milliseconds;
			return this;
		}

		/**
		 * @description Enables synchronous retry with the specified maximum attempts. After a 408 or 503 the request is
		 * sent again straight away, in the same transaction. After a 500, 502 or 504 it is sent again straight away only
		 * when it is safe to repeat: a GET, PUT or DELETE, or a request you gave an idempotency key with
		 * withIdempotencyKey. A POST or PATCH without a key is not sent again after those three, because the external
		 * system may have processed it; the call ends Failed with a line that says so. A 425 or 429 means "slow down", so
		 * it is not sent again straight away. To choose the codes yourself, use retryOn: a status you name there is sent
		 * again whatever the method, a POST or PATCH without a key included, so name a 500, 502 or 504 only when sending
		 * the request twice is safe.
		 *
		 * @param maxRetries The maximum number of retry attempts
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withRetry(3)
		 *    .send();
		 * ```
		 */
		global RequestBuilder withRetry(Integer maxRetries)
		{
			this.maxRetries = maxRetries;
			return this;
		}

		/**
		 * @description Enables synchronous retry with a linear backoff. The wait time lets the framework schedule a later
		 * retry when the attempts made straight away do not succeed. After a 408 or 503 the request is sent again straight
		 * away, in the same transaction. After a 500, 502 or 504 it is sent again, straight away or later, only when it is
		 * safe to repeat: a GET, PUT or DELETE, or a request you gave an idempotency key with withIdempotencyKey. A POST or
		 * PATCH without a key is not sent again after those three, because the external system may have processed it; the
		 * call ends Failed with a line that says so. A 425 or 429 means "slow down", so it waits for the later retry. To
		 * choose the codes yourself, use retryOn: a status you name there is sent again whatever the method, a POST or
		 * PATCH without a key included, so name a 500, 502 or 504 only when sending the request twice is safe.
		 *
		 * Through useHandler, your handler gets the same waits and the same maximum you pass here, on every run, unless it
		 * overrides createRetryStrategy; then its own strategy decides. A scheduled retry runs from the handler class alone,
		 * so it needs an API Setting record for the handler, with its API Credential and Endpoint Path filled in: the retry
		 * takes its credential and path from that record, not from the request. Without the record, the first run sends
		 * the request, but the retry it schedules ends Aborted instead of being sent.
		 *
		 * @param maxRetries The maximum number of retry attempts
		 * @param backoffSeconds The backoff period in seconds
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withRetry(3, 5)
		 *    .send();
		 * ```
		 */
		global RequestBuilder withRetry(Integer maxRetries, Integer backoffSeconds)
		{
			this.maxRetries = maxRetries;
			this.backoffSeconds = backoffSeconds;
			return this;
		}

		/**
		 * @description Retries a failed request, and makes each scheduled retry wait twice as long as the one before.
		 *
		 * Retries in the same transaction are sent again at once, because Apex cannot wait. A retry that is scheduled for
		 * later waits the base backoff the first time, then twice as long each time after that, up to 300 seconds. For a
		 * base of 2 seconds the waits are 2, 4, 8, 16 seconds and so on.
		 *
		 * Every retry already made counts towards the doubling, including the ones sent again at once in the transaction.
		 * So a retry scheduled after three re-sends in the transaction waits 16 seconds. The count adds up across runs,
		 * and the call never makes more retries in total than maxRetries. When you also call withCircuitBreaker and the
		 * circuit is open, the wait is at least the circuit's time-out.
		 *
		 * Through useHandler, your handler gets the same waits and the same maximum you pass here, on every run, unless it
		 * overrides createRetryStrategy; then its own strategy decides. A scheduled retry runs from the handler class alone,
		 * so it needs an API Setting record for the handler, with its API Credential and Endpoint Path filled in: the retry
		 * takes its credential and path from that record, not from the request. Without the record, the first run sends
		 * the request, but the retry it schedules ends Aborted instead of being sent.
		 * withRetry keeps the default waits: the base, then the base times the number of retries already made.
		 *
		 * @param maxRetries The maximum number of retry attempts
		 * @param baseBackoffSeconds The base backoff period in seconds
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withExponentialBackoff(3, 2)
		 *    .send();
		 * ```
		 */
		global RequestBuilder withExponentialBackoff(Integer maxRetries, Integer baseBackoffSeconds)
		{
			this.maxRetries = maxRetries;
			backoffSeconds = baseBackoffSeconds;
			exponentialBackoff = true;
			return this;
		}

		/**
		 * @description Chooses which HTTP status codes are worth another attempt. When the external system responds with one
		 * of the codes you list, the request is sent again straight away, in the same transaction, whatever its HTTP
		 * method: naming a code here is your choice to repeat the request. The same list decides whether a later retry is
		 * scheduled, which happens only when you also gave a wait time in `withRetry`, and a code you name is retried
		 * later too, whatever the method. A response with any other code is not retried, so an empty set retries nothing.
		 * Passing null is the same as not calling this method.
		 * Naming 500, 502 or 504 for a POST or PATCH without an idempotency key is at your own risk: the external system
		 * may have processed the request, and the call's issue, when one is logged, says so. If you do not call this
		 * method, the request is sent again straight away after a 408 or 503, and after a 500, 502 or 504 when it is safe
		 * to repeat; a POST or PATCH without an idempotency key is not sent again after a 500, 502 or 504, because the
		 * external system may have processed it. 425 and 429 mean "slow down", so the request waits for the scheduled
		 * retry instead.
		 *
		 * @param statusCodes The HTTP status codes that should be tried again
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withRetry(3)
		 *    .retryOn(new Set<Integer>{500, 503})
		 *    .send();
		 * ```
		 */
		global RequestBuilder retryOn(Set<Integer> statusCodes)
		{
			retryableCodes = statusCodes;
			return this;
		}

		/**
		 * @description Sets the failure handling strategy.
		 *
		 * @param action The failure action to apply
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
		 *    .send();
		 * ```
		 */
		global RequestBuilder onFailure(FailureAction action)
		{
			failureAction = action;
			return this;
		}

		/**
		 * @description Enables circuit breaker protection under the service's own breaker: the credential's breaker for a
		 * call built from a credential, the handler's breaker for a call made through useHandler(...). Every call to the
		 * same service shares that breaker, so once it opens after repeated failures, later calls are refused without
		 * being sent until it cools off. Calling it after withCircuitBreaker(String) drops the name given there.
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withCircuitBreaker()
		 *    .send();
		 * ```
		 */
		global RequestBuilder withCircuitBreaker()
		{
			useCircuitBreaker = true;
			circuitName = null;
			return this;
		}

		/**
		 * @description Enables circuit breaker protection under a breaker you name. Calls that give the same name share
		 * one breaker whatever credential or handler they use, and calls that give different names keep separate breakers
		 * even on the same credential, so one failing endpoint does not stop calls to another. The name also applies to a
		 * call made through useHandler(...), and the retries the framework schedules for a call built from a credential keep
		 * it. When the breaker is open, the call is refused without being sent and its error line names the breaker.
		 *
		 * @param circuitName The name of the circuit breaker this call uses
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withCircuitBreaker('payment-gateway')
		 *    .send();
		 * ```
		 */
		global RequestBuilder withCircuitBreaker(String circuitName)
		{
			useCircuitBreaker = true;
			this.circuitName = circuitName;
			return this;
		}

		/**
		 * @description Skips ApiCall__c persistence for this request.
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.get('MyService', '/healthCheck')
		 *    .skipLogging()
		 *    .send();
		 * ```
		 */
		global RequestBuilder skipLogging()
		{
			loggingSkipped = true;
			return this;
		}

		/**
		 * @description Keeps a correlation id with the call. The call record stores your transaction's logger
		 * context, including this id, so when the stored call runs again later (a scheduled retry) that run's log
		 * entries carry your transaction as their parent and keep your global context. The entries of an outbound
		 * call always correlate by the call's own trace id.
		 *
		 * @param correlationId The correlation identifier
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withCorrelationId('txn-12345')
		 *    .send();
		 * ```
		 */
		global RequestBuilder withCorrelationId(String correlationId)
		{
			this.correlationId = correlationId;
			return this;
		}

		/**
		 * @description Sets an explicit idempotency key for duplicate detection.
		 * When set, this key takes priority over auto-generated keys. It is sent as the Idempotency-Key header and recorded
		 * on the call, on send() and on a useHandler(...).invoke() alike, whether or not the service setting has Idempotency
		 * Enabled, and a POST or PATCH that carries it counts as safe to send again.
		 *
		 * @param idempotencyKey The idempotency key value
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('PaymentGateway', '/charges')
		 *    .body(chargeRequest)
		 *    .withIdempotencyKey('order-12345')
		 *    .send();
		 * ```
		 */
		global RequestBuilder withIdempotencyKey(String idempotencyKey)
		{
			this.idempotencyKey = idempotencyKey;
			return this;
		}

		/**
		 * @description Links this callout to a triggering business record.
		 *
		 * @param recordId The Salesforce record Id
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withTriggeringRecord(record.Id)
		 *    .send();
		 * ```
		 */
		global RequestBuilder withTriggeringRecord(Id recordId)
		{
			triggeringRecordId = recordId;
			return this;
		}

		/**
		 * @description Adds a request parameter for delegation mode, where your own handler class sends the request.
		 *
		 * @param name The parameter name
		 * @param value The parameter value
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.useHandler(API_SendEmail.class)
		 *    .withParameter(API_SendEmail.PARAM_SUBJECT, 'Hello')
		 *    .invoke();
		 * ```
		 */
		global RequestBuilder withParameter(String name, String value)
		{
			subscriberParameters.put(name, value);
			return this;
		}

		/**
		 * @description Adds multiple request parameters for delegation mode, where your own handler class sends the request.
		 *
		 * @param parameters Map of parameter names to values
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, String> parameters = new Map<String, String>{'key' => 'value'};
		 * UTIL_HttpClient.useHandler(API_SendEmail.class)
		 *    .withParameters(parameters)
		 *    .invoke();
		 * ```
		 */
		global RequestBuilder withParameters(Map<String, String> parameters)
		{
			subscriberParameters.putAll(parameters);
			return this;
		}

		/**
		 * @description Registers a single request body replacement token. The search token in the serialized request
		 * body will be replaced with the replace token before sending.
		 *
		 * @param searchToken The token to search for in the request body
		 * @param replaceToken The token to replace it with
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('PaymentGateway', '/charges')
		 *    .body(chargeRequest)
		 *    .replaceRequestToken('currencyIsoCode', 'currency')
		 *    .send();
		 * ```
		 */
		global RequestBuilder replaceRequestToken(String searchToken, String replaceToken)
		{
			requestReplacementTokens.put(searchToken, replaceToken);
			return this;
		}

		/**
		 * @description Registers multiple request body replacement tokens. Each search token in the serialized
		 * request body will be replaced with its corresponding replace token before sending.
		 *
		 * @param tokens Map of search tokens to their replacement values
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_HttpClient.post('PaymentGateway', '/charges')
		 *    .body(chargeRequest)
		 *    .replaceRequestTokens(new Map<String, String>{'currencyIsoCode' => 'currency', 'groupName' => 'group'})
		 *    .send();
		 * ```
		 */
		global RequestBuilder replaceRequestTokens(Map<String, String> tokens)
		{
			requestReplacementTokens.putAll(tokens);
			return this;
		}

		/**
		 * @description Registers a single response body replacement token. The search token in the response
		 * body will be replaced with the replace token after receiving.
		 *
		 * @param searchToken The token to search for in the response body
		 * @param replaceToken The token to replace it with
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * HttpResponse response = UTIL_HttpClient.get('PaymentGateway', '/charges')
		 *    .replaceResponseToken('currency', 'currencyIsoCode')
		 *    .send();
		 * ```
		 */
		global RequestBuilder replaceResponseToken(String searchToken, String replaceToken)
		{
			responseReplacementTokens.put(searchToken, replaceToken);
			return this;
		}

		/**
		 * @description Registers multiple response body replacement tokens. Each search token in the response
		 * body will be replaced with its corresponding replace token after receiving.
		 *
		 * @param tokens Map of search tokens to their replacement values
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * HttpResponse response = UTIL_HttpClient.get('PaymentGateway', '/charges')
		 *    .replaceResponseTokens(new Map<String, String>{'currency' => 'currencyIsoCode', 'group' => 'groupName'})
		 *    .send();
		 * ```
		 */
		global RequestBuilder replaceResponseTokens(Map<String, String> tokens)
		{
			responseReplacementTokens.putAll(tokens);
			return this;
		}

		/**
		 * @description Sets a mock response to inject at framework level, overriding the handler's own mock.
		 *
		 * @param mockResponse The mock response to inject
		 *
		 * @return This builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * API_MockFactory.MockResponse mock = new API_MockFactory.MockResponse();
		 * mock.body = '{"id": "12345"}';
		 * UTIL_HttpClient.post('MyService', '/send')
		 *    .withMockResponse(mock)
		 *    .send();
		 * ```
		 */
		global RequestBuilder withMockResponse(API_MockFactory.MockResponse mockResponse)
		{
			this.mockResponse = mockResponse;
			return this;
		}

		/**
		 * @description Executes the HTTP request and returns the raw HttpResponse. A response always
		 * comes back, so a caller never has to guard the return. When the request produced no response
		 * of its own, because processing failed, the configuration refused the call or the circuit was
		 * open, the response you get has status code 0, which no HTTP exchange can report, and a status
		 * line holding the first error recorded for the call. Its body is unset. Repeat calls hand back
		 * the same response object as the first call.
		 * Every failure the framework handles for a call leaves this method answering with its response rather than throwing: a
		 * call refused before it leaves the org, a transport failure, an exception in the handler, a call record that
		 * cannot be saved, a stored logger context that cannot be read, and a masking rule that blocks the failure
		 * attachments. A try/catch around this call has nothing to catch on those paths. A governor limit is the
		 * platform's own exception, outside this contract, and no Apex code can catch it.
		 *
		 * @return The HttpResponse from the callout
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * HttpResponse response = UTIL_HttpClient.get('MyService', '/data').send();
		 * ```
		 */
		global HttpResponse send()
		{
			if(!executed)
			{
				doExecute();
			}
			if(cachedResponse == null)
			{
				cachedResponse = buildSyntheticFailureResponse();
				responseSynthesized = true;
			}
			return cachedResponse;
		}

		/**
		 * @description Builds the response send() supplies when execution produced none of its own. The
		 * status code is SYNTHETIC_STATUS_CODE, which no HTTP exchange can report; the status line is the
		 * first error recorded against the handler that ran, trimmed to SYNTHETIC_STATUS_MAXIMUM_LENGTH
		 * so the stack trace recorded after it never reaches the caller. When no handler ran, or the one
		 * that ran recorded no error, or the error it recorded carries no readable message, the status
		 * line is the OutboundCall_NoRecordedError label instead.
		 * The body is never set. Every value read here is guarded, so this method cannot itself throw and
		 * the caller of send() is answered whatever went wrong.
		 *
		 * @return The response standing in for the one execution never produced.
		 */
		private HttpResponse buildSyntheticFailureResponse()
		{
			List<String> errors = invoke()?.result?.errors;
			String firstError = errors == null || errors.isEmpty() ? null : errors[0];
			String statusLine = String.isBlank(firstError) ? System.Label.OutboundCall_NoRecordedError : UTIL_String.abbreviate(firstError, SYNTHETIC_STATUS_MAXIMUM_LENGTH);

			HttpResponse syntheticResponse = new HttpResponse();
			syntheticResponse.setStatusCode(SYNTHETIC_STATUS_CODE);
			syntheticResponse.setStatus(statusLine);
			return syntheticResponse;
		}

		/**
		 * @description Executes the request and returns the response body as a String. Answers null when
		 * the request produced no response of its own, so an outcome with nothing to read stays
		 * distinguishable from a response whose body really is empty.
		 *
		 * @return The response body string
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String body = UTIL_HttpClient.get('MyService', '/data').asString();
		 * ```
		 */
		global String asString()
		{
			HttpResponse response = send();
			return responseSynthesized ? null : response?.getBody();
		}

		/**
		 * @description Executes the request and deserializes the response body as an untyped Map.
		 *
		 * @return The deserialized response as Map of String to Object
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, Object> data = UTIL_HttpClient.get('MyService', '/data').asMap();
		 * ```
		 */
		global Map<String, Object> asMap()
		{
			String body = asString();
			return String.isNotBlank(body) ? (Map<String, Object>)JSON.deserializeUntyped(body) : new Map<String, Object>();
		}

		/**
		 * @description Executes the request and deserializes the response body into the specified type.
		 *
		 * @param responseType The Apex Type to deserialize into
		 *
		 * @return The deserialized response object
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * MyDTO result = (MyDTO)UTIL_HttpClient.get('MyService', '/data')
		 *    .deserialize(MyDTO.class);
		 * ```
		 */
		global Object deserialize(Type responseType)
		{
			return JSON.deserialize(asString(), responseType);
		}

		/**
		 * @description Suppresses the delegate handler's own NextRetry__c self-scheduling for this
		 * invocation: the flag is threaded through the request parameters and applied to the fresh
		 * handler instance when it is created, before the callout runs. Framework-internal: it is for callers that
		 * manage the retries themselves (the async chain's per-step retry), so that only one piece of code schedules
		 * the retries of a call. Delegation mode (useHandler) only.
		 *
		 * @return This builder for method chaining.
		 *
		 * @since 1.6
		 */
		public RequestBuilder suppressHandlerSelfRetryScheduling()
		{
			handlerSelfRetrySchedulingSuppressed = true;
			return this;
		}

		/**
		 * @description Executes in delegation mode and returns the delegate handler instance.
		 *
		 * @return The executed API_Outbound delegate handler
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * API_Outbound handler = UTIL_HttpClient.useHandler(API_SendEmail.class)
		 *    .withTriggeringRecord(recordId)
		 *    .invoke();
		 * API_SendEmail.DTO_Response dto = (API_SendEmail.DTO_Response)handler.responsePayload;
		 * ```
		 */
		global API_Outbound invoke()
		{
			if(!executed)
			{
				doExecute();
			}
			return subscriberInstance != null ? subscriberInstance : (API_Outbound)handlerInstance;
		}

		/**
		 * @description Performs the actual HTTP execution through API_Dispatcher.
		 */
		private void doExecute()
		{
			executed = true;

			if(String.isNotBlank(correlationId))
			{
				LOG_Builder.setCorrelationId(correlationId);
			}

			ApiCall__c apiCall = buildApiCall();

			String mockServiceName = credentialName ?? apiCall.ServiceName__c;
			Boolean mockRegistered = false;

			if(mockResponse != null)
			{
				API_MockFactory.forService(mockServiceName)
						.body(mockResponse.body)
						.statusCode(mockResponse.statusCode)
						.status(mockResponse.status)
						.withHeaders(mockResponse.headers)
						.register();
				mockRegistered = true;
			}

			try
			{
				List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});

				if(!handlers.isEmpty())
				{
					API_Base handler = handlers[0];

					if(handler instanceof DefaultOutboundHandler)
					{
						handlerInstance = (DefaultOutboundHandler)handler;
						cachedResponse = handlerInstance.getHttpResponse();
						subscriberInstance = handlerInstance.getSubscriberHandler();
					}
				}
			}
			finally
			{
				if(mockRegistered)
				{
					API_MockFactory.unregisterMock(mockServiceName);
				}
			}
		}

		/**
		 * @description Builds a ApiCall__c record with DTO_NameValues parameters.
		 *
		 * @return An uncommitted API call record
		 */
		@SuppressWarnings('PMD.NcssMethodCount,PMD.NcssCount')
		private ApiCall__c buildApiCall()
		{
			DTO_NameValues parameters = new DTO_NameValues();

			if(credentialName != null)
			{
				parameters.add(KEY_CREDENTIAL, credentialName);
			}
			if(urlPath != null)
			{
				parameters.add(KEY_PATH, urlPath);
			}
			if(httpMethod != null)
			{
				parameters.add(KEY_HTTP_METHOD, API_Base.toHttpString(httpMethod));
			}
			if(requestBody != null)
			{
				parameters.add(KEY_BODY, requestBody);
			}
			if(!requestHeaders.isEmpty())
			{
				parameters.add(KEY_HTTP_HEADERS, JSON.serialize(requestHeaders));
			}
			if(!queryParameters.isEmpty())
			{
				parameters.add(KEY_QUERY_PARAMETERS, JSON.serialize(queryParameters));
			}
			if(!pathParameters.isEmpty())
			{
				parameters.add(KEY_PATH_PARAMETERS, JSON.serialize(pathParameters));
			}
			if(!requestReplacementTokens.isEmpty())
			{
				parameters.add(KEY_REQUEST_TOKENS, JSON.serialize(requestReplacementTokens));
			}
			if(!responseReplacementTokens.isEmpty())
			{
				parameters.add(KEY_RESPONSE_TOKENS, JSON.serialize(responseReplacementTokens));
			}
			if(timeoutMs != null)
			{
				parameters.add(KEY_TIMEOUT_MS, String.valueOf(timeoutMs));
			}
			if(maxRetries > 0)
			{
				parameters.add(KEY_MAX_RETRIES, String.valueOf(maxRetries));
			}
			if(backoffSeconds > 0)
			{
				parameters.add(KEY_BACKOFF_SECONDS, String.valueOf(backoffSeconds));
			}
			if(exponentialBackoff)
			{
				parameters.add(KEY_EXPONENTIAL_BACKOFF, String.valueOf(exponentialBackoff));
			}
			if(retryableCodes != null)
			{
				parameters.add(KEY_RETRYABLE_CODES, JSON.serialize(retryableCodes));
			}
			if(useCircuitBreaker)
			{
				parameters.add(KEY_CIRCUIT_BREAKER_ENABLED, String.valueOf(useCircuitBreaker));
			}
			if(circuitName != null)
			{
				parameters.add(KEY_CIRCUIT_NAME, circuitName);
			}
			if(failureAction == logFailureValue() || failureAction == retryThenLogValue())
			{
				parameters.add(KEY_LOG_FAILURES, 'true');
			}
			if(failureAction == logFailureValue())
			{
				parameters.add(KEY_SKIP_RETRY, 'true');
			}
			if(loggingSkipped)
			{
				parameters.add(KEY_SKIP_PERSISTENCE, 'true');
			}
			if(idempotencyKey != null)
			{
				parameters.add(KEY_IDEMPOTENCY_KEY, idempotencyKey);
			}

			if(subscriberHandlerType != null)
			{
				parameters.add(KEY_API_HANDLER_NAME, subscriberHandlerType.getName());
			}
			if(handlerSelfRetrySchedulingSuppressed)
			{
				parameters.add(KEY_SUPPRESS_SELF_RETRY, 'true');
			}

			for(String key : subscriberParameters.keySet())
			{
				parameters.add(key, subscriberParameters.get(key));
			}

			ApiCall__c apiCall = new ApiCall__c();
			apiCall.ServiceName__c = DefaultOutboundHandler.class.getName();
			apiCall.Direction__c = SEL_ApiCall.TYPE_OUTBOUND;

			if(triggeringRecordId != null)
			{
				apiCall.TriggeringRecordId__c = String.valueOf(triggeringRecordId);
			}

			apiCall.RequestParameters__c = parameters.serialize();

			if(String.isNotBlank(correlationId))
			{
				// doExecute has already applied the correlation id to the live logger context, so the record stores the
				// same context document every framework-built call record carries, and a later run can read it back.
				apiCall.LoggerContext__c = LOG_Builder.serializeContext();
			}

			return apiCall;
		}
	}
}