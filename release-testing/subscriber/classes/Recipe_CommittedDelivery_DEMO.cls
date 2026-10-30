// SPDX-License-Identifier: Apache-2.0
/**
 * @description Transactional-outbox composition pattern: an after-update trigger action detects
 * the closed transition and starts ONE delivery chain per trigger invocation, one ApiStep per
 * closed case. The enqueue is transaction-bound, so a rolled-back save enqueues nothing (no
 * ghost call), and a committed save gets loud, retried, dead-lettered delivery. Uses retryOn
 * (1.7 surface): this artifact's proof runs at the Stage B beta install. Proof artifact for
 * the Async Processing guide's "Calling an external system only after the transaction commits"
 * pattern.
 *
 * @see Recipe_CaseDelivery_SERVICE
 * @see Recipe_CommittedDelivery_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
public with sharing class Recipe_CommittedDelivery_DEMO extends kern.TRG_Base implements kern.IF_Trigger.AfterUpdate
{
	/**
	 * @description The status value whose transition starts a delivery.
	 */
	public static final String STATUS_CLOSED = 'Closed';

	/**
	 * @description The delivery chain's name; one chain per trigger transaction.
	 */
	public static final String CHAIN_NAME = 'Closed Case Delivery';

	/**
	 * @description HTTP statuses worth retrying; deterministic client errors stay out of the
	 * retry budget.
	 */
	public static final Set<Integer> RETRYABLE_STATUSES = new Set<Integer>{ 500, 502, 503, 504 };

	/**
	 * @description Detects cases that just closed and starts one delivery chain carrying one
	 * web-service step per case.
	 *
	 * @param newRecords The updated cases.
	 * @param oldRecords The pre-update cases.
	 */
	public void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		Map<Id, Case> oldById = new Map<Id, Case>((List<Case>) oldRecords);
		List<Case> justClosed = new List<Case>();
		for(Case currentCase : (List<Case>) newRecords)
		{
			if(currentCase.Status == STATUS_CLOSED && oldById.get(currentCase.Id)?.Status != STATUS_CLOSED)
			{
				justClosed.add(currentCase);
			}
		}
		if(justClosed.isEmpty())
		{
			return;
		}
		kern.UTIL_AsyncChain.ChainBuilder delivery = kern.UTIL_AsyncChain.newChain(CHAIN_NAME);
		for(Case closedCase : justClosed)
		{
			delivery.then(new kern.UTIL_AsyncChain.ApiStep(Recipe_CaseDelivery_SERVICE.class)
					.triggeringRecord(closedCase.Id)
					.withRetry(3, 60)
					.retryOn(RETRYABLE_STATUSES));
		}
		delivery.execute();
	}
}
