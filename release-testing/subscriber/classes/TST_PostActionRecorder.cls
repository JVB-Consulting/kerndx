// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test post-trigger action that records each invocation into a
 * transaction-scoped static ledger and emits a KernDX log entry. Drives the Phase-2
 * post-trigger-action sections' assertions for once-per-transaction firing, the touched
 * SObject-type context, and Order__c execution ordering. Also the shared observation surface
 * the other release-test post-actions append to — `record`/`reset` are static and resolve in
 * the subscriber's local namespace, so the section anon-Apex reads them directly after DML.
 * Logging publishes a platform event (no synchronous DML), so it never trips the framework's
 * no-DML contract.
 *
 * @author developer@kerndx.com
 *
 * @group Release Testing
 *
 * @date June 2026
 */
global with sharing class TST_PostActionRecorder implements kern.IF_Trigger.PostAction
{
	/**
	 * @description Action names in the order the framework invoked them this transaction.
	 * Section scripts assert this against the rows' `Order__c` configuration.
	 */
	public static List<String> executionOrder = new List<String>();

	/**
	 * @description Per-action invocation counts for this transaction. One top-level DML
	 * statement fires post-actions once, so an action invoked by a single DML has count 1.
	 */
	public static Map<String, Integer> invocationCounts = new Map<String, Integer>();

	/**
	 * @description Distinct SObject type names observed across every recorded invocation's
	 * `PostActionContext.touchedSObjectTypes` this transaction.
	 */
	public static Set<String> touchedTypeNames = new Set<String>();

	/**
	 * @description Clears the static ledger. Section scripts call this before exercising DML
	 * so assertions read only the invocations they triggered.
	 */
	public static void reset()
	{
		executionOrder = new List<String>();
		invocationCounts = new Map<String, Integer>();
		touchedTypeNames = new Set<String>();
	}

	/**
	 * @description Appends one invocation to the shared ledger.
	 *
	 * @param actionName The recording action's short name.
	 * @param context The post-action context supplied by the framework.
	 */
	public static void record(String actionName, kern.IF_Trigger.PostActionContext context)
	{
		executionOrder.add(actionName);
		Integer priorCount = invocationCounts.get(actionName) ?? 0;
		invocationCounts.put(actionName, priorCount + 1);
		if(context?.touchedSObjectTypes != null)
		{
			for(Schema.SObjectType touchedType : context.touchedSObjectTypes)
			{
				touchedTypeNames.add(String.valueOf(touchedType));
			}
		}
	}

	/**
	 * @description Records this invocation and emits a transaction-audit log entry via a
	 * platform event (asynchronous persistence — no synchronous DML).
	 *
	 * @param context The post-action context supplied by the framework.
	 */
	global void execute(kern.IF_Trigger.PostActionContext context)
	{
		record('Recorder', context);
		kern.LOG_Builder.build()
				.info('TST_PostActionRecorder fired for ' + touchedTypeNames.size() + ' SObject type(s)')
				.emitAt('TST_PostActionRecorder.execute');
	}
}
