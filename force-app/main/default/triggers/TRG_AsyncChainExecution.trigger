// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger on AsyncChainExecution__c. Fires the configured trigger actions for
 * data masking before insert and update so context data, step logs, and error messages
 * persisted across the chain's Queueable transactions are redacted before storage.
 *
 * @see AsyncChainExecution__c
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026
 */
trigger TRG_AsyncChainExecution on AsyncChainExecution__c (before insert, before update)
{
	new TRG_Dispatcher().run();
}