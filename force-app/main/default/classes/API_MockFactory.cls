// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Central factory for mock response management.
 * Provides test isolation via scoped registries and supports both
 * memory-based (unit tests) and metadata-based (runtime) mocking.
 *
 * Features:
 * - Memory mocks for unit tests with test isolation
 * - Metadata mocks for runtime/sandbox configuration
 * - Call verification for asserting mock invocations
 * - Dynamic response interpolation ({{request.field}})
 * - Fault simulation (delays, failure rates)
 *
 * @see API_MockFactory_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, April 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Register a custom mock response for an outbound service
 * API_MockFactory.forService(API_SendEmail.class.getName())
 *     .body('{"messageId":"msg-123"}').statusCode(200).register();
 * // Register an error mock
 * API_MockFactory.registerErrorMock(API_SendEmail.class.getName());
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.CyclomaticComplexity, PMD.CognitiveComplexity')
global inherited sharing class API_MockFactory
{
	/**
	 * @description In-memory registry mapping normalized service class names to mock responses.
	 */
	private static final Map<String, MockResponse> MEMORY_REGISTRY = new Map<String, MockResponse>();
	/**
	 * @description Registry tracking mock invocations per service class for verification.
	 */
	private static final Map<String, List<MockInvocation>> INVOCATION_REGISTRY = new Map<String, List<MockInvocation>>();
	/**
	 * @description Services with transaction-scoped mock enablement. Cleared by clearMocks().
	 */
	private static final Set<String> MOCK_ENABLED_SERVICES = new Set<String>();
	/**
	 * @description Response body that will fail JSON parsing, used for testing parse error handling.
	 */
	@TestVisible
	private static final String PARSE_FAIL_RESPONSE = '****}{}{}{}{}{}{}********';

	/**
	 * @description Creates a fluent builder for registering a mock response.
	 *
	 * @param serviceClassName The fully qualified service class name
	 *
	 * @return A new MockBuilder for chaining
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_MockFactory.forService('API_SendEmail')
	 *     .body('{"messageId":"msg-123"}')
	 *     .statusCode(200)
	 *     .register();
	 * ```
	 */
	global static MockBuilder forService(String serviceClassName)
	{
		return new MockBuilder(serviceClassName);
	}

	/**
	 * @description Get mock for outbound service.
	 * Records the invocation for later verification.
	 *
	 * @param serviceClassName The service class name to look up
	 * @param settingDeveloperName Optional API setting developer name for metadata lookup
	 *
	 * @return MockResponse if found, null otherwise
	 */
	@TestVisible
	private static MockResponse getOutboundMock(String serviceClassName, String settingDeveloperName)
	{
		return getOutboundMock(serviceClassName, settingDeveloperName, null);
	}

	/**
	 * @description Get mock for outbound service with request body for interpolation.
	 * Records the invocation for later verification.
	 *
	 * @param serviceClassName The service class name to look up
	 * @param settingDeveloperName Optional API setting developer name for metadata lookup
	 * @param requestBody The request body (used for interpolation and verification)
	 *
	 * @return MockResponse if found, null otherwise
	 */
	@TestVisible
	private static MockResponse getOutboundMock(String serviceClassName, String settingDeveloperName, String requestBody)
	{
		return resolveMock(serviceClassName, settingDeveloperName, requestBody);
	}

	/**
	 * @description Get mock for inbound service with request matching.
	 * Records the invocation for later verification.
	 *
	 * @param serviceClassName The service class name
	 * @param settingDeveloperName Optional API setting developer name for metadata lookup
	 * @param requestBody The request body for pattern matching and interpolation
	 *
	 * @return MockResponse if found, null otherwise
	 */
	public static MockResponse getInboundMock(String serviceClassName, String settingDeveloperName, String requestBody)
	{
		return resolveMock(serviceClassName, settingDeveloperName, requestBody);
	}

	/**
	 * @description Resolves a mock response from memory or metadata.
	 * Records the invocation for later verification.
	 *
	 * @param serviceClassName The service class name to look up
	 * @param settingDeveloperName Optional API setting developer name for metadata lookup
	 * @param requestBody The request body (used for interpolation and verification)
	 *
	 * @return MockResponse if found, null otherwise
	 */
	private static MockResponse resolveMock(String serviceClassName, String settingDeveloperName, String requestBody)
	{
		String key = normalizeKey(serviceClassName);

		if(Test.isRunningTest())
		{
			recordInvocation(key, requestBody);
		}

		if(MEMORY_REGISTRY.containsKey(key))
		{
			MockResponse mock = MEMORY_REGISTRY.get(key);
			return applyDynamicBehavior(mock, requestBody);
		}

		if(String.isNotBlank(settingDeveloperName))
		{
			return getFromMetadata(settingDeveloperName, requestBody);
		}

		return null;
	}

	/**
	 * @description Records a mock invocation for later verification.
	 * Only records during test execution to prevent heap accumulation in production.
	 *
	 * @param key The normalized service class name
	 * @param requestBody The request body at time of invocation
	 */
	private static void recordInvocation(String key, String requestBody)
	{
		if(!INVOCATION_REGISTRY.containsKey(key))
		{
			INVOCATION_REGISTRY.put(key, new List<MockInvocation>());
		}
		MockInvocation invocation = new MockInvocation();
		invocation.requestBody = requestBody;
		invocation.timestamp = System.now();
		INVOCATION_REGISTRY.get(key).add(invocation);
	}

	/**
	 * @description Applies dynamic behavior to a mock response.
	 * Handles interpolation, delays, and failure simulation.
	 *
	 * @param mock The original mock response
	 * @param requestBody The request body for interpolation
	 *
	 * @return MockResponse with dynamic behavior applied
	 */
	private static MockResponse applyDynamicBehavior(MockResponse mock, String requestBody)
	{
		MockResponse result = mock.copy();

		if(mock.failureRate != null && mock.failureRate > 0)
		{
			Integer randomValue = Math.mod(Math.abs(Crypto.getRandomInteger()), 100);
			if(randomValue < mock.failureRate)
			{
				result.statusCode = API_Base.HTTP_INTERNAL_SERVER_ERROR;
				result.body = '{"error":"SIMULATED_FAILURE","message":"Fault injection triggered by failureRate"}';
				result.simulatedFailure = true;
			}
		}

		if(!result.simulatedFailure && String.isNotBlank(result.body) && result.body.contains('{{'))
		{
			result.body = interpolateResponse(result.body, requestBody);
		}

		return result;
	}

	/**
	 * @description Interpolates `{{request.field}}` placeholders with values from request body.
	 * Supports nested fields like `{{request.data.id}}`.
	 *
	 * **Body-required contract.** Interpolation only runs when the request body is non-blank
	 * AND the template contains the `{{` token; if either condition is false the template is
	 * returned unchanged. Mocks that need `{{request.X}}` substitution therefore require a
	 * non-blank request body — handlers without a `DTO_Request` (e.g. GET-method mocks, or
	 * outbound services that don't serialize a body before send) cannot use placeholders, and
	 * their unsubstituted templates ship through verbatim. If you need request-context-bearing
	 * mock responses for body-less requests, encode the context in path / query parameters
	 * and add explicit handler logic that consumes them, OR use the dynamic mock factory
	 * (`API_MockFactory.forService(name).body(...)` with hand-built per-call response payloads).
	 *
	 * @param template The response body template with placeholders
	 * @param requestBody The request body JSON to extract values from
	 *
	 * @return Interpolated response body, or the template unchanged when the body is blank
	 *         or the template has no placeholders
	 */
	@TestVisible
	private static String interpolateResponse(String template, String requestBody)
	{
		if(String.isBlank(requestBody) || !template.contains('{{'))
		{
			return template;
		}

		try
		{
			Map<String, Object> requestData = (Map<String, Object>)JSON.deserializeUntyped(requestBody);
			String result = template;

			Pattern placeholderPattern = Pattern.compile('\\{\\{request\\.([a-zA-Z0-9_.]+)\\}\\}');
			Matcher matcher = placeholderPattern.matcher(template);

			while(matcher.find())
			{
				String fullMatch = matcher.group(0);
				String fieldPath = matcher.group(1);
				Object value = getNestedValue(requestData, fieldPath);

				if(value != null)
				{
					result = result.replace(fullMatch, String.valueOf(value));
				}
			}

			return result;
		}
		catch(Exception parseError)
		{
			LOG_Builder.build().error(parseError).emitAt(API_MockFactory.class.getName() + '.interpolateResponse');
			return template;
		}
	}

	/**
	 * @description Gets a nested value from a map using dot notation.
	 *
	 * @param data The root map
	 * @param fieldPath The dot-separated field path (e.g., "data.account.id")
	 *
	 * @return The value at the path, or null if not found
	 */
	private static Object getNestedValue(Map<String, Object> data, String fieldPath)
	{
		List<String> parts = fieldPath.split('\\.');
		Object current = data;

		for(String part : parts)
		{
			if(current == null || !(current instanceof Map<String, Object>))
			{
				return null;
			}
			current = ((Map<String, Object>)current).get(part);
		}

		return current;
	}

	/**
	 * @description Retrieves a mock response from metadata by API setting developer name.
	 *
	 * @param settingDeveloperName The API setting developer name to look up
	 * @param requestBody The request body for matching and interpolation
	 *
	 * @return MockResponse from metadata, or null if not found
	 */
	private static MockResponse getFromMetadata(String settingDeveloperName, String requestBody)
	{
		List<ApiMock__mdt> mocks = new SEL_ApiMock().findByApiSetting(settingDeveloperName);

		for(ApiMock__mdt mock : mocks)
		{
			if(API_MockMatcher.matches(mock, requestBody))
			{
				MockResponse response = buildMockResponse(mock);
				return applyDynamicBehavior(response, requestBody);
			}
		}

		return null;
	}

	/**
	 * @description Builds a MockResponse from an ApiMock__mdt record.
	 *
	 * @param mock The metadata record
	 *
	 * @return MockResponse populated from metadata
	 */
	@TestVisible
	private static MockResponse buildMockResponse(ApiMock__mdt mock)
	{
		MockResponse response = new MockResponse();
		response.statusCode = Integer.valueOf(mock.StatusCode__c);
		response.source = MockSource.METADATA;

		response.body = mock.ResponseBody__c;

		if(String.isNotBlank(mock.ResponseHeaders__c))
		{
			try
			{
				response.headers = (Map<String, String>)JSON.deserialize(
						mock.ResponseHeaders__c, Map<String, String>.class
				);
			}
			catch(Exception parseError)
			{
				response.headers = new Map<String, String>();
				LOG_Builder.build().error(parseError).emitAt(API_MockFactory.class.getName() + '.buildMockResponse');
			}
		}

		response.delayMs = mock.DelayMs__c != null ? Integer.valueOf(mock.DelayMs__c) : 0;
		response.failureRate = mock.FailureRate__c != null ? Integer.valueOf(mock.FailureRate__c) : 0;

		return response;
	}

	/**
	 * @description Clears all registered memory mocks and invocation history.
	 *
	 * @since 1.0
	 */
	global static void clearMocks()
	{
		MEMORY_REGISTRY.clear();
		INVOCATION_REGISTRY.clear();
		MOCK_ENABLED_SERVICES.clear();
	}

	/**
	 * @description Enables mocking for a service in the current transaction.
	 * Use '*' to enable for all services.
	 *
	 * @param serviceClassName The service class name, or '*' for all
	 */
	public static void enableMocking(String serviceClassName)
	{
		MOCK_ENABLED_SERVICES.add(normalizeKey(serviceClassName));
	}

	/**
	 * @description Checks if transaction-scoped mocking is enabled.
	 *
	 * @param serviceClassName The service class name to check
	 *
	 * @return True if mocking is enabled for this service or '*'
	 */
	public static Boolean isMockingEnabled(String serviceClassName)
	{
		return MOCK_ENABLED_SERVICES.contains(normalizeKey(serviceClassName))
				|| MOCK_ENABLED_SERVICES.contains('*');
	}

	/**
	 * @description Unregisters a specific mock by service class name.
	 *
	 * @param serviceClassName The service class name to unregister
	 */
	public static void unregisterMock(String serviceClassName)
	{
		MEMORY_REGISTRY.remove(normalizeKey(serviceClassName));
	}

	/**
	 * @description Checks if a mock is registered for a service.
	 *
	 * @param serviceClassName The service class name to check
	 *
	 * @return True if a mock is registered
	 */
	public static Boolean hasMock(String serviceClassName)
	{
		return MEMORY_REGISTRY.containsKey(normalizeKey(serviceClassName));
	}

	/**
	 * @description Returns the number of times a mock was invoked.
	 *
	 * @param serviceClassName The service class name to check
	 *
	 * @return Number of invocations (0 if never called)
	 *
	 * @example
	 * ```apex
	 * API_MockFactory.forService('API_MyService').body('{}').statusCode(200).register();
	 * Assert.areEqual(1, API_MockFactory.getInvocationCount('API_MyService'), 'Service should be called once');
	 * ```
	 */
	public static Integer getInvocationCount(String serviceClassName)
	{
		String key = normalizeKey(serviceClassName);
		List<MockInvocation> invocations = INVOCATION_REGISTRY.get(key);
		return invocations != null ? invocations.size() : 0;
	}

	/**
	 * @description Returns all invocation records for a service.
	 *
	 * @param serviceClassName The service class name
	 *
	 * @return List of MockInvocation records (empty list if never called)
	 */
	@TestVisible
	private static List<MockInvocation> getInvocations(String serviceClassName)
	{
		String key = normalizeKey(serviceClassName);
		List<MockInvocation> invocations = INVOCATION_REGISTRY.get(key);
		return invocations != null ? invocations : new List<MockInvocation>();
	}

	/**
	 * @description Verifies that a mock was called at least once.
	 *
	 * @param serviceClassName The service class name to verify
	 *
	 * @return True if the mock was invoked at least once
	 *
	 * @since 1.0
	 */
	global static Boolean wasCalled(String serviceClassName)
	{
		return getInvocationCount(serviceClassName) > 0;
	}

	/**
	 * @description Verifies that a mock was called exactly N times.
	 *
	 * @param serviceClassName The service class name to verify
	 * @param expectedCount The expected number of invocations
	 *
	 * @return True if the mock was invoked exactly expectedCount times
	 */
	@TestVisible
	private static Boolean wasCalledTimes(String serviceClassName, Integer expectedCount)
	{
		return getInvocationCount(serviceClassName) == expectedCount;
	}

	/**
	 * @description Verifies that a mock was never called.
	 *
	 * @param serviceClassName The service class name to verify
	 *
	 * @return True if the mock was never invoked
	 *
	 * @since 1.0
	 */
	global static Boolean wasNeverCalled(String serviceClassName)
	{
		return getInvocationCount(serviceClassName) == 0;
	}

	/**
	 * @description Verifies that the last invocation contained specific text in the request body.
	 *
	 * @param serviceClassName The service class name
	 * @param expectedContent Text that should be present in the request body
	 *
	 * @return True if the last request body contains the expected content
	 *
	 * @since 1.0
	 */
	global static Boolean lastRequestContains(String serviceClassName, String expectedContent)
	{
		List<MockInvocation> invocations = getInvocations(serviceClassName);
		if(invocations.isEmpty())
		{
			return false;
		}
		String lastRequestBody = invocations[invocations.size() - 1].requestBody;
		return String.isNotBlank(lastRequestBody) && lastRequestBody.contains(expectedContent);
	}

	/**
	 * @description Clears invocation history without clearing mock registrations.
	 * Useful when verifying invocations within a single test that makes multiple calls.
	 */
	@TestVisible
	private static void clearInvocations()
	{
		INVOCATION_REGISTRY.clear();
	}

	/**
	 * @description Normalizes a key to lowercase for consistent lookup.
	 *
	 * @param key The key to normalize
	 *
	 * @return Normalized lowercase key
	 */
	private static String normalizeKey(String key)
	{
		return String.isBlank(key) ? '' : key.trim().toLowerCase();
	}

	/**
	 * @description Extracts headers from an HttpResponse.
	 *
	 * @param response The HttpResponse to extract headers from
	 *
	 * @return Map of header key-value pairs
	 */
	private static Map<String, String> extractHeaders(HttpResponse response)
	{
		Map<String, String> headers = new Map<String, String>();
		for(String headerKey : response.getHeaderKeys())
		{
			if(headerKey != null)
			{
				headers.put(headerKey, response.getHeader(headerKey));
			}
		}
		return headers;
	}

	/**
	 * @description Registers an error mock (500 Internal Server Error) for the given service.
	 *
	 * @param serviceClassName The service class name to register an error mock for
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_MockFactory.registerErrorMock(API_SendEmail.class.getName());
	 * ```
	 */
	global static void registerErrorMock(String serviceClassName)
	{
		forService(serviceClassName)
				.body(API_Base.ERR_INTERNAL_SERVER)
				.statusCode(API_Base.HTTP_INTERNAL_SERVER_ERROR)
				.status(API_Base.ERR_INTERNAL_SERVER)
				.register();
	}

	/**
	 * @description Registers a parse-fail mock (200 OK with unparseable body) for the given service.
	 *
	 * @param serviceClassName The service class name to register a parse-fail mock for
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_MockFactory.registerParseFailMock(API_SendEmail.class.getName());
	 * ```
	 */
	global static void registerParseFailMock(String serviceClassName)
	{
		forService(serviceClassName)
				.body(PARSE_FAIL_RESPONSE)
				.statusCode(API_Base.HTTP_OK)
				.register();
	}

	/**
	 * @description Applies a MockResponse to an HttpResponse object.
	 *
	 * @param httpResponse The HttpResponse to populate
	 * @param mock The MockResponse containing values to apply
	 */
	private static void applyToHttpResponse(HttpResponse httpResponse, MockResponse mock)
	{
		httpResponse.setStatusCode(mock.statusCode);
		if(String.isNotBlank(mock.status))
		{
			httpResponse.setStatus(mock.status);
		}
		httpResponse.setBody(mock.body);

		if(mock.headers != null)
		{
			for(String headerKey : mock.headers.keySet())
			{
				httpResponse.setHeader(headerKey, mock.headers.get(headerKey));
			}
		}
	}

	/**
	 * @description Enumeration of mock response sources.
	 */
	@TestVisible
	private enum MockSource
	{
		/**
		 * @description Mock response registered in memory via forService().
		 */
		MEMORY,

		/**
		 * @description Mock response loaded from ApiMock__mdt custom metadata.
		 */
		METADATA
	}

	/**
	 * @description Represents a mock HTTP response with fault simulation options.
	 *
	 * @since 1.0
	 */
	global class MockResponse
	{
		/**
		 * @description The response body content (supports {{request.field}} interpolation).
		 *
		 * @since 1.0
		 */
		global String body;

		/**
		 * @description The HTTP status code.
		 *
		 * @since 1.0
		 */
		global Integer statusCode;

		/**
		 * @description The HTTP status text (e.g., "OK", "Internal Server Error").
		 *
		 * @since 1.0
		 */
		global String status;

		/**
		 * @description Response headers as key-value pairs.
		 *
		 * @since 1.0
		 */
		global Map<String, String> headers;

		/**
		 * @description The source of this mock (memory, metadata, or static resource).
		 */
		@TestVisible
		private MockSource source;

		/**
		 * @description Simulated delay in milliseconds (fault injection).
		 */
		@TestVisible
		private Integer delayMs;

		/**
		 * @description Percentage of requests to fail randomly (0-100).
		 */
		@TestVisible
		private Integer failureRate;

		/**
		 * @description True if this response was the result of failure rate simulation.
		 */
		@TestVisible
		private Boolean simulatedFailure;

		/**
		 * @description Creates a new mock response with default values.
		 */
		public MockResponse()
		{
			headers = new Map<String, String>();
			statusCode = API_Base.HTTP_OK;
			status = 'OK';
			source = MockSource.MEMORY;
			delayMs = 0;
			failureRate = 0;
			simulatedFailure = false;
		}

		/**
		 * @description Creates a shallow clone of this mock response.
		 *
		 * @return A new MockResponse with the same values
		 */
		@TestVisible
		private MockResponse copy()
		{
			MockResponse cloned = new MockResponse();
			cloned.body = body;
			cloned.statusCode = statusCode;
			cloned.status = status;
			cloned.headers = headers != null ? headers.clone() : new Map<String, String>();
			cloned.source = source;
			cloned.delayMs = delayMs;
			cloned.failureRate = failureRate;
			cloned.simulatedFailure = false;
			return cloned;
		}
	}

	/**
	 * @description Records a single mock invocation for verification.
	 */
	@TestVisible
	private class MockInvocation
	{
		/**
		 * @description The request body at time of invocation.
		 */
		public String requestBody;

		/**
		 * @description Timestamp when the mock was invoked.
		 */
		public Datetime timestamp;
	}

	/**
	 * @description Fluent builder for constructing and registering mock responses.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_MockFactory.forService('API_SendEmail')
	 *     .body('{"messageId":"msg-123"}')
	 *     .statusCode(200)
	 *     .register();
	 * ```
	 */
	global class MockBuilder
	{
		/**
		 * @description The service class name for registration.
		 */
		private final String serviceClassName;

		/**
		 * @description The mock response being built.
		 */
		private final MockResponse mock;

		/**
		 * @description Creates a new MockBuilder for the given service.
		 *
		 * @param serviceClassName The fully qualified service class name
		 */
		private MockBuilder(String serviceClassName)
		{
			this.serviceClassName = serviceClassName;
			mock = new MockResponse();
		}

		/**
		 * @description Sets the response body.
		 *
		 * @param body The response body (supports {{request.field}} interpolation)
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder body(String body)
		{
			mock.body = body;
			return this;
		}

		/**
		 * @description Sets the HTTP status code.
		 *
		 * @param statusCode The HTTP status code
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder statusCode(Integer statusCode)
		{
			mock.statusCode = statusCode;
			return this;
		}

		/**
		 * @description Sets the HTTP status text.
		 *
		 * @param status The HTTP status text (e.g., "OK", "Internal Server Error")
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder status(String status)
		{
			mock.status = status;
			return this;
		}

		/**
		 * @description Adds a single response header.
		 *
		 * @param name The header name
		 * @param value The header value
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder withHeader(String name, String value)
		{
			mock.headers.put(name, value);
			return this;
		}

		/**
		 * @description Adds multiple response headers.
		 *
		 * @param headers Map of header key-value pairs
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder withHeaders(Map<String, String> headers)
		{
			mock.headers.putAll(headers);
			return this;
		}

		/**
		 * @description Populates the builder from an existing HttpResponse.
		 *
		 * @param response The HttpResponse to extract body, status code, and headers from
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder fromResponse(HttpResponse response)
		{
			mock.body = response.getBody();
			mock.statusCode = response.getStatusCode();
			mock.headers = extractHeaders(response);
			return this;
		}

		/**
		 * @description Sets the failure rate percentage for fault injection.
		 *
		 * @param failureRate Percentage of requests to fail (0-100)
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder withFailureRate(Integer failureRate)
		{
			mock.failureRate = failureRate;
			return this;
		}

		/**
		 * @description Registers the mock response in the factory.
		 *
		 * @since 1.0
		 */
		global void register()
		{
			MEMORY_REGISTRY.put(normalizeKey(serviceClassName), mock);
		}
	}

	/**
	 * @description HttpCalloutMock implementation that resolves mock responses from the API_MockFactory registry.
	 * Cascade: factory memory mock → metadata mock → defaultMockBody → ConfigurationException.
	 */
	public class CalloutMock implements HttpCalloutMock
	{
		/**
		 * @description The API class name for looking up registered mocks.
		 */
		public String apiClassName;

		/**
		 * @description Optional API setting developer name for metadata-based mock lookup.
		 */
		public String settingDeveloperName;

		/**
		 * @description Default mock response body declared by the handler via defaultMockBody property.
		 */
		public String defaultMockBody;

		/**
		 * @description Returns an HTTP response by resolving from the factory registry.
		 *
		 * @param request The HTTP request for which a mock response is needed
		 *
		 * @return The mocked HTTP response
		 */
		public HttpResponse respond(HttpRequest request)
		{
			HttpResponse httpResponse = new HttpResponse();

			MockResponse factoryMock = getOutboundMock(apiClassName, settingDeveloperName, request?.getBody());

			if(factoryMock != null)
			{
				applyToHttpResponse(httpResponse, factoryMock);
				return httpResponse;
			}

			if(String.isNotBlank(defaultMockBody))
			{
				String body = defaultMockBody;
				if(body.contains('{{'))
				{
					body = interpolateResponse(body, request?.getBody());
				}
				httpResponse.setHeader(API_Base.HTTP_CONTENT_TYPE, API_Base.HTTP_ENCODING_JSON);
				httpResponse.setStatusCode(API_Base.HTTP_OK);
				httpResponse.setBody(body);
				return httpResponse;
			}

			throw new UTIL_Exceptions.ConfigurationException
					(
							'No mock response configured for ' + apiClassName + '. Register a mock via API_MockFactory.forService() or set defaultMockBody in configure().'
					);
		}
	}
}