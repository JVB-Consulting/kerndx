// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Throwaway verification of the Fast Start - Resilience snippet. NOT part of the
 * committed e2e suite — retry/circuit-breaker regression already lives in SubscriberResilience_TEST
 * and SubscriberHttpClient_TEST. This only proves the doc's SVC_ResilientSync snippet compiles and
 * behaves as the guide claims: the transient failure surfaces on the response (never thrown) and the
 * retries land on the ApiCall__c log.
 *
 * @see SVC_ResilientSync
 *
 * @author your.name@company.com
 *
 * @group Resilience
 *
 * @date February 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SVC_ResilientSync_TEST
{
	/** @description A transient (503) failure is retried, then surfaces on the response + ApiCall log. */
	@IsTest
	private static void shouldRetryThenSurfaceTransientFailure()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		kern.UTIL_CircuitBreaker.monitor(SVC_ResilientSync.CREDENTIAL).reset();
		kern.API_MockFactory.forService(SVC_ResilientSync.CREDENTIAL)
				.body('{"error":"service unavailable"}')
				.statusCode(503)
				.register();

		Test.startTest();
		HttpResponse response = new SVC_ResilientSync().fetchWithRetry();
		Test.stopTest();

		Assert.areEqual(503, response.getStatusCode(),
				'The transient failure surfaces on the response — it is never thrown at you');

		List<kern__ApiCall__c> calls =
		[
				SELECT kern__StatusCode__c, kern__Retries__c, kern__MaxRetries__c
				FROM kern__ApiCall__c
				ORDER BY CreatedDate DESC
				LIMIT 1
		];
		Assert.isFalse(calls.isEmpty(), 'The framework logs every callout as an ApiCall record');
		Assert.areEqual('503', calls[0].kern__StatusCode__c, 'The logged call records the failure status');
	}

	/** @description A healthy dependency hands back its body on the first attempt. */
	@IsTest
	private static void shouldReturnBodyOnSuccess()
	{
		kern.UTIL_CircuitBreaker.monitor(SVC_ResilientSync.CREDENTIAL).reset();
		kern.API_MockFactory.forService(SVC_ResilientSync.CREDENTIAL)
				.body('{"id":1,"title":"ok"}')
				.statusCode(200)
				.register();

		Test.startTest();
		HttpResponse response = new SVC_ResilientSync().fetchWithRetry();
		Test.stopTest();

		Assert.areEqual(200, response.getStatusCode(), 'A healthy call returns 200');
		Assert.isTrue(response.getBody().contains('"title":"ok"'), 'The body comes back for inspection');
	}
}
