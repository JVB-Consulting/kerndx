// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller Class used by the retry component(s). Supports both outbound
 * retry (re-executes the API call) and inbound replay (re-simulates the request).
 *
 * @see CTRL_RetryApiIssue_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, June 2026
 */
public inherited sharing class CTRL_RetryApiIssue
{
	/**
	 * @description Error message when retry setting is not enabled.
	 */
	@TestVisible
	private final static String MESSAGE_RETRY_FAILURE = 'Retry Failure is not enabled for this API call';

	/**
	 * @description Error message when inbound replay fails without specific errors.
	 */
	@TestVisible
	private static final String MESSAGE_INBOUND_REPLAY_FAILURE = 'Inbound replay failed';

	/**
	 * @description Will retry the API call
	 *
	 * @param recordId The id of the record
	 *
	 * @return DTO_Response
	 */
	@AuraEnabled
	public static DTO_Response retry(Id recordId)
	{
		ApiIssue__c apiIssue = (ApiIssue__c)new SEL_ApiIssue().findById(recordId);

		ApiSetting__mdt settings = new SEL_ApiSetting().findByClassName(apiIssue.ServiceName__c);

		DTO_Response dtoResponse = new DTO_Response();
		dtoResponse.callSuccessful = false;

		if(settings.RetryIssues__c)
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(apiIssue.ServiceName__c, apiIssue.TriggeringRecordId__c);
			apiCall.RequestParameters__c = apiIssue.RequestParameters__c;
			apiCall.IdempotencyKey__c = apiIssue.IdempotencyKey__c;

			API_Base handler = API_Dispatcher.execute(apiCall);

			if(handler.result.isSuccess)
			{
				apiIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
				DML_Builder.newTransaction().systemModeInternal().doUpdate(apiIssue).execute();
				dtoResponse.callSuccessful = true;
			}
			else
			{
				dtoResponse.errorMessage = handler.errorText;
			}
		}
		else
		{
			dtoResponse.errorMessage = MESSAGE_RETRY_FAILURE;
		}

		return dtoResponse;
	}

	/**
	 * @description Unified resolve action — handles both Outbound and Inbound failures.
	 * Routes to outbound retry or inbound replay based on the failure's direction.
	 *
	 * @param failureId The ApiIssue__c record ID to resolve
	 *
	 * @return DTO_Response
	 */
	@AuraEnabled
	public static DTO_Response resolveFailure(Id failureId)
	{
		ApiIssue__c apiIssue = (ApiIssue__c)new SEL_ApiIssue().findById(failureId);

		if(apiIssue.Direction__c == SEL_ApiCall.TYPE_INBOUND)
		{
			return replayInboundCall(apiIssue);
		}

		return retry(failureId);
	}

	/**
	 * @description Replays an inbound API call using the invoker. Safe Mode is disabled
	 * so changes persist on success.
	 *
	 * @param apiIssue The inbound failure record to replay
	 *
	 * @return DTO_Response with the result
	 */
	private static DTO_Response replayInboundCall(ApiIssue__c apiIssue)
	{
		DTO_Response dtoResponse = new DTO_Response();
		dtoResponse.callSuccessful = false;

		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(apiIssue.Id, false);

		if(invocationResult.success)
		{
			apiIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
			apiIssue.ResolvedDate__c = Datetime.now();
			DML_Builder.newTransaction().systemModeInternal().doUpdate(apiIssue).execute();
			dtoResponse.callSuccessful = true;
		}
		else
		{
			dtoResponse.errorMessage = String.isNotBlank(invocationResult.errorText)
					? invocationResult.errorText
					: MESSAGE_INBOUND_REPLAY_FAILURE;
		}

		return dtoResponse;
	}

	/**
	 * @description Schedules bulk retry of failures with staggered start using asynchronous processing.
	 *
	 * @param serviceName The service to retry failures for
	 * @param delayMinutes Minutes to delay before starting (spreads load)
	 *
	 * @return The async job ID, or null if no failures found
	 */
	public static Id scheduleBulkRetry(String serviceName, Integer delayMinutes)
	{
		List<ApiIssue__c> failures = new SEL_ApiIssue().findUnresolvedByService(serviceName);

		if(failures.isEmpty())
		{
			return null;
		}

		List<Object> items = new List<Object>();
		items.addAll(failures);

		Integer calloutSafeJobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items)
						.withDelayMinutes(delayMinutes)
						.withBatchSize(calloutSafeJobSize)
						.withQueueableJobSize(calloutSafeJobSize);

		return UTIL_AsynchronousJobLauncher.process(request, new FailureReplayProcessor());
	}

	/**
	 * @description Inner class to define structure of response body
	 */
	public class DTO_Response extends DTO_JsonBase
	{
		/**
		 * @description Boolean flag to identify if call is successful or not
		 */
		@AuraEnabled
		public Boolean callSuccessful;
		/**
		 * @description error message
		 */
		@AuraEnabled
		public String errorMessage;
	}

	/**
	 * @description Processor for bulk failure retry with staggered execution.
	 * Implements IF_Async.Processable for use with UTIL_AsynchronousJobLauncher.
	 */
	public class FailureReplayProcessor implements IF_Async.Processable
	{
		/**
		 * @description Resolves each failure in the batch.
		 *
		 * @param items The list of ApiIssue__c records to process
		 */
		public void execute(List<Object> items)
		{
			for(Integer index = 0; index < items.size(); index++)
			{
				if(index > 0 && API_Dispatcher.isCalloutBudgetExhausted())
				{
					LOG_Builder.build()
							.warn((items.size() - index) + ' failure replay(s) deferred — callout budget exhausted')
							.emitAt(CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor');
					break;
				}
				ApiIssue__c failure = (ApiIssue__c)items.get(index);
				CTRL_RetryApiIssue.resolveFailure(failure.Id);
			}
		}
	}
}