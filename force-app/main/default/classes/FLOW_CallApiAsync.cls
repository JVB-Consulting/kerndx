// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Asynchronously invokes web service calls, allowing large or delayed API callouts
 * to be processed outside of immediate flows or triggers. Leverages the adaptive asynchronous
 * processor to manage API requests efficiently.
 *
 * @see FLOW_CallApiAsync_TEST
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
 * List<ApiCall__c> apiCalls = new List<ApiCall__c>();
 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_GetCustomerInfo', recordId, new Map<String, String>{'customerId' => '5678'});
 * apiCalls.add(apiCall);
 * FLOW_CallApiAsync.invokeApiCallAsynchronously(apiCalls);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_CallApiAsync
{
	/**
	 * @description Default job size for API callout processing. Keeps each async execution within
	 * the 100-callout governor limit while targeting ~60s wall-clock time at ~3s per callout.
	 * Subscribers can override via `AsynchronousJobSetting__mdt.FLOW_CallApiAsync`.
	 */
	public static final Integer DEFAULT_JOB_SIZE = 20;

	/**
	 * @description Hard ceiling for callout job size, equal to the Salesforce governor limit for
	 * callouts per transaction (`Limits.getLimitCallouts()`). Applied after reading
	 * `AsynchronousJobSetting__mdt` to prevent a misconfigured `BatchSize__c` from causing
	 * `System.LimitException: Too many callouts`.
	 *
	 * @since 1.0
	 */
	public static final Integer MAXIMUM_CALLOUT_JOB_SIZE = 100;

	/**
	 * @description Invokes web service calls asynchronously by enqueuing Queueable jobs for each set of API calls.
	 * Falls back to Batch job if Queueable limits are exceeded. The job size is read from
	 * `AsynchronousJobSetting__mdt.FLOW_CallApiAsync` (default: 20) to keep each execution within
	 * the 100-callout governor limit.
	 *
	 * @param apiCalls The list of API calls containing details for API callouts.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = new List<ApiCall__c>();
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_GetCustomerInfo', null, new Map<String, String>{'customerId' => '5678'});
	 * apiCalls.add(apiCall);
	 * FLOW_CallApiAsync.invokeApiCallAsynchronously(apiCalls);
	 * ```
	 */

	@InvocableMethod
	(
			Category='Api Callouts'
			Label='Invoke Callout Asynchronously'
			Description='Queues an HTTP callout asynchronously. Use when a Flow sends data to an external service and does not need to wait for the response.'
	)
	global static void invokeApiCallAsynchronously(List<ApiCall__c> apiCalls)
	{
		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), DEFAULT_JOB_SIZE),
				MAXIMUM_CALLOUT_JOB_SIZE
		);
		UTIL_AsynchronousJobLauncher.process(apiCalls, new ApiCallProcessor(), jobSize);
	}

	/**
	 * @description Processor that executes API call records via the API dispatcher.
	 */
	private class ApiCallProcessor implements IF_Async.Processable
	{
		/**
		 * @description Executes the API callouts for the provided API calls.
		 *
		 * @param items The list of ApiCall__c records to process.
		 */
		public void execute(List<Object> items)
		{
			List<ApiCall__c> apiCalls = new List<ApiCall__c>();
			for(Object item : items)
			{
				apiCalls.add((ApiCall__c)item);
			}
			API_Dispatcher.execute(apiCalls);
		}
	}
}