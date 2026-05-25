// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Fluent HTTP client facade over the API_Dispatcher pipeline. Provides zero-boilerplate callouts
 * with automatic retry, circuit breaker, failure logging, performance timing, sensitive data masking,
 * and ApiCall__c lifecycle management — all routed through API_Dispatcher.execute().
 *
 * Supports two usage modes:
 * - Ad-hoc mode: Direct HTTP calls via get()/post()/put()/del()/patch() entry points
 * - Delegation mode: Subscriber handlers via useHandler() entry point
 *
 * @see UTIL_HttpClient_TEST
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
 * HttpResponse response = UTIL_HttpClient.post('PaymentGateway', '/charges')
 *    .body(chargeRequest)
 *    .withRetry(3)
 *    .send();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.ExcessiveClassLength,PMD.CyclomaticComplexity')
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
	 * @description Parameter key for maximum retry attempts.
	 */
	@TestVisible
	private static final String KEY_MAX_RETRIES = KEY_PREFIX + 'maxRetries';

	/**
	 * @description Parameter key for backoff seconds between retries.
	 */
	@TestVisible
	private static final String KEY_BACKOFF_SECONDS = KEY_PREFIX + 'backoffSeconds';

	/**
	 * @description Parameter key for exponential backoff flag.
	 */
	@TestVisible
	private static final String KEY_EXPONENTIAL_BACKOFF = KEY_PREFIX + 'exponentialBackoff';

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
	 * @description Default HTTP status codes eligible for retry.
	 */
	private static final Set<Integer> DEFAULT_RETRYABLE_CODES = new Set<Integer> {500, 502, 503, 504};

	/**
	 * @description Maximum number of synchronous retry attempts to prevent governor limit exhaustion.
	 */
	@TestVisible
	private static final Integer MAX_SYNCHRONOUS_RETRIES = 3;

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
		 * synchronous retry loop. When the request is delegated to a subscriber-supplied handler
		 * via `useHandler(HandlerClass.class)`, the subscriber handler decides its own retry
		 * behaviour and the `LOG_FAILURE` / `RETRY_THEN_LOG` distinction is observationally
		 * identical from the framework's side. Subscribers shipping their own handlers should
		 * read the `KEY_SKIP_RETRY` parameter from the inbound DTO_NameValues if they want to
		 * honour the caller's "don't retry" intent.
		 */
		LOG_FAILURE,
		/**
		 * @description Retry the request, then log a failure record if all retries are exhausted.
		 *
		 * In delegation mode (subscriber-supplied handler via `useHandler`), retry behaviour is
		 * the subscriber handler's responsibility — see `LOG_FAILURE` for the contract caveat.
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
	 * @description Creates a GET request for the specified credential and path.
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
	 * @description Creates a POST request for the specified credential and path.
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
	 * @description Creates a PUT request for the specified credential and path.
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
	 * @description Creates a PATCH request for the specified credential and path.
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
	 * @description Creates a delegation mode request for the specified subscriber handler.
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
		 * For delegation mode, calls setApiCall directly then delegates.
		 * For normal mode, super.process() handles the full lifecycle (setApiCall is called by API_Base.process).
		 *
		 * @param apiCallRecord The API call to process
		 */
		public override void process(ApiCall__c apiCallRecord)
		{
			if(hasSubscriberHandler(apiCallRecord))
			{
				setApiCall(apiCallRecord);
				processSubscriberHandler(apiCallRecord);
			}
			else
			{
				super.process(apiCallRecord);
			}
		}

		/**
		 * @description Framework validation hook. Builds and applies in-memory settings before
		 * the standard validation runs, ensuring settings are available for circuit breaker checks etc.
		 *
		 * @return True if the request should be aborted
		 */
		protected override Boolean performValidation()
		{
			buildAndApplySettings();
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
		 * @description Sends the request with synchronous retry logic.
		 *
		 * @param requestObj The HTTP request to send
		 */
		public override void sendRequest(HttpRequest requestObj)
		{
			String maxRetriesValue = inputs.get(KEY_MAX_RETRIES);
			String retryableCodesJson = inputs.get(KEY_RETRYABLE_CODES);
			String skipRetryValue = inputs.get(KEY_SKIP_RETRY);

			Integer maxAttempts = Math.min
					(
							1 + (maxRetriesValue != null ? Integer.valueOf(maxRetriesValue) : 0),
							1 + MAX_SYNCHRONOUS_RETRIES
					);
			Set<Integer> codes = retryableCodesJson != null
					? (Set<Integer>)JSON.deserialize(retryableCodesJson, Set<Integer>.class)
					: DEFAULT_RETRYABLE_CODES;
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
				Boolean isRetryable = codes.contains(statusCode);

				if(attempt < (maxAttempts - 1) && isRetryable)
				{
					continue;
				}

				break;
			}

			if(retriesPerformed > 0)
			{
				apiCall.Retries__c = retriesPerformed;
			}
		}

		/**
		 * @description Returns the HTTP response.
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
		 * @description Builds and applies in-memory ApiSetting__mdt from inputs.
		 */
		private void buildAndApplySettings()
		{
			String backoffValue = inputs.get(KEY_BACKOFF_SECONDS);
			String circuitBreakerValue = inputs.get(KEY_CIRCUIT_BREAKER_ENABLED);
			String logFailuresValue = inputs.get(KEY_LOG_FAILURES);
			String maxRetriesValue = inputs.get(KEY_MAX_RETRIES);
			String pathValue = inputs.get(KEY_PATH);
			String settingName = inputs.get(KEY_API_HANDLER_NAME) ?? getServiceName();
			String explicitIdempotencyKey = inputs.get(KEY_IDEMPOTENCY_KEY);

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

			if(String.isNotBlank(explicitIdempotencyKey))
			{
				apiCall.IdempotencyKey__c = explicitIdempotencyKey;
			}
		}

		/**
		 * @description Delegates processing to a subscriber handler.
		 *
		 * @param apiCallRecord The API call to process
		 */
		private void processSubscriberHandler(ApiCall__c apiCallRecord)
		{
			String handlerName = inputs.get(KEY_API_HANDLER_NAME);
			Type handlerType = UTIL_System.getTypeForClassName(handlerName, API_Outbound.class);
			subscriberHandler = (API_Outbound)handlerType.newInstance();
			subscriberHandler.skipPersistence = true;

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
				if(!key.startsWith(KEY_PREFIX))
				{
					subscriberInputs.add(key, inputs.get(key));
				}
			}

			apiCallRecord.RequestParameters__c = subscriberInputs.isEmpty()
					? null
					: subscriberInputs.serialize();

			applySubscriberSettings(handlerName, callerOverrides);

			try
			{
				subscriberHandler.process(apiCallRecord);
				subscriberHandler.commitWork();
			}
			catch(Exception error)
			{
				subscriberHandler.handleError(error);
				subscriberHandler.setApiCallDetails();
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

			Boolean hasCredential = String.isNotBlank(subscriberHandler.namedCredentialOverride);
			if(!hasCredential && subscriberHandler.defaultMockBody != null)
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
		 * @description The HTTP method for this request.
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
		 * @description Whether to use exponential backoff.
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
		 * @description Whether to use a circuit breaker.
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
		 * @description Sets the URL path for the request.
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
		 * @description Sets the HTTP method for the request.
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
		 * @description Sets the request timeout in milliseconds.
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
		 * @description Enables synchronous retry with the specified maximum attempts.
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
		 * @description Enables synchronous retry with a linear backoff.
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
		 * @description Enables synchronous retry with exponential backoff.
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
		 * @description Restricts retry to specific HTTP status codes.
		 *
		 * @param statusCodes The status codes eligible for retry
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
		 * @description Enables circuit breaker protection using the credential name as identifier.
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
			circuitName = credentialName;
			return this;
		}

		/**
		 * @description Enables circuit breaker protection with a custom identifier.
		 *
		 * @param circuitName The circuit breaker identifier
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
		 * @description Sets a correlation ID for cross-transaction log tracing.
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
		 * When set, this key takes priority over auto-generated keys.
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
		 * @description Adds a request parameter for subscriber handler mode.
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
		 * @description Adds multiple request parameters for subscriber handler mode.
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
		 * @description Executes the HTTP request and returns the raw HttpResponse.
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
			return cachedResponse;
		}

		/**
		 * @description Executes the request and returns the response body as a String.
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
			return send()?.getBody();
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

			ApiCall__c apiCall = buildApiCall();

			if(String.isNotBlank(correlationId))
			{
				LOG_Builder.setCorrelationId(correlationId);
			}

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
		@SuppressWarnings('PMD.NcssMethodCount')
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
				apiCall.LoggerContext__c = correlationId;
			}

			return apiCall;
		}
	}
}