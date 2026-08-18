// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Pause-for-approval composition pattern, second leg: the invocable a
 * record-triggered flow calls when the human approves, starting the continuation chain for the
 * approved record. The record is the join between the legs; the new chain keeps its own
 * correlation identifier. Top-level class because invocable methods must live in an outer
 * class. Proof artifact for the Async Processing guide's "Pausing for an approval: two chains
 * and a hand-off" pattern.
 *
 * @see Recipe_ApprovalHandOff_DEMO
 * @see Recipe_ApprovalHandOff_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
public with sharing class Recipe_ApprovalContinuation_DEMO
{
	/**
	 * @description Flow-facing request: the record whose approval resumes the work.
	 */
	public class Request
	{
		/**
		 * @description The record whose approval resumes the work.
		 */
		@InvocableVariable(required=true) public Id recordId;
	}

	/**
	 * @description Starts the continuation chain for the approved record.
	 *
	 * @param requests Exactly one request per invocation.
	 */
	@InvocableMethod(label='Continue After Approval')
	public static void start(List<Request> requests)
	{
		if(requests.size() != 1)
		{
			throw new IllegalArgumentException('Continue After Approval handles one request per invocation.');
		}
		kern.UTIL_AsyncChain.newChain('Order Approval - Continuation')
				.withInitialContext('recordId', requests[0].recordId)
				.then(new Recipe_ApprovalHandOff_DEMO.ContinueStep())
				.execute();
	}
}
