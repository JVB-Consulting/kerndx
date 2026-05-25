// SPDX-License-Identifier: BUSL-1.1
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
 * @date February 2026, May 2026
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
	 * @description Executes the scheduled job, retrieving a list of API calls that are batched and ready for outbound
	 * processing, updating their status to indicate they are queued, and committing the updated records to the database.
	 * This method allows for controlled and consistent processing of API callouts on a scheduled basis.
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

		for(ApiCall__c apiCall : apiCalls)
		{
			apiCall.Status__c = SEL_ApiCall.STATUS_QUEUED;
		}

		DML_Builder.newTransaction().withSystemMode().doUpdate(apiCalls).allowPartial().execute();
	}
}