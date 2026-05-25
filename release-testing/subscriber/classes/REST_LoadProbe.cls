// SPDX-License-Identifier: BUSL-1.1
/**
 * @description REST endpoint for callout-storm load testing. Accepts a POST with a failRate parameter
 * (0-100) that controls the probability of an outbound failure simulation. Used by section-51 of the
 * extended-load test suite to verify retry and circuit breaker behavior under sustained parallel HTTP
 * pressure. DELETE resets the circuit breaker. GET returns current circuit state.
 *
 * @see API_LoadProbe
 * @see kern.UTIL_CircuitBreaker
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date May 2026
 */
@RestResource(UrlMapping='/v1/load-probe')
global inherited sharing class REST_LoadProbe
{
	/**
	 * @description Default circuit breaker identifier used by the load probe.
	 */
	private static final String DEFAULT_CIRCUIT_ID = 'load-probe';

	/**
	 * @description Default circuit breaker failure threshold.
	 */
	private static final Integer DEFAULT_THRESHOLD = 5;

	/**
	 * @description Default circuit breaker open-to-half-open timeout in seconds.
	 */
	private static final Integer DEFAULT_TIMEOUT = 30;

	/**
	 * @description Handles POST requests. Dispatches to API_LoadProbe via the inbound API framework.
	 * The request body should be a JSON object with a {@code failRate} integer (0-100) and an optional
	 * {@code circuitId} string.
	 */
	@HttpPost
	global static void probe()
	{
		kern.API_Dispatcher.processInboundService(API_LoadProbe.class.getName());
	}

	/**
	 * @description Handles DELETE requests. Resets the circuit breaker for the given circuitId
	 * (defaults to {@code load-probe}) so subsequent load test runs begin from a CLOSED state.
	 * Accepts {@code circuitId} as a query parameter.
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
				.withFailureThreshold(DEFAULT_THRESHOLD)
				.withTimeout(DEFAULT_TIMEOUT)
				.reset();

		RestContext.response.statusCode = 200;
		RestContext.response.responseBody = Blob.valueOf(JSON.serialize(
				new Map<String, Object>{'reset' => true, 'circuitId' => circuitId}
		));
	}

	/**
	 * @description Handles GET requests. Returns the current circuit breaker metrics without
	 * modifying state. Accepts {@code circuitId} as a query parameter.
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
				.withFailureThreshold(DEFAULT_THRESHOLD)
				.withTimeout(DEFAULT_TIMEOUT);

		kern.UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();

		RestContext.response.statusCode = 200;
		RestContext.response.responseBody = Blob.valueOf(JSON.serialize(
				new Map<String, Object>
				{
						'state' => metrics.state.name(),
						'failureCount' => metrics.failureCount,
						'circuitId' => metrics.circuitId
				}
		));
	}
}
