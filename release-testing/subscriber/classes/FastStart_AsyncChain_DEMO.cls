// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Async chain step that enriches an Account by stamping a Description.
 *
 * Extend kern.UTIL_AsyncChain.ChainStep and implement work(). The framework calls
 * work() inside its own Queueable transaction, passing a shared ChainContext that
 * carries state from earlier steps in the chain.
 *
 * The class is global so the managed package's reflection-based step resolver can
 * instantiate it. A public no-arg constructor is required (Apex provides one when
 * no constructors are declared).
 *
 * @see FastStart_AsyncChain_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
global inherited sharing class FastStart_AsyncChain_DEMO extends kern.UTIL_AsyncChain.ChainStep
{
	/** @description Chain context key that carries the Account Id to enrich. */
	public static final String CONTEXT_KEY_ACCOUNT_ID = 'accountId';

	/** @description Description value stamped on the enriched Account. */
	@TestVisible
	private static final String ENRICHMENT_NOTE = 'Enriched by Fast Start chain';

	/** @description Error message returned when the context is missing the account Id. */
	@TestVisible
	private static final String ERROR_MISSING_ACCOUNT_ID = 'Missing accountId in chain context';

	/**
	 * @description Reads the Account Id from context, updates the Account's Description.
	 *
	 * Returns a failed StepResult when the context does not carry an accountId — this
	 * causes the chain to stop and the AsyncChainExecution__c row to record the failure.
	 *
	 * @param context Shared chain context from upstream steps.
	 *
	 * @return StepResult indicating success with the enriched Account Id, or failure
	 *         when the context is missing the accountId key.
	 */
	global override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
	{
		Id accountId = (Id)context.get(CONTEXT_KEY_ACCOUNT_ID);

		if(accountId == null)
		{
			return kern.UTIL_AsyncChain.failed(ERROR_MISSING_ACCOUNT_ID);
		}

		Account record = new Account(Id = accountId, Description = ENRICHMENT_NOTE);
		kern.DML_Builder.newTransaction().doUpdate(record).execute();

		return kern.UTIL_AsyncChain.succeeded('Account enriched', accountId);
	}
}
