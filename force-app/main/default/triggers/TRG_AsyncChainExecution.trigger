// SPDX-License-Identifier: Apache-2.0
/**
 * @description Trigger on AsyncChainExecution__c. It registers every trigger event, so a trigger action row you add
 * for this object runs on any of them. The package's own rows use the before events. Before insert and update the
 * trigger masks the record's data, so context data, step logs, and error messages persisted across the chain's
 * Queueable transactions are redacted before storage.
 *
 * @see AsyncChainExecution__c
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, November 2026
 */
trigger TRG_AsyncChainExecution on AsyncChainExecution__c (before insert, before update, before delete, after insert, after update, after delete, after undelete)
{
	new TRG_Dispatcher().run();
}