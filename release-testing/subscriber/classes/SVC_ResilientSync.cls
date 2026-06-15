// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Calls a flaky dependency the resilient way: retry, backoff, and a circuit breaker
 * are wired straight into the framework's HTTP client. The framework retries transient failures,
 * logs every attempt, and hands you back the response to inspect — it never throws the transient
 * failure at you.
 *
 * @see SVC_ResilientSync_TEST
 *
 * @author your.name@company.com
 *
 * @group Resilience
 *
 * @date February 2026
 */
public with sharing class SVC_ResilientSync
{
	/** @description Named Credential / API name the callout targets. */
	@TestVisible
	private static final String CREDENTIAL = 'kern__API_ExampleRestApi';

	/** @description Endpoint path appended to the Named Credential. */
	@TestVisible
	private static final String ENDPOINT_PATH = '/posts/1';

	/**
	 * @description Calls the dependency with retry, exponential backoff, and a circuit breaker baked
	 * in. The framework retries transient (5xx) failures, opens the circuit on a sustained outage, and
	 * records each attempt on the ApiCall__c log record.
	 *
	 * @return The HttpResponse — inspect getStatusCode() and getBody(); the retry history is on the
	 * matching ApiCall__c record.
	 */
	public HttpResponse fetchWithRetry()
	{
		return kern.UTIL_HttpClient.get(CREDENTIAL, ENDPOINT_PATH)
				.withExponentialBackoff(3, 2)
				.withCircuitBreaker()
				.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
				.send();
	}
}
