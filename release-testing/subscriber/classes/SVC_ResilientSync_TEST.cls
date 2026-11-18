// SPDX-License-Identifier: Apache-2.0
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
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SVC_ResilientSync_TEST
{
	/** @description A transient (503) failure is retried, then surfaces on the response + ApiCall log. */
	@IsTest
	private static void shouldRetryThenSurfaceTransientFailure()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		kern.UTIL_CircuitBreaker.monitor(SVC_ResilientSync.SERVICE_NAME).reset();
		kern.API_MockFactory.forService(SVC_ResilientSync.SERVICE_NAME)
				.body('{"error":"service unavailable"}')
				.statusCode(503)
				.register();

		Test.startTest();
		HttpResponse response = new SVC_ResilientSync().fetchWithRetry();
		Test.stopTest();

		Assert.areEqual(503, response.getStatusCode(),
				'The transient failure surfaces on the response — it is never thrown at you');

		List<kern__ApiCall__c> calls = new SEL_ApiCalls().query
				.orderBy(kern__ApiCall__c.CreatedDate).descending()
				.withLimit(1)
				.toList();
		Assert.isFalse(calls.isEmpty(), 'The framework logs every callout as an ApiCall record');
		Assert.areEqual('503', calls[0].kern__StatusCode__c, 'The logged call records the failure status');
	}

	/** @description A healthy dependency hands back its body on the first attempt. */
	@IsTest
	private static void shouldReturnBodyOnSuccess()
	{
		kern.UTIL_CircuitBreaker.monitor(SVC_ResilientSync.SERVICE_NAME).reset();
		kern.API_MockFactory.forService(SVC_ResilientSync.SERVICE_NAME)
				.body('{"id":1,"title":"ok"}')
				.statusCode(200)
				.register();

		Test.startTest();
		HttpResponse response = new SVC_ResilientSync().fetchWithRetry();
		Test.stopTest();

		Assert.areEqual(200, response.getStatusCode(), 'A healthy call returns 200');
		Assert.isTrue(response.getBody().contains('"title":"ok"'), 'The body comes back for inspection');
	}

	/**
	 * @description Reads the call records the framework saves. Every read goes through a selector, in tests too, so the
	 * test keeps a short one of its own. It reads in user mode, so the person running the test needs read access to
	 * API calls.
	 */
	private with sharing class SEL_ApiCalls extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for call records.
		 */
		public SEL_ApiCalls()
		{
			super(kern__ApiCall__c.SObjectType);
		}

		/**
		 * @description Lists the fields every read returns.
		 *
		 * @return The fields.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField>
			{
					kern__ApiCall__c.kern__StatusCode__c,
					kern__ApiCall__c.kern__Retries__c,
					kern__ApiCall__c.kern__MaxRetries__c
			};
		}
	}
}
