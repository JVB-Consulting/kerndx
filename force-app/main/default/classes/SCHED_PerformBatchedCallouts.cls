// SPDX-License-Identifier: Apache-2.0
/**
 * @description The `SCHED_PerformBatchedCallouts` class is a scheduled job responsible for processing
 * batched API calls that are queued for outbound processing. This class retrieves a list of queued API calls,
 * updates their status to indicate readiness for processing, and commits the updates to the database.
 * This enables efficient handling and scheduling of multiple API requests.
 *
 * @see SCHED_PerformBatchedCallouts_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, November 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * System.schedule('Process Batched Callouts', '0 0 0 * * ?', new SCHED_PerformBatchedCallouts());
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SCHED_PerformBatchedCallouts implements Schedulable
{
	/**
	 * @description The class and method the warning about calls that were not moved to Queued is filed under.
	 */
	@TestVisible
	private static final String LOG_LOCATION = SCHED_PerformBatchedCallouts.class.getName() + '/execute';

	/**
	 * @description The context key for the number of Batched calls that were not moved to Queued.
	 */
	@TestVisible
	private static final String CONTEXT_NOT_QUEUED_CALL_COUNT = 'notQueuedCallCount';

	/**
	 * @description The warning written when the save refused some Batched calls. Each refused call has its own error log
	 * entry. {0} is the number of calls that stay at Batched, {1} the number of Batched calls found.
	 */
	private static final String MESSAGE_CALLS_NOT_QUEUED = '{0} of {1} Batched calls could not be moved to Queued and stay at Batched. '
			+ 'Each has its own error entry.';

	/**
	 * @description Executes the scheduled job, retrieving a list of API calls that are batched and ready for outbound
	 * processing, updating their status to indicate they are queued, and committing the updated records to the database.
	 * This method allows for controlled and consistent processing of API callouts on a scheduled basis.
	 *
	 * The save ignores record sharing, so the job moves every Batched call, whoever scheduled it. It writes only the
	 * status of each call and leaves every other field as it is.
	 *
	 * A call whose save is refused anyway (for example by a validation rule) stays at Batched and gets its own error log
	 * entry, and one warning log entry says how many calls were not moved to Queued.
	 *
	 * @param context relevant context
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Schedule the job to run every day at midnight to process batched API calls.
	 * System.schedule('Process Batched API Calls', '0 0 0 * * ?', new SCHED_PerformBatchedCallouts());
	 * ```
	 */
	global void execute(SchedulableContext context)
	{
		List<ApiCall__c> apiCalls = new SEL_ApiCall().findByBatchedOutbound();
		List<ApiCall__c> queuedCalls = new List<ApiCall__c>();

		for(ApiCall__c apiCall : apiCalls)
		{
			queuedCalls.add(new ApiCall__c(Id = apiCall.Id, Status__c = SEL_ApiCall.STATUS_QUEUED));
		}

		List<Database.SaveResult> results = DML_Builder.newTransaction()
				.systemModeInternal()
				.bypassSharingInternal()
				.doUpdate(queuedCalls)
				.allowPartial()
				.execute()
				.getUpdateResults();

		Integer queuedCallCount = 0;
		for(Database.SaveResult result : results)
		{
			queuedCallCount += result.isSuccess() ? 1 : 0;
		}
		Integer notQueuedCallCount = apiCalls.size() - queuedCallCount;
		if(notQueuedCallCount > 0)
		{
			LOG_Builder.build()
					.warn(String.format(MESSAGE_CALLS_NOT_QUEUED, new List<Object> {notQueuedCallCount, apiCalls.size()}))
					.withContext(CONTEXT_NOT_QUEUED_CALL_COUNT, notQueuedCallCount)
					.emitAt(LOG_LOCATION);
		}
	}
}