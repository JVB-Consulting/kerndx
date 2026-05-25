// SPDX-License-Identifier: BUSL-1.1
/**
 * @description REST endpoint for circuit breaker load testing. Accepts failure/success probes,
 * checks circuit breaker state via Platform Cache, and returns metrics. Designed to be hit
 * with parallel HTTP requests from external tooling to verify circuit breaker behavior under
 * concurrent load.
 *
 * @see kern.UTIL_CircuitBreaker
 *
 * @author your.name@company.com
 *
 * @group Resilience
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity')
@RestResource(UrlMapping='/v1/resilience-probe/*')
global inherited sharing class REST_ResilienceProbe
{
	/**
	 * @description Default circuit ID when none is specified in the request.
	 */
	private static final String DEFAULT_CIRCUIT_ID = 'load-test';
	/**
	 * @description Default failure threshold.
	 */
	private static final Integer DEFAULT_THRESHOLD = 5;
	/**
	 * @description Default timeout in seconds for OPEN to HALF_OPEN transition.
	 */
	private static final Integer DEFAULT_TIMEOUT = 30;

	/**
	 * @description Probes the circuit breaker. Reads circuit configuration from the JSON body
	 * (circuitId, threshold, timeout, fail), checks allowRequest(), records success or failure,
	 * and returns the current state. Returns 503 when the circuit is OPEN.
	 */
	@HttpPost
	global static void probe()
	{
		try
		{
			Map<String, Object> body = parseBody();

			String circuitId = body.containsKey('circuitId') ? String.valueOf(body.get('circuitId')) : DEFAULT_CIRCUIT_ID;
			Integer threshold = body.containsKey('threshold') ? ((Decimal)body.get('threshold')).intValue() : DEFAULT_THRESHOLD;
			Integer timeoutSeconds = body.containsKey('timeout') ? ((Decimal)body.get('timeout')).intValue() : DEFAULT_TIMEOUT;
			Boolean shouldFail = body.containsKey('fail') ? (Boolean)body.get('fail') : false;

			kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(circuitId)
					.withFailureThreshold(threshold).withTimeout(timeoutSeconds);

			if(!breaker.allowRequest())
			{
				respond(503, new Map<String, Object>
				{
						'allowed' => false, 'state' => breaker.getState().name(), 'blocked' => true
				});
				return;
			}

			if(shouldFail)
			{
				breaker.recordFailure();
			}
			else
			{
				breaker.recordSuccess();
			}

			kern.UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();
			respond(shouldFail ? 500 : 200, new Map<String, Object>
			{
					'allowed' => true, 'state' => metrics.state.name(),
					'failureCount' => metrics.failureCount, 'blocked' => false
			});
		}
		catch(Exception error)
		{
			respond(500, new Map<String, Object>
			{
					'error' => error.getMessage(), 'type' => error.getTypeName()
			});
		}
	}

	/**
	 * @description Returns the current circuit breaker state and metrics without modifying state.
	 * Accepts circuitId as a query parameter.
	 */
	@HttpGet
	global static void getState()
	{
		String circuitId = RestContext.request.params.get('circuitId');
		if(String.isBlank(circuitId))
		{
			circuitId = DEFAULT_CIRCUIT_ID;
		}

		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(circuitId)
				.withFailureThreshold(DEFAULT_THRESHOLD).withTimeout(DEFAULT_TIMEOUT);
		kern.UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();

		respond(200, new Map<String, Object>
		{
				'state' => metrics.state.name(), 'failureCount' => metrics.failureCount,
				'circuitId' => metrics.circuitId
		});
	}

	/**
	 * @description Resets the circuit breaker to CLOSED state. Accepts circuitId as a query parameter.
	 */
	@HttpDelete
	global static void resetCircuit()
	{
		String circuitId = RestContext.request.params.get('circuitId');
		if(String.isBlank(circuitId))
		{
			circuitId = DEFAULT_CIRCUIT_ID;
		}

		kern.UTIL_CircuitBreaker.monitor(circuitId)
				.withFailureThreshold(DEFAULT_THRESHOLD).withTimeout(DEFAULT_TIMEOUT).reset();
		respond(200, new Map<String, Object> {'reset' => true, 'circuitId' => circuitId});
	}

	/**
	 * @description Parses the request body as a JSON map.
	 *
	 * @return Deserialized map, or empty map if body is null/blank.
	 */
	private static Map<String, Object> parseBody()
	{
		if(RestContext.request.requestBody == null)
		{
			return new Map<String, Object>();
		}
		String raw = RestContext.request.requestBody.toString();
		if(String.isBlank(raw))
		{
			return new Map<String, Object>();
		}
		return (Map<String, Object>)JSON.deserializeUntyped(raw);
	}

	/**
	 * @description Sets the REST response status code and JSON body.
	 *
	 * @param statusCode HTTP status code.
	 * @param body Map to serialize as JSON.
	 */
	private static void respond(Integer statusCode, Map<String, Object> body)
	{
		RestContext.response.statusCode = StatusCode;
		RestContext.response.responseBody = Blob.valueOf(JSON.serialize(body));
	}
}
